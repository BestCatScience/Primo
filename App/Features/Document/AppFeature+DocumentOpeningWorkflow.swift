import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleSavedProjectMove(
        state: inout State,
        url: DocumentProjectPath,
        relativeFolderPath: RelativeProjectFolderPath?
    ) -> Effect<Action> {
        do {
            let destinationURL = try documentWorkspaceClient.moveSavedProject(url, relativeFolderPath)
            if let openTabIndex = state.workspace.openTabs.firstIndex(where: { $0.sourceProjectURL == url }) {
                state.workspace.openTabs[openTabIndex].sourceProjectURL = destinationURL
            }
            return .send(.homeProjectsLoadRequested)
        } catch {
            state.application.presentBanner(
                error.localizedDescription.isEmpty ? state.appLanguage.localized("Move failed") : error.localizedDescription
            )
            return .none
        }
    }

    func handleOpenDocumentSelection(
        state: inout State,
        url: DocumentProjectPath,
        removesStagedWorkspaceItem: Bool
    ) -> Effect<Action> {
        if let existingTabID = state.tabID(forSourceProjectURL: url) {
            state.application.showWorkspace()
            state.application.finishHydration()
            return .send(.tabSelected(existingTabID))
        }
        if !state.showsHome {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        state.application.isHydrating = true
        return workspaceTabCoordinator.openProjectEffect(
            at: url,
            removeWorkspaceItemAfterLoad: removesStagedWorkspaceItem
        )
    }

    func handleOpenDocumentLoaded(
        state: inout State,
        loaded: LoadedPaintProject,
        sourceURL: DocumentProjectPath
    ) -> Effect<Action> {
        if let existingTabID = state.tabID(forSourceProjectURL: sourceURL) {
            state.workspace.activeTabID = existingTabID
            state.application.finishHydration(showingHome: false)
            return .send(.tabSelected(existingTabID))
        }
        state.applyLoadedProject(loaded)
        activateNewTab(
            state: &state,
            title: sourceURL.displayName,
            sourceProjectURL: sourceURL
        )
        state.application.finishHydration(showingHome: false)
        state.application.presentBanner(
            StudioStrings.openedDocument(loaded.presentation.layerRows.count, state.appLanguage)
        )
        return .none
    }
}
