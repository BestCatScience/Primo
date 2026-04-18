import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleOpenImportedDocumentRequest(
        state: inout State,
        sourceURL: URL
    ) -> Effect<Action> {
        beginImportedWorkspaceProjectLoad(
            state: &state,
            sourceURL: sourceURL,
            onSuccess: { .openImportedDocumentLoaded($0, $1) },
            onFailure: { .openDocumentFailed($0.feedback) }
        )
    }

    func handleOpenImportedDocumentLoaded(
        state: inout State,
        loaded: LoadedPaintProject,
        suggestedTitle: String
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
                    feedback: .openedDocument(loaded.presentation.layerRows.count)
                )
            ),
            state: &state
        )
    }

    func handleSavedProjectMove(
        state: inout State,
        url: DocumentProjectPath,
        relativeFolderPath: RelativeProjectFolderPath?
    ) -> Effect<Action> {
        let request = WorkspaceCatalogRequest.moveSavedProject(
            WorkspaceSavedProjectMoveRequest(
                sourceURL: url,
                relativeFolderPath: relativeFolderPath,
                openTabID: state.workspace.tabID(forSourceProjectURL: url)
            )
        )
        return .send(.workspaceCatalogRequested(request))
    }

    func handleOpenDocumentSelection(
        state: inout State,
        url: DocumentProjectPath,
        removesStagedWorkspaceItem: Bool
    ) -> Effect<Action> {
        if let existingTabID = state.workspace.tabID(forSourceProjectURL: url) {
            state.application.showWorkspace()
            state.application.completeWorkspaceProjectLoad()
            return .send(.tabSelected(existingTabID))
        }
        return beginWorkspaceProjectLoad(
            state: &state,
            fileURL: url.fileURL,
            removeWorkspaceItemOnSuccess: removesStagedWorkspaceItem ? url : nil,
            onSuccess: { .openDocumentLoaded($0, url) },
            onFailure: { .openDocumentFailed($0.feedback) }
        )
    }

    func handleOpenDocumentLoaded(
        state: inout State,
        loaded: LoadedPaintProject,
        sourceURL: DocumentProjectPath
    ) -> Effect<Action> {
        if let existingTabID = state.workspace.tabID(forSourceProjectURL: sourceURL) {
            state.application.completeWorkspaceProjectLoad()
            return .send(.tabSelected(existingTabID))
        }
        return applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .newTab(
                    title: sourceURL.displayName,
                    sourceProjectURL: sourceURL
                ),
                successEffects: .init(
                    feedback: .openedDocument(loaded.presentation.layerRows.count)
                )
            ),
            state: &state
        )
    }
}
