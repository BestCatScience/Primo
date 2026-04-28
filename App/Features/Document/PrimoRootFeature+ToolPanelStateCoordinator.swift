import Foundation
import PrimoDocumentContracts

extension PrimoRootFeature {
    struct ToolPanelStateCoordinator {
        func panelState(for panel: StudioPanelKind, in state: PrimoRootFeature.State) -> StudioPanelLayoutState {
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
            in state: inout PrimoRootFeature.State
        ) {
            switch panel {
            case .brush:
                state.brushPanel = panelState
            case .layers:
                state.layerPanel = panelState
            }
        }

        func toggleCollapse(for panel: StudioPanelKind, in state: inout PrimoRootFeature.State) {
            var current = panelState(for: panel, in: state)
            current.isCollapsed.toggle()
            setPanelState(current, for: panel, in: &state)
        }

        func expand(_ panel: StudioPanelKind, in state: inout PrimoRootFeature.State) {
            var current = panelState(for: panel, in: state)
            current.isCollapsed = false
            setPanelState(current, for: panel, in: &state)
        }

        func resetPanels(in state: inout PrimoRootFeature.State) {
            state.brushPanel = StudioPanelLayoutState()
            state.layerPanel = StudioPanelLayoutState()
        }

        func syncToolSpecificBrushSize(state: inout PrimoRootFeature.State) {
            state.brushPalette.brush.storeCurrentRadius(for: state.canvas.currentTool)
        }

        func applyToolSpecificBrushSize(for tool: StudioToolKind, state: inout PrimoRootFeature.State) {
            state.brushPalette.brush.applyStoredRadius(for: tool)
        }
    }
}
