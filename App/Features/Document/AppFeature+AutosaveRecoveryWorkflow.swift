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
        guard let item = state.recovery.items.first(where: { $0.id == autosaveID }) else {
            return .none
        }
        if !state.showsHome {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        state.application.isHydrating = true
        state.recovery.dismiss()
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
        state.application.finishHydration(showingHome: false)
        state.recovery.removeItem(id: item.id)
        state.recovery.dismiss()
        state.application.presentBanner(state.appLanguage.localized("自動保存から復元しました"))
    }

    func handleAutosaveRecoveryDiscardRequest(
        state: inout State,
        autosaveID: WorkspaceItemID
    ) {
        state.recovery.removeItem(id: autosaveID)
        try? documentWorkspaceClient.discardAutosaveEntry(autosaveID)
    }
}
