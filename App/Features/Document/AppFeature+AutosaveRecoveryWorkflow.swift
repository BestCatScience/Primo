import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension AppIntegrationFeature {
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
        let language = state.application.appLanguage
        return beginWorkspaceProjectLoad(
            state: &state,
            fileURL: item.autosaveProjectURL.fileURL,
            onSuccess: { .autosaveRecoveryOpened($0, item, $1) },
            onFailure: {
                .autosaveRecoveryRestoreFailed(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: $0, context: .autosaveRestore),
                        language: language
                    )
                )
            }
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
                    completion: .restoredAutosave
                )
            ),
            presentation: LoadedWorkspacePresentation(
                issues: issues,
                completion: .restoredAutosave
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
        message: String?
    ) {
        state.application.failHydration(
            message: message
        )
    }
}
