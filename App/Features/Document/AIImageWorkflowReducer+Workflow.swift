import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentRuntime
import PrimoAIImageApplication
import PrimoAIImageDomain

extension AIImageWorkflowReducer {
    private struct AIImageValidatedEdit {
        let command: SubmitAIImageEditCommand
        let selectionRegion: AIImageSelectionRegion?
        let outputLayerIndex: Int
        let sourceSurface: DocumentCompositeSurface
    }

    private struct AIImageValidationFailure: Error, Equatable {
        let feedback: ApplicationFeature.Feedback
    }

    private struct AIImageRequestContract {
        func validate(
            command: SubmitAIImageEditCommand,
            state: DocumentEditingState,
            selectionWorkflow: SelectionWorkflowService
        ) -> Result<AIImageValidatedEdit, AIImageValidationFailure> {
            guard
                let snapshot = state.canvas.renderSnapshot,
                let layer = snapshot.layers.first(where: { $0.index == command.descriptor.inputLayerIndex })
            else {
                return .failure(AIImageValidationFailure(feedback: .aiImagePrepareLayerFailed))
            }

            let adjustedSelection = command.descriptor.editScope == .selectedArea
                ? selectionWorkflow.adjustedSelection(
                    state.canvas.selection,
                    canvasSize: state.canvas.canvasSize,
                    expansion: command.descriptor.maskSettings.expansion,
                    isInverted: command.descriptor.maskSettings.isInverted
                )
                : nil
            if command.descriptor.editScope == .selectedArea, adjustedSelection?.isEmpty != false {
                return .failure(AIImageValidationFailure(feedback: .aiImageSelectionRequired))
            }

            let outputLayerIndex = command.descriptor.outputMode == .replaceCurrentLayer
                ? command.descriptor.inputLayerIndex
                : state.canvas.activeLayerIndex
            guard let sourceSurface = DocumentCompositeSurface(
                validatingWidth: snapshot.width,
                height: snapshot.height,
                pixelData: layer.pixelData
            ) else {
                return .failure(AIImageValidationFailure(feedback: .aiImagePrepareLayerFailed))
            }
            let selectionRegion: AIImageSelectionRegion?
            if let adjustedSelection {
                guard let expandedMask = selectionWorkflow.expandedMask(
                    from: adjustedSelection,
                    canvasWidth: snapshot.width,
                    canvasHeight: snapshot.height
                ) else {
                    return .failure(AIImageValidationFailure(feedback: .aiImagePrepareLayerFailed))
                }
                selectionRegion = AIImageSelectionRegion(
                    selectionBounds: adjustedSelection.bounds,
                    expandedMask: expandedMask
                )
            } else {
                selectionRegion = nil
            }

            return .success(
                AIImageValidatedEdit(
                    command: command,
                    selectionRegion: selectionRegion,
                    outputLayerIndex: outputLayerIndex,
                    sourceSurface: sourceSurface
                )
            )
        }
    }

    private struct AIImagePreviewApplicationPlan {
        let preview: AIImagePreviewState
        let target: LayerContentMutationTarget
    }

    private struct AIImagePreviewApplicationContract {
        func validate(
            preview: AIImagePreviewState,
            state: DocumentEditingState,
            namingPolicy: DocumentNamingPolicy
        ) -> Result<AIImagePreviewApplicationPlan, AIImageValidationFailure> {
            switch preview.descriptor.outputMode {
            case .replaceCurrentLayer:
                guard state.layerSidebar.layer(withIndex: preview.outputLayerIndex) != nil else {
                    return .failure(AIImageValidationFailure(feedback: .aiImageApplyFailed))
                }
                return .success(
                    AIImagePreviewApplicationPlan(
                        preview: preview,
                        target: .existingLayer(index: preview.outputLayerIndex)
                    )
                )

            case .newLayer:
                return .success(
                    AIImagePreviewApplicationPlan(
                        preview: preview,
                        target: .newLayer(name: namingPolicy.aiImageLayerName(for: state.layerSidebar))
                    )
                )
            }
        }
    }

    private struct AIImageDocumentService {
        struct AppliedPreview {
            let targetLayerIndex: Int
        }

        let contentService: DocumentContentService

        func apply(_ plan: AIImagePreviewApplicationPlan) -> Result<AppliedPreview, DocumentMutationFailure> {
            contentService.applyPixels(
                plan.preview.outputSurface.pixelData,
                to: plan.target
            )
            .map { AppliedPreview(targetLayerIndex: $0.targetLayerIndex) }
        }
    }

    private var aiImageRequestContract: AIImageRequestContract {
        AIImageRequestContract()
    }

    private var aiImagePreviewApplicationContract: AIImagePreviewApplicationContract {
        AIImagePreviewApplicationContract()
    }

    private var aiImagePreviewPreparationService: AIImagePreviewPreparationService {
        AIImagePreviewPreparationService(editUseCase: aiImageEditUseCase)
    }

    private var aiImageLayerContentService: DocumentContentService {
        documentContentService
    }

    private var aiImageDocumentService: AIImageDocumentService {
        AIImageDocumentService(contentService: aiImageLayerContentService)
    }

    func handleAIImageEditRequest(
        state: inout State,
        request: SubmitAIImageEditCommand
    ) -> Effect<Action> {
        let validatedEdit: AIImageValidatedEdit
        switch aiImageRequestContract.validate(
            command: request,
            state: state.editing,
            selectionWorkflow: selectionWorkflowService
        ) {
        case let .failure(error):
            return .send(.delegate(.documentMutationFeedback(error.feedback)))
        case let .success(edit):
            validatedEdit = edit
        }

        let generationStart = AIImageGenerationStart(
            descriptor: validatedEdit.command.descriptor,
            jobID: uuidClient.generate(),
            createdAt: dateClient.now()
        )
        let jobID = generationStart.jobID
        state.activeAIImageJobID = jobID
        return .merge(
            .send(.delegate(.aiImageGenerationStarted(generationStart))),
            .run { [aiImagePreviewPreparationService] send in
                switch await aiImagePreviewPreparationService.preparePreview(
                    AIImagePreviewPreparationRequest(
                        command: validatedEdit.command,
                        selectionRegion: validatedEdit.selectionRegion,
                        outputLayerIndex: validatedEdit.outputLayerIndex,
                        sourceSurface: validatedEdit.sourceSurface
                    )
                ) {
                case let .success(preview):
                    await send(.aiImagePreviewPrepared(jobID: jobID, preview: preview))
                case let .failure(.editFailed(failure)):
                    await send(.aiImagePreviewPreparationFailed(jobID: jobID, feedback: DocumentFeature.aiImageFailureFeedback(failure)))
                case .failure(.unsupportedImage):
                    await send(.aiImagePreviewPreparationFailed(jobID: jobID, feedback: .aiImageUnsupportedImage))
                }
            }
            .cancellable(id: ApplicationFeature.CancelID.aiImageEdit, cancelInFlight: true)
        )
    }

    func handleAIImageEditSucceeded(
        state: inout State,
        preview: AIImagePreviewState
    ) -> Effect<Action> {
        state.activeAIImageJobID = nil
        let language = appLanguageClient.load()
        let applicationPlan: AIImagePreviewApplicationPlan
        switch aiImagePreviewApplicationContract.validate(
            preview: preview,
            state: state.editing,
            namingPolicy: DocumentNamingPolicy(language: language)
        ) {
        case let .failure(error):
            return handleAIImageEditFailed(state: &state, feedback: error.feedback)
        case let .success(plan):
            applicationPlan = plan
        }

        let appliedPreview: AIImageDocumentService.AppliedPreview
        switch aiImageDocumentService.apply(applicationPlan) {
        case let .success(preview):
            appliedPreview = preview
        case let .failure(failure):
            return handleAIImageEditFailed(
                state: &state,
                feedback: DocumentMutationFeedbackMapper().feedback(
                    for: failure,
                    default: .aiImageApplyFailed
                ) ?? .aiImageApplyFailed
            )
        }
        let correctedPreview = AIImagePreviewState(
            descriptor: preview.descriptor,
            outputLayerIndex: appliedPreview.targetLayerIndex,
            outputSurface: preview.outputSurface,
            beforePreviewImageData: preview.beforePreviewImageData,
            afterPreviewImageData: preview.afterPreviewImageData
        )

        return .merge(
            .send(
                .delegate(
                    .aiImageEditApplied(
                        AIImageAppliedEdit(
                            preview: correctedPreview,
                            historyID: uuidClient.generate(),
                            createdAt: dateClient.now()
                        )
                    )
                )
            ),
            completeDocumentMutation(
                state: &state,
                contract: DocumentMutationContract(
                    canvasMutation: .finalizeLayer(
                        LayerMutationFinalization(
                            index: appliedPreview.targetLayerIndex,
                            incrementsRevision: true
                        )
                    ),
                    successFeedback: .aiImageEditApplied
                )
            )
        )
    }

    func handleAIImageEditFailed(
        state: inout State,
        feedback: ApplicationFeature.Feedback
    ) -> Effect<Action> {
        state.activeAIImageJobID = nil
        return .send(.delegate(.aiImageGenerationFailed(feedback, appLanguageClient.load())))
    }

    func handleAIImageCancelRequested(state: inout State) -> Effect<Action> {
        state.activeAIImageJobID = nil
        return .merge(
            .send(.delegate(.aiImageGenerationFailed(.aiImageGenerationCanceled, appLanguageClient.load()))),
            .cancel(id: ApplicationFeature.CancelID.aiImageEdit)
        )
    }
}
