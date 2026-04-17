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

    private struct NanoBananaPreviewApplicationPlan {
        enum Target {
            case existingLayer(index: Int)
            case newLayer(name: String)
        }

        let preview: NanoBananaPreviewState
        let target: Target
    }

    private struct NanoBananaPreviewApplicationContract {
        func validate(
            preview: NanoBananaPreviewState,
            state: AppFeature.State
        ) -> Result<NanoBananaPreviewApplicationPlan, NanoBananaValidationError> {
            switch preview.request.outputMode {
            case .replaceCurrentLayer:
                guard state.layerSidebar.layer(withIndex: preview.outputLayerIndex) != nil else {
                    return .failure(
                        NanoBananaValidationError(
                            message: state.application.appLanguage.localized("Could not apply Nano Banana edit")
                        )
                    )
                }
                return .success(
                    NanoBananaPreviewApplicationPlan(
                        preview: preview,
                        target: .existingLayer(index: preview.outputLayerIndex)
                    )
                )

            case .newLayer:
                return .success(
                    NanoBananaPreviewApplicationPlan(
                        preview: preview,
                        target: .newLayer(name: state.layerSidebar.numberedLayerName(prefix: "Nano Banana"))
                    )
                )
            }
        }
    }

    private struct NanoBananaDocumentService {
        struct AppliedPreview {
            let targetLayerIndex: Int
            let presentation: PaintDocumentPresentation
        }

        let paintDocumentClient: PaintDocumentClient

        func apply(
            _ plan: NanoBananaPreviewApplicationPlan
        ) -> AppliedPreview {
            let targetLayerIndex: Int
            switch plan.target {
            case let .existingLayer(index):
                targetLayerIndex = index
            case let .newLayer(name):
                paintDocumentClient.addLayer(name)
                targetLayerIndex = paintDocumentClient.presentation().activeLayerIndex
            }

            paintDocumentClient.setActiveLayer(targetLayerIndex)
            paintDocumentClient.replaceLayerPixels(targetLayerIndex, plan.preview.pixelData)
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
                        await send(
                            .nanoBananaEditFailed(
                                .nanoBananaEditFailed(
                                    prepared.appLanguage.localized("Nano Banana returned an unsupported image")
                                )
                            )
                        )
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
                    await send(
                        .nanoBananaEditFailed(
                            .nanoBananaEditFailed(
                                AppFeature.localizedNanoBananaErrorMessage(
                                    error.localizedDescription,
                                    language: prepared.appLanguage
                                )
                            )
                        )
                    )
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

        func applyFailure(
            state: inout State,
            feedback: ApplicationFeedback
        ) {
            state.nanoBanana.markFailed(
                feedback: feedback,
                language: state.application.appLanguage
            )
            state.application.presentFeedback(feedback)
        }

        func cancel(state: inout State) -> Effect<Action> {
            state.nanoBanana.markCanceled(
                feedback: .nanoBananaGenerationCanceled,
                language: state.application.appLanguage
            )
            state.application.presentFeedback(.nanoBananaGenerationCanceled)
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

    private var nanoBananaPreviewApplicationContract: NanoBananaPreviewApplicationContract {
        NanoBananaPreviewApplicationContract()
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
            state.application.presentFeedback(
                .nanoBananaEditFailed(Self.optionalErrorMessage(error))
            )
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
        let applicationPlan: NanoBananaPreviewApplicationPlan
        switch nanoBananaPreviewApplicationContract.validate(preview: preview, state: state) {
        case let .failure(error):
            nanoBananaGenerationService.applyFailure(
                state: &state,
                feedback: .nanoBananaEditFailed(error.message)
            )
            return
        case let .success(plan):
            applicationPlan = plan
        }
        let appliedPreview = nanoBananaDocumentService.apply(applicationPlan)
        nanoBananaGenerationService.applySuccess(
            state: &state,
            preview: preview
        )
        state.canvas.finalizeLayerMutation(
            at: appliedPreview.targetLayerIndex,
            incrementsRevision: true
        )
        state.nanoBanana.completeAppliedEdit(request: preview.request)
        AppFeature.canvasPresentationStateCoordinator.applyPresentation(
            appliedPreview.presentation,
            to: &state
        )
        state.application.presentFeedback(.nanoBananaEditApplied)
    }

    func handleNanoBananaEditFailed(
        state: inout State,
        feedback: ApplicationFeedback
    ) {
        nanoBananaGenerationService.applyFailure(state: &state, feedback: feedback)
    }

    func handleNanoBananaCancelRequested(state: inout State) -> Effect<Action> {
        nanoBananaGenerationService.cancel(state: &state)
    }

    func handleNanoBananaRegenerateRequested(state: inout State) -> Effect<Action> {
        guard let request = state.nanoBanana.regenerationRequest() else { return .none }
        return .send(.nanoBananaEditRequested(request))
    }

    func handleNanoBananaRetryJob(
        state: inout State,
        jobID: UUID
    ) -> Effect<Action> {
        guard let request = state.nanoBanana.retryRequest(for: jobID) else { return .none }
        return .send(.nanoBananaEditRequested(request))
    }
}
