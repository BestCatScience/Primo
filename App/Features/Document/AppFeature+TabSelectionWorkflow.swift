import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleTabSelection(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let targetTab = state.workspace.tab(withID: tabID) else {
            return
        }
        if !state.application.showsHome, state.workspace.isActiveTab(tabID) == false {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        do {
            let loaded = try paintDocumentClient.loadProject(targetTab.backingStoreURL.fileURL)
            state.workspace.activateTab(tabID, pane: targetTab.pane)
            applyLoadedProject(loaded, state: &state)
            state.application.showWorkspace()
        } catch {
            state.application.presentBanner(
                error.localizedDescription.isEmpty ? StudioStrings.openFailed(state.application.appLanguage) : error.localizedDescription
            )
        }
    }

    func handleTabClosed(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        let wasActive = state.workspace.isActiveTab(tabID)
        guard let closingTab = state.workspace.removeTab(id: tabID) else { return }
        clearAutosave(for: closingTab)
        try? documentWorkspaceClient.removeWorkspaceItem(closingTab.backingStoreURL)

        guard wasActive else { return }
        let replacement = state.workspace.selectedTab(in: closingTab.pane)
            ?? state.workspace.selectedTab(in: closingTab.pane == .primary ? .secondary : .primary)
        guard let replacement else {
            state.workspace.clearActiveTab()
            state.application.showHome()
            return
        }

        do {
            let loaded = try paintDocumentClient.loadProject(replacement.backingStoreURL.fileURL)
            state.workspace.activateTab(replacement.id, pane: replacement.pane)
            applyLoadedProject(loaded, state: &state)
            state.application.showWorkspace()
        } catch {
            state.workspace.clearActiveTab()
            state.application.showHome()
            state.application.presentBanner(
                error.localizedDescription.isEmpty ? StudioStrings.openFailed(state.application.appLanguage) : error.localizedDescription
            )
        }
    }

    func handleCloseOtherTabs(
        state: inout State,
        retaining tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        let removedTabs = state.workspace.retainOnlyTab(id: tabID)
        removedTabs.forEach {
            clearAutosave(for: $0)
            try? documentWorkspaceClient.removeWorkspaceItem($0.backingStoreURL)
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
            try? documentWorkspaceClient.removeWorkspaceItem($0.backingStoreURL)
        }
    }
}
