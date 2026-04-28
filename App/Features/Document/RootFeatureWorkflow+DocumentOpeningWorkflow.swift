import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension RootFeatureWorkflowReducer {
    func handleOpenImportedDocumentRequest(
        state: inout State,
        sourceURL: URL
    ) -> Effect<Action> {
        switch preparedDocumentReplacementRequestForProjectLoad(state: &state) {
        case let .success(replacementRequest):
            return .merge(
                .send(.application(.hydrationStarted)),
                .send(.workspace(.importedProjectLoadRequested(sourceURL, replacementRequest: replacementRequest)))
            )
        case let .failure(failure):
            return presentWorkspaceLoadPreparationFailure(failure, state: state)
        }
    }

    func handleOpenImportedDocumentLoaded(
        state: inout State,
        loaded: LoadedPaintProject,
        suggestedTitle: String,
        issues: [WorkspaceProjectLoadIssue]
    ) -> Effect<Action> {
        let trimmedTitle = suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty
            ? (state.application.appLanguage == .japanese ? "読み込み済みドキュメント" : "Imported Document")
            : trimmedTitle
        return applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .newTab(
                    title: resolvedTitle,
                    sourceProjectURL: nil
                ),
                successEffects: .init(
                    completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                )
            ),
            presentation: LoadedWorkspacePresentation(
                issues: issues,
                completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
            ),
            state: &state
        )
    }

    func handleOpenDocumentSelection(
        state: inout State,
        url: DocumentProjectPath,
        removesStagedWorkspaceItem: Bool
    ) -> Effect<Action> {
        if let existingTabID = state.workspace.tabID(forSourceProjectURL: url) {
            return .merge(
                .send(.application(.workspaceProjectLoadCompleted(nil))),
                .send(.workspace(.tabSelected(existingTabID)))
            )
        }
        switch preparedDocumentReplacementRequestForProjectLoad(state: &state) {
        case let .success(replacementRequest):
            return .merge(
                .send(.application(.hydrationStarted)),
                .send(
                    .workspace(
                        .projectLoadRequested(
                            url,
                            removesStagedWorkspaceItem: removesStagedWorkspaceItem,
                            replacementRequest: replacementRequest
                        )
                    )
                )
            )
        case let .failure(failure):
            return presentWorkspaceLoadPreparationFailure(failure, state: state)
        }
    }

    func handleOpenDocumentLoaded(
        state: inout State,
        loaded: LoadedPaintProject,
        sourceURL: DocumentProjectPath,
        issues: [WorkspaceProjectLoadIssue]
    ) -> Effect<Action> {
        if let existingTabID = state.workspace.tabID(forSourceProjectURL: sourceURL) {
            return .merge(
                .send(.application(.workspaceProjectLoadCompleted(
                    workspaceFeedbackMapper.bannerMessage(
                        for: issues,
                        language: state.application.appLanguage
                    )
                ))),
                .send(.workspace(.tabSelected(existingTabID)))
            )
        }
        return applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .newTab(
                    title: sourceURL.displayName,
                    sourceProjectURL: sourceURL
                ),
                successEffects: .init(
                    completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                )
            ),
            presentation: LoadedWorkspacePresentation(
                issues: issues,
                completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
            ),
            state: &state
        )
    }

    func preparedDocumentReplacementRequestForProjectLoad(
        state: inout State
    ) -> Result<WorkspaceDocumentReplacementRequest?, WorkspacePersistenceFailure> {
        guard !state.application.showsHome else { return .success(nil) }
        return documentReplacementRequest(state: &state).map(Optional.some)
    }

    func presentWorkspaceLoadPreparationFailure(
        _ failure: WorkspacePersistenceFailure,
        state: State
    ) -> Effect<Action> {
        .send(.application(.bannerPresented(
            workspaceFeedbackMapper.message(
                for: workspaceFeedbackMapper.feedback(for: failure),
                language: state.application.appLanguage
            )
        )))
    }
}
