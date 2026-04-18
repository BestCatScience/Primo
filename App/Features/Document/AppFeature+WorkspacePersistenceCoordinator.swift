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

    enum WorkspaceDocumentSavePurpose: Equatable, Sendable {
        case saveDocument
        case homeReturn
    }

    struct WorkspaceDocumentSaveRequest: Equatable, Sendable {
        let activeTab: OpenDocumentTab
        let paperStyle: CanvasPaperStyle
        let preferredDestinationURL: DocumentProjectPath?
        let trigger: SaveHistoryTrigger
        let purpose: WorkspaceDocumentSavePurpose
    }

    struct WorkspaceDocumentSaveResult: Equatable, Sendable {
        let activeTabID: OpenDocumentTab.ID
        let savedURL: DocumentProjectPath
        let purpose: WorkspaceDocumentSavePurpose
        let previewImageData: Data?
        let canvasSize: CGSize
    }

    struct WorkspaceDocumentReplacementRequest: Equatable, Sendable {
        let activeTab: OpenDocumentTab
        let paperStyle: CanvasPaperStyle
    }

    struct LoadedWorkspaceFollowUpPersistenceRequest: Equatable, Sendable {
        let activeTab: OpenDocumentTab
        let paperStyle: CanvasPaperStyle
        let persistsToBackingStore: Bool
        let persistsAutosave: Bool
        let successEffects: LoadedWorkspaceProjectPlan.SuccessEffects
    }

    struct LoadedWorkspaceFollowUpPersistenceResult: Equatable, Sendable {
        let successEffects: LoadedWorkspaceProjectPlan.SuccessEffects
    }

    struct WorkspaceCloseTabsSaveRequest: Equatable, Sendable {
        let operation: PendingCloseOperation
        let tabs: [OpenDocumentTab]
        let activeTab: WorkspaceDocumentReplacementRequest?
    }

    struct WorkspaceCloseTabsSaveResult: Equatable, Sendable {
        let operation: PendingCloseOperation
    }

    struct WorkspaceArtifactDiscardRequest: Equatable, Sendable {
        let tabs: [OpenDocumentTab]
    }

    struct WorkspaceTabReservationRequest: Equatable, Sendable {
        let title: String
        let sourceProjectURL: DocumentProjectPath?
        let pane: WorkspacePane
    }

    struct WorkspaceSavedProjectMoveRequest: Equatable, Sendable {
        let sourceURL: DocumentProjectPath
        let relativeFolderPath: RelativeProjectFolderPath?
        let openTabID: OpenDocumentTab.ID?
    }

    struct WorkspaceSavedProjectMoveResult: Equatable, Sendable {
        let sourceURL: DocumentProjectPath
        let destinationURL: DocumentProjectPath
        let openTabID: OpenDocumentTab.ID?
    }

    struct WorkspaceAutosaveEntryDiscardRequest: Equatable, Sendable {
        let autosaveID: WorkspaceItemID
    }

    struct WorkspaceCatalogFailure: Error, Equatable {
        let request: WorkspaceCatalogRequest
        let feedback: ApplicationFeedback
    }

    enum WorkspacePersistenceRequest: Equatable, Sendable {
        case dirtyPresentationRefreshed(WorkspaceDirtyPresentationRequest)
        case saveActiveDocument(WorkspaceDocumentSaveRequest)
        case prepareDocumentReplacement(WorkspaceDocumentReplacementRequest)
        case reserveNewTabBackingStore(WorkspaceTabReservationRequest)
        case loadedWorkspaceFollowUp(LoadedWorkspaceFollowUpPersistenceRequest)
        case saveTabsForClose(WorkspaceCloseTabsSaveRequest)
        case discardAutosaveArtifacts(WorkspaceArtifactDiscardRequest)
    }

    enum WorkspacePersistenceResult: Equatable, Sendable {
        case dirtyPresentationPersisted(OpenDocumentTab.ID)
        case activeDocumentSaved(WorkspaceDocumentSaveResult)
        case documentReplacementPrepared(OpenDocumentTab.ID)
        case newTabBackingStoreReserved(PreparedWorkspaceTab)
        case loadedWorkspaceFollowUpApplied(LoadedWorkspaceFollowUpPersistenceResult)
        case tabsSavedForClose(WorkspaceCloseTabsSaveResult)
        case autosaveArtifactsDiscarded
    }

    enum WorkspaceCatalogRequest: Equatable, Sendable {
        case moveSavedProject(WorkspaceSavedProjectMoveRequest)
        case discardAutosaveEntry(WorkspaceAutosaveEntryDiscardRequest)
    }

    enum WorkspaceCatalogResult: Equatable, Sendable {
        case savedProjectMoved(WorkspaceSavedProjectMoveResult)
        case autosaveEntryDiscarded(WorkspaceItemID)
    }

    struct LoadedWorkspaceProjectPlan: Equatable, Sendable {
        enum Destination: Equatable, Sendable {
            case selectedTab(tabID: OpenDocumentTab.ID, pane: WorkspacePane)
            case newTab(title: String, sourceProjectURL: DocumentProjectPath?)
            case activeTab(title: String?, sourceProjectURL: DocumentProjectPath?)
        }

        struct FollowUp: Equatable, Sendable {
            var marksTabDirty = false
            var persistsToBackingStore = false
            var persistsAutosave = false
        }

        enum RecoveryResolution: Equatable, Sendable {
            case none
            case removeItem(WorkspaceItemID)
            case completeRestore(WorkspaceItemID)
            case dismiss
        }

        enum SaveHistoryResolution: Equatable, Sendable {
            case none
            case completeRestore
        }

        struct SuccessEffects: Equatable, Sendable {
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

    struct WorkspaceBackingStoreService: Sendable {
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

    struct WorkspacePersistenceUseCase: Sendable {
        let workspaceBackingStoreService: WorkspaceBackingStoreService
        let workspaceCatalogService: WorkspaceCatalogService
        let workspaceIdentityService: WorkspaceIdentityService

        func execute(
            _ request: WorkspacePersistenceRequest
        ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
            switch request {
            case let .dirtyPresentationRefreshed(dirtyPresentation):
                return persistDirtyPresentation(dirtyPresentation, request: request)
            case let .saveActiveDocument(saveRequest):
                return saveActiveDocument(saveRequest, request: request)
            case let .prepareDocumentReplacement(replacementRequest):
                return prepareDocumentReplacement(replacementRequest, request: request)
            case let .reserveNewTabBackingStore(reservationRequest):
                return reserveNewTabBackingStore(reservationRequest, request: request)
            case let .loadedWorkspaceFollowUp(followUpRequest):
                return applyLoadedWorkspaceFollowUp(followUpRequest, request: request)
            case let .saveTabsForClose(closeRequest):
                return saveTabsForClose(closeRequest, request: request)
            case let .discardAutosaveArtifacts(discardRequest):
                discardAutosaveArtifacts(discardRequest)
                return .success(.autosaveArtifactsDiscarded)
            }
        }

        private func persistDirtyPresentation(
            _ requestPayload: WorkspaceDirtyPresentationRequest,
            request: WorkspacePersistenceRequest
        ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
            do {
                try workspaceBackingStoreService.saveProject(
                    at: requestPayload.activeTab.backingStoreURL.fileURL,
                    paperStyle: requestPayload.paperStyle
                )
                try workspaceBackingStoreService.persistAutosaveSnapshot(
                    requestPayload.activeTab.backingStoreURL,
                    requestPayload.activeTab
                )
                return .success(
                    .dirtyPresentationPersisted(requestPayload.activeTab.id)
                )
            } catch {
                return .failure(
                    WorkspacePersistenceFailure(
                        request: request,
                        feedback: .saveFailed(AppFeature.optionalErrorMessage(error))
                    )
                )
            }
        }

        private func saveActiveDocument(
            _ requestPayload: WorkspaceDocumentSaveRequest,
            request: WorkspacePersistenceRequest
        ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
            do {
                try workspaceBackingStoreService.saveProject(
                    at: requestPayload.activeTab.backingStoreURL.fileURL,
                    paperStyle: requestPayload.paperStyle
                )
                let savedURL = try workspaceBackingStoreService.persistProjectSnapshot(
                    requestPayload.activeTab.backingStoreURL,
                    preferredDestinationURL: requestPayload.preferredDestinationURL
                )

                var savedTab = requestPayload.activeTab
                savedTab.title = savedURL.displayName
                savedTab.sourceProjectURL = savedURL
                savedTab.isDirty = false

                do {
                    // Best-effort cleanup of autosave artifacts after a successful save transition.
                    try workspaceBackingStoreService.discardAutosaveSnapshot(requestPayload.activeTab)
                } catch {
                }

                do {
                    // Save history is resilience-focused and should not block a successful save.
                    try workspaceBackingStoreService.persistSaveHistorySnapshot(
                        savedTab.backingStoreURL,
                        savedTab,
                        requestPayload.trigger
                    )
                } catch {
                }

                return .success(
                    .activeDocumentSaved(
                        WorkspaceDocumentSaveResult(
                            activeTabID: requestPayload.activeTab.id,
                            savedURL: savedURL,
                            purpose: requestPayload.purpose,
                            previewImageData: savedTab.previewImageData,
                            canvasSize: savedTab.canvasSize
                        )
                    )
                )
            } catch {
                return .failure(
                    WorkspacePersistenceFailure(
                        request: request,
                        feedback: .saveFailed(AppFeature.optionalErrorMessage(error))
                    )
                )
            }
        }

        private func prepareDocumentReplacement(
            _ requestPayload: WorkspaceDocumentReplacementRequest,
            request: WorkspacePersistenceRequest
        ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
            do {
                try workspaceBackingStoreService.saveProject(
                    at: requestPayload.activeTab.backingStoreURL.fileURL,
                    paperStyle: requestPayload.paperStyle
                )
                return .success(
                    .documentReplacementPrepared(requestPayload.activeTab.id)
                )
            } catch {
                return .failure(
                    WorkspacePersistenceFailure(
                        request: request,
                        feedback: .saveFailed(AppFeature.optionalErrorMessage(error))
                    )
                )
            }
        }

        private func reserveNewTabBackingStore(
            _ requestPayload: WorkspaceTabReservationRequest,
            request: WorkspacePersistenceRequest
        ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
            let tabID = workspaceIdentityService.generateTabID()
            do {
                let backingStoreURL = try workspaceBackingStoreService.createTabBackingStoreURL(tabID)
                return .success(
                    .newTabBackingStoreReserved(
                        PreparedWorkspaceTab(
                            id: tabID,
                            title: requestPayload.title,
                            backingStoreURL: backingStoreURL,
                            sourceProjectURL: requestPayload.sourceProjectURL,
                            pane: requestPayload.pane
                        )
                    )
                )
            } catch {
                return .failure(
                    WorkspacePersistenceFailure(
                        request: request,
                        feedback: .couldNotCreateTab
                    )
                )
            }
        }

        private func applyLoadedWorkspaceFollowUp(
            _ requestPayload: LoadedWorkspaceFollowUpPersistenceRequest,
            request: WorkspacePersistenceRequest
        ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
            do {
                if requestPayload.persistsToBackingStore {
                    try workspaceBackingStoreService.saveProject(
                        at: requestPayload.activeTab.backingStoreURL.fileURL,
                        paperStyle: requestPayload.paperStyle
                    )
                }
                if requestPayload.persistsAutosave {
                    try workspaceBackingStoreService.persistAutosaveSnapshot(
                        requestPayload.activeTab.backingStoreURL,
                        requestPayload.activeTab
                    )
                }
                if let autosaveEntryID = requestPayload.successEffects.discardedAutosaveEntryID {
                    try workspaceCatalogService.discardAutosaveEntry(autosaveEntryID)
                }
                return .success(
                    .loadedWorkspaceFollowUpApplied(
                        LoadedWorkspaceFollowUpPersistenceResult(
                            successEffects: requestPayload.successEffects
                        )
                    )
                )
            } catch {
                return .failure(
                    WorkspacePersistenceFailure(
                        request: request,
                        feedback: .saveFailed(AppFeature.optionalErrorMessage(error))
                    )
                )
            }
        }

        private func saveTabsForClose(
            _ requestPayload: WorkspaceCloseTabsSaveRequest,
            request: WorkspacePersistenceRequest
        ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
            do {
                if let activeTab = requestPayload.activeTab {
                    try workspaceBackingStoreService.saveProject(
                        at: activeTab.activeTab.backingStoreURL.fileURL,
                        paperStyle: activeTab.paperStyle
                    )
                }

                for tab in requestPayload.tabs {
                    let destinationURL = try workspaceBackingStoreService.persistProjectSnapshot(
                        tab.backingStoreURL,
                        preferredDestinationURL: tab.sourceProjectURL
                    )

                    var savedTab = tab
                    savedTab.title = destinationURL.displayName
                    savedTab.sourceProjectURL = destinationURL
                    savedTab.isDirty = false

                    do {
                        // Best-effort cleanup of autosave artifacts for a tab that is about to close.
                        try workspaceBackingStoreService.discardAutosaveSnapshot(tab)
                    } catch {
                    }

                    do {
                        // Save history should not block closing the workspace after a successful save.
                        try workspaceBackingStoreService.persistSaveHistorySnapshot(
                            savedTab.backingStoreURL,
                            savedTab,
                            .closeSave
                        )
                    } catch {
                    }
                }

                return .success(
                    .tabsSavedForClose(
                        WorkspaceCloseTabsSaveResult(
                            operation: requestPayload.operation
                        )
                    )
                )
            } catch {
                return .failure(
                    WorkspacePersistenceFailure(
                        request: request,
                        feedback: .saveFailed(AppFeature.optionalErrorMessage(error))
                    )
                )
            }
        }

        private func discardAutosaveArtifacts(
            _ requestPayload: WorkspaceArtifactDiscardRequest
        ) {
            for tab in requestPayload.tabs {
                do {
                    // Best-effort cleanup of autosave artifacts during tab teardown.
                    try workspaceBackingStoreService.discardAutosaveSnapshot(tab)
                } catch {
                }
                do {
                    // Best-effort cleanup of transient workspace items during tab teardown.
                    try workspaceBackingStoreService.removeWorkspaceItem(tab.backingStoreURL)
                } catch {
                }
            }
        }
    }

    struct WorkspaceCatalogUseCase: Sendable {
        let workspaceCatalogService: WorkspaceCatalogService

        func execute(
            _ request: WorkspaceCatalogRequest
        ) -> Result<WorkspaceCatalogResult, WorkspaceCatalogFailure> {
            switch request {
            case let .moveSavedProject(moveRequest):
                return moveSavedProject(moveRequest, request: request)
            case let .discardAutosaveEntry(discardRequest):
                return discardAutosaveEntry(discardRequest, request: request)
            }
        }

        private func moveSavedProject(
            _ requestPayload: WorkspaceSavedProjectMoveRequest,
            request: WorkspaceCatalogRequest
        ) -> Result<WorkspaceCatalogResult, WorkspaceCatalogFailure> {
            do {
                let destinationURL = try workspaceCatalogService.moveSavedProject(
                    requestPayload.sourceURL,
                    to: requestPayload.relativeFolderPath
                )
                return .success(
                    .savedProjectMoved(
                        WorkspaceSavedProjectMoveResult(
                            sourceURL: requestPayload.sourceURL,
                            destinationURL: destinationURL,
                            openTabID: requestPayload.openTabID
                        )
                    )
                )
            } catch {
                return .failure(
                    WorkspaceCatalogFailure(
                        request: request,
                        feedback: .moveFailed(AppFeature.optionalErrorMessage(error))
                    )
                )
            }
        }

        private func discardAutosaveEntry(
            _ requestPayload: WorkspaceAutosaveEntryDiscardRequest,
            request: WorkspaceCatalogRequest
        ) -> Result<WorkspaceCatalogResult, WorkspaceCatalogFailure> {
            do {
                try workspaceCatalogService.discardAutosaveEntry(requestPayload.autosaveID)
                return .success(.autosaveEntryDiscarded(requestPayload.autosaveID))
            } catch {
                return .failure(
                    WorkspaceCatalogFailure(
                        request: request,
                        feedback: .autosaveRestoreFailed(AppFeature.optionalErrorMessage(error))
                    )
                )
            }
        }
    }

    struct WorkspaceCatalogService: Sendable {
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

    struct WorkspaceArtifactService: Sendable {
        let documentWorkspaceClient: DocumentWorkspaceClient

        func timelapseTemporaryDirectory() -> URL {
            documentWorkspaceClient.timelapseTemporaryDirectory()
        }

        func writePNGToTemporaryDirectory(_ data: Data) throws -> URL {
            try documentWorkspaceClient.writePNGToTemporaryDirectory(data)
        }
    }

    struct WorkspaceIdentityService: Sendable {
        let uuidClient: UUIDClient

        func generateTabID() -> OpenDocumentTab.ID {
            uuidClient.generate()
        }
    }

    struct PreparedWorkspaceTab: Equatable, Sendable {
        let id: OpenDocumentTab.ID
        let title: String
        let backingStoreURL: DocumentProjectPath
        let sourceProjectURL: DocumentProjectPath?
        let pane: WorkspacePane
    }

    struct PendingLoadedWorkspaceProject: Equatable, Sendable {
        let loaded: LoadedPaintProject
        let plan: LoadedWorkspaceProjectPlan
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

    var workspacePersistenceUseCase: WorkspacePersistenceUseCase {
        WorkspacePersistenceUseCase(
            workspaceBackingStoreService: workspaceBackingStoreService,
            workspaceCatalogService: workspaceCatalogService,
            workspaceIdentityService: workspaceIdentityService
        )
    }

    var workspaceCatalogUseCase: WorkspaceCatalogUseCase {
        WorkspaceCatalogUseCase(
            workspaceCatalogService: workspaceCatalogService
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

    func refreshActiveTabMetadataForPersistence(
        state: inout State
    ) -> OpenDocumentTab? {
        let paperStyle = resolvedPaperStyle(for: state)
        state.workspace.updateActiveTabMetadata(
            previewImageData: documentPresentationQueryService.compositePNGData(
                paperStyle: paperStyle
            ),
            canvasSize: state.canvas.canvasSize
        )
        return state.workspace.activeTab
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

    func documentReplacementRequest(
        state: inout State,
        failureFeedback: ApplicationFeedback = .saveFailed(nil)
    ) -> Result<WorkspaceDocumentReplacementRequest, WorkspacePersistenceFailure> {
        let activeTab: OpenDocumentTab
        switch requireActiveTab(in: state, failureFeedback: failureFeedback) {
        case let .success(tab):
            activeTab = tab
        case let .failure(failure):
            return .failure(failure)
        }
        let refreshedActiveTab = refreshActiveTabMetadataForPersistence(state: &state) ?? activeTab
        return .success(
            WorkspaceDocumentReplacementRequest(
                activeTab: refreshedActiveTab,
                paperStyle: resolvedPaperStyle(for: state)
            )
        )
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
        return .success(())
    }

    func applyLoadedWorkspaceProject(
        _ loaded: LoadedPaintProject,
        using plan: LoadedWorkspaceProjectPlan,
        state: inout State
    ) -> Effect<Action> {
        switch plan.destination {
        case let .newTab(title, sourceProjectURL):
            state.workspace.pendingLoadedWorkspaceProject = PendingLoadedWorkspaceProject(
                loaded: loaded,
                plan: plan
            )
            return .send(
                .workspacePersistenceRequested(
                    .reserveNewTabBackingStore(
                        WorkspaceTabReservationRequest(
                            title: title,
                            sourceProjectURL: sourceProjectURL,
                            pane: state.workspace.focusedWorkspacePane
                        )
                    )
                )
            )

        case .selectedTab, .activeTab:
            return completeLoadedWorkspaceProject(
                loaded,
                using: plan,
                preparedTab: nil,
                state: &state
            )
        }
    }

    func completeLoadedWorkspaceProject(
        _ loaded: LoadedPaintProject,
        using plan: LoadedWorkspaceProjectPlan,
        preparedTab: PreparedWorkspaceTab?,
        state: inout State
    ) -> Effect<Action> {
        let activationResult: Result<Void, WorkspacePersistenceFailure>
        switch plan.destination {
        case let .selectedTab(tabID, pane):
            state.workspace.activateTab(tabID, pane: pane)
            applyLoadedProject(loaded, state: &state)
            activationResult = .success(())

        case .newTab:
            guard let preparedTab else {
                state.application.completeWorkspaceProjectLoad(
                    feedback: .couldNotCreateTab
                )
                return .none
            }
            applyLoadedProject(loaded, state: &state)
            activationResult = activatePreparedTab(preparedTab, state: &state)

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
            return .none
        case .success:
            break
        }

        switch makeLoadedWorkspaceFollowUpRequest(
            plan: plan,
            state: &state
        ) {
        case let .failure(failure):
            state.application.completeWorkspaceProjectLoad(
                feedback: failure.feedback
            )
            return .none
        case let .success(.some(request)):
            return .send(.workspacePersistenceRequested(request))
        case .success(.none):
            applyLoadedWorkspaceSuccessEffects(
                plan.successEffects,
                state: &state
            )
            state.application.completeWorkspaceProjectLoad(
                feedback: plan.successEffects.feedback
            )
            return .none
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

    func saveActiveDocumentRequest(
        state: inout State,
        preferredDestinationURL: DocumentProjectPath?,
        trigger: SaveHistoryTrigger,
        purpose: WorkspaceDocumentSavePurpose
    ) -> Result<WorkspacePersistenceRequest, WorkspacePersistenceFailure> {
        let context: WorkspaceDocumentReplacementRequest
        switch documentReplacementRequest(state: &state) {
        case let .success(request):
            context = request
        case let .failure(failure):
            return .failure(failure)
        }
        return .success(
            .saveActiveDocument(
                WorkspaceDocumentSaveRequest(
                    activeTab: context.activeTab,
                    paperStyle: context.paperStyle,
                    preferredDestinationURL: preferredDestinationURL,
                    trigger: trigger,
                    purpose: purpose
                )
            )
        )
    }

    func makeLoadedWorkspaceFollowUpRequest(
        plan: LoadedWorkspaceProjectPlan,
        state: inout State
    ) -> Result<WorkspacePersistenceRequest?, WorkspacePersistenceFailure> {
        if plan.followUp.marksTabDirty {
            state.workspace.setActiveTabDirty(true)
        }

        let requiresBackingStorePersistence: Bool = {
            switch plan.destination {
            case .newTab:
                return true
            case .selectedTab, .activeTab:
                return false
            }
        }()

        let shouldPersistToBackingStore = requiresBackingStorePersistence || plan.followUp.persistsToBackingStore
        guard shouldPersistToBackingStore || plan.followUp.persistsAutosave || plan.successEffects.discardedAutosaveEntryID != nil else {
            return .success(nil)
        }

        let context: WorkspaceDocumentReplacementRequest
        switch documentReplacementRequest(state: &state) {
        case let .success(request):
            context = request
        case let .failure(failure):
            return .failure(failure)
        }

        return .success(
            .loadedWorkspaceFollowUp(
                LoadedWorkspaceFollowUpPersistenceRequest(
                    activeTab: context.activeTab,
                    paperStyle: context.paperStyle,
                    persistsToBackingStore: shouldPersistToBackingStore,
                    persistsAutosave: plan.followUp.persistsAutosave,
                    successEffects: plan.successEffects
                )
            )
        )
    }

    func closeTabsPersistenceRequest(
        operation: PendingCloseOperation,
        tabIDs: [OpenDocumentTab.ID],
        state: inout State
    ) -> Result<WorkspacePersistenceRequest, WorkspacePersistenceFailure> {
        var tabs = tabIDs.compactMap { state.workspace.tab(withID: $0) }
        let activeTabRequest: WorkspaceDocumentReplacementRequest?
        if let activeTabID = state.workspace.activeTabID, tabIDs.contains(activeTabID) {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                activeTabRequest = request
                if let index = tabs.firstIndex(where: { $0.id == request.activeTab.id }) {
                    tabs[index] = request.activeTab
                }
            case let .failure(failure):
                return .failure(failure)
            }
        } else {
            activeTabRequest = nil
        }
        return .success(
            .saveTabsForClose(
                WorkspaceCloseTabsSaveRequest(
                    operation: operation,
                    tabs: tabs,
                    activeTab: activeTabRequest
                )
            )
        )
    }

    func discardArtifactsRequest(
        for tabs: [OpenDocumentTab]
    ) -> WorkspacePersistenceRequest {
        .discardAutosaveArtifacts(
            WorkspaceArtifactDiscardRequest(
                tabs: tabs
            )
        )
    }

    func workspacePersistenceEffect(
        for request: WorkspacePersistenceRequest
    ) -> Effect<Action> {
        .run { [workspacePersistenceUseCase] send in
            switch workspacePersistenceUseCase.execute(request) {
            case let .success(result):
                await send(.workspacePersistenceSucceeded(result))
            case let .failure(failure):
                await send(.workspacePersistenceFailed(failure))
            }
        }
    }

    func workspaceCatalogEffect(
        for request: WorkspaceCatalogRequest
    ) -> Effect<Action> {
        .run { [workspaceCatalogUseCase] send in
            switch workspaceCatalogUseCase.execute(request) {
            case let .success(result):
                await send(.workspaceCatalogSucceeded(result))
            case let .failure(failure):
                await send(.workspaceCatalogFailed(failure))
            }
        }
    }

    func documentReplacementPreparationEffect(
        request: WorkspaceDocumentReplacementRequest?,
        onPrepared: @escaping @Sendable () -> Action,
        onFailure: @escaping @Sendable (WorkspacePersistenceFailure) -> Action
    ) -> Effect<Action> {
        guard let request else {
            return .send(onPrepared())
        }
        return .run { [workspacePersistenceUseCase] send in
            let persistenceRequest = WorkspacePersistenceRequest.prepareDocumentReplacement(request)
            switch workspacePersistenceUseCase.execute(persistenceRequest) {
            case .success:
                await send(onPrepared())
            case let .failure(failure):
                await send(onFailure(failure))
            }
        }
    }

    func handleWorkspacePersistenceRequested(
        request: WorkspacePersistenceRequest
    ) -> Effect<Action> {
        workspacePersistenceEffect(for: request)
    }

    func handleWorkspaceCatalogRequested(
        request: WorkspaceCatalogRequest
    ) -> Effect<Action> {
        workspaceCatalogEffect(for: request)
    }

    func handleWorkspacePersistenceSucceeded(
        state: inout State,
        result: WorkspacePersistenceResult
    ) -> Effect<Action> {
        switch result {
        case .dirtyPresentationPersisted:
            return .none

        case let .activeDocumentSaved(saved):
            state.workspace.updateTab(
                id: saved.activeTabID,
                title: saved.savedURL.displayName,
                sourceProjectURL: saved.savedURL,
                previewImageData: saved.previewImageData,
                canvasSize: saved.canvasSize,
                isDirty: false
            )
            state.application.presentFeedback(
                .savedDocument(saved.savedURL.fileURL.lastPathComponent)
            )
            switch saved.purpose {
            case .saveDocument:
                return .send(.homeProjectsLoadRequested)
            case .homeReturn:
                state.application.showHome()
                return .send(.homeProjectsLoadRequested)
            }

        case .documentReplacementPrepared:
            return .none

        case let .newTabBackingStoreReserved(preparedTab):
            guard let pendingLoadedWorkspaceProject = state.workspace.pendingLoadedWorkspaceProject else {
                return .none
            }
            state.workspace.pendingLoadedWorkspaceProject = nil
            return completeLoadedWorkspaceProject(
                pendingLoadedWorkspaceProject.loaded,
                using: pendingLoadedWorkspaceProject.plan,
                preparedTab: preparedTab,
                state: &state
            )

        case let .loadedWorkspaceFollowUpApplied(followUp):
            applyLoadedWorkspaceSuccessEffects(
                followUp.successEffects,
                state: &state
            )
            state.application.completeWorkspaceProjectLoad(
                feedback: followUp.successEffects.feedback
            )
            return .none

        case let .tabsSavedForClose(closeResult):
            return performCloseOperation(closeResult.operation)

        case .autosaveArtifactsDiscarded:
            return .none
        }
    }

    func handleWorkspacePersistenceFailed(
        state: inout State,
        failure: WorkspacePersistenceFailure
    ) -> Effect<Action> {
        switch failure.request {
        case .some(.loadedWorkspaceFollowUp):
            state.application.completeWorkspaceProjectLoad(
                feedback: failure.feedback
            )
        case .some(.reserveNewTabBackingStore):
            state.workspace.pendingLoadedWorkspaceProject = nil
            state.application.completeWorkspaceProjectLoad(
                feedback: failure.feedback
            )
        default:
            state.application.presentFeedback(failure.feedback)
        }
        return .none
    }

    func handleWorkspaceCatalogSucceeded(
        state: inout State,
        result: WorkspaceCatalogResult
    ) -> Effect<Action> {
        switch result {
        case let .savedProjectMoved(moveResult):
            if let openTabID = moveResult.openTabID {
                state.workspace.updateTab(id: openTabID, sourceProjectURL: moveResult.destinationURL)
            }
            return .send(.homeProjectsLoadRequested)

        case let .autosaveEntryDiscarded(autosaveID):
            state.recovery.removeItem(id: autosaveID)
            return .none
        }
    }

    func handleWorkspaceCatalogFailed(
        state: inout State,
        failure: WorkspaceCatalogFailure
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

    func applyLoadedWorkspaceSuccessEffects(
        _ successEffects: LoadedWorkspaceProjectPlan.SuccessEffects,
        state: inout State
    ) {
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

    static func nextUntitledTabTitle(existingTabs: [OpenDocumentTab]) -> String {
        let untitledTabs = existingTabs.filter { $0.sourceProjectURL == nil && $0.title.hasPrefix("Untitled") }
        return untitledTabs.isEmpty ? "Untitled" : "Untitled \(untitledTabs.count + 1)"
    }
}
