import Foundation

extension AppFeature.State {
    func panelState(for panel: StudioPanelKind) -> StudioPanelLayoutState {
        AppFeature.toolPanelStateCoordinator.panelState(for: panel, in: self)
    }

    mutating func setPanelState(_ panelState: StudioPanelLayoutState, for panel: StudioPanelKind) {
        AppFeature.toolPanelStateCoordinator.setPanelState(panelState, for: panel, in: &self)
    }

    mutating func toggleCollapse(for panel: StudioPanelKind) {
        AppFeature.toolPanelStateCoordinator.toggleCollapse(for: panel, in: &self)
    }

    mutating func syncToolSpecificBrushSize() {
        AppFeature.toolPanelStateCoordinator.syncToolSpecificBrushSize(state: &self)
    }

    mutating func applyToolSpecificBrushSize(for tool: StudioToolKind) {
        AppFeature.toolPanelStateCoordinator.applyToolSpecificBrushSize(for: tool, state: &self)
    }
}
