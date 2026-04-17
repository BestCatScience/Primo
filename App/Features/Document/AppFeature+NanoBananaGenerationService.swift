import ComposableArchitecture
import Foundation

extension AppFeature {
    private struct NanoBananaValidatedEdit {
        let normalizedRequest: NanoBananaGenerationRequest
        let adjustedSelection: CanvasSelection?
        let outputLayerIndex: Int
        let canvasWidth: Int
        let canvasHeight: Int
        let sourceLayerPixelData: Data
        let beforePreviewImageData: Data?
        let appLanguage: AppLanguage
        let trimmedPrompt: String
    }

    private struct NanoBananaValidationError: LocalizedError {
        let message: String

        var errorDescription: String? {
            message
        }
    }

    private struct NanoBananaRequestContract {
        func validate(
            request: NanoBananaGenerationRequest,
            state: AppFeature.State
        ) -> Result<NanoBananaValidatedEdit, NanoBananaValidationError> {
            let trimmedPrompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedCredential = request.config.credential.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedEndpoint = request.config.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPrompt.isEmpty else {
                return .failure(
                    NanoBananaValidationError(
                        message: state.application.appLanguage.localized("Enter a prompt for Nano Banana")
                    )
                )
            }
            guard request.config.accessMode == .appManaged || !trimmedCredential.isEmpty else {
                return .failure(
                    NanoBananaValidationError(
                        message: state.application.appLanguage.localized("Enter your Gemini API key")
                    )
                )
            }
            guard request.config.accessMode == .userAPIKey || !trimmedEndpoint.isEmpty else {
                return .failure(
                    NanoBananaValidationError(
                        message: state.application.appLanguage.localized("Enter your app server endpoint")
                    )
                )
            }
            guard
                let snapshot = state.canvas.renderSnapshot,
                let layer = snapshot.layers.first(where: { $0.index == request.inputLayerIndex })
            else {
                return .failure(
                    NanoBananaValidationError(
                        message: state.application.appLanguage.localized("Could not prepare the active layer for Nano Banana")
                    )
                )
            }

            let adjustedSelection = request.editScope == .selectedArea
                ? AppFeature.adjustedSelection(
                    state.canvas.selection,
                    canvasSize: state.canvas.canvasSize,
                    expansion: request.maskSettings.expansion,
                    isInverted: request.maskSettings.isInverted
                )
                : nil
            if request.editScope == .selectedArea, adjustedSelection?.isEmpty != false {
                return .failure(
                    NanoBananaValidationError(
                        message: state.application.appLanguage.localized("Create a selection to use inpaint")
                    )
                )
            }

            let normalizedRequest = NanoBananaGenerationRequest(
                prompt: trimmedPrompt,
                config: NanoBananaRequestConfig(
                    accessMode: request.config.accessMode,
                    credential: trimmedCredential,
                    endpoint: trimmedEndpoint
                ),
                model: request.model,
                inputLayerIndex: request.inputLayerIndex,
                editScope: request.editScope,
                outputMode: request.outputMode,
                maskSettings: request.maskSettings
            )
            let outputLayerIndex = request.outputMode == .replaceCurrentLayer
                ? request.inputLayerIndex
                : state.canvas.activeLayerIndex
            let canvasWidth = snapshot.width
            let canvasHeight = snapshot.height
            let sourceLayerPixelData = layer.pixelData
            let beforePreviewImageData = AppFeature.pngData(
                fromLayerPixelData: request.outputMode == .replaceCurrentLayer
                    ? sourceLayerPixelData
                    : Data(repeating: 0, count: canvasWidth * canvasHeight * 4),
                width: canvasWidth,
                height: canvasHeight
            )

            return .success(
                NanoBananaValidatedEdit(
                    normalizedRequest: normalizedRequest,
                    adjustedSelection: adjustedSelection,
                    outputLayerIndex: outputLayerIndex,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    sourceLayerPixelData: sourceLayerPixelData,
                    beforePreviewImageData: beforePreviewImageData,
                    appLanguage: state.application.appLanguage,
                    trimmedPrompt: trimmedPrompt
                )
            )
        }
    }

    private struct NanoBananaDocumentService {
        struct AppliedPreview {
            let targetLayerIndex: Int
            let presentation: PaintDocumentPresentation
        }

        let paintDocumentClient: PaintDocumentClient

        func applyPreview(
            _ preview: NanoBananaPreviewState,
            newLayerName: String
        ) -> AppliedPreview {
            let targetLayerIndex: Int
            switch preview.request.outputMode {
            case .replaceCurrentLayer:
                targetLayerIndex = preview.outputLayerIndex
            case .newLayer:
                paintDocumentClient.addLayer(newLayerName)
                targetLayerIndex = paintDocumentClient.presentation().activeLayerIndex
            }

            paintDocumentClient.setActiveLayer(targetLayerIndex)
            paintDocumentClient.replaceLayerPixels(targetLayerIndex, preview.pixelData)
            return AppliedPreview(
                targetLayerIndex: targetLayerIndex,
                presentation: paintDocumentClient.presentation()
            )
        }
    }

    private struct NanoBananaGenerationService {
        let nanoBananaClient: NanoBananaClient
        let uuidClient: UUIDClient
        let dateClient: DateClient

        func beginGeneration(
            state: inout State,
            edit: NanoBananaValidatedEdit
        ) -> NanoBananaValidatedEdit {
            let jobID = uuidClient.generate()
            state.nanoBanana.beginGeneration(
                request: edit.normalizedRequest,
                jobID: jobID,
                createdAt: dateClient.now()
            )
            return edit
        }

        func makeEditEffect(_ prepared: NanoBananaValidatedEdit) -> Effect<Action> {
            .run { [nanoBananaClient] send in
                do {
                    let requestPrompt = prepared.normalizedRequest.editScope == .selectedArea
                        ? "Only edit the selected region. Keep everything outside the selected region unchanged.\n\n\(prepared.trimmedPrompt)"
                        : prepared.trimmedPrompt

                    let finalPixelData: Data?
                    switch prepared.normalizedRequest.editScope {
                    case .wholeLayer:
                        guard let inputPNGData = AppFeature.pngData(
                            fromLayerPixelData: prepared.sourceLayerPixelData,
                            width: prepared.canvasWidth,
                            height: prepared.canvasHeight
                        ) else {
                            finalPixelData = nil
                            break
                        }
                        let outputPNGData = try await nanoBananaClient.editImage(
                            inputPNGData,
                            requestPrompt,
                            prepared.normalizedRequest.config,
                            prepared.normalizedRequest.model
                        )
                        finalPixelData = AppFeature.rawLayerPixelData(
                            fromPNGData: outputPNGData,
                            width: prepared.canvasWidth,
                            height: prepared.canvasHeight
                        )

                    case .selectedArea:
                        guard
                            let adjustedSelection = prepared.adjustedSelection,
                            let crop = AppFeature.inpaintCrop(
                                source: prepared.sourceLayerPixelData,
                                canvasWidth: prepared.canvasWidth,
                                canvasHeight: prepared.canvasHeight,
                                selection: adjustedSelection
                            ),
                            let cropPNGData = AppFeature.pngData(
                                fromLayerPixelData: crop.pixelData,
                                width: crop.width,
                                height: crop.height
                            )
                        else {
                            finalPixelData = nil
                            break
                        }

                        let outputPNGData = try await nanoBananaClient.editImage(
                            cropPNGData,
                            requestPrompt,
                            prepared.normalizedRequest.config,
                            prepared.normalizedRequest.model
                        )
                        guard let editedCropPixelData = AppFeature.rawLayerPixelData(
                            fromPNGData: outputPNGData,
                            width: crop.width,
                            height: crop.height
                        ) else {
                            finalPixelData = nil
                            break
                        }

                        let baseLayerPixelData = prepared.normalizedRequest.outputMode == .replaceCurrentLayer
                            ? prepared.sourceLayerPixelData
                            : Data(repeating: 0, count: prepared.canvasWidth * prepared.canvasHeight * 4)
                        finalPixelData = AppFeature.applyingInpaintCrop(
                            editedCropPixelData,
                            to: baseLayerPixelData,
                            canvasWidth: prepared.canvasWidth,
                            canvasHeight: prepared.canvasHeight,
                            crop: crop
                        )
                    }

                    guard let finalPixelData else {
                        await send(.nanoBananaEditFailed("Nano Banana returned an unsupported image."))
                        return
                    }

                    let preview = NanoBananaPreviewState(
                        request: prepared.normalizedRequest,
                        outputLayerIndex: prepared.outputLayerIndex,
                        pixelData: finalPixelData,
                        beforePreviewImageData: prepared.beforePreviewImageData,
                        afterPreviewImageData: AppFeature.pngData(
                            fromLayerPixelData: finalPixelData,
                            width: prepared.canvasWidth,
                            height: prepared.canvasHeight
                        )
                    )
                    await send(.nanoBananaEditSucceeded(preview))
                } catch {
                    await send(.nanoBananaEditFailed(
                        AppFeature.localizedNanoBananaErrorMessage(
                            error.localizedDescription,
                            language: prepared.appLanguage
                        )
                    ))
                }
            }
            .cancellable(id: CancelID.nanoBananaEdit, cancelInFlight: true)
        }

        func applySuccess(
            state: inout State,
            preview: NanoBananaPreviewState
        ) {
            state.nanoBanana.recordSucceededGeneration(
                preview: preview,
                historyID: uuidClient.generate(),
                createdAt: dateClient.now()
            )
        }

        func applyFailure(state: inout State, message: String) {
            state.nanoBanana.markFailed(message: message)
            state.application.presentBanner(
                message.isEmpty
                    ? state.application.appLanguage.localized("Nano Banana edit failed")
                    : message
            )
        }

        func cancel(state: inout State) -> Effect<Action> {
            let localizedMessage = state.application.appLanguage.localized("Nano Banana generation canceled")
            state.nanoBanana.markCanceled(localizedMessage: localizedMessage)
            state.application.presentBanner(localizedMessage)
            return .cancel(id: CancelID.nanoBananaEdit)
        }
    }

    private var nanoBananaGenerationService: NanoBananaGenerationService {
        NanoBananaGenerationService(
            nanoBananaClient: nanoBananaClient,
            uuidClient: uuidClient,
            dateClient: dateClient
        )
    }

    private var nanoBananaRequestContract: NanoBananaRequestContract {
        NanoBananaRequestContract()
    }

    private var nanoBananaDocumentService: NanoBananaDocumentService {
        NanoBananaDocumentService(paintDocumentClient: paintDocumentClient)
    }

    func handleNanoBananaEditRequest(
        state: inout State,
        request: NanoBananaGenerationRequest
    ) -> Effect<Action> {
        let validatedEdit: NanoBananaValidatedEdit
        switch nanoBananaRequestContract.validate(request: request, state: state) {
        case let .failure(error):
            state.application.presentBanner(error.localizedDescription)
            return .none
        case let .success(edit):
            validatedEdit = edit
        }
        let prepared = nanoBananaGenerationService.beginGeneration(
            state: &state,
            edit: validatedEdit
        )
        return nanoBananaGenerationService.makeEditEffect(prepared)
    }

    func handleNanoBananaEditSucceeded(
        state: inout State,
        preview: NanoBananaPreviewState
    ) {
        nanoBananaGenerationService.applySuccess(
            state: &state,
            preview: preview
        )
        let appliedPreview = nanoBananaDocumentService.applyPreview(
            preview,
            newLayerName: "Nano Banana \(state.layerSidebar.layers.count + 1)"
        )
        state.canvas.discardBufferedStrokes(for: appliedPreview.targetLayerIndex, incrementsRevision: true)
        state.canvas.clearSelection()
        state.nanoBanana.completeAppliedEdit(request: preview.request)
        AppFeature.canvasPresentationStateCoordinator.applyPresentation(
            appliedPreview.presentation,
            to: &state
        )
        state.application.presentBanner(state.application.appLanguage.localized("Nano Banana edit applied"))
    }

    func handleNanoBananaEditFailed(
        state: inout State,
        message: String
    ) {
        nanoBananaGenerationService.applyFailure(state: &state, message: message)
    }

    func handleNanoBananaCancelRequested(state: inout State) -> Effect<Action> {
        nanoBananaGenerationService.cancel(state: &state)
    }
}
