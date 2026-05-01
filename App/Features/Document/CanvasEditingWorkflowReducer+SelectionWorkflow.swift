import ComposableArchitecture
import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts

extension CanvasEditingWorkflowReducer {
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
        return .send(.canvas(.selectionUpdated(selection)))
    }

    func handleLassoSelection(
        state: inout State,
        points: [CGPoint]
    ) -> Effect<Action> {
        let incomingSelection = selectionWorkflowService.makeLassoSelection(
            from: points,
            canvasSize: state.canvas.canvasSize
        )
        let selection = selectionWorkflowService.combinedSelection(
            existing: state.canvas.selection,
            incoming: incomingSelection,
            mode: state.brushPalette.selection.combineMode,
            canvasSize: state.canvas.canvasSize
        )
        return .send(.canvas(.selectionUpdated(selection)))
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
        return .send(.canvas(.selectionUpdated(selection)))
    }
}
