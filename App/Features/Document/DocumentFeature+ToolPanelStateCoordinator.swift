import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension DocumentFeature {
    static let toolPanelStateCoordinator = ToolPanelStateCoordinator()

    struct ToolPanelStateCoordinator {
        func panelState(for panel: StudioPanelKind, in state: DocumentEditingState) -> StudioPanelLayoutState {
            switch panel {
            case .brush:
                return state.brushPanel
            case .layers:
                return state.layerPanel
            }
        }

        func setPanelState(
            _ panelState: StudioPanelLayoutState,
            for panel: StudioPanelKind,
            in state: inout DocumentEditingState
        ) {
            switch panel {
            case .brush:
                state.brushPanel = panelState
            case .layers:
                state.layerPanel = panelState
            }
        }

        func toggleCollapse(for panel: StudioPanelKind, in state: inout DocumentEditingState) {
            var current = panelState(for: panel, in: state)
            current.isCollapsed.toggle()
            setPanelState(current, for: panel, in: &state)
        }

        func expand(_ panel: StudioPanelKind, in state: inout DocumentEditingState) {
            var current = panelState(for: panel, in: state)
            current.isCollapsed = false
            setPanelState(current, for: panel, in: &state)
        }

        func resetPanels(in state: inout DocumentEditingState) {
            state.brushPanel = StudioPanelLayoutState()
            state.layerPanel = StudioPanelLayoutState()
        }

        func syncToolSpecificBrushSize(state: inout DocumentEditingState) {
            state.brushPalette.brush.storeCurrentRadius(for: state.canvas.currentTool)
        }

        func applyToolSpecificBrushSize(for tool: StudioToolKind, state: inout DocumentEditingState) {
            state.brushPalette.brush.applyStoredRadius(for: tool)
        }
    }
}

extension DocumentEditingState {
    mutating func refreshBrushPaletteState() {
        DocumentFeature.toolPanelStateCoordinator.syncToolSpecificBrushSize(state: &self)
        canvas.updateInteractionModes(
            selectionMode: brushPalette.selection.toolMode,
            shapeMode: brushPalette.shape.mode,
            eyedropperSamplingSource: brushPalette.sampling.eyedropperSource
        )
        canvas.updateInteractionStyle(
            previewStyle: DocumentFeature.canvasToolStateCoordinator.previewStrokeStyle(for: self),
            paperStyle: DocumentFeature.canvasToolStateCoordinator.resolvedPaperStyle(for: self)
        )
        layerSidebar.syncPaper(
            color: brushPalette.paper.color,
            isTransparent: brushPalette.paper.isTransparent
        )
    }

    mutating func syncBrushPalettePaperBinding() -> CanvasPaperStyle {
        refreshBrushPaletteState()
        let paperStyle = DocumentFeature.canvasToolStateCoordinator.resolvedPaperStyle(for: self)
        canvas.updatePaperStyle(paperStyle)
        return paperStyle
    }

    mutating func syncLayerSidebarPaperBinding() -> CanvasPaperStyle {
        brushPalette.syncPaper(
            color: layerSidebar.paperColor,
            isTransparent: layerSidebar.transparentPaper
        )
        return syncBrushPalettePaperBinding()
    }

    mutating func selectTool(
        _ tool: StudioToolKind,
        showsBrushSettingsPopover: Bool
    ) {
        DocumentFeature.toolPanelStateCoordinator.syncToolSpecificBrushSize(state: &self)
        canvas.selectTool(
            tool,
            selectionMode: brushPalette.selection.toolMode,
            shapeMode: brushPalette.shape.mode,
            eyedropperSamplingSource: brushPalette.sampling.eyedropperSource
        )
        DocumentFeature.toolPanelStateCoordinator.applyToolSpecificBrushSize(for: tool, state: &self)
        if tool == .text {
            brushPanel.isCollapsed = false
            brushPalette.ensureTextPlacement(in: canvas.canvasSize)
            syncTextEditorWithActiveLayer()
        }
        if showsBrushSettingsPopover {
            brushPanel.isCollapsed = false
            brushPalette.presentBrushSettingsPopover()
        }
        canvas.updatePreviewStyle(DocumentFeature.canvasToolStateCoordinator.previewStrokeStyle(for: self))
    }

    mutating func syncTextEditorWithActiveLayer() {
        brushPalette.syncTextEditor(
            with: layerSidebar.layer(withIndex: layerSidebar.activeLayerIndex)
        )
    }

    mutating func placeText(_ point: CGPoint) {
        brushPalette.setTextPlacement(point)
        brushPanel.isCollapsed = false
    }

    mutating func applyColorSampled(_ sampledColor: SampledColor) {
        brushPalette.applySampledColor(DocumentFeature.color(from: sampledColor))
        canvas.updatePreviewStyle(DocumentFeature.canvasToolStateCoordinator.previewStrokeStyle(for: self))
    }

    mutating func toggleBrushAndEraser() {
        DocumentFeature.toolPanelStateCoordinator.syncToolSpecificBrushSize(state: &self)
        let nextTool: StudioToolKind = canvas.currentTool == .erase ? .brush : .erase
        canvas.selectTool(
            nextTool,
            selectionMode: brushPalette.selection.toolMode,
            shapeMode: brushPalette.shape.mode,
            eyedropperSamplingSource: brushPalette.sampling.eyedropperSource
        )
        DocumentFeature.toolPanelStateCoordinator.applyToolSpecificBrushSize(for: nextTool, state: &self)
        canvas.updatePreviewStyle(DocumentFeature.canvasToolStateCoordinator.previewStrokeStyle(for: self))
    }
}
