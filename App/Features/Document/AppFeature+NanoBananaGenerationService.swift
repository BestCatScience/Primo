import ComposableArchitecture
import Foundation
import PrimoNanoBananaApplication
import PrimoNanoBananaDomain

extension AppFeature {
    private struct NanoBananaValidatedEdit {
        let command: SubmitNanoBananaEditCommand
        let adjustedSelection: CanvasSelection?
        let outputLayerIndex: Int
        let canvasWidth: Int
        let canvasHeight: Int
        let sourceLayerPixelData: Data
        let beforePreviewImageData: Data?
    }

    private struct NanoBananaValidationFailure: Error, Equatable {
        let feedback: ApplicationFeedback
    }

    private struct NanoBananaRequestContract {
        func validate(
            command: SubmitNanoBananaEditCommand,
            state: AppFeature.State
        ) -> Result<NanoBananaValidatedEdit, NanoBananaValidationFailure> {
            guard
                let snapshot = state.canvas.renderSnapshot,
                let layer = snapshot.layers.first(where: { $0.index == command.descriptor.inputLayerIndex })
            else {
                return .failure(NanoBananaValidationFailure(feedback: .nanoBananaPrepareLayerFailed))
            }

            let adjustedSelection = command.descriptor.editScope == .selectedArea
                ? AppFeature.adjustedSelection(
                    state.canvas.selection,
                    canvasSize: state.canvas.canvasSize,
                    expansion: command.descriptor.maskSettings.expansion,
                    isInverted: command.descriptor.maskSettings.isInverted
                )
                : nil
            if command.descriptor.editScope == .selectedArea, adjustedSelection?.isEmpty != false {
                return .failure(NanoBananaValidationFailure(feedback: .nanoBananaSelectionRequired))
            }

            let outputLayerIndex = command.descriptor.outputMode == .replaceCurrentLayer
                ? command.descriptor.inputLayerIndex
                : state.canvas.activeLayerIndex
            let canvasWidth = snapshot.width
            let canvasHeight = snapshot.height
            let sourceLayerPixelData = layer.pixelData
            let beforePreviewImageData = AppFeature.pngData(
                fromLayerPixelData: command.descriptor.outputMode == .replaceCurrentLayer
                    ? sourceLayerPixelData
                    : Data(repeating: 0, count: canvasWidth * canvasHeight * 4),
                width: canvasWidth,
                height: canvasHeight
            )

            return .success(
                NanoBananaValidatedEdit(
                    command: command,
                    adjustedSelection: adjustedSelection,
                    outputLayerIndex: outputLayerIndex,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    sourceLayerPixelData: sourceLayerPixelData,
                    beforePreviewImageData: beforePreviewImageData
                )
            )
        }
    }

    private struct NanoBananaPreviewApplicationPlan {
        let preview: NanoBananaPreviewState
        let target: LayerContentMutationTarget
    }

    private struct NanoBananaPreviewApplicationContract {
        func validate(
            preview: NanoBananaPreviewState,
            state: AppFeature.State
        ) -> Result<NanoBananaPreviewApplicationPlan, NanoBananaValidationFailure> {
            let namingPolicy = AppFeature.DocumentNamingPolicy(language: state.application.appLanguage)
            switch preview.descriptor.outputMode {
            case .replaceCurrentLayer:
                guard state.layerSidebar.layer(withIndex: preview.outputLayerIndex) != nil else {
                    return .failure(NanoBananaValidationFailure(feedback: .nanoBananaApplyFailed))
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
                        target: .newLayer(name: namingPolicy.nanoBananaLayerName(for: state.layerSidebar))
                    )
                )
            }
        }
    }

    private struct NanoBananaDocumentService {
        struct AppliedPreview {
            let targetLayerIndex: Int
        }

        let paintDocumentClient: PaintDocumentClient
        let layerContentTransactionService: LayerContentTransactionService

        func apply(
            _ plan: NanoBananaPreviewApplicationPlan
        ) -> Result<AppliedPreview, DocumentMutationFailure> {
            layerContentTransactionService.apply(target: plan.target) { targetLayerIndex in
                switch paintDocumentClient.setActiveLayer(targetLayerIndex) {
                case let .failure(failure):
                    return .failure(failure)
                case .success:
                    return paintDocumentClient.replaceLayerPixels(
                        targetLayerIndex,
                        plan.preview.pixelData
                    )
                }
            }
            .map {
                AppliedPreview(
                    targetLayerIndex: $0.targetLayerIndex
                )
            }
        }
    }

    private struct NanoBananaGenerationService {
        let nanoBananaEditUseCase: NanoBananaEditUseCase
        let uuidClient: UUIDClient
        let dateClient: DateClient

        func beginGeneration(
            state: inout State,
            edit: NanoBananaValidatedEdit
        ) -> NanoBananaValidatedEdit {
            let jobID = uuidClient.generate()
            state.nanoBanana.beginGeneration(
                descriptor: edit.command.descriptor,
                jobID: jobID,
                createdAt: dateClient.now()
            )
            return edit
        }

        func makeEditEffect(_ prepared: NanoBananaValidatedEdit) -> Effect<Action> {
            .run { [nanoBananaEditUseCase] send in
                func executeEdit(inputPNGData: Data, cropScoped: Bool) async -> Result<Data, NanoBananaEditFailure> {
                    var command = prepared.command
                    if cropScoped {
                        let prompt = "Only edit the selected region. Keep everything outside the selected region unchanged.\n\n\(command.descriptor.prompt.rawValue)"
                        guard let adjustedPrompt = NonEmptyPrompt(prompt) else {
                            return .failure(.transport("Selected-area prompt normalization failed."))
                        }
                        command.descriptor.prompt = adjustedPrompt
                    }
                    return await nanoBananaEditUseCase.execute(
                        NanoBananaEditExecutionRequest(
                            inputPNGData: inputPNGData,
                            command: command
                        )
                    )
                }

                let finalPixelData: Data?
                switch prepared.command.descriptor.editScope {
                case .wholeLayer:
                    guard let inputPNGData = AppFeature.pngData(
                        fromLayerPixelData: prepared.sourceLayerPixelData,
                        width: prepared.canvasWidth,
                        height: prepared.canvasHeight
                    ) else {
                        finalPixelData = nil
                        break
                    }

                    let outputPNGData: Data
                    switch await executeEdit(inputPNGData: inputPNGData, cropScoped: false) {
                    case let .success(imageData):
                        outputPNGData = imageData
                    case let .failure(failure):
                        await send(
                            .nanoBanana(
                                .generationFailed(
                                    AppFeature.nanoBananaFailureFeedback(failure)
                                )
                            )
                        )
                        return
                    }

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

                    let outputPNGData: Data
                    switch await executeEdit(inputPNGData: cropPNGData, cropScoped: true) {
                    case let .success(imageData):
                        outputPNGData = imageData
                    case let .failure(failure):
                        await send(
                            .nanoBanana(
                                .generationFailed(
                                    AppFeature.nanoBananaFailureFeedback(failure)
                                )
                            )
                        )
                        return
                    }

                    guard let editedCropPixelData = AppFeature.rawLayerPixelData(
                        fromPNGData: outputPNGData,
                        width: crop.width,
                        height: crop.height
                    ) else {
                        finalPixelData = nil
                        break
                    }

                    let baseLayerPixelData = prepared.command.descriptor.outputMode == .replaceCurrentLayer
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
                        .nanoBanana(
                            .generationFailed(
                                .nanoBananaUnsupportedImage
                            )
                        )
                    )
                    return
                }

                let preview = NanoBananaPreviewState(
                    descriptor: prepared.command.descriptor,
                    outputLayerIndex: prepared.outputLayerIndex,
                    pixelData: finalPixelData,
                    beforePreviewImageData: prepared.beforePreviewImageData,
                    afterPreviewImageData: AppFeature.pngData(
                        fromLayerPixelData: finalPixelData,
                        width: prepared.canvasWidth,
                        height: prepared.canvasHeight
                    )
                )
                await send(.nanoBanana(.generationSucceeded(preview)))
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
            nanoBananaEditUseCase: nanoBananaEditUseCase,
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
        NanoBananaDocumentService(
            paintDocumentClient: paintDocumentClient,
            layerContentTransactionService: layerContentTransactionService
        )
    }

    func handleNanoBananaEditRequest(
        state: inout State,
        request: SubmitNanoBananaEditCommand
    ) -> Effect<Action> {
        let validatedEdit: NanoBananaValidatedEdit
        switch nanoBananaRequestContract.validate(command: request, state: state) {
        case let .failure(error):
            state.application.presentFeedback(error.feedback)
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
                feedback: error.feedback
            )
            return
        case let .success(plan):
            applicationPlan = plan
        }
        let appliedPreview: NanoBananaDocumentService.AppliedPreview
        switch nanoBananaDocumentService.apply(applicationPlan) {
        case let .success(preview):
            appliedPreview = preview
        case let .failure(failure):
            nanoBananaGenerationService.applyFailure(
                state: &state,
                feedback: documentMutationFeedbackMapper.feedback(
                    for: failure,
                    default: .nanoBananaApplyFailed
                ) ?? .nanoBananaApplyFailed
            )
            return
        }
        nanoBananaGenerationService.applySuccess(
            state: &state,
            preview: preview
        )
        state.nanoBanana.completeAppliedEdit(request: preview.descriptor)
        completeDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .finalizeLayer(
                    LayerMutationFinalization(
                        index: appliedPreview.targetLayerIndex,
                        incrementsRevision: true
                    )
                ),
                successFeedback: .nanoBananaEditApplied
            )
        )
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

}
