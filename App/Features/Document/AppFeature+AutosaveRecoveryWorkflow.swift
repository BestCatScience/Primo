import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleAutosaveRecoveryLoadRequest() -> Effect<Action> {
        .send(.workspaceCatalogRequested(.loadAutosaveRecoveryItems))
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
            onSuccess: { .autosaveRecoveryOpened($0, item, $1) },
            onFailure: { .autosaveRecoveryRestoreFailed(.autosaveRestoreFailed($0.errorMessage)) }
        )
    }

    func handleAutosaveRecoveryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        item: AutosaveRecoveryItem,
        issues: [WorkspaceProjectLoadIssue]
    ) -> Effect<Action> {
        return applyLoadedWorkspaceProject(
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
                    feedback: .restoredAutosave,
                    warningMessage: workspaceProjectLoadWarningMessage(
                        issues,
                        language: state.application.appLanguage
                    )
                )
            ),
            state: &state
        )
    }

    func handleAutosaveRecoveryDiscardRequest(
        state: inout State,
        autosaveID: WorkspaceItemID
    ) -> Effect<Action> {
        .send(
            .workspaceCatalogRequested(
                .discardAutosaveEntry(
                    WorkspaceAutosaveEntryDiscardRequest(
                        autosaveID: autosaveID
                    )
                )
            )
        )
    }

    func handleAutosaveRecoveryRestoreFailed(
        state: inout State,
        feedback: ApplicationFeedback
    ) {
        state.application.failHydration(feedback: feedback)
    }
}
