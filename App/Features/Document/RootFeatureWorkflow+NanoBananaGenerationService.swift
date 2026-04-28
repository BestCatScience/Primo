import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoNanoBananaApplication
import PrimoNanoBananaDomain

extension RootFeatureWorkflowReducer {
    private struct NanoBananaValidatedEdit {
        let command: SubmitNanoBananaEditCommand
        let selectionRegion: NanoBananaSelectionRegion?
        let outputLayerIndex: Int
        let sourceSurface: DocumentCompositeSurface
    }

    private struct NanoBananaValidationFailure: Error, Equatable {
        let feedback: ApplicationFeedback
    }

    private struct NanoBananaRequestContract {
        func validate(
            command: SubmitNanoBananaEditCommand,
            state: PrimoRootFeature.State,
            gpuOperations: DocumentGpuOperationGateway
        ) -> Result<NanoBananaValidatedEdit, NanoBananaValidationFailure> {
            let selectionWorkflow = SelectionWorkflowService(gpuOperations: gpuOperations)
            guard
                let snapshot = state.document.canvas.renderSnapshot,
                let layer = snapshot.layers.first(where: { $0.index == command.descriptor.inputLayerIndex })
            else {
                return .failure(NanoBananaValidationFailure(feedback: .nanoBananaPrepareLayerFailed))
            }

            let adjustedSelection = command.descriptor.editScope == .selectedArea
                ? selectionWorkflow.adjustedSelection(
                    state.document.canvas.selection,
                    canvasSize: state.document.canvas.canvasSize,
                    expansion: command.descriptor.maskSettings.expansion,
                    isInverted: command.descriptor.maskSettings.isInverted
                )
                : nil
            if command.descriptor.editScope == .selectedArea, adjustedSelection?.isEmpty != false {
                return .failure(NanoBananaValidationFailure(feedback: .nanoBananaSelectionRequired))
            }

            let outputLayerIndex = command.descriptor.outputMode == .replaceCurrentLayer
                ? command.descriptor.inputLayerIndex
                : state.document.canvas.activeLayerIndex
            let sourceSurface = DocumentCompositeSurface(
                width: snapshot.width,
                height: snapshot.height,
                pixelData: layer.pixelData
            )
            let selectionRegion: NanoBananaSelectionRegion?
            if let adjustedSelection {
                guard let expandedMask = selectionWorkflow.expandedMask(
                    from: adjustedSelection,
                    canvasWidth: snapshot.width,
                    canvasHeight: snapshot.height
                ) else {
                    return .failure(NanoBananaValidationFailure(feedback: .nanoBananaPrepareLayerFailed))
                }
                selectionRegion = NanoBananaSelectionRegion(
                    selectionBounds: adjustedSelection.bounds,
                    expandedMask: expandedMask
                )
            } else {
                selectionRegion = nil
            }

            return .success(
                NanoBananaValidatedEdit(
                    command: command,
                    selectionRegion: selectionRegion,
                    outputLayerIndex: outputLayerIndex,
                    sourceSurface: sourceSurface
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
            state: PrimoRootFeature.State
        ) -> Result<NanoBananaPreviewApplicationPlan, NanoBananaValidationFailure> {
            let namingPolicy = DocumentFeature.DocumentNamingPolicy(language: state.application.appLanguage)
            switch preview.descriptor.outputMode {
            case .replaceCurrentLayer:
                guard state.document.layerSidebar.layer(withIndex: preview.outputLayerIndex) != nil else {
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
                        target: .newLayer(name: namingPolicy.nanoBananaLayerName(for: state.document.layerSidebar))
                    )
                )
            }
        }
    }

    private struct NanoBananaDocumentService {
        struct AppliedPreview {
            let targetLayerIndex: Int
        }

        let contentService: DocumentContentService

        func apply(
            _ plan: NanoBananaPreviewApplicationPlan
        ) -> Result<AppliedPreview, DocumentMutationFailure> {
            contentService.applyPixels(
                plan.preview.outputSurface.pixelData,
                to: plan.target
            )
            .map { AppliedPreview(targetLayerIndex: $0.targetLayerIndex) }
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
                        sourceSurface: prepared.sourceSurface
                    )
                ) {
                case let .success(preview):
                    await send(.nanoBanana(.generationSucceeded(preview)))
                case let .failure(.editFailed(failure)):
                    await send(
                        .nanoBanana(
                            .generationFailed(
                                DocumentFeature.nanoBananaFailureFeedback(failure)
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
        ) -> Effect<Action> {
            state.nanoBanana.markFailed(
                feedback: feedback,
                language: state.application.appLanguage
            )
            return .send(.application(.feedbackPresented(feedback)))
        }

        func cancel(state: inout State) -> Effect<Action> {
            state.nanoBanana.markCanceled(
                feedback: .nanoBananaGenerationCanceled,
                language: state.application.appLanguage
            )
            return .merge(
                .send(.application(.feedbackPresented(.nanoBananaGenerationCanceled))),
                .cancel(id: CancelID.nanoBananaEdit)
            )
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

    private var nanoBananaLayerContentService: PrimoDocumentApplication.DocumentContentService {
        PrimoDocumentApplication.DocumentContentService(
            documentQueryGateway: documentQueryGateway,
            documentMutationGateway: documentMutationGateway,
            textLayerGateway: textLayerGateway
        )
    }

    private var nanoBananaDocumentService: NanoBananaDocumentService {
        NanoBananaDocumentService(
            contentService: nanoBananaLayerContentService
        )
    }

    func handleNanoBananaEditRequest(
        state: inout State,
        request: SubmitNanoBananaEditCommand
    ) -> Effect<Action> {
        let validatedEdit: NanoBananaValidatedEdit
        switch nanoBananaRequestContract.validate(
            command: request,
            state: state,
            gpuOperations: documentGpuOperationGateway
        ) {
        case let .failure(error):
            return .send(.application(.feedbackPresented(error.feedback)))
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
    ) -> Effect<Action> {
        let applicationPlan: NanoBananaPreviewApplicationPlan
        switch nanoBananaPreviewApplicationContract.validate(preview: preview, state: state) {
        case let .failure(error):
            return nanoBananaGenerationService.applyFailure(
                state: &state,
                feedback: error.feedback
            )
        case let .success(plan):
            applicationPlan = plan
        }
        let appliedPreview: NanoBananaDocumentService.AppliedPreview
        switch nanoBananaDocumentService.apply(applicationPlan) {
        case let .success(preview):
            appliedPreview = preview
        case let .failure(failure):
            return nanoBananaGenerationService.applyFailure(
                state: &state,
                feedback: documentMutationFeedbackMapper.feedback(
                    for: failure,
                    default: .nanoBananaApplyFailed
                ) ?? .nanoBananaApplyFailed
            )
        }
        nanoBananaGenerationService.applySuccess(
            state: &state,
            preview: preview
        )
        state.nanoBanana.completeAppliedEdit(request: preview.descriptor)
        return completeDocumentMutation(
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
    ) -> Effect<Action> {
        nanoBananaGenerationService.applyFailure(state: &state, feedback: feedback)
    }

    func handleNanoBananaCancelRequested(state: inout State) -> Effect<Action> {
        nanoBananaGenerationService.cancel(state: &state)
    }

}
