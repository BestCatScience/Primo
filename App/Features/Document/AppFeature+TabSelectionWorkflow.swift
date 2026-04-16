import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleTabSelection(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let targetTab = state.workspace.openTabs.first(where: { $0.id == tabID }) else {
            return
        }
        if !state.showsHome, state.activeTabID != tabID {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        do {
            let loaded = try paintDocumentClient.loadProject(targetTab.backingStoreURL.fileURL)
            state.workspace.activeTabID = tabID
            state.workspace.setSelectedTabID(tabID, for: targetTab.pane)
            state.workspace.focusedWorkspacePane = targetTab.pane
            state.applyLoadedProject(loaded)
            state.application.showWorkspace()
        } catch {
            state.application.presentBanner(
                error.localizedDescription.isEmpty ? StudioStrings.openFailed(state.appLanguage) : error.localizedDescription
            )
        }
    }

    func handleTabClosed(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let closingIndex = state.workspace.openTabs.firstIndex(where: { $0.id == tabID }) else {
            return
        }
        let closingTab = state.workspace.openTabs[closingIndex]
        let wasActive = state.workspace.activeTabID == tabID
        state.workspace.openTabs.remove(at: closingIndex)
        clearAutosave(for: closingTab)
        try? documentWorkspaceClient.removeWorkspaceItem(closingTab.backingStoreURL)
        state.workspace.ensureSelectionIntegrity()

        guard wasActive else { return }
        let replacement = state.workspace.selectedTab(in: closingTab.pane)
            ?? state.workspace.selectedTab(in: closingTab.pane == .primary ? .secondary : .primary)
        guard let replacement else {
            state.workspace.activeTabID = nil
            state.application.showHome()
            return
        }

        do {
            let loaded = try paintDocumentClient.loadProject(replacement.backingStoreURL.fileURL)
            state.workspace.activeTabID = replacement.id
            state.workspace.focusedWorkspacePane = replacement.pane
            state.applyLoadedProject(loaded)
            state.application.showWorkspace()
        } catch {
            state.workspace.activeTabID = nil
            state.application.showHome()
            state.application.presentBanner(
                error.localizedDescription.isEmpty ? StudioStrings.openFailed(state.appLanguage) : error.localizedDescription
            )
        }
    }

    func handleCloseOtherTabs(
        state: inout State,
        retaining tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        let retainedTabs = state.workspace.openTabs.filter { $0.id == tabID }
        let removedTabs = state.workspace.openTabs.filter { $0.id != tabID }
        removedTabs.forEach {
            clearAutosave(for: $0)
            try? documentWorkspaceClient.removeWorkspaceItem($0.backingStoreURL)
        }
        state.workspace.openTabs = retainedTabs
        state.workspace.primarySelectedTabID = retainedTabs.first(where: { $0.pane == .primary })?.id
        state.workspace.secondarySelectedTabID = retainedTabs.first(where: { $0.pane == .secondary })?.id
        if state.workspace.activeTabID != tabID {
            return .send(.tabSelected(tabID))
        }
        state.workspace.ensureSelectionIntegrity()
        return .none
    }

    func handleCloseTabsToRight(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let tabIndex = state.workspace.openTabs.firstIndex(where: { $0.id == tabID }) else { return }
        let tab = state.workspace.openTabs[tabIndex]
        let paneTabs = state.workspace.openTabs.enumerated().filter { $0.element.pane == tab.pane }
        guard let paneIndex = paneTabs.firstIndex(where: { $0.element.id == tabID }) else { return }
        let idsToRemove = Set(paneTabs.dropFirst(paneIndex + 1).map(\.element.id))
        let removedTabs = state.workspace.openTabs.filter { idsToRemove.contains($0.id) }
        removedTabs.forEach {
            clearAutosave(for: $0)
            try? documentWorkspaceClient.removeWorkspaceItem($0.backingStoreURL)
        }
        state.workspace.openTabs.removeAll { idsToRemove.contains($0.id) }
        state.workspace.ensureSelectionIntegrity()
    }
}
