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
        applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .newTab(
                    title: item.title,
                    sourceProjectURL: item.sourceProjectURL
                ),
                marksTabDirty: true,
                persistsToBackingStore: true,
                persistsAutosave: true,
                discardedAutosaveEntryID: item.id,
                removedRecoveryItemID: item.id,
                dismissesRecovery: true,
                bannerMessage: state.application.appLanguage.localized("自動保存から復元しました")
            ),
            state: &state
        )
    }

    func handleAutosaveRecoveryDiscardRequest(
        state: inout State,
        autosaveID: WorkspaceItemID
    ) {
        state.recovery.removeItem(id: autosaveID)
        try? workspaceCatalogService.discardAutosaveEntry(autosaveID)
    }
}
