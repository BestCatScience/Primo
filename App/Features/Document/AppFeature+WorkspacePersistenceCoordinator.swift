import ComposableArchitecture
import Foundation

extension AppFeature {
    struct WorkspacePersistenceFailure: Error, Equatable {
        let request: WorkspacePersistenceRequest?
        let feedback: ApplicationFeedback

        init(
            request: WorkspacePersistenceRequest? = nil,
            feedback: ApplicationFeedback
        ) {
            self.request = request
            self.feedback = feedback
        }
    }

    struct WorkspaceDirtyPresentationRequest: Equatable, Sendable {
        let activeTab: OpenDocumentTab
        let paperStyle: CanvasPaperStyle
    }

    enum WorkspacePersistenceRequest: Equatable, Sendable {
        case dirtyPresentationRefreshed(WorkspaceDirtyPresentationRequest)
    }

    enum WorkspacePersistenceResult: Equatable, Sendable {
        case dirtyPresentationPersisted(OpenDocumentTab.ID)
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
            var feedback: ApplicationFeedback?
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

    struct PreparedWorkspaceTab {
        let id: OpenDocumentTab.ID
        let title: String
        let backingStoreURL: DocumentProjectPath
        let sourceProjectURL: DocumentProjectPath?
        let pane: WorkspacePane
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

    func saveFailureFeedback(_ error: Error) -> ApplicationFeedback {
        .saveFailed(Self.optionalErrorMessage(error))
    }

    func requireActiveTab(
        in state: State,
        failureFeedback: ApplicationFeedback = .saveFailed(nil)
    ) -> Result<OpenDocumentTab, WorkspacePersistenceFailure> {
        guard let activeTab = state.workspace.activeTab else {
            return .failure(
                WorkspacePersistenceFailure(
                    feedback: failureFeedback
                )
            )
        }
        return .success(activeTab)
    }

    func persistActiveTabToBackingStore(
        state: inout State
    ) -> Result<Void, WorkspacePersistenceFailure> {
        let activeTab: OpenDocumentTab
        switch requireActiveTab(in: state) {
        case let .success(tab):
            activeTab = tab
        case let .failure(failure):
            return .failure(failure)
        }
        do {
            try workspaceBackingStoreService.saveProject(
                at: activeTab.backingStoreURL.fileURL,
                paperStyle: resolvedPaperStyle(for: state)
            )
            state.workspace.updateActiveTabMetadata(
                previewImageData: paintDocumentClient.compositePNGData(resolvedPaperStyle(for: state)),
                canvasSize: state.canvas.canvasSize
            )
            return .success(())
        } catch {
            return .failure(
                WorkspacePersistenceFailure(
                    feedback: saveFailureFeedback(
                        error
                    )
                )
            )
        }
    }

    func prepareForDocumentReplacement(
        state: inout State
    ) -> Result<Void, WorkspacePersistenceFailure> {
        guard !state.application.showsHome else { return .success(()) }
        return persistActiveTabToBackingStore(state: &state)
    }

    func persistActiveProjectToWorkspace(
        state: inout State,
        preferredDestinationURL: DocumentProjectPath?
    ) -> Result<DocumentProjectPath, WorkspacePersistenceFailure> {
        let activeTab: OpenDocumentTab
        switch requireActiveTab(in: state) {
        case let .success(tab):
            activeTab = tab
        case let .failure(failure):
            return .failure(failure)
        }
        switch persistActiveTabToBackingStore(state: &state) {
        case .success:
            break
        case let .failure(failure):
            return .failure(failure)
        }

        do {
            let savedURL = try workspaceBackingStoreService.persistProjectSnapshot(
                activeTab.backingStoreURL,
                preferredDestinationURL: preferredDestinationURL
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
            return .success(savedURL)
        } catch {
            return .failure(
                WorkspacePersistenceFailure(
                    feedback: saveFailureFeedback(
                        error
                    )
                )
            )
        }
    }

    func prepareNewTabReservation(
        title: String,
        sourceProjectURL: DocumentProjectPath?,
        state: State
    ) -> Result<PreparedWorkspaceTab, WorkspacePersistenceFailure> {
        let tabID = workspaceIdentityService.generateTabID()
        let backingStoreURL: DocumentProjectPath
        do {
            backingStoreURL = try workspaceBackingStoreService.createTabBackingStoreURL(tabID)
        } catch {
            return .failure(
                WorkspacePersistenceFailure(
                    feedback: .couldNotCreateTab
                )
            )
        }
        return .success(
            PreparedWorkspaceTab(
                id: tabID,
                title: title,
                backingStoreURL: backingStoreURL,
                sourceProjectURL: sourceProjectURL,
                pane: state.workspace.focusedWorkspacePane
            )
        )
    }

    func activatePreparedTab(
        _ preparedTab: PreparedWorkspaceTab,
        state: inout State
    ) -> Result<Void, WorkspacePersistenceFailure> {
        let tab = OpenDocumentTab(
            id: preparedTab.id,
            title: preparedTab.title,
            backingStoreURL: preparedTab.backingStoreURL,
            sourceProjectURL: preparedTab.sourceProjectURL,
            canvasSize: state.canvas.canvasSize,
            isDirty: false,
            pane: preparedTab.pane,
            previewImageData: documentPresentationQueryService.compositePNGData(
                paperStyle: resolvedPaperStyle(for: state)
            )
        )
        state.workspace.appendTab(tab)
        state.workspace.activateTab(preparedTab.id, pane: preparedTab.pane)
        return persistActiveTabToBackingStore(state: &state)
    }

    func applyLoadedWorkspaceProject(
        _ loaded: LoadedPaintProject,
        using plan: LoadedWorkspaceProjectPlan,
        state: inout State
    ) {
        let preparedTab: PreparedWorkspaceTab?
        switch plan.destination {
        case .selectedTab, .activeTab:
            preparedTab = nil
        case let .newTab(title, sourceProjectURL):
            switch prepareNewTabReservation(
                title: title,
                sourceProjectURL: sourceProjectURL,
                state: state
            ) {
            case let .success(reservation):
                preparedTab = reservation
            case let .failure(failure):
                state.application.completeWorkspaceProjectLoad(
                    feedback: failure.feedback
                )
                return
            }
        }

        let activationResult: Result<Void, WorkspacePersistenceFailure>
        switch plan.destination {
        case let .selectedTab(tabID, pane):
            state.workspace.activateTab(tabID, pane: pane)
            applyLoadedProject(loaded, state: &state)
            activationResult = .success(())

        case .newTab:
            applyLoadedProject(loaded, state: &state)
            if let preparedTab {
                activationResult = activatePreparedTab(preparedTab, state: &state)
            } else {
                activationResult = .success(())
            }

        case let .activeTab(title, sourceProjectURL):
            applyLoadedProject(loaded, state: &state)
            state.workspace.updateActiveTabMetadata(
                title: title,
                sourceProjectURL: sourceProjectURL,
                previewImageData: documentPresentationQueryService.compositePNGData(
                    paperStyle: resolvedPaperStyle(for: state)
                ),
                canvasSize: state.canvas.canvasSize
            )
            activationResult = .success(())
        }

        switch activationResult {
        case let .failure(failure):
            state.application.completeWorkspaceProjectLoad(
                feedback: failure.feedback
            )
            return
        case .success:
            break
        }

        switch applyLoadedWorkspaceFollowUp(
            plan.followUp,
            state: &state
        ) {
        case let .failure(failure):
            state.application.completeWorkspaceProjectLoad(
                feedback: failure.feedback
            )
        case .success:
            applyLoadedWorkspaceSuccessEffects(
                plan.successEffects,
                state: &state
            )
            state.application.completeWorkspaceProjectLoad(
                feedback: plan.successEffects.feedback
            )
        }
    }

    func dirtyPresentationRequest(
        state: State
    ) -> WorkspacePersistenceRequest? {
        guard let activeTab = state.workspace.activeTab else {
            return nil
        }
        return .dirtyPresentationRefreshed(
            WorkspaceDirtyPresentationRequest(
                activeTab: activeTab,
                paperStyle: resolvedPaperStyle(for: state)
            )
        )
    }

    func workspacePersistenceEffect(
        for request: WorkspacePersistenceRequest
    ) -> Effect<Action> {
        .run { [workspaceBackingStoreService] send in
            do {
                switch request {
                case let .dirtyPresentationRefreshed(dirtyPresentation):
                    try workspaceBackingStoreService.saveProject(
                        at: dirtyPresentation.activeTab.backingStoreURL.fileURL,
                        paperStyle: dirtyPresentation.paperStyle
                    )
                    try workspaceBackingStoreService.persistAutosaveSnapshot(
                        dirtyPresentation.activeTab.backingStoreURL,
                        dirtyPresentation.activeTab
                    )
                    await send(
                        .workspacePersistenceSucceeded(
                            .dirtyPresentationPersisted(
                                dirtyPresentation.activeTab.id
                            )
                        )
                    )
                }
            } catch {
                await send(
                    .workspacePersistenceFailed(
                        WorkspacePersistenceFailure(
                            request: request,
                            feedback: saveFailureFeedback(error)
                        )
                    )
                )
            }
        }
    }

    func handleWorkspacePersistenceRequested(
        request: WorkspacePersistenceRequest
    ) -> Effect<Action> {
        workspacePersistenceEffect(for: request)
    }

    func handleWorkspacePersistenceSucceeded(
        state: inout State,
        result: WorkspacePersistenceResult
    ) {
        switch result {
        case .dirtyPresentationPersisted:
            break
        }
    }

    func handleWorkspacePersistenceFailed(
        state: inout State,
        failure: WorkspacePersistenceFailure
    ) {
        state.application.presentFeedback(failure.feedback)
    }

    func applyDirtyPresentation(state: inout State) -> Effect<Action> {
        applyPresentation(documentPresentationQueryService.presentation(), state: &state)
        state.workspace.setActiveTabDirty(true)
        state.workspace.updateActiveTabMetadata(
            previewImageData: documentPresentationQueryService.compositePNGData(
                paperStyle: resolvedPaperStyle(for: state)
            ),
            canvasSize: state.canvas.canvasSize
        )
        guard let request = dirtyPresentationRequest(state: state) else {
            return .none
        }
        return .send(.workspacePersistenceRequested(request))
    }

    func persistActiveTabAutosave(
        state: inout State
    ) -> Result<Void, WorkspacePersistenceFailure> {
        let activeTab: OpenDocumentTab
        switch requireActiveTab(in: state) {
        case let .success(tab):
            activeTab = tab
        case let .failure(failure):
            return .failure(failure)
        }

        do {
            try workspaceBackingStoreService.persistAutosaveSnapshot(
                activeTab.backingStoreURL,
                activeTab
            )
            return .success(())
        } catch {
            return .failure(
                WorkspacePersistenceFailure(
                    feedback: saveFailureFeedback(
                        error
                    )
                )
            )
        }
    }

    func applyLoadedWorkspaceFollowUp(
        _ followUp: LoadedWorkspaceProjectPlan.FollowUp,
        state: inout State
    ) -> Result<Void, WorkspacePersistenceFailure> {
        if followUp.marksTabDirty {
            state.workspace.setActiveTabDirty(true)
        }
        if followUp.persistsToBackingStore {
            switch persistActiveTabToBackingStore(state: &state) {
            case .success:
                break
            case let .failure(failure):
                return .failure(failure)
            }
        }
        if followUp.persistsAutosave {
            switch persistActiveTabAutosave(state: &state) {
            case .success:
                break
            case let .failure(failure):
                return .failure(failure)
            }
        }
        return .success(())
    }

    func applyLoadedWorkspaceSuccessEffects(
        _ successEffects: LoadedWorkspaceProjectPlan.SuccessEffects,
        state: inout State
    ) {
        if let autosaveEntryID = successEffects.discardedAutosaveEntryID {
            do {
                try workspaceCatalogService.discardAutosaveEntry(autosaveEntryID)
            } catch {
                state.application.presentFeedback(
                    .autosaveRestoreFailed(Self.optionalErrorMessage(error))
                )
            }
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
        do {
            // Best-effort cleanup of autosave artifacts after a successful persistence transition.
            try workspaceBackingStoreService.discardAutosaveSnapshot(tab)
        } catch {
        }
    }

    func discardTransientWorkspaceArtifacts(for tab: OpenDocumentTab) {
        clearAutosave(for: tab)
        do {
            // Best-effort cleanup of transient workspace artifacts during tab teardown.
            try workspaceBackingStoreService.removeWorkspaceItem(tab.backingStoreURL)
        } catch {
        }
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
    ) -> Result<Void, WorkspacePersistenceFailure> {
        if let activeTabID = state.workspace.activeTabID, tabIDs.contains(activeTabID) {
            switch persistActiveTabToBackingStore(state: &state) {
            case .success:
                break
            case let .failure(failure):
                return .failure(failure)
            }
        }
        for tabID in tabIDs {
            guard let previousTab = state.workspace.tab(withID: tabID) else { continue }
            let destinationURL: DocumentProjectPath
            do {
                destinationURL = try workspaceBackingStoreService.persistProjectSnapshot(
                    previousTab.backingStoreURL,
                    preferredDestinationURL: previousTab.sourceProjectURL
                )
            } catch {
                return .failure(
                    WorkspacePersistenceFailure(
                        feedback: .saveFailed(Self.optionalErrorMessage(error))
                    )
                )
            }
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
        return .success(())
    }

    static func nextUntitledTabTitle(existingTabs: [OpenDocumentTab]) -> String {
        let untitledTabs = existingTabs.filter { $0.sourceProjectURL == nil && $0.title.hasPrefix("Untitled") }
        return untitledTabs.isEmpty ? "Untitled" : "Untitled \(untitledTabs.count + 1)"
    }
}
