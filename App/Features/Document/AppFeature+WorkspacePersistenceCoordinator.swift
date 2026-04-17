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

        struct FollowUp {
            var marksTabDirty = false
            var persistsToBackingStore = false
            var persistsAutosave = false
        }

        enum RecoveryResolution {
            case none
            case removeItem(WorkspaceItemID)
            case completeRestore(WorkspaceItemID)
            case dismiss
        }

        enum SaveHistoryResolution {
            case none
            case completeRestore
        }

        struct SuccessEffects {
            var discardedAutosaveEntryID: WorkspaceItemID?
            var recoveryResolution: RecoveryResolution = .none
            var saveHistoryResolution: SaveHistoryResolution = .none
            var bannerMessage: String?
        }

        let destination: Destination
        var followUp = FollowUp()
        var successEffects = SuccessEffects()

        init(
            destination: Destination,
            followUp: FollowUp = FollowUp(),
            successEffects: SuccessEffects = SuccessEffects()
        ) {
            self.destination = destination
            self.followUp = followUp
            self.successEffects = successEffects
        }
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

        let followUpSucceeded = applyLoadedWorkspaceFollowUp(
            plan.followUp,
            state: &state
        )
        if followUpSucceeded {
            applyLoadedWorkspaceSuccessEffects(
                plan.successEffects,
                state: &state
            )
        }
        state.application.completeWorkspaceProjectLoad(
            bannerMessage: followUpSucceeded ? plan.successEffects.bannerMessage : nil
        )
    }

    func applyDirtyPresentation(state: inout State) {
        applyCurrentDocumentPresentation(state: &state)
        state.workspace.setActiveTabDirty(true)
        guard persistActiveTabToBackingStore(state: &state) else { return }
        persistActiveTabAutosave(state: &state)
    }

    @discardableResult
    func persistActiveTabAutosave(state: inout State) -> Bool {
        guard let activeTab = state.workspace.activeTab else { return false }

        do {
            try workspaceBackingStoreService.persistAutosaveSnapshot(
                activeTab.backingStoreURL,
                activeTab
            )
            return true
        } catch {
            state.application.presentBanner(
                error.localizedDescription.isEmpty ? state.application.appLanguage.localized("Save failed") : error.localizedDescription
            )
            return false
        }
    }

    @discardableResult
    func applyLoadedWorkspaceFollowUp(
        _ followUp: LoadedWorkspaceProjectPlan.FollowUp,
        state: inout State
    ) -> Bool {
        if followUp.marksTabDirty {
            state.workspace.setActiveTabDirty(true)
        }
        if followUp.persistsToBackingStore,
           !persistActiveTabToBackingStore(state: &state) {
            return false
        }
        if followUp.persistsAutosave,
           !persistActiveTabAutosave(state: &state) {
            return false
        }
        return true
    }

    func applyLoadedWorkspaceSuccessEffects(
        _ successEffects: LoadedWorkspaceProjectPlan.SuccessEffects,
        state: inout State
    ) {
        if let autosaveEntryID = successEffects.discardedAutosaveEntryID {
            try? workspaceCatalogService.discardAutosaveEntry(autosaveEntryID)
        }

        switch successEffects.recoveryResolution {
        case .none:
            break
        case let .removeItem(id):
            state.recovery.removeItem(id: id)
        case let .completeRestore(id):
            state.recovery.completeRestore(of: id)
        case .dismiss:
            state.recovery.dismiss()
        }

        switch successEffects.saveHistoryResolution {
        case .none:
            break
        case .completeRestore:
            state.saveHistory.completeRestore()
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
