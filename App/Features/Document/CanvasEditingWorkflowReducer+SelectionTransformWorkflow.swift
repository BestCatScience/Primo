import ComposableArchitecture
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentMutationContracts

extension CanvasEditingWorkflowReducer {
    func handleApplyTransform(state: inout State) -> Effect<Action> {
        let outcome = canvasEditingWorkflowService.execute(
            .applyTransform,
            state: CanvasEditingContext(canvas: state.canvas)
        )
        switch outcome {
        case .noPreview:
            return .none

        case .resetTransformPreview:
            _ = completeDocumentMutation(
                state: &state,
                contract: DocumentMutationContract(
                    canvasMutation: .resetTransformPreview,
                    refresh: .none,
                    successFeedback: nil
                )
            )
            return .none

        case .appliedTextTransform:
            return completeDocumentMutation(
                state: &state,
                contract: DocumentMutationContract(
                    canvasMutation: .resetTransformPreview,
                    successFeedback: nil
                )
            )

        case let .appliedPixelTransform(layerIndex, selection):
            return completeDocumentMutation(
                state: &state,
                contract: DocumentMutationContract(
                    canvasMutation: .completeTransform(
                        layerIndex: layerIndex,
                        selection: selection
                    ),
                    successFeedback: nil
                )
            )

        case let .failure(failure):
            return transformFailureEffect(failure)
        }
    }

    private func transformFailureEffect(
        _ failure: DocumentMutationFailure
    ) -> Effect<Action> {
        guard let feedback = DocumentMutationFeedbackMapper().feedback(for: failure) else {
            return .none
        }
        return .send(.delegate(.documentMutationFeedback(feedback)))
    }
}

private extension CanvasEditingContext {
    init(canvas: CanvasFeature.State) {
        self.init(
            transformHasPreview: canvas.transformHasPreview,
            transformPreviewOffset: canvas.transformPreviewOffset,
            transformPreviewScaleX: canvas.transformPreviewScaleX,
            transformPreviewScaleY: canvas.transformPreviewScaleY,
            transformPreviewRotationDegrees: canvas.transformPreviewRotationDegrees,
            transformMode: canvas.transformMode,
            transformPivot: canvas.transformPivot,
            transformQuadOffsets: canvas.transformQuadOffsets,
            activeLayerIndex: canvas.activeLayerIndex,
            activeTextLayer: canvas.activeTextLayer,
            selection: canvas.selection,
            canvasSize: canvas.canvasSize
        )
    }
}
