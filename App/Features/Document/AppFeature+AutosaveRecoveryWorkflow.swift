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
        guard let item = state.recovery.item(id: autosaveID) else {
            return .none
        }
        return beginWorkspaceProjectLoad(
            state: &state,
            fileURL: item.autosaveProjectURL.fileURL,
            onSuccess: { .autosaveRecoveryOpened($0, item) },
            onFailure: { .autosaveRecoveryRestoreFailed($0) }
        )
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
                followUp: .init(
                    marksTabDirty: true,
                    persistsToBackingStore: true,
                    persistsAutosave: true
                ),
                successEffects: .init(
                    discardedAutosaveEntryID: item.id,
                    recoveryResolution: .completeRestore(item.id),
                    bannerMessage: state.application.appLanguage.localized("自動保存から復元しました")
                )
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

    func handleAutosaveRecoveryRestoreFailed(
        state: inout State,
        message: String
    ) {
        state.application.failHydration(
            message: message.isEmpty
                ? state.application.appLanguage.localized("Could not restore autosave")
                : message
        )
    }
}
