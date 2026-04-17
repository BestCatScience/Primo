import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleSavedProjectMove(
        state: inout State,
        url: DocumentProjectPath,
        relativeFolderPath: RelativeProjectFolderPath?
    ) -> Effect<Action> {
        do {
            let destinationURL = try workspaceStorageService.moveSavedProject(
                url,
                to: relativeFolderPath
            )
            if let openTabID = state.workspace.tabID(forSourceProjectURL: url) {
                state.workspace.updateTab(id: openTabID, sourceProjectURL: destinationURL)
            }
            return .send(.homeProjectsLoadRequested)
        } catch {
            state.application.presentBanner(
                error.localizedDescription.isEmpty ? state.application.appLanguage.localized("Move failed") : error.localizedDescription
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
            state.application.finishHydration()
            return .send(.tabSelected(existingTabID))
        }
        if !state.application.showsHome {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        state.application.beginHydration()
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
        if let existingTabID = state.workspace.tabID(forSourceProjectURL: sourceURL) {
            state.application.finishHydration(showingHome: false)
            return .send(.tabSelected(existingTabID))
        }
        applyLoadedProject(loaded, state: &state)
        activateNewTab(
            state: &state,
            title: sourceURL.displayName,
            sourceProjectURL: sourceURL
        )
        state.application.finishHydration(showingHome: false)
        state.application.presentBanner(
            StudioStrings.openedDocument(loaded.presentation.layerRows.count, state.application.appLanguage)
        )
        return .none
    }
}
