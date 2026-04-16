import ComposableArchitecture
import CoreGraphics
import Foundation

extension AppFeature {
    func handleToolSelection(
        state: inout State,
        tool: StudioToolKind,
        showsBrushSettingsPopover: Bool
    ) {
        syncToolSpecificBrushSize(state: &state)
        state.canvas.selectTool(
            tool,
            selectionMode: state.brushPalette.selection.toolMode,
            shapeMode: state.brushPalette.shape.mode,
            eyedropperSamplingSource: state.brushPalette.sampling.eyedropperSource
        )
        applyToolSpecificBrushSize(for: tool, state: &state)
        if tool == .text {
            state.brushPanel.isCollapsed = false
            if state.brushPalette.text.position == nil {
                state.brushPalette.text.position = CGPoint(
                    x: state.canvas.canvasSize.width * 0.12,
                    y: state.canvas.canvasSize.height * 0.12
                )
            }
            syncTextEditorWithActiveLayer(state: &state)
        }
        if showsBrushSettingsPopover {
            state.brushPanel.isCollapsed = false
            state.brushPalette.ui.showsBrushSettingsPopover = true
        }
        state.canvas.updatePreviewStyle(previewStrokeStyle(for: state))
    }

    func handleClearSelection(state: inout State) {
        state.canvas.clearSelectionState()
    }

    func handleInvertSelection(state: inout State) {
        state.canvas.replaceSelection(
            Self.invertedSelection(
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
            Self.adjustedSelection(
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
            Self.featheredSelection(
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
        let incomingSelection = Self.makeColorRangeSelection(
            request: request,
            snapshot: state.canvas.renderSnapshot,
            activeLayerIndex: state.canvas.activeLayerIndex,
            mode: state.canvas.selectionMode
        )
        let selection = Self.combinedSelection(
            existing: state.canvas.selection,
            incoming: incomingSelection,
            mode: state.brushPalette.selection.combineMode,
            canvasSize: state.canvas.canvasSize
        )
        return .send(.canvas(.selectionUpdated(selection)))
    }

    func handlePlaceText(
        state: inout State,
        point: CGPoint
    ) {
        state.brushPalette.text.position = point
        state.brushPanel.isCollapsed = false
    }

    func handleBrushPaletteStateRefresh(state: inout State) {
        syncToolSpecificBrushSize(state: &state)
        state.canvas.updateInteractionModes(
            selectionMode: state.brushPalette.selection.toolMode,
            shapeMode: state.brushPalette.shape.mode,
            eyedropperSamplingSource: state.brushPalette.sampling.eyedropperSource
        )
        state.canvas.updateInteractionStyle(
            previewStyle: previewStrokeStyle(for: state),
            paperStyle: resolvedPaperStyle(for: state)
        )
        state.layerSidebar.paperColor = state.brushPalette.paper.color
        state.layerSidebar.transparentPaper = state.brushPalette.paper.isTransparent
        paintDocumentClient.setPaperStyle(resolvedPaperStyle(for: state))
    }

    func handlePaperBindingSync(state: inout State) {
        state.canvas.updatePaperStyle(resolvedPaperStyle(for: state))
        paintDocumentClient.setPaperStyle(resolvedPaperStyle(for: state))
    }

    func handlePaperColorBindingChanged(state: inout State) {
        state.brushPalette.paper.color = state.layerSidebar.paperColor
        handlePaperBindingSync(state: &state)
    }

    func handleTransparentPaperBindingChanged(state: inout State) {
        state.brushPalette.paper.isTransparent = state.layerSidebar.transparentPaper
        handlePaperBindingSync(state: &state)
    }

    func handleLassoSelection(
        state: inout State,
        points: [CGPoint]
    ) -> Effect<Action> {
        let incomingSelection = Self.makeLassoSelection(
            from: points,
            canvasSize: state.canvas.canvasSize
        )
        let selection = Self.combinedSelection(
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
        let incomingSelection = Self.makeAutoSelection(
            at: sample.point,
            snapshot: state.canvas.renderSnapshot,
            layerIndex: state.canvas.activeLayerIndex,
            thresholdMode: state.brushPalette.selection.thresholdMode,
            opacityTolerance: state.brushPalette.selection.opacityTolerance,
            colorTolerance: state.brushPalette.selection.colorTolerance,
            expansion: Int(state.brushPalette.selection.expansion.rounded())
        )
        let selection = Self.combinedSelection(
            existing: state.canvas.selection,
            incoming: incomingSelection,
            mode: state.brushPalette.selection.combineMode,
            canvasSize: state.canvas.canvasSize
        )
        return .send(.canvas(.selectionUpdated(selection)))
    }

    func handleColorSampled(
        state: inout State,
        sampledColor: SampledColor
    ) {
        let sampled = Self.color(from: sampledColor)
        if state.brushPalette.brush.selectedColorSlot == .transparent {
            state.brushPalette.brush.selectedColorSlot = .primary
        }
        state.brushPalette.brush.setSelectedSlotColor(sampled)
        state.brushPalette.library.selectedBrush = nil
        state.canvas.updatePreviewStyle(previewStrokeStyle(for: state))
    }

    func handleToggleBrushAndEraser(state: inout State) {
        syncToolSpecificBrushSize(state: &state)
        let nextTool: StudioToolKind = state.canvas.currentTool == .erase ? .brush : .erase
        state.canvas.selectTool(
            nextTool,
            selectionMode: state.brushPalette.selection.toolMode,
            shapeMode: state.brushPalette.shape.mode,
            eyedropperSamplingSource: state.brushPalette.sampling.eyedropperSource
        )
        applyToolSpecificBrushSize(for: nextTool, state: &state)
        state.canvas.updatePreviewStyle(previewStrokeStyle(for: state))
    }
}
