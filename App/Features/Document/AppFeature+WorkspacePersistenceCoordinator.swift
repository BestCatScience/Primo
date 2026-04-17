import ComposableArchitecture
import Foundation

extension AppFeature {
    private struct WorkspaceOperationError: LocalizedError {
        let message: String

        var errorDescription: String? {
            message
        }
    }

    struct LoadedWorkspaceProjectPlan {
        enum Destination {
            case selectedTab(tabID: OpenDocumentTab.ID, pane: WorkspacePane)
            case newTab(title: String, sourceProjectURL: DocumentProjectPath?)
            case activeTab(title: String?, sourceProjectURL: DocumentProjectPath?)
        }

        let destination: Destination
        var marksTabDirty = false
        var persistsToBackingStore = false
        var persistsAutosave = false
        var discardedAutosaveEntryID: WorkspaceItemID?
        var removedRecoveryItemID: WorkspaceItemID?
        var dismissesRecovery = false
        var dismissesSaveHistory = false
        var bannerMessage: String?
    }

    struct WorkspaceBackingStoreService {
        let paintDocumentClient: PaintDocumentClient
        let documentWorkspaceClient: DocumentWorkspaceClient

        func saveProject(
            at fileURL: URL,
            paperStyle: CanvasPaperStyle
        ) throws {
            try paintDocumentClient.saveProject(fileURL, paperStyle)
        }

        func persistProjectSnapshot(
            _ sourceURL: DocumentProjectPath,
            preferredDestinationURL: DocumentProjectPath?
        ) throws -> DocumentProjectPath {
            try documentWorkspaceClient.persistProjectSnapshot(
                sourceURL,
                preferredDestinationURL
            )
        }

        func createTabBackingStoreURL(_ tabID: OpenDocumentTab.ID) throws -> DocumentProjectPath {
            try documentWorkspaceClient.createTabBackingStoreURL(tabID)
        }

        func persistAutosaveSnapshot(
            _ backingStoreURL: DocumentProjectPath,
            _ tab: OpenDocumentTab
        ) throws {
            try documentWorkspaceClient.persistAutosaveSnapshot(backingStoreURL, tab)
        }

        func discardAutosaveSnapshot(_ tab: OpenDocumentTab) throws {
            try documentWorkspaceClient.discardAutosaveSnapshot(tab)
        }

        func persistSaveHistorySnapshot(
            _ backingStoreURL: DocumentProjectPath,
            _ tab: OpenDocumentTab,
            _ trigger: SaveHistoryTrigger
        ) throws {
            try documentWorkspaceClient.persistSaveHistorySnapshot(backingStoreURL, tab, trigger)
        }

        func removeWorkspaceItem(_ url: DocumentProjectPath) throws {
            try documentWorkspaceClient.removeWorkspaceItem(url)
        }
    }

    struct WorkspaceCatalogService {
        let documentWorkspaceClient: DocumentWorkspaceClient

        func loadSavedProjects() throws -> [SavedProjectSummary] {
            try documentWorkspaceClient.loadSavedProjects()
        }

        func moveSavedProject(
            _ url: DocumentProjectPath,
            to relativeFolderPath: RelativeProjectFolderPath?
        ) throws -> DocumentProjectPath {
            try documentWorkspaceClient.moveSavedProject(url, relativeFolderPath)
        }

        func loadAutosaveRecoveryItems() throws -> [AutosaveRecoveryItem] {
            try documentWorkspaceClient.loadAutosaveRecoveryItems()
        }

        func discardAutosaveEntry(_ id: WorkspaceItemID) throws {
            try documentWorkspaceClient.discardAutosaveEntry(id)
        }

        func loadSaveHistoryEntries(for tab: OpenDocumentTab) throws -> [SaveHistoryEntry] {
            try documentWorkspaceClient.loadSaveHistoryEntries(tab)
        }
    }

    struct WorkspaceArtifactService {
        let documentWorkspaceClient: DocumentWorkspaceClient

        func timelapseTemporaryDirectory() -> URL {
            documentWorkspaceClient.timelapseTemporaryDirectory()
        }

        func writePNGToTemporaryDirectory(_ data: Data) throws -> URL {
            try documentWorkspaceClient.writePNGToTemporaryDirectory(data)
        }
    }

    struct WorkspaceIdentityService {
        let uuidClient: UUIDClient

        func generateTabID() -> OpenDocumentTab.ID {
            uuidClient.generate()
        }
    }

    var workspaceBackingStoreService: WorkspaceBackingStoreService {
        WorkspaceBackingStoreService(
            paintDocumentClient: paintDocumentClient,
            documentWorkspaceClient: documentWorkspaceClient
        )
    }

    var workspaceCatalogService: WorkspaceCatalogService {
        WorkspaceCatalogService(
            documentWorkspaceClient: documentWorkspaceClient
        )
    }

    var workspaceArtifactService: WorkspaceArtifactService {
        WorkspaceArtifactService(
            documentWorkspaceClient: documentWorkspaceClient
        )
    }

    var workspaceIdentityService: WorkspaceIdentityService {
        WorkspaceIdentityService(
            uuidClient: uuidClient
        )
    }

    @discardableResult
    func persistActiveTabToBackingStore(state: inout State) -> Bool {
        guard let activeTab = state.workspace.activeTab else { return false }
        do {
            try workspaceBackingStoreService.saveProject(
                at: activeTab.backingStoreURL.fileURL,
                paperStyle: resolvedPaperStyle(for: state)
            )
            state.workspace.updateActiveTabMetadata(
                previewImageData: compositePNGData(state: state),
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
            let savedURL = try workspaceBackingStoreService.persistProjectSnapshot(
                activeTab.backingStoreURL,
                preferredDestinationURL: preferredDestinationURL
            )
            let previousTab = activeTab
            state.workspace.updateActiveTabMetadata(
                title: savedURL.displayName,
                sourceProjectURL: savedURL,
                previewImageData: compositePNGData(state: state),
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
        let tabID = workspaceIdentityService.generateTabID()
        guard let backingStoreURL = try? workspaceBackingStoreService.createTabBackingStoreURL(tabID) else {
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
            previewImageData: compositePNGData(state: state)
        )
        state.workspace.appendTab(tab)
        state.workspace.activateTab(tabID, pane: state.workspace.focusedWorkspacePane)
        _ = persistActiveTabToBackingStore(state: &state)
    }

    func applyLoadedWorkspaceProject(
        _ loaded: LoadedPaintProject,
        using plan: LoadedWorkspaceProjectPlan,
        state: inout State
    ) {
        if let autosaveEntryID = plan.discardedAutosaveEntryID {
            try? workspaceCatalogService.discardAutosaveEntry(autosaveEntryID)
        }

        switch plan.destination {
        case let .selectedTab(tabID, pane):
            state.workspace.activateTab(tabID, pane: pane)
            applyLoadedProject(loaded, state: &state)

        case let .newTab(title, sourceProjectURL):
            applyLoadedProject(loaded, state: &state)
            activateNewTab(
                state: &state,
                title: title,
                sourceProjectURL: sourceProjectURL
            )

        case let .activeTab(title, sourceProjectURL):
            applyLoadedProject(loaded, state: &state)
            state.workspace.updateActiveTabMetadata(
                title: title,
                sourceProjectURL: sourceProjectURL,
                previewImageData: compositePNGData(state: state),
                canvasSize: state.canvas.canvasSize
            )
        }

        if plan.marksTabDirty {
            state.workspace.setActiveTabDirty(true)
        }
        if plan.persistsToBackingStore {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        if plan.persistsAutosave {
            persistActiveTabAutosave(state: &state)
        }
        if let recoveryItemID = plan.removedRecoveryItemID {
            state.recovery.removeItem(id: recoveryItemID)
        }
        if plan.dismissesRecovery {
            state.recovery.dismiss()
        }
        if plan.dismissesSaveHistory {
            state.saveHistory.dismiss()
        }
        state.application.finishHydration(showingHome: false)
        if let bannerMessage = plan.bannerMessage {
            state.application.presentBanner(bannerMessage)
        }
    }

    func applyDirtyPresentation(state: inout State) {
        applyCurrentDocumentPresentation(state: &state)
        state.workspace.setActiveTabDirty(true)
        guard persistActiveTabToBackingStore(state: &state) else { return }
        persistActiveTabAutosave(state: &state)
    }

    func persistActiveTabAutosave(state: inout State) {
        guard let activeTab = state.workspace.activeTab else { return }

        do {
            try workspaceBackingStoreService.persistAutosaveSnapshot(
                activeTab.backingStoreURL,
                activeTab
            )
        } catch {
            state.application.presentBanner(
                error.localizedDescription.isEmpty ? state.application.appLanguage.localized("Save failed") : error.localizedDescription
            )
        }
    }

    func clearAutosave(for tab: OpenDocumentTab) {
        try? workspaceBackingStoreService.discardAutosaveSnapshot(tab)
    }

    func discardTransientWorkspaceArtifacts(for tab: OpenDocumentTab) {
        clearAutosave(for: tab)
        try? workspaceBackingStoreService.removeWorkspaceItem(tab.backingStoreURL)
    }

    func discardTransientWorkspaceArtifacts(for tabs: [OpenDocumentTab]) {
        tabs.forEach(discardTransientWorkspaceArtifacts(for:))
    }

    func persistSaveHistorySnapshot(
        for tab: OpenDocumentTab,
        trigger: SaveHistoryTrigger
    ) {
        do {
            try workspaceBackingStoreService.persistSaveHistorySnapshot(
                tab.backingStoreURL,
                tab,
                trigger
            )
        } catch {
            // Save history is a resilience feature. Keep editing even if a snapshot could not be recorded.
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
            let destinationURL = try workspaceBackingStoreService.persistProjectSnapshot(
                previousTab.backingStoreURL,
                preferredDestinationURL: previousTab.sourceProjectURL
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
                    previewImageData: compositePNGData(state: state),
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
