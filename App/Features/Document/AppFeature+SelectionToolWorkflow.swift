import ComposableArchitecture
import CoreGraphics
import Foundation

extension AppFeature {
    func handleToolSelection(
        state: inout State,
        tool: StudioToolKind,
        showsBrushSettingsPopover: Bool
    ) {
        state.syncToolSpecificBrushSize()
        state.canvas.currentTool = tool
        state.applyToolSpecificBrushSize(for: tool)
        state.canvas.selectionMode = state.brushPalette.selection.toolMode
        state.canvas.shapeMode = state.brushPalette.shape.mode
        state.canvas.eyedropperSamplingSource = state.brushPalette.sampling.eyedropperSource
        state.canvas.selectionPreviewPoints = []
        state.canvas.resetTransformPreview()
        if tool != .select && tool != .move {
            state.canvas.selection = nil
        }
        if tool == .text {
            state.brushPanel.isCollapsed = false
            if state.brushPalette.text.position == nil {
                state.brushPalette.text.position = CGPoint(
                    x: state.canvas.canvasSize.width * 0.12,
                    y: state.canvas.canvasSize.height * 0.12
                )
            }
            state.syncTextEditorWithActiveLayer()
        }
        if showsBrushSettingsPopover {
            state.brushPanel.isCollapsed = false
            state.brushPalette.ui.showsBrushSettingsPopover = true
        }
        state.canvas.previewStyle = state.previewStrokeStyle()
    }

    func handleClearSelection(state: inout State) {
        state.canvas.selection = nil
        state.canvas.selectionPreviewPoints = []
        state.canvas.resetTransformPreview()
    }

    func handleInvertSelection(state: inout State) {
        state.canvas.selection = Self.invertedSelection(
            state.canvas.selection,
            canvasSize: state.canvas.canvasSize,
            mode: state.canvas.selectionMode
        )
        state.canvas.selectionPreviewPoints = []
        state.canvas.resetTransformPreview()
    }

    func handleAdjustSelection(
        state: inout State,
        expansion: Int
    ) {
        guard state.canvas.selection != nil else { return }
        state.canvas.selection = Self.adjustedSelection(
            state.canvas.selection,
            canvasSize: state.canvas.canvasSize,
            expansion: expansion,
            isInverted: false
        )
        state.canvas.selectionPreviewPoints = []
        state.canvas.resetTransformPreview()
    }

    func handleFeatherSelection(
        state: inout State,
        radius: Int
    ) {
        guard state.canvas.selection != nil else { return }
        state.canvas.selection = Self.featheredSelection(
            state.canvas.selection,
            canvasSize: state.canvas.canvasSize,
            radius: radius
        )
        state.canvas.selectionPreviewPoints = []
        state.canvas.resetTransformPreview()
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
        state.canvas.selectionPreviewPoints = []
        state.canvas.resetTransformPreview()
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
        state.syncToolSpecificBrushSize()
        state.canvas.selectionMode = state.brushPalette.selection.toolMode
        state.canvas.shapeMode = state.brushPalette.shape.mode
        state.canvas.eyedropperSamplingSource = state.brushPalette.sampling.eyedropperSource
        state.canvas.previewStyle = state.previewStrokeStyle()
        state.canvas.paperStyle = state.resolvedPaperStyle()
        state.layerSidebar.paperColor = state.brushPalette.paper.color
        state.layerSidebar.transparentPaper = state.brushPalette.paper.isTransparent
        paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
    }

    func handlePaperBindingSync(state: inout State) {
        state.canvas.paperStyle = state.resolvedPaperStyle()
        paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
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
        state.canvas.previewStyle = state.previewStrokeStyle()
    }

    func handleToggleBrushAndEraser(state: inout State) {
        state.syncToolSpecificBrushSize()
        let nextTool: StudioToolKind = state.canvas.currentTool == .erase ? .brush : .erase
        state.canvas.currentTool = nextTool
        state.applyToolSpecificBrushSize(for: nextTool)
        state.canvas.selectionMode = state.brushPalette.selection.toolMode
        state.canvas.eyedropperSamplingSource = state.brushPalette.sampling.eyedropperSource
        state.canvas.selectionPreviewPoints = []
        state.canvas.resetTransformPreview()
        if nextTool != .select && nextTool != .move {
            state.canvas.selection = nil
        }
        state.canvas.previewStyle = state.previewStrokeStyle()
    }
}
