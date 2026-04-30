import ComposableArchitecture
import PrimoDocumentApplication
import PrimoDocumentContracts

struct DocumentMutationWorkflowSupport<Action> {
    typealias State = DocumentFeature.State
    typealias DocumentCanvasMutation = DocumentFeature.DocumentCanvasMutation
    typealias DocumentMutationContract = DocumentFeature.DocumentMutationContract

    var presentationProvider: () -> PaintDocumentPresentation
    var refreshRequestedAction: Action
    var feedbackAction: (ApplicationFeature.Feedback) -> Action
    var presentationAppliedAction: Action

    @discardableResult
    func completeDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty
    ) -> Effect<Action> {
        apply(contract.canvasMutation, to: &state)
        let refreshEffect: Effect<Action>
        switch contract.refresh {
        case .none:
            refreshEffect = .none
        case .current:
            refreshEffect = applyPresentation(presentationProvider(), to: &state)
        case .dirty:
            refreshEffect = .send(refreshRequestedAction)
        }
        return .merge(
            refreshEffect,
            documentMutationFeedbackEffect(for: contract.successFeedback)
        )
    }

    @discardableResult
    func performDocumentMutation<Success>(
        state: inout State,
        contract: DocumentMutationContract = .dirty,
        failureFeedback: ApplicationFeature.Feedback? = nil,
        mutation: () -> Result<Success, DocumentMutationFailure>,
        onSuccess: (Success, inout State) -> Void = { _, _ in }
    ) -> Effect<Action> {
        switch mutation() {
        case let .success(success):
            onSuccess(success, &state)
            return completeDocumentMutation(state: &state, contract: contract)

        case let .failure(failure):
            return documentMutationFeedbackEffect(
                for: DocumentFeature.DocumentMutationFeedbackMapper().feedback(
                    for: failure,
                    default: failureFeedback
                )
            )
        }
    }

    func documentMutationFeedbackEffect(
        for feedback: ApplicationFeature.Feedback?
    ) -> Effect<Action> {
        guard let feedback else { return .none }
        return .send(feedbackAction(feedback))
    }

    func applyPresentation(
        _ presentation: PaintDocumentPresentation,
        to state: inout State
    ) -> Effect<Action> {
        guard DocumentFeature.canvasPresentationStateCoordinator.applyPresentation(presentation, to: &state) else {
            return .none
        }
        return .send(presentationAppliedAction)
    }

    private func apply(
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

extension DocumentLifecycleReducer {
    var documentMutationWorkflowSupport: DocumentMutationWorkflowSupport<Action> {
        DocumentMutationWorkflowSupport(
            presentationProvider: { documentQueryGateway.presentation() },
            refreshRequestedAction: .delegate(.presentationRefreshRequested),
            feedbackAction: { .delegate(.documentMutationFeedback($0)) },
            presentationAppliedAction: .delegate(.presentationApplied)
        )
    }

    @discardableResult
    func completeDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty
    ) -> Effect<Action> {
        documentMutationWorkflowSupport.completeDocumentMutation(state: &state, contract: contract)
    }

    @discardableResult
    func performDocumentMutation<Success>(
        state: inout State,
        contract: DocumentMutationContract = .dirty,
        failureFeedback: ApplicationFeature.Feedback? = nil,
        mutation: () -> Result<Success, DocumentMutationFailure>,
        onSuccess: (Success, inout State) -> Void = { _, _ in }
    ) -> Effect<Action> {
        documentMutationWorkflowSupport.performDocumentMutation(
            state: &state,
            contract: contract,
            failureFeedback: failureFeedback,
            mutation: mutation,
            onSuccess: onSuccess
        )
    }
}

extension CanvasEditingWorkflowReducer {
    var documentMutationWorkflowSupport: DocumentMutationWorkflowSupport<Action> {
        DocumentMutationWorkflowSupport(
            presentationProvider: { documentQueryGateway.presentation() },
            refreshRequestedAction: .delegate(.presentationRefreshRequested),
            feedbackAction: { .delegate(.documentMutationFeedback($0)) },
            presentationAppliedAction: .delegate(.presentationApplied)
        )
    }

    @discardableResult
    func completeDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty
    ) -> Effect<Action> {
        documentMutationWorkflowSupport.completeDocumentMutation(state: &state, contract: contract)
    }

    @discardableResult
    func performDocumentMutation<Success>(
        state: inout State,
        contract: DocumentMutationContract = .dirty,
        failureFeedback: ApplicationFeature.Feedback? = nil,
        mutation: () -> Result<Success, DocumentMutationFailure>,
        onSuccess: (Success, inout State) -> Void = { _, _ in }
    ) -> Effect<Action> {
        documentMutationWorkflowSupport.performDocumentMutation(
            state: &state,
            contract: contract,
            failureFeedback: failureFeedback,
            mutation: mutation,
            onSuccess: onSuccess
        )
    }

    func documentMutationFeedbackEffect(for feedback: ApplicationFeature.Feedback?) -> Effect<Action> {
        documentMutationWorkflowSupport.documentMutationFeedbackEffect(for: feedback)
    }
}

extension LayerWorkflowReducer {
    var documentMutationWorkflowSupport: DocumentMutationWorkflowSupport<Action> {
        DocumentMutationWorkflowSupport(
            presentationProvider: { documentQueryGateway.presentation() },
            refreshRequestedAction: .delegate(.presentationRefreshRequested),
            feedbackAction: { .delegate(.documentMutationFeedback($0)) },
            presentationAppliedAction: .delegate(.presentationApplied)
        )
    }

    @discardableResult
    func completeDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty
    ) -> Effect<Action> {
        documentMutationWorkflowSupport.completeDocumentMutation(state: &state, contract: contract)
    }

    @discardableResult
    func performDocumentMutation<Success>(
        state: inout State,
        contract: DocumentMutationContract = .dirty,
        failureFeedback: ApplicationFeature.Feedback? = nil,
        mutation: () -> Result<Success, DocumentMutationFailure>,
        onSuccess: (Success, inout State) -> Void = { _, _ in }
    ) -> Effect<Action> {
        documentMutationWorkflowSupport.performDocumentMutation(
            state: &state,
            contract: contract,
            failureFeedback: failureFeedback,
            mutation: mutation,
            onSuccess: onSuccess
        )
    }

    func documentMutationFeedbackEffect(for feedback: ApplicationFeature.Feedback?) -> Effect<Action> {
        documentMutationWorkflowSupport.documentMutationFeedbackEffect(for: feedback)
    }
}

extension AdjustmentWorkflowReducer {
    var documentMutationWorkflowSupport: DocumentMutationWorkflowSupport<Action> {
        DocumentMutationWorkflowSupport(
            presentationProvider: { documentQueryGateway.presentation() },
            refreshRequestedAction: .delegate(.presentationRefreshRequested),
            feedbackAction: { .delegate(.documentMutationFeedback($0)) },
            presentationAppliedAction: .delegate(.presentationApplied)
        )
    }

    @discardableResult
    func performDocumentMutation<Success>(
        state: inout State,
        contract: DocumentMutationContract = .dirty,
        failureFeedback: ApplicationFeature.Feedback? = nil,
        mutation: () -> Result<Success, DocumentMutationFailure>,
        onSuccess: (Success, inout State) -> Void = { _, _ in }
    ) -> Effect<Action> {
        documentMutationWorkflowSupport.performDocumentMutation(
            state: &state,
            contract: contract,
            failureFeedback: failureFeedback,
            mutation: mutation,
            onSuccess: onSuccess
        )
    }
}

extension AIImageWorkflowReducer {
    var documentMutationWorkflowSupport: DocumentMutationWorkflowSupport<Action> {
        DocumentMutationWorkflowSupport(
            presentationProvider: { documentQueryGateway.presentation() },
            refreshRequestedAction: .delegate(.presentationRefreshRequested),
            feedbackAction: { .delegate(.documentMutationFeedback($0)) },
            presentationAppliedAction: .delegate(.presentationApplied)
        )
    }

    @discardableResult
    func completeDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty
    ) -> Effect<Action> {
        documentMutationWorkflowSupport.completeDocumentMutation(state: &state, contract: contract)
    }
}
