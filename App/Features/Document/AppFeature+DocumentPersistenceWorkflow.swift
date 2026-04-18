import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleSaveHistoryRequest(state: inout State) -> Effect<Action> {
        guard let activeTab = state.workspace.activeTab else { return .none }
        state.saveHistory.beginPresentation()
        return .send(
            .workspaceCatalogRequested(
                .loadSaveHistoryEntries(
                    WorkspaceSaveHistoryLoadRequest(
                        activeTab: activeTab
                    )
                )
            )
        )
    }

    func handleSaveHistoryRestoreRequest(
        state: inout State,
        projectURL: DocumentProjectPath,
        openInNewTab: Bool
    ) -> Effect<Action> {
        return beginWorkspaceProjectLoad(
            state: &state,
            fileURL: projectURL.fileURL,
            onSuccess: { .saveHistoryOpened($0, projectURL, openInNewTab, $1) },
            onFailure: { .saveHistoryRestoreFailed(.saveHistoryRestoreFailed($0.errorMessage)) }
        )
    }

    func handleSaveHistoryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        projectURL: DocumentProjectPath,
        openInNewTab: Bool,
        issues: [WorkspaceProjectLoadIssue]
    ) -> Effect<Action> {
        let restoredTitle = projectURL.displayName
        let warningMessage = workspaceProjectLoadWarningMessage(
            issues,
            language: state.application.appLanguage
        )
        if openInNewTab || state.workspace.activeTab == nil {
            return applyLoadedWorkspaceProject(
                loaded,
                using: LoadedWorkspaceProjectPlan(
                    destination: .newTab(
                        title: "\(restoredTitle) Snapshot",
                        sourceProjectURL: nil
                    ),
                    followUp: .init(
                        marksTabDirty: true,
                        persistsToBackingStore: true,
                        persistsAutosave: true
                    ),
                    successEffects: .init(
                        saveHistoryResolution: .completeRestore,
                        feedback: .restoredSaveHistory,
                        warningMessage: warningMessage
                    )
                ),
                state: &state
            )
        } else {
            let existingSourceURL = state.workspace.activeTab?.sourceProjectURL
            let existingTitle = state.workspace.activeTab?.title ?? restoredTitle
            return applyLoadedWorkspaceProject(
                loaded,
                using: LoadedWorkspaceProjectPlan(
                    destination: .activeTab(
                        title: existingTitle,
                        sourceProjectURL: existingSourceURL
                    ),
                    followUp: .init(
                        marksTabDirty: true,
                        persistsToBackingStore: true,
                        persistsAutosave: true
                    ),
                    successEffects: .init(
                        saveHistoryResolution: .completeRestore,
                        feedback: .restoredSaveHistory,
                        warningMessage: warningMessage
                    )
                ),
                state: &state
            )
        }
    }

    func handleSaveDocumentRequest(
        state: inout State,
        preferredDestinationURL: DocumentProjectPath?
    ) -> Effect<Action> {
        switch saveActiveDocumentRequest(
            state: &state,
            preferredDestinationURL: preferredDestinationURL,
            trigger: .manualSave,
            purpose: .saveDocument
        ) {
        case let .success(request):
            return .send(.workspacePersistenceRequested(request))
        case let .failure(failure):
            state.application.presentFeedback(failure.feedback)
            return .none
        }
    }

    func handleSaveHistoryRestoreFailed(
        state: inout State,
        feedback: ApplicationFeedback
    ) {
        state.application.failHydration(feedback: feedback)
    }

    func handleSaveHistoryLoadFailed(
        state: inout State,
        feedback: ApplicationFeedback
    ) {
        state.saveHistory.dismiss()
        state.application.presentFeedback(feedback)
    }
}
