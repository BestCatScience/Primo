import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleTabSelection(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let targetTab = state.openTabs.first(where: { $0.id == tabID }) else {
            return
        }
        if !state.showsHome, state.activeTabID != tabID {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        do {
            let loaded = try paintDocumentClient.loadProject(targetTab.backingStoreURL.fileURL)
            state.activeTabID = tabID
            state.setSelectedTabID(tabID, for: targetTab.pane)
            state.focusedWorkspacePane = targetTab.pane
            state.applyLoadedProject(loaded)
            state.showsHome = false
        } catch {
            state.bannerMessage = error.localizedDescription.isEmpty ? StudioStrings.openFailed(state.appLanguage) : error.localizedDescription
        }
    }

    func handleTabClosed(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let closingIndex = state.openTabs.firstIndex(where: { $0.id == tabID }) else {
            return
        }
        let closingTab = state.openTabs[closingIndex]
        let wasActive = state.activeTabID == tabID
        state.openTabs.remove(at: closingIndex)
        clearAutosave(for: closingTab)
        try? documentWorkspaceClient.removeWorkspaceItem(closingTab.backingStoreURL)
        state.ensureWorkspaceSelectionIntegrity()

        guard wasActive else { return }
        let replacement = state.selectedTab(in: closingTab.pane)
            ?? state.selectedTab(in: closingTab.pane == .primary ? .secondary : .primary)
        guard let replacement else {
            state.activeTabID = nil
            state.showsHome = true
            return
        }

        do {
            let loaded = try paintDocumentClient.loadProject(replacement.backingStoreURL.fileURL)
            state.activeTabID = replacement.id
            state.focusedWorkspacePane = replacement.pane
            state.applyLoadedProject(loaded)
            state.showsHome = false
        } catch {
            state.activeTabID = nil
            state.showsHome = true
            state.bannerMessage = error.localizedDescription.isEmpty ? StudioStrings.openFailed(state.appLanguage) : error.localizedDescription
        }
    }

    func handleCloseOtherTabs(
        state: inout State,
        retaining tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        let retainedTabs = state.openTabs.filter { $0.id == tabID }
        let removedTabs = state.openTabs.filter { $0.id != tabID }
        removedTabs.forEach {
            clearAutosave(for: $0)
            try? documentWorkspaceClient.removeWorkspaceItem($0.backingStoreURL)
        }
        state.openTabs = retainedTabs
        state.primarySelectedTabID = retainedTabs.first(where: { $0.pane == .primary })?.id
        state.secondarySelectedTabID = retainedTabs.first(where: { $0.pane == .secondary })?.id
        if state.activeTabID != tabID {
            return .send(.tabSelected(tabID))
        }
        state.ensureWorkspaceSelectionIntegrity()
        return .none
    }

    func handleCloseTabsToRight(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let tabIndex = state.openTabs.firstIndex(where: { $0.id == tabID }) else { return }
        let tab = state.openTabs[tabIndex]
        let paneTabs = state.openTabs.enumerated().filter { $0.element.pane == tab.pane }
        guard let paneIndex = paneTabs.firstIndex(where: { $0.element.id == tabID }) else { return }
        let idsToRemove = Set(paneTabs.dropFirst(paneIndex + 1).map(\.element.id))
        let removedTabs = state.openTabs.filter { idsToRemove.contains($0.id) }
        removedTabs.forEach {
            clearAutosave(for: $0)
            try? documentWorkspaceClient.removeWorkspaceItem($0.backingStoreURL)
        }
        state.openTabs.removeAll { idsToRemove.contains($0.id) }
        state.ensureWorkspaceSelectionIntegrity()
    }
}
