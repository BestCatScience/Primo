import ComposableArchitecture
import Foundation

extension AppFeature {
    private struct WorkspaceOperationError: LocalizedError {
        let message: String

        var errorDescription: String? {
            message
        }
    }

    private var workspaceClient: DocumentWorkspaceClient {
        @Dependency(\.documentWorkspaceClient) var workspaceClient
        return workspaceClient
    }

    private var workspaceUUIDClient: UUIDClient {
        @Dependency(\.uuidClient) var uuidClient
        return uuidClient
    }

    @discardableResult
    func persistActiveTabToBackingStore(state: inout State) -> Bool {
        guard let activeTab = state.activeTab else { return false }
        do {
            try paintDocumentClient.saveProject(activeTab.backingStoreURL.fileURL, state.resolvedPaperStyle())
            state.updateActiveTabMetadata(
                previewImageData: paintDocumentClient.compositePNGData(state.resolvedPaperStyle())
            )
            return true
        } catch {
            state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Save failed") : error.localizedDescription
            return false
        }
    }

    func persistActiveProjectToWorkspace(
        state: inout State,
        preferredDestinationURL: DocumentProjectPath?
    ) -> DocumentProjectPath? {
        guard let activeTab = state.activeTab else { return nil }
        guard persistActiveTabToBackingStore(state: &state) else { return nil }

        do {
            let savedURL = try workspaceClient.persistProjectSnapshot(
                activeTab.backingStoreURL,
                preferredDestinationURL
            )
            let previousTab = activeTab
            state.updateActiveTabMetadata(
                title: savedURL.displayName,
                sourceProjectURL: savedURL,
                previewImageData: paintDocumentClient.compositePNGData(state.resolvedPaperStyle())
            )
            state.setActiveTabDirty(false)
            clearAutosave(for: previousTab)
            if let refreshedTab = state.activeTab {
                clearAutosave(for: refreshedTab)
            }
            return savedURL
        } catch {
            state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Save failed") : error.localizedDescription
            return nil
        }
    }

    func activateNewTab(
        state: inout State,
        title: String,
        sourceProjectURL: DocumentProjectPath?
    ) {
        let tabID = workspaceUUIDClient.generate()
        guard let backingStoreURL = try? workspaceClient.createTabBackingStoreURL(tabID) else {
            state.bannerMessage = state.appLanguage.localized("Could not create a tab")
            return
        }
        let tab = OpenDocumentTab(
            id: tabID,
            title: title,
            backingStoreURL: backingStoreURL,
            sourceProjectURL: sourceProjectURL,
            canvasSize: state.canvas.canvasSize,
            isDirty: false,
            pane: state.focusedWorkspacePane,
            previewImageData: paintDocumentClient.compositePNGData(state.resolvedPaperStyle())
        )
        state.openTabs.append(tab)
        state.activeTabID = tabID
        state.setSelectedTabID(tabID, for: state.focusedWorkspacePane)
        _ = persistActiveTabToBackingStore(state: &state)
    }

    func applyDirtyPresentation(state: inout State) {
        state.applyPresentation(paintDocumentClient.presentation())
        state.setActiveTabDirty(true)
        guard persistActiveTabToBackingStore(state: &state) else { return }
        persistActiveTabAutosave(state: &state)
    }

    func persistActiveTabAutosave(state: inout State) {
        guard let activeTab = state.activeTab else { return }

        do {
            try workspaceClient.persistAutosaveSnapshot(activeTab.backingStoreURL, activeTab)
        } catch {
            state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Save failed") : error.localizedDescription
        }
    }

    func clearAutosave(for tab: OpenDocumentTab) {
        try? workspaceClient.discardAutosaveSnapshot(tab)
    }

    func persistSaveHistorySnapshot(
        for tab: OpenDocumentTab,
        trigger: SaveHistoryTrigger
    ) {
        do {
            try workspaceClient.persistSaveHistorySnapshot(tab.backingStoreURL, tab, trigger)
        } catch {
            // Save history is a resilience feature. Keep editing even if a snapshot could not be recorded.
        }
    }

    func requestCloseOperation(
        state: inout State,
        operation: PendingCloseOperation
    ) -> Effect<Action> {
        let tabIDs: [OpenDocumentTab.ID] = {
            switch operation {
            case let .tab(tabID):
                return [tabID]
            case let .closeOtherTabs(tabID):
                return state.openTabs.filter { $0.id != tabID }.map(\.id)
            case let .closeTabsToRight(tabID):
                guard let tab = state.openTabs.first(where: { $0.id == tabID }) else { return [] }
                let paneTabs = state.openTabs.filter { $0.pane == tab.pane }
                guard let index = paneTabs.firstIndex(where: { $0.id == tabID }) else { return [] }
                return Array(paneTabs.dropFirst(index + 1).map(\.id))
            }
        }()

        let dirtyTabs = state.openTabs.filter { tabIDs.contains($0.id) && $0.isDirty }
        guard !dirtyTabs.isEmpty else {
            return performCloseOperation(state: &state, operation: operation)
        }

        state.pendingCloseConfirmation = PendingCloseConfirmationState(
            operation: operation,
            tabIDs: dirtyTabs.map(\.id),
            tabTitles: dirtyTabs.map(\.title)
        )
        return .none
    }

    func performCloseOperation(
        state: inout State,
        operation: PendingCloseOperation
    ) -> Effect<Action> {
        switch operation {
        case let .tab(tabID):
            return .send(.tabClosed(tabID))
        case let .closeOtherTabs(tabID):
            return .send(.closeOtherTabs(tabID))
        case let .closeTabsToRight(tabID):
            return .send(.closeTabsToRight(tabID))
        }
    }

    func saveTabsForClose(
        _ tabIDs: [OpenDocumentTab.ID],
        state: inout State
    ) throws {
        if let activeTabID = state.activeTabID, tabIDs.contains(activeTabID),
           !persistActiveTabToBackingStore(state: &state) {
            throw WorkspaceOperationError(
                message: state.bannerMessage ?? state.appLanguage.localized("Save failed")
            )
        }
        for tabID in tabIDs {
            guard let tabIndex = state.openTabs.firstIndex(where: { $0.id == tabID }) else { continue }
            let previousTab = state.openTabs[tabIndex]
            let destinationURL = try workspaceClient.persistProjectSnapshot(
                previousTab.backingStoreURL,
                previousTab.sourceProjectURL
            )
            state.openTabs[tabIndex].sourceProjectURL = destinationURL
            state.openTabs[tabIndex].title = destinationURL.displayName
            state.openTabs[tabIndex].isDirty = false
            if tabID == state.activeTabID {
                state.updateActiveTabMetadata(
                    title: destinationURL.displayName,
                    sourceProjectURL: destinationURL,
                    previewImageData: paintDocumentClient.compositePNGData(state.resolvedPaperStyle())
                )
            }
            clearAutosave(for: previousTab)
            clearAutosave(for: state.openTabs[tabIndex])
            persistSaveHistorySnapshot(for: state.openTabs[tabIndex], trigger: .closeSave)
        }
    }

    static func nextUntitledTabTitle(existingTabs: [OpenDocumentTab]) -> String {
        let untitledTabs = existingTabs.filter { $0.sourceProjectURL == nil && $0.title.hasPrefix("Untitled") }
        return untitledTabs.isEmpty ? "Untitled" : "Untitled \(untitledTabs.count + 1)"
    }
}
