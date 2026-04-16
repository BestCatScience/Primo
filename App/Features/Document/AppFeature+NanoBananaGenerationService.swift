import ComposableArchitecture
import Foundation

extension AppFeature {
    private struct NanoBananaGenerationService {
        struct PreparedEdit {
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

        let nanoBananaClient: NanoBananaClient
        let uuidClient: UUIDClient
        let dateClient: DateClient

        func prepareEdit(
            state: inout State,
            request: NanoBananaGenerationRequest
        ) -> PreparedEdit? {
            let trimmedPrompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedCredential = request.config.credential.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedEndpoint = request.config.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPrompt.isEmpty else {
                state.application.presentBanner(state.appLanguage.localized("Enter a prompt for Nano Banana"))
                return nil
            }
            guard request.config.accessMode == .appManaged || !trimmedCredential.isEmpty else {
                state.application.presentBanner(state.appLanguage.localized("Enter your Gemini API key"))
                return nil
            }
            guard request.config.accessMode == .userAPIKey || !trimmedEndpoint.isEmpty else {
                state.application.presentBanner(state.appLanguage.localized("Enter your app server endpoint"))
                return nil
            }
            guard
                let snapshot = state.canvas.renderSnapshot,
                let layer = snapshot.layers.first(where: { $0.index == request.inputLayerIndex })
            else {
                state.application.presentBanner(state.appLanguage.localized("Could not prepare the active layer for Nano Banana"))
                return nil
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
                state.application.presentBanner(state.appLanguage.localized("Create a selection to use inpaint"))
                return nil
            }

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
            let jobID = uuidClient.generate()
            state.isNanoBananaGenerating = true
            state.nanoBananaPreview = nil
            state.pendingNanoBananaRequest = normalizedRequest
            state.activeNanoBananaJobID = jobID
            state.pendingNanoBananaOutputMode = request.outputMode
            state.nanoBananaJobs.insert(
                NanoBananaJob(
                    id: jobID,
                    request: normalizedRequest,
                    createdAt: dateClient.now(),
                    status: .running,
                    message: nil
                ),
                at: 0
            )
            state.nanoBananaJobs = Array(state.nanoBananaJobs.prefix(12))

            return PreparedEdit(
                normalizedRequest: normalizedRequest,
                adjustedSelection: adjustedSelection,
                outputLayerIndex: outputLayerIndex,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                sourceLayerPixelData: sourceLayerPixelData,
                beforePreviewImageData: beforePreviewImageData,
                appLanguage: state.appLanguage,
                trimmedPrompt: trimmedPrompt
            )
        }

        func makeEditEffect(_ prepared: PreparedEdit) -> Effect<Action> {
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
            preview: NanoBananaPreviewState,
            paintDocumentClient: PaintDocumentClient
        ) {
            state.isNanoBananaGenerating = false
            state.nanoBananaHistory.insert(
                NanoBananaHistoryItem(
                    id: uuidClient.generate(),
                    request: preview.request,
                    createdAt: dateClient.now(),
                    previewImageData: preview.afterPreviewImageData
                ),
                at: 0
            )
            state.nanoBananaHistory = Array(state.nanoBananaHistory.prefix(12))
            if let activeJobID = state.activeNanoBananaJobID,
               let jobIndex = state.nanoBananaJobs.firstIndex(where: { $0.id == activeJobID }) {
                state.nanoBananaJobs[jobIndex].status = .succeeded
                state.nanoBananaJobs[jobIndex].message = nil
            }
            applyPreview(state: &state, preview: preview, paintDocumentClient: paintDocumentClient)
        }

        func applyPreview(
            state: inout State,
            preview: NanoBananaPreviewState,
            paintDocumentClient: PaintDocumentClient
        ) {
            let targetLayerIndex: Int
            switch preview.request.outputMode {
            case .replaceCurrentLayer:
                targetLayerIndex = preview.outputLayerIndex
            case .newLayer:
                paintDocumentClient.addLayer("Nano Banana \(state.layerSidebar.layers.count + 1)")
                targetLayerIndex = paintDocumentClient.presentation().activeLayerIndex
            }

            paintDocumentClient.setActiveLayer(targetLayerIndex)
            paintDocumentClient.replaceLayerPixels(targetLayerIndex, preview.pixelData)
            if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == targetLayerIndex }) {
                state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
            }
            state.canvas.selection = nil
            state.nanoBananaPreview = nil
            state.pendingNanoBananaRequest = preview.request
            state.activeNanoBananaJobID = nil
            state.pendingNanoBananaOutputMode = .replaceCurrentLayer
            state.applyPresentation(paintDocumentClient.presentation())
            state.application.presentBanner(state.appLanguage.localized("Nano Banana edit applied"))
        }

        func applyFailure(state: inout State, message: String) {
            state.isNanoBananaGenerating = false
            if let activeJobID = state.activeNanoBananaJobID,
               let jobIndex = state.nanoBananaJobs.firstIndex(where: { $0.id == activeJobID }) {
                state.nanoBananaJobs[jobIndex].status = .failed
                state.nanoBananaJobs[jobIndex].message = message
            }
            state.application.presentBanner(
                message.isEmpty
                    ? state.appLanguage.localized("Nano Banana edit failed")
                    : message
            )
        }

        func cancel(state: inout State) -> Effect<Action> {
            state.isNanoBananaGenerating = false
            if let activeJobID = state.activeNanoBananaJobID,
               let jobIndex = state.nanoBananaJobs.firstIndex(where: { $0.id == activeJobID }) {
                state.nanoBananaJobs[jobIndex].status = .canceled
                state.nanoBananaJobs[jobIndex].message = state.appLanguage.localized("Nano Banana generation canceled")
            }
            state.application.presentBanner(state.appLanguage.localized("Nano Banana generation canceled"))
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

    func handleNanoBananaEditRequest(
        state: inout State,
        request: NanoBananaGenerationRequest
    ) -> Effect<Action> {
        guard let prepared = nanoBananaGenerationService.prepareEdit(state: &state, request: request) else {
            return .none
        }
        return nanoBananaGenerationService.makeEditEffect(prepared)
    }

    func handleNanoBananaEditSucceeded(
        state: inout State,
        preview: NanoBananaPreviewState
    ) {
        nanoBananaGenerationService.applySuccess(
            state: &state,
            preview: preview,
            paintDocumentClient: paintDocumentClient
        )
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

    func handleNanoBananaPreviewAccepted(state: inout State) {
        guard let preview = state.nanoBananaPreview else { return }
        nanoBananaGenerationService.applyPreview(
            state: &state,
            preview: preview,
            paintDocumentClient: paintDocumentClient
        )
    }
}
