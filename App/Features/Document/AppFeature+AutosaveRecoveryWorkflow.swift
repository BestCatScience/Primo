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
        if !state.application.showsHome {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        state.application.beginHydration()
        state.recovery.dismiss()
        return workspaceTabCoordinator.restoreAutosaveEffect(item: item)
    }

    func handleAutosaveRecoveryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        item: AutosaveRecoveryItem
    ) {
        try? workspaceCatalogService.discardAutosaveEntry(item.id)
        applyLoadedProject(loaded, state: &state)
        activateNewTab(
            state: &state,
            title: item.title,
            sourceProjectURL: item.sourceProjectURL
        )
        state.workspace.setActiveTabDirty(true)
        _ = persistActiveTabToBackingStore(state: &state)
        persistActiveTabAutosave(state: &state)
        state.application.finishHydration(showingHome: false)
        state.recovery.removeItem(id: item.id)
        state.recovery.dismiss()
        state.application.presentBanner(state.application.appLanguage.localized("自動保存から復元しました"))
    }

    func handleAutosaveRecoveryDiscardRequest(
        state: inout State,
        autosaveID: WorkspaceItemID
    ) {
        state.recovery.removeItem(id: autosaveID)
        try? workspaceCatalogService.discardAutosaveEntry(autosaveID)
    }
}
