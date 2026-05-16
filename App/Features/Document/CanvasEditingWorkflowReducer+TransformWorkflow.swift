import ComposableArchitecture
import CoreGraphics
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts

extension CanvasEditingWorkflowReducer {
    func handlePreviewLayerMoveWithTransform(
        state: inout State,
        offset: CGSize
    ) -> Effect<Action> {
        let baseSnapshot = state.canvas.selectionMoveBaseSnapshot ?? state.canvas.renderSnapshot
        guard
            let baseSnapshot,
            let layer = baseSnapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
            let sourceSurface = RgbaSurface(width: baseSnapshot.width, height: baseSnapshot.height, data: layer.pixelData),
            let transformedPixels = layerTransformProcessor.transformedLayerPixels(
                source: sourceSurface,
                selection: state.canvas.selectionMoveSourceSelection ?? state.canvas.selection,
                translation: offset,
                scaleX: 1,
                scaleY: 1,
                rotationDegrees: 0,
                pivot: nil,
                mode: .standard,
                quadOffsets: .zero
            )
        else {
            state.canvas.resetStrokePreview()
            return .none
        }

        DocumentFeature.canvasPreviewStateCoordinator.applyLiveStrokePreview(
            baseSnapshot: baseSnapshot,
            activeLayerIndex: state.canvas.activeLayerIndex,
            adjustedActiveLayerPixels: transformedPixels,
            gpuOperations: documentRenderingWorkflow,
            to: &state
        )
        return .none
    }

    func handleApplyLayerMoveWithTransform(
        state: inout State,
        offset: CGSize
    ) -> Effect<Action> {
        defer {
            state.canvas.cancelSelectionMove()
        }
        guard canMoveActiveSelection(in: state) else {
            state.canvas.resetStrokePreview()
            return .none
        }
        let roundedOffset = CGSize(width: offset.width.rounded(), height: offset.height.rounded())
        guard roundedOffset != .zero else {
            state.canvas.resetStrokePreview()
            return .none
        }
        guard let canvasGeometry = canvasGeometry(in: state) else {
            state.canvas.resetStrokePreview()
            return .none
        }
        let selection = state.canvas.selectionMoveSourceSelection ?? state.canvas.selection

        let outcome = canvasEditingWorkflowService.execute(
            .applyTransform,
            state: CanvasEditingContext(
                transformHasPreview: true,
                transformPreviewOffset: roundedOffset,
                transformPreviewScaleX: 1,
                transformPreviewScaleY: 1,
                transformPreviewRotationDegrees: 0,
                transformMode: .standard,
                transformPivot: nil,
                transformQuadOffsets: .zero,
                activeLayerIndex: state.canvas.activeLayerIndex,
                activeTextLayer: state.canvas.activeTextLayer,
                selection: selection,
                canvasGeometry: canvasGeometry
            )
        )

        switch outcome {
        case let .appliedPixelTransform(layerIndex, transformedSelection):
            state.canvas.replaceSelection(transformedSelection)
            return completeDocumentMutation(
                state: &state,
                contract: DocumentMutationContract(
                    canvasMutation: .finalizeLayer(
                        LayerMutationFinalization(
                            index: layerIndex,
                            incrementsRevision: true,
                            clearsSelection: false
                        )
                    )
                )
            )
        case .appliedTextTransform:
            return completeDocumentMutation(state: &state)
        case .noPreview, .resetTransformPreview:
            state.canvas.resetStrokePreview()
            return .none
        case let .failure(failure):
            state.canvas.resetStrokePreview()
            return documentMutationFeedbackEffect(
                for: DocumentMutationFeedbackMapper().feedback(for: failure)
            )
        }
    }
}
