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
        guard let activeTab = state.workspace.activeTab else { return false }
        do {
            try paintDocumentClient.saveProject(activeTab.backingStoreURL.fileURL, resolvedPaperStyle(for: state))
            state.workspace.updateActiveTabMetadata(
                previewImageData: paintDocumentClient.compositePNGData(resolvedPaperStyle(for: state)),
                canvasSize: state.canvas.canvasSize
            )
            return true
        } catch {
            state.application.presentBanner(
                error.localizedDescription.isEmpty ? state.application.appLanguage.localized("Save failed") : error.localizedDescription
            )
            return false
        }
    }

    func persistActiveProjectToWorkspace(
        state: inout State,
        preferredDestinationURL: DocumentProjectPath?
    ) -> DocumentProjectPath? {
        guard let activeTab = state.workspace.activeTab else { return nil }
        guard persistActiveTabToBackingStore(state: &state) else { return nil }

        do {
            let savedURL = try workspaceClient.persistProjectSnapshot(
                activeTab.backingStoreURL,
                preferredDestinationURL
            )
            let previousTab = activeTab
            state.workspace.updateActiveTabMetadata(
                title: savedURL.displayName,
                sourceProjectURL: savedURL,
                previewImageData: paintDocumentClient.compositePNGData(resolvedPaperStyle(for: state)),
                canvasSize: state.canvas.canvasSize
            )
            state.workspace.setActiveTabDirty(false)
            clearAutosave(for: previousTab)
            if let refreshedTab = state.workspace.activeTab {
                clearAutosave(for: refreshedTab)
            }
            return savedURL
        } catch {
            state.application.presentBanner(
                error.localizedDescription.isEmpty ? state.application.appLanguage.localized("Save failed") : error.localizedDescription
            )
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
            state.application.presentBanner(state.application.appLanguage.localized("Could not create a tab"))
            return
        }
        let tab = OpenDocumentTab(
            id: tabID,
            title: title,
            backingStoreURL: backingStoreURL,
            sourceProjectURL: sourceProjectURL,
            canvasSize: state.canvas.canvasSize,
            isDirty: false,
            pane: state.workspace.focusedWorkspacePane,
            previewImageData: paintDocumentClient.compositePNGData(resolvedPaperStyle(for: state))
        )
        state.workspace.appendTab(tab)
        state.workspace.activateTab(tabID, pane: state.workspace.focusedWorkspacePane)
        _ = persistActiveTabToBackingStore(state: &state)
    }

    func applyDirtyPresentation(state: inout State) {
        applyPresentation(paintDocumentClient.presentation(), state: &state)
        state.workspace.setActiveTabDirty(true)
        guard persistActiveTabToBackingStore(state: &state) else { return }
        persistActiveTabAutosave(state: &state)
    }

    func persistActiveTabAutosave(state: inout State) {
        guard let activeTab = state.workspace.activeTab else { return }

        do {
            try workspaceClient.persistAutosaveSnapshot(activeTab.backingStoreURL, activeTab)
        } catch {
            state.application.presentBanner(
                error.localizedDescription.isEmpty ? state.application.appLanguage.localized("Save failed") : error.localizedDescription
            )
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
                return state.workspace.tabIDs(excluding: tabID)
            case let .closeTabsToRight(tabID):
                return state.workspace.tabIDsToRight(of: tabID)
            }
        }()

        let dirtyTabs = state.workspace.dirtyTabs(withIDs: tabIDs)
        guard !dirtyTabs.isEmpty else {
            return performCloseOperation(state: &state, operation: operation)
        }

        state.workspace.presentCloseConfirmation(operation: operation, dirtyTabs: dirtyTabs)
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
        if let activeTabID = state.workspace.activeTabID, tabIDs.contains(activeTabID),
           !persistActiveTabToBackingStore(state: &state) {
            throw WorkspaceOperationError(
                message: state.application.bannerMessage ?? state.application.appLanguage.localized("Save failed")
            )
        }
        for tabID in tabIDs {
            guard let previousTab = state.workspace.tab(withID: tabID) else { continue }
            let destinationURL = try workspaceClient.persistProjectSnapshot(
                previousTab.backingStoreURL,
                previousTab.sourceProjectURL
            )
            let updatedTab = state.workspace.updateTab(
                id: tabID,
                title: destinationURL.displayName,
                sourceProjectURL: destinationURL,
                isDirty: false
            )
            if tabID == state.workspace.activeTabID {
                state.workspace.updateActiveTabMetadata(
                    title: destinationURL.displayName,
                    sourceProjectURL: destinationURL,
                    previewImageData: paintDocumentClient.compositePNGData(resolvedPaperStyle(for: state)),
                    canvasSize: state.canvas.canvasSize
                )
            }
            clearAutosave(for: previousTab)
            if let updatedTab {
                clearAutosave(for: updatedTab)
                persistSaveHistorySnapshot(for: updatedTab, trigger: .closeSave)
            }
        }
    }

    static func nextUntitledTabTitle(existingTabs: [OpenDocumentTab]) -> String {
        let untitledTabs = existingTabs.filter { $0.sourceProjectURL == nil && $0.title.hasPrefix("Untitled") }
        return untitledTabs.isEmpty ? "Untitled" : "Untitled \(untitledTabs.count + 1)"
    }
}
