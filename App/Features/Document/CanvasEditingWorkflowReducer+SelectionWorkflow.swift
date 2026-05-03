import ComposableArchitecture
import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts

extension CanvasEditingWorkflowReducer {
    var selectionWorkflowService: SelectionWorkflowService {
        selectionWorkflowEnvironment.workflow
    }

    func handleInvertSelection(state: inout State) {
        state.canvas.replaceSelection(
            selectionWorkflowService.invertedSelection(
                state.canvas.selection,
                canvasSize: state.canvas.canvasSize,
                mode: state.canvas.selectionMode
            )
        )
    }

    func handleAdjustSelection(
        state: inout State,
        expansion: Int
    ) {
        guard state.canvas.selection != nil else { return }
        state.canvas.replaceSelection(
            selectionWorkflowService.adjustedSelection(
                state.canvas.selection,
                canvasSize: state.canvas.canvasSize,
                expansion: expansion,
                isInverted: false
            )
        )
    }

    func handleFeatherSelection(
        state: inout State,
        radius: Int
    ) {
        guard state.canvas.selection != nil else { return }
        state.canvas.replaceSelection(
            selectionWorkflowService.featheredSelection(
                state.canvas.selection,
                canvasSize: state.canvas.canvasSize,
                radius: radius
            )
        )
    }

    func handleColorRangeSelectionRequest(
        state: inout State,
        request: ColorRangeSelectionRequest
    ) -> Effect<Action> {
        let incomingSelection = selectionWorkflowService.makeColorRangeSelection(
            request: request,
            snapshot: state.canvas.renderSnapshot,
            activeLayerIndex: state.canvas.activeLayerIndex,
            mode: state.canvas.selectionMode
        )
        let selection = selectionWorkflowService.combinedSelection(
            existing: state.canvas.selection,
            incoming: incomingSelection,
            mode: state.brushPalette.selection.combineMode,
            canvasSize: state.canvas.canvasSize
        )
        state.canvas.replaceSelection(selection)
        return .none
    }

    func handleLassoSelection(
        state: inout State,
        points: [CGPoint]
    ) -> Effect<Action> {
        let incomingSelection: CanvasSelection?
        switch state.canvas.selectionMode {
        case .rectangle:
            guard let startPoint = points.first, let endPoint = points.last else { return .none }
            incomingSelection = selectionWorkflowService.makeRectangleSelection(
                from: startPoint,
                to: endPoint,
                canvasSize: state.canvas.canvasSize
            )
        case .lasso:
            incomingSelection = selectionWorkflowService.makeLassoSelection(
                from: points,
                canvasSize: state.canvas.canvasSize
            )
        case .auto:
            incomingSelection = nil
        }
        let selection = selectionWorkflowService.combinedSelection(
            existing: state.canvas.selection,
            incoming: incomingSelection,
            mode: state.brushPalette.selection.combineMode,
            canvasSize: state.canvas.canvasSize
        )
        state.canvas.replaceSelection(selection)
        return .none
    }

    func handleAutoSelection(
        state: inout State,
        sample: StylusSample
    ) -> Effect<Action> {
        let incomingSelection = selectionWorkflowService.makeAutoSelection(
            at: sample.point,
            snapshot: state.canvas.renderSnapshot,
            layerIndex: state.canvas.activeLayerIndex,
            thresholdMode: state.brushPalette.selection.thresholdMode,
            opacityTolerance: state.brushPalette.selection.opacityTolerance,
            colorTolerance: state.brushPalette.selection.colorTolerance,
            expansion: Int(state.brushPalette.selection.expansion.rounded())
        )
        let selection = selectionWorkflowService.combinedSelection(
            existing: state.canvas.selection,
            incoming: incomingSelection,
            mode: state.brushPalette.selection.combineMode,
            canvasSize: state.canvas.canvasSize
        )
        state.canvas.replaceSelection(selection)
        return .none
    }

    func handlePreviewSelectionMove(
        state: inout State,
        offset: CGSize
    ) -> Effect<Action> {
        guard canMoveActiveSelection(in: state) else {
            state.canvas.cancelSelectionMove()
            state.canvas.resetStrokePreview()
            return .none
        }
        guard abs(offset.width) >= 0.5 || abs(offset.height) >= 0.5 else {
            state.canvas.resetStrokePreview()
            return .none
        }
        let selection = state.canvas.selectionMoveSourceSelection ?? state.canvas.selection
        let baseSnapshot = state.canvas.selectionMoveBaseSnapshot ?? state.canvas.renderSnapshot
        guard
            let baseSnapshot,
            let layer = baseSnapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
            let transformedPixels = layerTransformProcessor.transformedLayerPixels(
                source: layer.pixelData,
                canvasWidth: baseSnapshot.width,
                canvasHeight: baseSnapshot.height,
                selection: selection,
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

    func handleApplySelectionMove(
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
                canvasSize: state.canvas.canvasSize
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

    func handleCancelSelectionMove(state: inout State) -> Effect<Action> {
        state.canvas.cancelSelectionMove()
        state.canvas.resetStrokePreview()
        return .none
    }

    private func canMoveActiveSelection(in state: State) -> Bool {
        guard state.canvas.selection != nil || state.canvas.selectionMoveStartPoint != nil else { return false }
        guard let layer = state.canvas.layerBuffers.first(where: { $0.index == state.canvas.activeLayerIndex }) else {
            return false
        }
        let layerRow = state.layerSidebar.layer(withIndex: state.canvas.activeLayerIndex)
        return layer.visible && !(layerRow?.isLocked ?? false)
    }
}
