import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleAutosaveRecoveryLoadRequest() -> Effect<Action> {
        workspaceTabCoordinator.loadAutosaveRecoveryEffect()
    }

    func handleAutosaveRecoveryRestoreRequest(
        state: inout State,
        autosaveID: WorkspaceItemID
    ) -> Effect<Action> {
        guard let item = state.autosaveRecoveryItems.first(where: { $0.id == autosaveID }) else {
            return .none
        }
        if !state.showsHome {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        state.isHydrating = true
        state.isShowingAutosaveRecovery = false
        return workspaceTabCoordinator.restoreAutosaveEffect(item: item)
    }

    func handleAutosaveRecoveryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        item: AutosaveRecoveryItem
    ) {
        try? documentWorkspaceClient.discardAutosaveEntry(item.id)
        state.applyLoadedProject(loaded)
        activateNewTab(
            state: &state,
            title: item.title,
            sourceProjectURL: item.sourceProjectURL
        )
        state.setActiveTabDirty(true)
        _ = persistActiveTabToBackingStore(state: &state)
        persistActiveTabAutosave(state: &state)
        state.isHydrating = false
        state.showsHome = false
        state.autosaveRecoveryItems.removeAll { $0.id == item.id }
        state.isShowingAutosaveRecovery = false
        state.bannerMessage = state.appLanguage.localized("自動保存から復元しました")
    }

    func handleAutosaveRecoveryDiscardRequest(
        state: inout State,
        autosaveID: WorkspaceItemID
    ) {
        state.autosaveRecoveryItems.removeAll { $0.id == autosaveID }
        state.isShowingAutosaveRecovery = !state.autosaveRecoveryItems.isEmpty
        try? documentWorkspaceClient.discardAutosaveEntry(autosaveID)
    }
}
