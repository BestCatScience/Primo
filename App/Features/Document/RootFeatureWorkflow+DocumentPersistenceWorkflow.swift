import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension RootFeatureWorkflowReducer {
    func handleSaveHistoryRestoreRequest(
        state: inout State,
        projectURL: DocumentProjectPath,
        openInNewTab: Bool
    ) -> Effect<Action> {
        switch preparedDocumentReplacementRequestForProjectLoad(state: &state) {
        case let .success(replacementRequest):
            return .merge(
                .send(.application(.hydrationStarted)),
                .send(
                    .workspace(
                        .saveHistoryProjectLoadRequested(
                            projectURL,
                            openInNewTab: openInNewTab,
                            replacementRequest: replacementRequest
                        )
                    )
                )
            )
        case let .failure(failure):
            return presentWorkspaceLoadPreparationFailure(failure, state: state)
        }
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
            return .send(.workspace(.persistenceRequested(request)))
        case let .failure(failure):
            return .send(.application(.bannerPresented(
                workspaceFeedbackMapper.message(
                    for: workspaceFeedbackMapper.feedback(for: failure),
                    language: state.application.appLanguage
                )
            )))
        }
    }

}
