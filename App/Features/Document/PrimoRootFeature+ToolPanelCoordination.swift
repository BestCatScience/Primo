import Foundation
import PrimoDocumentContracts

extension CrossFeatureIntegrationReducer {
    func panelState(
        for panel: StudioPanelKind,
        state: State
    ) -> StudioPanelLayoutState {
        PrimoRootFeature.toolPanelStateCoordinator.panelState(for: panel, in: state)
    }

    func setPanelState(
        _ panelState: StudioPanelLayoutState,
        for panel: StudioPanelKind,
        state: inout State
    ) {
        PrimoRootFeature.toolPanelStateCoordinator.setPanelState(panelState, for: panel, in: &state)
    }

    func togglePanelCollapse(
        for panel: StudioPanelKind,
        state: inout State
    ) {
        PrimoRootFeature.toolPanelStateCoordinator.toggleCollapse(for: panel, in: &state)
    }

    func syncToolSpecificBrushSize(state: inout State) {
        PrimoRootFeature.toolPanelStateCoordinator.syncToolSpecificBrushSize(state: &state)
    }

    func applyToolSpecificBrushSize(
        for tool: StudioToolKind,
        state: inout State
    ) {
        PrimoRootFeature.toolPanelStateCoordinator.applyToolSpecificBrushSize(for: tool, state: &state)
    }
}
