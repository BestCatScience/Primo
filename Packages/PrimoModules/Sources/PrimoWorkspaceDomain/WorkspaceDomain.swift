import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain

public func optionalErrorMessage(_ error: Error) -> String? {
    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
}

public enum WorkspacePersistenceIssue: Error, Equatable, Sendable, DomainIssue {
    case autosaveCleanupFailed(String?)
    case saveHistoryPersistFailed(String?)
    case workspaceItemRemovalFailed(String?)
    case autosaveEntryDiscardFailed(String?)
}

public enum WorkspacePersistenceFailureReason: Error, Equatable, Sendable, FailureReason {
    case saveFailed(String?)
    case couldNotCreateTab
    case activeTabUnavailable
}

public struct WorkspacePersistenceFailure: Error, Equatable, Sendable {
    public let request: WorkspacePersistenceRequest?
    public let reason: WorkspacePersistenceFailureReason

    public init(
        request: WorkspacePersistenceRequest? = nil,
        reason: WorkspacePersistenceFailureReason
    ) {
        self.request = request
        self.reason = reason
    }
}

public struct WorkspaceDirtyPresentationRequest: Equatable, Sendable {
    public let activeTab: OpenDocumentTab
    public let paperStyle: CanvasPaperStyle

    public init(activeTab: OpenDocumentTab, paperStyle: CanvasPaperStyle) {
        self.activeTab = activeTab
        self.paperStyle = paperStyle
    }
}

public enum WorkspaceDocumentSavePurpose: Equatable, Sendable {
    case saveDocument
    case homeReturn
}

public struct WorkspaceDocumentSaveRequest: Equatable, Sendable {
    public let activeTab: OpenDocumentTab
    public let paperStyle: CanvasPaperStyle
    public let preferredDestinationURL: DocumentProjectPath?
    public let trigger: SaveHistoryTrigger
    public let purpose: WorkspaceDocumentSavePurpose

    public init(
        activeTab: OpenDocumentTab,
        paperStyle: CanvasPaperStyle,
        preferredDestinationURL: DocumentProjectPath?,
        trigger: SaveHistoryTrigger,
        purpose: WorkspaceDocumentSavePurpose
    ) {
        self.activeTab = activeTab
        self.paperStyle = paperStyle
        self.preferredDestinationURL = preferredDestinationURL
        self.trigger = trigger
        self.purpose = purpose
    }
}

public struct WorkspaceDocumentSaveResult: Equatable, Sendable {
    public let activeTabID: OpenDocumentTab.ID
    public let savedURL: DocumentProjectPath
    public let purpose: WorkspaceDocumentSavePurpose
    public let previewSurface: DocumentCompositeSurface?
    /// Legacy preview bytes retained for migration and fallback UI.
    public let previewImageData: Data?
    public let canvasSize: CGSize
    public var issues: [WorkspacePersistenceIssue]

    public init(
        activeTabID: OpenDocumentTab.ID,
        savedURL: DocumentProjectPath,
        purpose: WorkspaceDocumentSavePurpose,
        previewSurface: DocumentCompositeSurface? = nil,
        previewImageData: Data?,
        canvasSize: CGSize,
        issues: [WorkspacePersistenceIssue] = []
    ) {
        self.activeTabID = activeTabID
        self.savedURL = savedURL
        self.purpose = purpose
        self.previewSurface = previewSurface
        self.previewImageData = previewImageData
        self.canvasSize = canvasSize
        self.issues = issues
    }
}

public struct WorkspaceActiveCanvasDuplicateRequest: Equatable, Sendable {
    public let activeTab: OpenDocumentTab
    public let title: String
    public let pane: WorkspacePane
    public let paperStyle: CanvasPaperStyle

    public init(
        activeTab: OpenDocumentTab,
        title: String,
        pane: WorkspacePane,
        paperStyle: CanvasPaperStyle
    ) {
        self.activeTab = activeTab
        self.title = title
        self.pane = pane
        self.paperStyle = paperStyle
    }
}

public struct WorkspaceActiveCanvasDuplicateResult: Equatable, Sendable {
    public let preparedTab: PreparedWorkspaceTab
    public let canvasSize: CGSize
    public let previewSurface: DocumentCompositeSurface?
    public let previewImageData: Data?

    public init(
        preparedTab: PreparedWorkspaceTab,
        canvasSize: CGSize,
        previewSurface: DocumentCompositeSurface?,
        previewImageData: Data?
    ) {
        self.preparedTab = preparedTab
        self.canvasSize = canvasSize
        self.previewSurface = previewSurface
        self.previewImageData = previewImageData
    }
}

public struct WorkspaceDocumentReplacementRequest: Equatable, Sendable {
    public let activeTab: OpenDocumentTab
    public let paperStyle: CanvasPaperStyle

    public init(activeTab: OpenDocumentTab, paperStyle: CanvasPaperStyle) {
        self.activeTab = activeTab
        self.paperStyle = paperStyle
    }
}

public struct LoadedWorkspaceFollowUpPersistenceRequest: Equatable, Sendable {
    public let activeTab: OpenDocumentTab
    public let paperStyle: CanvasPaperStyle
    public let persistsToBackingStore: Bool
    public let persistsAutosave: Bool
    public let successEffects: LoadedWorkspaceProjectPlan.SuccessEffects

    public init(
        activeTab: OpenDocumentTab,
        paperStyle: CanvasPaperStyle,
        persistsToBackingStore: Bool,
        persistsAutosave: Bool,
        successEffects: LoadedWorkspaceProjectPlan.SuccessEffects
    ) {
        self.activeTab = activeTab
        self.paperStyle = paperStyle
        self.persistsToBackingStore = persistsToBackingStore
        self.persistsAutosave = persistsAutosave
        self.successEffects = successEffects
    }
}

public struct LoadedWorkspaceFollowUpPersistenceResult: Equatable, Sendable {
    public let successEffects: LoadedWorkspaceProjectPlan.SuccessEffects
    public var issues: [WorkspacePersistenceIssue]

    public init(
        successEffects: LoadedWorkspaceProjectPlan.SuccessEffects,
        issues: [WorkspacePersistenceIssue] = []
    ) {
        self.successEffects = successEffects
        self.issues = issues
    }
}

public enum PendingCloseOperation: Equatable, Sendable {
    case tab(OpenDocumentTab.ID)
    case closeOtherTabs(OpenDocumentTab.ID)
    case closeTabsToRight(OpenDocumentTab.ID)
}

public struct WorkspaceCloseTabsSaveRequest: Equatable, Sendable {
    public let operation: PendingCloseOperation
    public let tabs: [OpenDocumentTab]
    public let activeTab: WorkspaceDocumentReplacementRequest?

    public init(
        operation: PendingCloseOperation,
        tabs: [OpenDocumentTab],
        activeTab: WorkspaceDocumentReplacementRequest?
    ) {
        self.operation = operation
        self.tabs = tabs
        self.activeTab = activeTab
    }
}

public struct WorkspaceCloseTabsSaveResult: Equatable, Sendable {
    public let operation: PendingCloseOperation
    public var issues: [WorkspacePersistenceIssue]

    public init(
        operation: PendingCloseOperation,
        issues: [WorkspacePersistenceIssue] = []
    ) {
        self.operation = operation
        self.issues = issues
    }
}

public struct WorkspaceArtifactDiscardRequest: Equatable, Sendable {
    public let tabs: [OpenDocumentTab]

    public init(tabs: [OpenDocumentTab]) {
        self.tabs = tabs
    }
}

public struct WorkspaceTabReservationRequest: Equatable, Sendable {
    public let title: String
    public let sourceProjectURL: DocumentProjectPath?
    public let pane: WorkspacePane

    public init(title: String, sourceProjectURL: DocumentProjectPath?, pane: WorkspacePane) {
        self.title = title
        self.sourceProjectURL = sourceProjectURL
        self.pane = pane
    }
}

public struct WorkspaceSavedProjectMoveRequest: Equatable, Sendable {
    public let sourceURL: DocumentProjectPath
    public let relativeFolderPath: RelativeProjectFolderPath?
    public let openTabID: OpenDocumentTab.ID?

    public init(
        sourceURL: DocumentProjectPath,
        relativeFolderPath: RelativeProjectFolderPath?,
        openTabID: OpenDocumentTab.ID?
    ) {
        self.sourceURL = sourceURL
        self.relativeFolderPath = relativeFolderPath
        self.openTabID = openTabID
    }
}

public struct WorkspaceSavedProjectMoveResult: Equatable, Sendable {
    public let sourceURL: DocumentProjectPath
    public let destinationURL: DocumentProjectPath
    public let openTabID: OpenDocumentTab.ID?

    public init(sourceURL: DocumentProjectPath, destinationURL: DocumentProjectPath, openTabID: OpenDocumentTab.ID?) {
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.openTabID = openTabID
    }
}

public struct WorkspaceAutosaveEntryDiscardRequest: Equatable, Sendable {
    public let autosaveID: WorkspaceItemID

    public init(autosaveID: WorkspaceItemID) {
        self.autosaveID = autosaveID
    }
}

public struct WorkspaceSaveHistoryLoadRequest: Equatable, Sendable {
    public let activeTab: OpenDocumentTab

    public init(activeTab: OpenDocumentTab) {
        self.activeTab = activeTab
    }
}

public enum WorkspaceCatalogFailureReason: Error, Equatable, Sendable, FailureReason {
    case loadSavedProjectsFailed(String?)
    case loadAutosaveRecoveryItemsFailed(String?)
    case loadSaveHistoryEntriesFailed(String?)
    case moveSavedProjectFailed(String?)
    case discardAutosaveEntryFailed(String?)
}

public struct WorkspaceCatalogFailure: Error, Equatable, Sendable {
    public let request: WorkspaceCatalogRequest
    public let reason: WorkspaceCatalogFailureReason

    public init(request: WorkspaceCatalogRequest, reason: WorkspaceCatalogFailureReason) {
        self.request = request
        self.reason = reason
    }
}

public enum WorkspacePersistenceRequest: Equatable, Sendable {
    case dirtyPresentationRefreshed(WorkspaceDirtyPresentationRequest)
    case saveActiveDocument(WorkspaceDocumentSaveRequest)
    case duplicateActiveCanvas(WorkspaceActiveCanvasDuplicateRequest)
    case prepareDocumentReplacement(WorkspaceDocumentReplacementRequest)
    case reserveNewTabBackingStore(WorkspaceTabReservationRequest)
    case loadedWorkspaceFollowUp(LoadedWorkspaceFollowUpPersistenceRequest)
    case saveTabsForClose(WorkspaceCloseTabsSaveRequest)
    case discardAutosaveArtifacts(WorkspaceArtifactDiscardRequest)
}

public enum WorkspacePersistenceResult: Equatable, Sendable {
    case dirtyPresentationPersisted(OpenDocumentTab.ID)
    case activeDocumentSaved(WorkspaceDocumentSaveResult)
    case activeCanvasDuplicated(WorkspaceActiveCanvasDuplicateResult)
    case documentReplacementPrepared(OpenDocumentTab.ID)
    case newTabBackingStoreReserved(PreparedWorkspaceTab)
    case loadedWorkspaceFollowUpApplied(LoadedWorkspaceFollowUpPersistenceResult)
    case tabsSavedForClose(WorkspaceCloseTabsSaveResult)
    case autosaveArtifactsDiscarded([WorkspacePersistenceIssue])
}

public enum WorkspaceCatalogRequest: Equatable, Sendable {
    case loadSavedProjects
    case loadAutosaveRecoveryItems
    case loadSaveHistoryEntries(WorkspaceSaveHistoryLoadRequest)
    case moveSavedProject(WorkspaceSavedProjectMoveRequest)
    case discardAutosaveEntry(WorkspaceAutosaveEntryDiscardRequest)
}

public enum WorkspaceCatalogResult: Equatable, Sendable {
    case savedProjectsLoaded([SavedProjectSummary])
    case autosaveRecoveryItemsLoaded([AutosaveRecoveryItem])
    case saveHistoryEntriesLoaded([SaveHistoryEntry])
    case savedProjectMoved(WorkspaceSavedProjectMoveResult)
    case autosaveEntryDiscarded(WorkspaceItemID)
}

public struct LoadedWorkspaceProjectPlan: Equatable, Sendable {
    public enum Destination: Equatable, Sendable {
        case selectedTab(tabID: OpenDocumentTab.ID, pane: WorkspacePane)
        case newTab(title: String, sourceProjectURL: DocumentProjectPath?)
        case activeTab(title: String?, sourceProjectURL: DocumentProjectPath?)
    }

    public struct FollowUp: Equatable, Sendable {
        public var marksTabDirty = false
        public var persistsToBackingStore = false
        public var persistsAutosave = false

        public init(
            marksTabDirty: Bool = false,
            persistsToBackingStore: Bool = false,
            persistsAutosave: Bool = false
        ) {
            self.marksTabDirty = marksTabDirty
            self.persistsToBackingStore = persistsToBackingStore
            self.persistsAutosave = persistsAutosave
        }
    }

    public enum RecoveryResolution: Equatable, Sendable {
        case none
        case removeItem(WorkspaceItemID)
        case completeRestore(WorkspaceItemID)
        case dismiss
    }

    public enum SaveHistoryResolution: Equatable, Sendable {
        case none
        case completeRestore
    }

    public enum Completion: Equatable, Sendable {
        case none
        case openedDocument(layerCount: Int)
        case restoredSaveHistory
        case restoredAutosave
    }

    public struct SuccessEffects: Equatable, Sendable {
        public var discardedAutosaveEntryID: WorkspaceItemID?
        public var recoveryResolution: RecoveryResolution = .none
        public var saveHistoryResolution: SaveHistoryResolution = .none
        public var completion: Completion = .none

        public init(
            discardedAutosaveEntryID: WorkspaceItemID? = nil,
            recoveryResolution: RecoveryResolution = .none,
            saveHistoryResolution: SaveHistoryResolution = .none,
            completion: Completion = .none
        ) {
            self.discardedAutosaveEntryID = discardedAutosaveEntryID
            self.recoveryResolution = recoveryResolution
            self.saveHistoryResolution = saveHistoryResolution
            self.completion = completion
        }
    }

    public let destination: Destination
    public var followUp: FollowUp
    public var successEffects: SuccessEffects

    public init(
        destination: Destination,
        followUp: FollowUp = FollowUp(),
        successEffects: SuccessEffects = SuccessEffects()
    ) {
        self.destination = destination
        self.followUp = followUp
        self.successEffects = successEffects
    }
}

public struct PreparedWorkspaceTab: Equatable, Sendable {
    public let id: OpenDocumentTab.ID
    public let title: String
    public let backingStoreURL: DocumentProjectPath
    public let sourceProjectURL: DocumentProjectPath?
    public let pane: WorkspacePane

    public init(
        id: OpenDocumentTab.ID,
        title: String,
        backingStoreURL: DocumentProjectPath,
        sourceProjectURL: DocumentProjectPath?,
        pane: WorkspacePane
    ) {
        self.id = id
        self.title = title
        self.backingStoreURL = backingStoreURL
        self.sourceProjectURL = sourceProjectURL
        self.pane = pane
    }
}

public struct WorkspacePersistenceUseCase: Sendable {
    public let workspaceBackingStore: WorkspaceBackingStoreGateway
    public let workspaceCatalog: WorkspaceCatalogGateway
    public let identityGenerator: WorkspaceIdentityGenerator

    public init(
        workspaceBackingStore: WorkspaceBackingStoreGateway,
        workspaceCatalog: WorkspaceCatalogGateway,
        identityGenerator: WorkspaceIdentityGenerator
    ) {
        self.workspaceBackingStore = workspaceBackingStore
        self.workspaceCatalog = workspaceCatalog
        self.identityGenerator = identityGenerator
    }

    public func execute(
        _ request: WorkspacePersistenceRequest
    ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
        switch request {
        case let .dirtyPresentationRefreshed(dirtyPresentation):
            return persistDirtyPresentation(dirtyPresentation, request: request)
        case let .saveActiveDocument(saveRequest):
            return saveActiveDocument(saveRequest, request: request)
        case let .duplicateActiveCanvas(duplicateRequest):
            return duplicateActiveCanvas(duplicateRequest, request: request)
        case let .prepareDocumentReplacement(replacementRequest):
            return prepareDocumentReplacement(replacementRequest, request: request)
        case let .reserveNewTabBackingStore(reservationRequest):
            return reserveNewTabBackingStore(reservationRequest, request: request)
        case let .loadedWorkspaceFollowUp(followUpRequest):
            return applyLoadedWorkspaceFollowUp(followUpRequest, request: request)
        case let .saveTabsForClose(closeRequest):
            return saveTabsForClose(closeRequest, request: request)
        case let .discardAutosaveArtifacts(discardRequest):
            return .success(.autosaveArtifactsDiscarded(discardAutosaveArtifacts(discardRequest)))
        }
    }

    private func persistDirtyPresentation(
        _ requestPayload: WorkspaceDirtyPresentationRequest,
        request: WorkspacePersistenceRequest
    ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
        do {
            try workspaceBackingStore.saveProject(
                requestPayload.activeTab.backingStoreURL.fileURL,
                requestPayload.paperStyle
            )
            try workspaceBackingStore.persistAutosaveSnapshot(
                requestPayload.activeTab.backingStoreURL,
                requestPayload.activeTab
            )
            return .success(.dirtyPresentationPersisted(requestPayload.activeTab.id))
        } catch {
            return .failure(
                WorkspacePersistenceFailure(
                    request: request,
                    reason: .saveFailed(optionalErrorMessage(error))
                )
            )
        }
    }

    private func saveActiveDocument(
        _ requestPayload: WorkspaceDocumentSaveRequest,
        request: WorkspacePersistenceRequest
    ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
        do {
            try workspaceBackingStore.saveProject(
                requestPayload.activeTab.backingStoreURL.fileURL,
                requestPayload.paperStyle
            )
            let savedURL = try workspaceBackingStore.persistProjectSnapshot(
                requestPayload.activeTab.backingStoreURL,
                requestPayload.preferredDestinationURL
            )

            var savedTab = requestPayload.activeTab
            savedTab.title = savedURL.displayName
            savedTab.sourceProjectURL = savedURL
            savedTab.isDirty = false
            var issues: [WorkspacePersistenceIssue] = []

            do {
                try workspaceBackingStore.discardAutosaveSnapshot(requestPayload.activeTab)
            } catch {
                issues.append(.autosaveCleanupFailed(optionalErrorMessage(error)))
            }

            do {
                try workspaceBackingStore.persistSaveHistorySnapshot(
                    savedTab.backingStoreURL,
                    savedTab,
                    requestPayload.trigger
                )
            } catch {
                issues.append(.saveHistoryPersistFailed(optionalErrorMessage(error)))
            }

            return .success(
                .activeDocumentSaved(
                    WorkspaceDocumentSaveResult(
                        activeTabID: requestPayload.activeTab.id,
                        savedURL: savedURL,
                        purpose: requestPayload.purpose,
                        previewSurface: savedTab.previewSurface,
                        previewImageData: savedTab.previewImageData,
                        canvasSize: savedTab.canvasSize,
                        issues: issues
                    )
                )
            )
        } catch {
            return .failure(
                WorkspacePersistenceFailure(
                    request: request,
                    reason: .saveFailed(optionalErrorMessage(error))
                )
            )
        }
    }

    private func duplicateActiveCanvas(
        _ requestPayload: WorkspaceActiveCanvasDuplicateRequest,
        request: WorkspacePersistenceRequest
    ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
        let tabID = identityGenerator.generateTabID()
        do {
            try workspaceBackingStore.saveProject(
                requestPayload.activeTab.backingStoreURL.fileURL,
                requestPayload.paperStyle
            )
            let backingStoreURL = try workspaceBackingStore.createTabBackingStoreURL(tabID)
            _ = try workspaceBackingStore.persistProjectSnapshot(
                requestPayload.activeTab.backingStoreURL,
                backingStoreURL
            )
            let preparedTab = PreparedWorkspaceTab(
                id: tabID,
                title: requestPayload.title,
                backingStoreURL: backingStoreURL,
                sourceProjectURL: nil,
                pane: requestPayload.pane
            )
            return .success(
                .activeCanvasDuplicated(
                    WorkspaceActiveCanvasDuplicateResult(
                        preparedTab: preparedTab,
                        canvasSize: requestPayload.activeTab.canvasSize,
                        previewSurface: requestPayload.activeTab.previewSurface,
                        previewImageData: requestPayload.activeTab.previewImageData
                    )
                )
            )
        } catch {
            return .failure(
                WorkspacePersistenceFailure(
                    request: request,
                    reason: .saveFailed(optionalErrorMessage(error))
                )
            )
        }
    }

    private func prepareDocumentReplacement(
        _ requestPayload: WorkspaceDocumentReplacementRequest,
        request: WorkspacePersistenceRequest
    ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
        do {
            try workspaceBackingStore.saveProject(
                requestPayload.activeTab.backingStoreURL.fileURL,
                requestPayload.paperStyle
            )
            return .success(.documentReplacementPrepared(requestPayload.activeTab.id))
        } catch {
            return .failure(
                WorkspacePersistenceFailure(
                    request: request,
                    reason: .saveFailed(optionalErrorMessage(error))
                )
            )
        }
    }

    private func reserveNewTabBackingStore(
        _ requestPayload: WorkspaceTabReservationRequest,
        request: WorkspacePersistenceRequest
    ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
        let tabID = identityGenerator.generateTabID()
        do {
            let backingStoreURL = try workspaceBackingStore.createTabBackingStoreURL(tabID)
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
                    reason: .couldNotCreateTab
                )
            )
        }
    }

    private func applyLoadedWorkspaceFollowUp(
        _ requestPayload: LoadedWorkspaceFollowUpPersistenceRequest,
        request: WorkspacePersistenceRequest
    ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
        do {
            var issues: [WorkspacePersistenceIssue] = []
            if requestPayload.persistsToBackingStore {
                try workspaceBackingStore.saveProject(
                    requestPayload.activeTab.backingStoreURL.fileURL,
                    requestPayload.paperStyle
                )
            }
            if requestPayload.persistsAutosave {
                try workspaceBackingStore.persistAutosaveSnapshot(
                    requestPayload.activeTab.backingStoreURL,
                    requestPayload.activeTab
                )
            }
            if let autosaveEntryID = requestPayload.successEffects.discardedAutosaveEntryID {
                do {
                    try workspaceCatalog.discardAutosaveEntry(autosaveEntryID)
                } catch {
                    issues.append(.autosaveEntryDiscardFailed(optionalErrorMessage(error)))
                }
            }
            return .success(
                .loadedWorkspaceFollowUpApplied(
                    LoadedWorkspaceFollowUpPersistenceResult(
                        successEffects: requestPayload.successEffects,
                        issues: issues
                    )
                )
            )
        } catch {
            return .failure(
                WorkspacePersistenceFailure(
                    request: request,
                    reason: .saveFailed(optionalErrorMessage(error))
                )
            )
        }
    }

    private func saveTabsForClose(
        _ requestPayload: WorkspaceCloseTabsSaveRequest,
        request: WorkspacePersistenceRequest
    ) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
        do {
            var issues: [WorkspacePersistenceIssue] = []
            if let activeTab = requestPayload.activeTab {
                try workspaceBackingStore.saveProject(
                    activeTab.activeTab.backingStoreURL.fileURL,
                    activeTab.paperStyle
                )
            }

            for tab in requestPayload.tabs {
                let destinationURL = try workspaceBackingStore.persistProjectSnapshot(
                    tab.backingStoreURL,
                    tab.sourceProjectURL
                )

                var savedTab = tab
                savedTab.title = destinationURL.displayName
                savedTab.sourceProjectURL = destinationURL
                savedTab.isDirty = false

                do {
                    try workspaceBackingStore.discardAutosaveSnapshot(tab)
                } catch {
                    issues.append(.autosaveCleanupFailed(optionalErrorMessage(error)))
                }

                do {
                    try workspaceBackingStore.persistSaveHistorySnapshot(
                        savedTab.backingStoreURL,
                        savedTab,
                        .closeSave
                    )
                } catch {
                    issues.append(.saveHistoryPersistFailed(optionalErrorMessage(error)))
                }
            }

            return .success(
                .tabsSavedForClose(
                    WorkspaceCloseTabsSaveResult(
                        operation: requestPayload.operation,
                        issues: issues
                    )
                )
            )
        } catch {
            return .failure(
                WorkspacePersistenceFailure(
                    request: request,
                    reason: .saveFailed(optionalErrorMessage(error))
                )
            )
        }
    }

    private func discardAutosaveArtifacts(
        _ requestPayload: WorkspaceArtifactDiscardRequest
    ) -> [WorkspacePersistenceIssue] {
        var issues: [WorkspacePersistenceIssue] = []
        for tab in requestPayload.tabs {
            do {
                try workspaceBackingStore.discardAutosaveSnapshot(tab)
            } catch {
                issues.append(.autosaveCleanupFailed(optionalErrorMessage(error)))
            }
            do {
                try workspaceBackingStore.removeWorkspaceItem(tab.backingStoreURL)
            } catch {
                issues.append(.workspaceItemRemovalFailed(optionalErrorMessage(error)))
            }
        }
        return issues
    }
}

public struct WorkspaceCatalogUseCase: Sendable {
    public let workspaceCatalog: WorkspaceCatalogGateway

    public init(workspaceCatalog: WorkspaceCatalogGateway) {
        self.workspaceCatalog = workspaceCatalog
    }

    public func execute(
        _ request: WorkspaceCatalogRequest
    ) -> Result<WorkspaceCatalogResult, WorkspaceCatalogFailure> {
        switch request {
        case .loadSavedProjects:
            return loadSavedProjects(request: request)
        case .loadAutosaveRecoveryItems:
            return loadAutosaveRecoveryItems(request: request)
        case let .loadSaveHistoryEntries(loadRequest):
            return loadSaveHistoryEntries(loadRequest, request: request)
        case let .moveSavedProject(moveRequest):
            return moveSavedProject(moveRequest, request: request)
        case let .discardAutosaveEntry(discardRequest):
            return discardAutosaveEntry(discardRequest, request: request)
        }
    }

    private func loadSavedProjects(
        request: WorkspaceCatalogRequest
    ) -> Result<WorkspaceCatalogResult, WorkspaceCatalogFailure> {
        do {
            return .success(.savedProjectsLoaded(try workspaceCatalog.loadSavedProjects()))
        } catch {
            return .failure(
                WorkspaceCatalogFailure(
                    request: request,
                    reason: .loadSavedProjectsFailed(optionalErrorMessage(error))
                )
            )
        }
    }

    private func loadAutosaveRecoveryItems(
        request: WorkspaceCatalogRequest
    ) -> Result<WorkspaceCatalogResult, WorkspaceCatalogFailure> {
        do {
            return .success(.autosaveRecoveryItemsLoaded(try workspaceCatalog.loadAutosaveRecoveryItems()))
        } catch {
            return .failure(
                WorkspaceCatalogFailure(
                    request: request,
                    reason: .loadAutosaveRecoveryItemsFailed(optionalErrorMessage(error))
                )
            )
        }
    }

    private func loadSaveHistoryEntries(
        _ requestPayload: WorkspaceSaveHistoryLoadRequest,
        request: WorkspaceCatalogRequest
    ) -> Result<WorkspaceCatalogResult, WorkspaceCatalogFailure> {
        do {
            return .success(
                .saveHistoryEntriesLoaded(
                    try workspaceCatalog.loadSaveHistoryEntries(requestPayload.activeTab)
                )
            )
        } catch {
            return .failure(
                WorkspaceCatalogFailure(
                    request: request,
                    reason: .loadSaveHistoryEntriesFailed(optionalErrorMessage(error))
                )
            )
        }
    }

    private func moveSavedProject(
        _ requestPayload: WorkspaceSavedProjectMoveRequest,
        request: WorkspaceCatalogRequest
    ) -> Result<WorkspaceCatalogResult, WorkspaceCatalogFailure> {
        do {
            let destinationURL = try workspaceCatalog.moveSavedProject(
                requestPayload.sourceURL,
                requestPayload.relativeFolderPath
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
                    reason: .moveSavedProjectFailed(optionalErrorMessage(error))
                )
            )
        }
    }

    private func discardAutosaveEntry(
        _ requestPayload: WorkspaceAutosaveEntryDiscardRequest,
        request: WorkspaceCatalogRequest
    ) -> Result<WorkspaceCatalogResult, WorkspaceCatalogFailure> {
        do {
            try workspaceCatalog.discardAutosaveEntry(requestPayload.autosaveID)
            return .success(.autosaveEntryDiscarded(requestPayload.autosaveID))
        } catch {
            return .failure(
                WorkspaceCatalogFailure(
                    request: request,
                    reason: .discardAutosaveEntryFailed(optionalErrorMessage(error))
                )
            )
        }
    }
}

public enum WorkspaceProjectLoadIssue: Error, Equatable, Sendable {
    case workspaceItemRemovalFailed(String?)
    case importedStagingCleanupFailed(String?)
}

public enum WorkspaceProjectLoadFailureReason: Error, Equatable, Sendable {
    case prepareDocumentReplacementFailed(WorkspacePersistenceFailureReason)
    case openFailed(String?)
    case importFailed(String?)
}

public struct WorkspaceProjectLoadOperation: Equatable, Sendable {
    public let fileURL: URL
    public let removeWorkspaceItemOnSuccess: DocumentProjectPath?

    public init(fileURL: URL, removeWorkspaceItemOnSuccess: DocumentProjectPath?) {
        self.fileURL = fileURL
        self.removeWorkspaceItemOnSuccess = removeWorkspaceItemOnSuccess
    }
}

public struct WorkspaceImportedProjectLoadOperation: Equatable, Sendable {
    public let sourceURL: URL

    public init(sourceURL: URL) {
        self.sourceURL = sourceURL
    }
}

public enum WorkspaceProjectLoadRequest: Equatable, Sendable {
    case project(WorkspaceProjectLoadOperation)
    case imported(WorkspaceImportedProjectLoadOperation)
}

public enum WorkspaceProjectLoadResult<LoadedProject>: Equatable where LoadedProject: Equatable {
    case project(LoadedProject, [WorkspaceProjectLoadIssue])
    case imported(LoadedProject, String, [WorkspaceProjectLoadIssue])
}

public struct WorkspaceProjectLoadFailure: Error, Equatable, Sendable {
    public let request: WorkspaceProjectLoadRequest
    public let reason: WorkspaceProjectLoadFailureReason

    public init(request: WorkspaceProjectLoadRequest, reason: WorkspaceProjectLoadFailureReason) {
        self.request = request
        self.reason = reason
    }
}

public struct WorkspaceProjectPreparationUseCase: Sendable {
    public let workspacePersistenceUseCase: WorkspacePersistenceUseCase

    public init(workspacePersistenceUseCase: WorkspacePersistenceUseCase) {
        self.workspacePersistenceUseCase = workspacePersistenceUseCase
    }

    public func execute(
        _ request: WorkspaceDocumentReplacementRequest
    ) -> Result<Void, WorkspacePersistenceFailure> {
        switch workspacePersistenceUseCase.execute(.prepareDocumentReplacement(request)) {
        case .success:
            return .success(())
        case let .failure(failure):
            return .failure(failure)
        }
    }
}

public struct WorkspaceProjectCleanupService: Sendable {
    public let workspaceBackingStore: WorkspaceBackingStoreGateway
    public let documentImport: DocumentImportGateway

    public init(
        workspaceBackingStore: WorkspaceBackingStoreGateway,
        documentImport: DocumentImportGateway
    ) {
        self.workspaceBackingStore = workspaceBackingStore
        self.documentImport = documentImport
    }

    public func discardWorkspaceItemIfNeeded(
        _ workspaceItem: DocumentProjectPath?
    ) -> [WorkspaceProjectLoadIssue] {
        guard let workspaceItem else { return [] }
        do {
            try workspaceBackingStore.removeWorkspaceItem(workspaceItem)
            return []
        } catch {
            return [.workspaceItemRemovalFailed(optionalErrorMessage(error))]
        }
    }

    public func discardImportedStaging(
        _ stagedProjectURL: DocumentProjectPath
    ) -> [WorkspaceProjectLoadIssue] {
        switch documentImport.discardStagedDocument(stagedProjectURL) {
        case .success:
            return []
        case let .failure(failure):
            return [.importedStagingCleanupFailed(failure.errorDescription)]
        }
    }
}

public struct WorkspaceProjectLoadUseCase<LoadedProject>: Sendable where LoadedProject: Equatable {
    public let projectLoader: ProjectLoadingGateway<LoadedProject>
    public let documentImport: DocumentImportGateway
    public let cleanupService: WorkspaceProjectCleanupService

    public init(
        projectLoader: ProjectLoadingGateway<LoadedProject>,
        documentImport: DocumentImportGateway,
        cleanupService: WorkspaceProjectCleanupService
    ) {
        self.projectLoader = projectLoader
        self.documentImport = documentImport
        self.cleanupService = cleanupService
    }

    public func execute(
        _ request: WorkspaceProjectLoadRequest
    ) -> Result<WorkspaceProjectLoadResult<LoadedProject>, WorkspaceProjectLoadFailure> {
        switch request {
        case let .project(operation):
            return loadProject(operation, request: request)
        case let .imported(operation):
            return loadImportedProject(operation, request: request)
        }
    }

    private func loadProject(
        _ operation: WorkspaceProjectLoadOperation,
        request: WorkspaceProjectLoadRequest
    ) -> Result<WorkspaceProjectLoadResult<LoadedProject>, WorkspaceProjectLoadFailure> {
        do {
            let loaded = try projectLoader.loadProject(operation.fileURL)
            let issues = cleanupService.discardWorkspaceItemIfNeeded(operation.removeWorkspaceItemOnSuccess)
            return .success(.project(loaded, issues))
        } catch {
            return .failure(
                WorkspaceProjectLoadFailure(
                    request: request,
                    reason: .openFailed(optionalErrorMessage(error))
                )
            )
        }
    }

    private func loadImportedProject(
        _ operation: WorkspaceImportedProjectLoadOperation,
        request: WorkspaceProjectLoadRequest
    ) -> Result<WorkspaceProjectLoadResult<LoadedProject>, WorkspaceProjectLoadFailure> {
        switch documentImport.stageImportedDocument(.init(sourceURL: operation.sourceURL)) {
        case let .failure(error):
            return .failure(
                WorkspaceProjectLoadFailure(
                    request: request,
                    reason: .importFailed(error.errorDescription)
                )
            )
        case let .success(staged):
            do {
                let loaded = try projectLoader.loadProject(staged.stagedProjectURL.fileURL)
                let issues = cleanupService.discardImportedStaging(staged.stagedProjectURL)
                return .success(.imported(loaded, staged.suggestedTitle, issues))
            } catch {
                _ = cleanupService.discardImportedStaging(staged.stagedProjectURL)
                return .failure(
                    WorkspaceProjectLoadFailure(
                        request: request,
                        reason: .openFailed(optionalErrorMessage(error))
                    )
                )
            }
        }
    }
}

public struct WorkspaceProjectLoadCommand: Equatable, Sendable {
    public let loadRequest: WorkspaceProjectLoadRequest
    public let prepareDocumentReplacementRequest: WorkspaceDocumentReplacementRequest?

    public init(
        loadRequest: WorkspaceProjectLoadRequest,
        prepareDocumentReplacementRequest: WorkspaceDocumentReplacementRequest?
    ) {
        self.loadRequest = loadRequest
        self.prepareDocumentReplacementRequest = prepareDocumentReplacementRequest
    }
}

public struct WorkspaceProjectLoadingService<LoadedProject>: Sendable where LoadedProject: Equatable {
    public let preparationUseCase: WorkspaceProjectPreparationUseCase
    public let loadUseCase: WorkspaceProjectLoadUseCase<LoadedProject>

    public init(
        preparationUseCase: WorkspaceProjectPreparationUseCase,
        loadUseCase: WorkspaceProjectLoadUseCase<LoadedProject>
    ) {
        self.preparationUseCase = preparationUseCase
        self.loadUseCase = loadUseCase
    }

    public func execute(
        _ command: WorkspaceProjectLoadCommand
    ) -> Result<WorkspaceProjectLoadResult<LoadedProject>, WorkspaceProjectLoadFailure> {
        if let prepareRequest = command.prepareDocumentReplacementRequest {
            switch preparationUseCase.execute(prepareRequest) {
            case .success:
                break
            case let .failure(failure):
                return .failure(
                    WorkspaceProjectLoadFailure(
                        request: command.loadRequest,
                        reason: .prepareDocumentReplacementFailed(failure.reason)
                    )
                )
            }
        }
        return loadUseCase.execute(command.loadRequest)
    }
}
