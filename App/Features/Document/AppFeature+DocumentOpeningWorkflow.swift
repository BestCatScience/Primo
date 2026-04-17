import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleSavedProjectMove(
        state: inout State,
        url: DocumentProjectPath,
        relativeFolderPath: RelativeProjectFolderPath?
    ) -> Effect<Action> {
        do {
            let destinationURL = try workspaceCatalogService.moveSavedProject(
                url,
                to: relativeFolderPath
            )
            if let openTabID = state.workspace.tabID(forSourceProjectURL: url) {
                state.workspace.updateTab(id: openTabID, sourceProjectURL: destinationURL)
            }
            return .send(.homeProjectsLoadRequested)
        } catch {
            state.application.presentFeedback(
                .moveFailed(error.localizedDescription.isEmpty ? nil : error.localizedDescription)
            )
            return .none
        }
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
            onFailure: { .openDocumentFailed($0) }
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
        applyLoadedWorkspaceProject(
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
        return .none
    }
}
