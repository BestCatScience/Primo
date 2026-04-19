import ComposableArchitecture
import Foundation
import PrimoNanoBananaApplication
import PrimoNanoBananaDomain

extension AppFeature {
    private struct NanoBananaValidatedEdit {
        let command: SubmitNanoBananaEditCommand
        let selectionRegion: NanoBananaSelectionRegion?
        let outputLayerIndex: Int
        let canvasWidth: Int
        let canvasHeight: Int
        let sourceLayerPixelData: Data
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
            let selectionRegion = adjustedSelection.map {
                NanoBananaSelectionRegion(
                    selectionBounds: $0.bounds,
                    expandedMask: AppFeature.expandedMask(
                        from: $0,
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight
                    )
                )
            }

            return .success(
                NanoBananaValidatedEdit(
                    command: command,
                    selectionRegion: selectionRegion,
                    outputLayerIndex: outputLayerIndex,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    sourceLayerPixelData: sourceLayerPixelData
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

        let documentMutationGateway: DocumentMutationGateway
        let layerContentTransactionService: LayerContentTransactionService

        func apply(
            _ plan: NanoBananaPreviewApplicationPlan
        ) -> Result<AppliedPreview, DocumentMutationFailure> {
            layerContentTransactionService.apply(target: plan.target) { targetLayerIndex in
                switch documentMutationGateway.setActiveLayer(targetLayerIndex) {
                case let .failure(failure):
                    return .failure(failure)
                case .success:
                    return documentMutationGateway.replaceLayerPixels(
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
        let previewPreparationService: NanoBananaPreviewPreparationService
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
            .run { [previewPreparationService] send in
                switch await previewPreparationService.preparePreview(
                    NanoBananaPreviewPreparationRequest(
                        command: prepared.command,
                        selectionRegion: prepared.selectionRegion,
                        outputLayerIndex: prepared.outputLayerIndex,
                        canvasWidth: prepared.canvasWidth,
                        canvasHeight: prepared.canvasHeight,
                        sourceLayerPixelData: prepared.sourceLayerPixelData
                    )
                ) {
                case let .success(preview):
                    await send(.nanoBanana(.generationSucceeded(preview)))
                case let .failure(.editFailed(failure)):
                    await send(
                        .nanoBanana(
                            .generationFailed(
                                AppFeature.nanoBananaFailureFeedback(failure)
                            )
                        )
                    )
                case .failure(.unsupportedImage):
                    await send(
                        .nanoBanana(
                            .generationFailed(.nanoBananaUnsupportedImage)
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
            previewPreparationService: NanoBananaPreviewPreparationService(
                editUseCase: nanoBananaEditUseCase
            ),
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
            documentMutationGateway: documentMutationGateway,
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
