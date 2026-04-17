import Foundation

extension AppFeature {
    func panelState(
        for panel: StudioPanelKind,
        state: State
    ) -> StudioPanelLayoutState {
        AppFeature.toolPanelStateCoordinator.panelState(for: panel, in: state)
    }

    func setPanelState(
        _ panelState: StudioPanelLayoutState,
        for panel: StudioPanelKind,
        state: inout State
    ) {
        AppFeature.toolPanelStateCoordinator.setPanelState(panelState, for: panel, in: &state)
    }

    func togglePanelCollapse(
        for panel: StudioPanelKind,
        state: inout State
    ) {
        AppFeature.toolPanelStateCoordinator.toggleCollapse(for: panel, in: &state)
    }

    func expandPanel(
        _ panel: StudioPanelKind,
        state: inout State
    ) {
        AppFeature.toolPanelStateCoordinator.expand(panel, in: &state)
    }

    func resetPanels(state: inout State) {
        AppFeature.toolPanelStateCoordinator.resetPanels(in: &state)
    }

    func syncToolSpecificBrushSize(state: inout State) {
        AppFeature.toolPanelStateCoordinator.syncToolSpecificBrushSize(state: &state)
    }

    func applyToolSpecificBrushSize(
        for tool: StudioToolKind,
        state: inout State
    ) {
        AppFeature.toolPanelStateCoordinator.applyToolSpecificBrushSize(for: tool, state: &state)
    }
}
