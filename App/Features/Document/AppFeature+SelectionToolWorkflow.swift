import ComposableArchitecture
import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

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
            state.brushPalette.ensureTextPlacement(in: state.canvas.canvasSize)
            syncTextEditorWithActiveLayer(state: &state)
        }
        if showsBrushSettingsPopover {
            state.brushPanel.isCollapsed = false
            state.brushPalette.presentBrushSettingsPopover()
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
                mode: state.canvas.selectionMode,
                gpuOperations: documentGpuOperationGateway
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
                isInverted: false,
                gpuOperations: documentGpuOperationGateway
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
                radius: radius,
                gpuOperations: documentGpuOperationGateway
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
            mode: state.canvas.selectionMode,
            gpuOperations: documentGpuOperationGateway
        )
        let selection = Self.combinedSelection(
            existing: state.canvas.selection,
            incoming: incomingSelection,
            mode: state.brushPalette.selection.combineMode,
            canvasSize: state.canvas.canvasSize,
            gpuOperations: documentGpuOperationGateway
        )
        return .send(.canvas(.selectionUpdated(selection)))
    }

    func handlePlaceText(
        state: inout State,
        point: CGPoint
    ) {
        state.brushPalette.setTextPlacement(point)
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
        state.layerSidebar.syncPaper(
            color: state.brushPalette.paper.color,
            isTransparent: state.brushPalette.paper.isTransparent
        )
    }

    func handlePaperBindingSync(state: inout State) -> Effect<Action> {
        handleBrushPaletteStateRefresh(state: &state)
        state.canvas.updatePaperStyle(resolvedPaperStyle(for: state))
        return .send(
            .documentPaperStyleSyncRequested(
                resolvedPaperStyle(for: state)
            )
        )
    }

    func handlePaperColorBindingChanged(state: inout State) -> Effect<Action> {
        state.brushPalette.syncPaper(
            color: state.layerSidebar.paperColor,
            isTransparent: state.layerSidebar.transparentPaper
        )
        return handlePaperBindingSync(state: &state)
    }

    func handleTransparentPaperBindingChanged(state: inout State) -> Effect<Action> {
        state.brushPalette.syncPaper(
            color: state.layerSidebar.paperColor,
            isTransparent: state.layerSidebar.transparentPaper
        )
        return handlePaperBindingSync(state: &state)
    }

    func handleBrushPalettePaperBindingChanged(state: inout State) -> Effect<Action> {
        handlePaperBindingSync(state: &state)
    }

    func handleLassoSelection(
        state: inout State,
        points: [CGPoint]
    ) -> Effect<Action> {
        let incomingSelection = Self.makeLassoSelection(
            from: points,
            canvasSize: state.canvas.canvasSize,
            gpuOperations: documentGpuOperationGateway
        )
        let selection = Self.combinedSelection(
            existing: state.canvas.selection,
            incoming: incomingSelection,
            mode: state.brushPalette.selection.combineMode,
            canvasSize: state.canvas.canvasSize,
            gpuOperations: documentGpuOperationGateway
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
            expansion: Int(state.brushPalette.selection.expansion.rounded()),
            gpuOperations: documentGpuOperationGateway
        )
        let selection = Self.combinedSelection(
            existing: state.canvas.selection,
            incoming: incomingSelection,
            mode: state.brushPalette.selection.combineMode,
            canvasSize: state.canvas.canvasSize,
            gpuOperations: documentGpuOperationGateway
        )
        return .send(.canvas(.selectionUpdated(selection)))
    }

    func handleColorSampled(
        state: inout State,
        sampledColor: SampledColor
    ) {
        state.brushPalette.applySampledColor(Self.color(from: sampledColor))
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
