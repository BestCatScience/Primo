import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension AppIntegrationFeature {
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
        let language = state.application.appLanguage
        return beginWorkspaceProjectLoad(
            state: &state,
            fileURL: projectURL.fileURL,
            onSuccess: { .saveHistoryOpened($0, projectURL, openInNewTab, $1) },
            onFailure: {
                .saveHistoryRestoreFailed(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: $0, context: .saveHistoryRestore),
                        language: language
                    )
                )
            }
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
                        completion: .restoredSaveHistory
                    )
                ),
                presentation: LoadedWorkspacePresentation(
                    issues: issues,
                    completion: .restoredSaveHistory
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
                        completion: .restoredSaveHistory
                    )
                ),
                presentation: LoadedWorkspacePresentation(
                    issues: issues,
                    completion: .restoredSaveHistory
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
            state.application.presentBanner(
                workspaceFeedbackMapper.message(
                    for: workspaceFeedbackMapper.feedback(for: failure),
                    language: state.application.appLanguage
                )
            )
            return .none
        }
    }

    func handleSaveHistoryRestoreFailed(
        state: inout State,
        message: String?
    ) {
        state.application.failHydration(
            message: message
        )
    }

    func handleSaveHistoryLoadFailed(
        state: inout State,
        message: String?
    ) {
        state.saveHistory.dismiss()
        state.application.presentBanner(message)
    }
}
