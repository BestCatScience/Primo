import ComposableArchitecture
import Foundation
import PrimoBrushDomain
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain

extension DocumentMutationWorkflowOutcome where Selection == CanvasSelection, Feedback == AppFeature.ApplicationFeedback {
    init(
        canvasMutation: DocumentCanvasMutationIntent<CanvasSelection> = .none,
        refresh: DocumentPresentationRefreshIntent = .dirty,
        successFeedback: AppFeature.ApplicationFeedback?,
        updatesWorkspaceArtifacts: Bool = true
    ) {
        self.init(
            canvasMutation: canvasMutation,
            refresh: refresh,
            feedback: successFeedback.map { .success($0) } ?? .none,
            updatesWorkspaceArtifacts: updatesWorkspaceArtifacts
        )
    }
}

extension AppIntegrationFeature {
    typealias DocumentCanvasMutation = DocumentCanvasMutationIntent<CanvasSelection>
    typealias DocumentPresentationRefresh = DocumentPresentationRefreshIntent
    typealias LayerMutationFinalization = DocumentLayerMutationFinalization
    typealias DocumentMutationContract = DocumentMutationWorkflowOutcome<CanvasSelection, ApplicationFeedback>
    typealias LayerWorkflowService = DocumentMutationWorkflowService

    struct DocumentCanvasMutationCoordinator {
        func apply(
            _ mutation: DocumentCanvasMutation,
            to state: inout State
        ) {
            switch mutation {
            case .none:
                break
            case .clearSelection:
                state.canvas.clearSelection()
            case let .finalizeLayer(finalization):
                state.canvas.finalizeLayerMutation(
                    at: finalization.index,
                    incrementsRevision: finalization.incrementsRevision,
                    clearsSelection: finalization.clearsSelection
                )
            case let .completeTransform(layerIndex, selection):
                state.canvas.completeTransformMutation(
                    at: layerIndex,
                    selection: selection
                )
            case .resetTransientEditingState:
                state.canvas.resetTransientEditingState()
            case .resetTransformPreview:
                state.canvas.resetTransformPreview()
            }
        }
    }

    struct DocumentPresentationRefreshCoordinator {
        func apply(
            _ refresh: DocumentPresentationRefresh,
            to state: inout State,
            applyCurrentPresentation: (inout State) -> Void,
            applyDirtyPresentation: (inout State) -> Void
        ) {
            switch refresh {
            case .none:
                break
            case .current:
                applyCurrentPresentation(&state)
            case .dirty:
                applyDirtyPresentation(&state)
            }
        }
    }

    struct DocumentMutationFeedbackCoordinator {
        func apply(
            _ feedback: ApplicationFeedback?,
            to state: inout State
        ) {
            guard let feedback else { return }
            state.application.presentFeedback(feedback)
        }
    }

    struct DocumentMutationFeedbackMapper {
        func feedback(
            for failure: DocumentMutationFailure,
            default defaultFeedback: ApplicationFeedback? = nil
        ) -> ApplicationFeedback? {
            if let defaultFeedback {
                return defaultFeedback
            }
            switch failure {
            case .invalidCanvasSize:
                return .canvasSizeUnsupported
            case .noUndoState:
                return .undoUnavailableWhileDrawing
            case .noRedoState:
                return .redoUnavailableWhileDrawing
            case .invalidLayerIndex:
                return .layerUnavailable
            case .invalidFolderID:
                return .folderUnavailable
            case .layerLocked:
                return .layerEditLocked
            case .alphaLocked:
                return .layerAlphaEditLocked
            case .invalidOpacity:
                return .invalidLayerOpacity
            case .emptyInput:
                return .emptyDocumentMutationInput
            case let .bridgeMutationFailed(message):
                return .documentMutationBridgeFailed(message)
            case .incompatibleLayerType:
                return .unsupportedLayerType
            case let .transactionFailure(primary, rollback):
                return .documentMutationTransactionFailed(primary, rollback)
            }
        }
    }

    var layerWorkflowService: LayerWorkflowService {
        documentMutationWorkflowService
    }

    var documentCanvasMutationCoordinator: DocumentCanvasMutationCoordinator {
        DocumentCanvasMutationCoordinator()
    }

    var documentPresentationRefreshCoordinator: DocumentPresentationRefreshCoordinator {
        DocumentPresentationRefreshCoordinator()
    }

    var documentMutationFeedbackCoordinator: DocumentMutationFeedbackCoordinator {
        DocumentMutationFeedbackCoordinator()
    }

    var documentMutationFeedbackMapper: DocumentMutationFeedbackMapper {
        DocumentMutationFeedbackMapper()
    }

    @discardableResult
    func completeDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty
    ) -> Effect<Action> {
        documentCanvasMutationCoordinator.apply(
            contract.canvasMutation,
            to: &state
        )
        let effect: Effect<Action>
        switch contract.refresh {
        case .none:
            effect = .none
        case .current:
            applyPresentation(documentPresentationQueryService.presentation(), state: &state)
            effect = .none
        case .dirty:
            effect = applyDirtyPresentation(
                state: &state,
                updatesWorkspaceArtifacts: contract.updatesWorkspaceArtifacts
            )
        }
        documentMutationFeedbackCoordinator.apply(
            contract.successFeedback,
            to: &state
        )
        return effect
    }

    @discardableResult
    func performDocumentMutation<Success>(
        state: inout State,
        contract: DocumentMutationContract = .dirty,
        failureFeedback: ApplicationFeedback? = nil,
        mutation: () -> Result<Success, DocumentMutationFailure>,
        onSuccess: (Success, inout State) -> Void = { _, _ in }
    ) -> Effect<Action> {
        switch mutation() {
        case let .success(success):
            onSuccess(success, &state)
            return completeDocumentMutation(state: &state, contract: contract)
        case let .failure(failure):
            documentMutationFeedbackCoordinator.apply(
                documentMutationFeedbackMapper.feedback(
                    for: failure,
                    default: failureFeedback
                ),
                to: &state
            )
            return .none
        }
    }
}

private extension DocumentMutationWorkflowOutcome where Selection == CanvasSelection, Feedback == AppFeature.ApplicationFeedback {
    var successFeedback: AppFeature.ApplicationFeedback? {
        guard case let .success(feedback) = feedback else { return nil }
        return feedback
    }
}
