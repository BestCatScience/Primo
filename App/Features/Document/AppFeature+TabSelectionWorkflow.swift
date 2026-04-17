import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleTabSelection(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        guard let targetTab = state.workspace.tab(withID: tabID) else {
            return .none
        }
        if state.workspace.isActiveTab(tabID), !state.application.showsHome {
            return .none
        }
        if !state.application.showsHome, state.workspace.isActiveTab(tabID) == false {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        state.application.beginHydration()
        return workspaceTabCoordinator.loadTabSelectionEffect(
            tabID: tabID,
            backingStoreURL: targetTab.backingStoreURL.fileURL
        )
    }

    func handleTabSelectionLoaded(
        state: inout State,
        tabID: OpenDocumentTab.ID,
        loaded: LoadedPaintProject
    ) {
        guard let targetTab = state.workspace.tab(withID: tabID) else {
            state.application.finishHydration()
            return
        }
        state.workspace.activateTab(tabID, pane: targetTab.pane)
        state.application.showWorkspace()
        applyLoadedProject(loaded, state: &state)
    }

    func handleTabSelectionFailed(
        state: inout State,
        message: String
    ) {
        state.application.finishHydration()
        if state.workspace.activeTab == nil {
            state.application.showHome()
        }
        state.application.presentBanner(
            message.isEmpty ? StudioStrings.openFailed(state.application.appLanguage) : message
        )
    }

    func handleTabClosed(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        let wasActive = state.workspace.isActiveTab(tabID)
        guard let closingTab = state.workspace.removeTab(id: tabID) else { return .none }
        clearAutosave(for: closingTab)
        try? workspaceBackingStoreService.removeWorkspaceItem(closingTab.backingStoreURL)

        guard wasActive else { return .none }
        let replacement = state.workspace.selectedTab(in: closingTab.pane)
            ?? state.workspace.selectedTab(in: closingTab.pane == .primary ? .secondary : .primary)
        guard let replacement else {
            state.workspace.clearActiveTab()
            state.application.showHome()
            return .none
        }
        state.workspace.clearActiveTab()
        return .send(.tabSelected(replacement.id))
    }

    func handleCloseOtherTabs(
        state: inout State,
        retaining tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        let removedTabs = state.workspace.retainOnlyTab(id: tabID)
        removedTabs.forEach {
            clearAutosave(for: $0)
            try? workspaceBackingStoreService.removeWorkspaceItem($0.backingStoreURL)
        }
        if state.workspace.isActiveTab(tabID) == false {
            return .send(.tabSelected(tabID))
        }
        return .none
    }

    func handleCloseTabsToRight(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        let idsToRemove = Set(state.workspace.tabIDsToRight(of: tabID))
        let removedTabs = state.workspace.removeTabs(withIDs: idsToRemove)
        removedTabs.forEach {
            clearAutosave(for: $0)
            try? workspaceBackingStoreService.removeWorkspaceItem($0.backingStoreURL)
        }
    }
}
