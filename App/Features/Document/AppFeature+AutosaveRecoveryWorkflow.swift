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
            onFailure: {
                .autosaveRecoveryRestoreFailed(
                    .autosaveRestoreFailed(Self.optionalErrorMessage($0))
                )
            }
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
                    feedback: .restoredAutosave
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
        feedback: ApplicationFeedback
    ) {
        state.application.failHydration(feedback: feedback)
    }
}
