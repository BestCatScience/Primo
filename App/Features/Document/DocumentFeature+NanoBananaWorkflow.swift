import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoNanoBananaApplication
import PrimoNanoBananaDomain

extension DocumentFeature {
    private struct NanoBananaValidatedEdit {
        let command: SubmitNanoBananaEditCommand
        let selectionRegion: NanoBananaSelectionRegion?
        let outputLayerIndex: Int
        let sourceSurface: DocumentCompositeSurface
    }

    private struct NanoBananaValidationFailure: Error, Equatable {
        let feedback: ApplicationFeature.Feedback
    }

    private struct NanoBananaRequestContract {
        func validate(
            command: SubmitNanoBananaEditCommand,
            state: DocumentFeature.State,
            gpuOperations: DocumentGpuOperationGateway
        ) -> Result<NanoBananaValidatedEdit, NanoBananaValidationFailure> {
            let selectionWorkflow = SelectionWorkflowService(gpuOperations: gpuOperations)
            guard
                let snapshot = state.canvas.renderSnapshot,
                let layer = snapshot.layers.first(where: { $0.index == command.descriptor.inputLayerIndex })
            else {
                return .failure(NanoBananaValidationFailure(feedback: .nanoBananaPrepareLayerFailed))
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
                return .failure(NanoBananaValidationFailure(feedback: .nanoBananaSelectionRequired))
            }

            let outputLayerIndex = command.descriptor.outputMode == .replaceCurrentLayer
                ? command.descriptor.inputLayerIndex
                : state.canvas.activeLayerIndex
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
            state: DocumentFeature.State,
            namingPolicy: DocumentNamingPolicy
        ) -> Result<NanoBananaPreviewApplicationPlan, NanoBananaValidationFailure> {
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

        let contentService: DocumentContentService

        func apply(_ plan: NanoBananaPreviewApplicationPlan) -> Result<AppliedPreview, DocumentMutationFailure> {
            contentService.applyPixels(
                plan.preview.outputSurface.pixelData,
                to: plan.target
            )
            .map { AppliedPreview(targetLayerIndex: $0.targetLayerIndex) }
        }
    }

    private var nanoBananaRequestContract: NanoBananaRequestContract {
        NanoBananaRequestContract()
    }

    private var nanoBananaPreviewApplicationContract: NanoBananaPreviewApplicationContract {
        NanoBananaPreviewApplicationContract()
    }

    private var nanoBananaPreviewPreparationService: NanoBananaPreviewPreparationService {
        NanoBananaPreviewPreparationService(editUseCase: nanoBananaEditUseCase)
    }

    private var nanoBananaLayerContentService: DocumentContentService {
        DocumentContentService(
            documentQueryGateway: documentQueryGateway,
            documentMutationGateway: documentMutationGateway,
            textLayerGateway: textLayerGateway
        )
    }

    private var nanoBananaDocumentService: NanoBananaDocumentService {
        NanoBananaDocumentService(contentService: nanoBananaLayerContentService)
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
            return .send(.delegate(.documentMutationFeedback(error.feedback)))
        case let .success(edit):
            validatedEdit = edit
        }

        let generationStart = NanoBananaGenerationStart(
            descriptor: validatedEdit.command.descriptor,
            jobID: uuidClient.generate(),
            createdAt: dateClient.now()
        )
        return .merge(
            .send(.delegate(.nanoBananaGenerationStarted(generationStart))),
            .run { [nanoBananaPreviewPreparationService] send in
                switch await nanoBananaPreviewPreparationService.preparePreview(
                    NanoBananaPreviewPreparationRequest(
                        command: validatedEdit.command,
                        selectionRegion: validatedEdit.selectionRegion,
                        outputLayerIndex: validatedEdit.outputLayerIndex,
                        sourceSurface: validatedEdit.sourceSurface
                    )
                ) {
                case let .success(preview):
                    await send(.nanoBananaPreviewPrepared(preview))
                case let .failure(.editFailed(failure)):
                    await send(.nanoBananaPreviewPreparationFailed(Self.nanoBananaFailureFeedback(failure)))
                case .failure(.unsupportedImage):
                    await send(.nanoBananaPreviewPreparationFailed(.nanoBananaUnsupportedImage))
                }
            }
            .cancellable(id: ApplicationFeature.CancelID.nanoBananaEdit, cancelInFlight: true)
        )
    }

    func handleNanoBananaEditSucceeded(
        state: inout State,
        preview: NanoBananaPreviewState
    ) -> Effect<Action> {
        let language = appLanguageClient.load()
        let applicationPlan: NanoBananaPreviewApplicationPlan
        switch nanoBananaPreviewApplicationContract.validate(
            preview: preview,
            state: state,
            namingPolicy: DocumentNamingPolicy(language: language)
        ) {
        case let .failure(error):
            return handleNanoBananaEditFailed(state: &state, feedback: error.feedback)
        case let .success(plan):
            applicationPlan = plan
        }

        let appliedPreview: NanoBananaDocumentService.AppliedPreview
        switch nanoBananaDocumentService.apply(applicationPlan) {
        case let .success(preview):
            appliedPreview = preview
        case let .failure(failure):
            return handleNanoBananaEditFailed(
                state: &state,
                feedback: DocumentMutationFeedbackMapper().feedback(
                    for: failure,
                    default: .nanoBananaApplyFailed
                ) ?? .nanoBananaApplyFailed
            )
        }

        return .merge(
            .send(
                .delegate(
                    .nanoBananaEditApplied(
                        NanoBananaAppliedEdit(
                            preview: preview,
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
                    successFeedback: .nanoBananaEditApplied
                )
            )
        )
    }

    func handleNanoBananaEditFailed(
        state: inout State,
        feedback: ApplicationFeature.Feedback
    ) -> Effect<Action> {
        .send(.delegate(.nanoBananaGenerationFailed(feedback, appLanguageClient.load())))
    }

    func handleNanoBananaCancelRequested(state: inout State) -> Effect<Action> {
        .merge(
            .send(.delegate(.nanoBananaGenerationFailed(.nanoBananaGenerationCanceled, appLanguageClient.load()))),
            .cancel(id: ApplicationFeature.CancelID.nanoBananaEdit)
        )
    }
}
