import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceDomain

public typealias WorkspacePersistenceIssue = PrimoWorkspaceDomain.WorkspacePersistenceIssue
public typealias WorkspacePersistenceFailureReason = PrimoWorkspaceDomain.WorkspacePersistenceFailureReason
public typealias WorkspacePersistenceFailure = PrimoWorkspaceDomain.WorkspacePersistenceFailure
public typealias WorkspaceDirtyPresentationRequest = PrimoWorkspaceDomain.WorkspaceDirtyPresentationRequest
public typealias WorkspaceDocumentSavePurpose = PrimoWorkspaceDomain.WorkspaceDocumentSavePurpose
public typealias WorkspaceDocumentSaveRequest = PrimoWorkspaceDomain.WorkspaceDocumentSaveRequest
public typealias WorkspaceDocumentSaveResult = PrimoWorkspaceDomain.WorkspaceDocumentSaveResult
public typealias WorkspaceDocumentReplacementRequest = PrimoWorkspaceDomain.WorkspaceDocumentReplacementRequest
public typealias LoadedWorkspaceFollowUpPersistenceRequest = PrimoWorkspaceDomain.LoadedWorkspaceFollowUpPersistenceRequest
public typealias LoadedWorkspaceFollowUpPersistenceResult = PrimoWorkspaceDomain.LoadedWorkspaceFollowUpPersistenceResult
public typealias WorkspaceCloseTabsSaveRequest = PrimoWorkspaceDomain.WorkspaceCloseTabsSaveRequest
public typealias WorkspaceCloseTabsSaveResult = PrimoWorkspaceDomain.WorkspaceCloseTabsSaveResult
public typealias WorkspaceArtifactDiscardRequest = PrimoWorkspaceDomain.WorkspaceArtifactDiscardRequest
public typealias WorkspaceTabReservationRequest = PrimoWorkspaceDomain.WorkspaceTabReservationRequest
public typealias WorkspaceSavedProjectMoveRequest = PrimoWorkspaceDomain.WorkspaceSavedProjectMoveRequest
public typealias WorkspaceSavedProjectMoveResult = PrimoWorkspaceDomain.WorkspaceSavedProjectMoveResult
public typealias WorkspaceAutosaveEntryDiscardRequest = PrimoWorkspaceDomain.WorkspaceAutosaveEntryDiscardRequest
public typealias WorkspaceSaveHistoryLoadRequest = PrimoWorkspaceDomain.WorkspaceSaveHistoryLoadRequest
public typealias WorkspaceCatalogFailureReason = PrimoWorkspaceDomain.WorkspaceCatalogFailureReason
public typealias WorkspaceCatalogFailure = PrimoWorkspaceDomain.WorkspaceCatalogFailure
public typealias WorkspacePersistenceRequest = PrimoWorkspaceDomain.WorkspacePersistenceRequest
public typealias WorkspacePersistenceResult = PrimoWorkspaceDomain.WorkspacePersistenceResult
public typealias WorkspaceCatalogRequest = PrimoWorkspaceDomain.WorkspaceCatalogRequest
public typealias WorkspaceCatalogResult = PrimoWorkspaceDomain.WorkspaceCatalogResult
public typealias LoadedWorkspaceProjectPlan = PrimoWorkspaceDomain.LoadedWorkspaceProjectPlan
public typealias WorkspacePersistenceUseCase = PrimoWorkspaceDomain.WorkspacePersistenceUseCase
public typealias WorkspaceCatalogUseCase = PrimoWorkspaceDomain.WorkspaceCatalogUseCase
public typealias PreparedWorkspaceTab = PrimoWorkspaceDomain.PreparedWorkspaceTab
public typealias WorkspaceProjectLoadIssue = PrimoWorkspaceDomain.WorkspaceProjectLoadIssue
public typealias WorkspaceProjectLoadFailureReason = PrimoWorkspaceDomain.WorkspaceProjectLoadFailureReason
public typealias WorkspaceProjectLoadOperation = PrimoWorkspaceDomain.WorkspaceProjectLoadOperation
public typealias WorkspaceImportedProjectLoadOperation = PrimoWorkspaceDomain.WorkspaceImportedProjectLoadOperation
public typealias WorkspaceProjectLoadRequest = PrimoWorkspaceDomain.WorkspaceProjectLoadRequest
public typealias WorkspaceProjectLoadFailure = PrimoWorkspaceDomain.WorkspaceProjectLoadFailure
public typealias WorkspaceProjectPreparationUseCase = PrimoWorkspaceDomain.WorkspaceProjectPreparationUseCase
public typealias WorkspaceProjectLoadResult<LoadedProject: Equatable> = PrimoWorkspaceDomain.WorkspaceProjectLoadResult<LoadedProject>
public typealias WorkspaceProjectLoadUseCase<LoadedProject: Equatable> = PrimoWorkspaceDomain.WorkspaceProjectLoadUseCase<LoadedProject>
public typealias WorkspaceProjectLoadCommand = PrimoWorkspaceDomain.WorkspaceProjectLoadCommand
public typealias WorkspaceProjectLoadingService<LoadedProject: Equatable> = PrimoWorkspaceDomain.WorkspaceProjectLoadingService<LoadedProject>
public typealias WorkspaceProjectCleanupService = PrimoWorkspaceDomain.WorkspaceProjectCleanupService

public struct WorkspaceBackingStoreService: Sendable {
    public let documentPersistenceGateway: DocumentPersistenceGateway
    public let documentWorkspaceClient: DocumentWorkspaceClient

    public init(
        documentPersistenceGateway: DocumentPersistenceGateway,
        documentWorkspaceClient: DocumentWorkspaceClient
    ) {
        self.documentPersistenceGateway = documentPersistenceGateway
        self.documentWorkspaceClient = documentWorkspaceClient
    }

    public func saveProject(at fileURL: URL, paperStyle: CanvasPaperStyle) throws {
        try documentPersistenceGateway.saveProject(fileURL, paperStyle)
    }

    public func persistProjectSnapshot(
        _ sourceURL: DocumentProjectPath,
        preferredDestinationURL: DocumentProjectPath?
    ) throws -> DocumentProjectPath {
        try documentWorkspaceClient.persistProjectSnapshot(sourceURL, preferredDestinationURL)
    }

    public func createTabBackingStoreURL(_ tabID: OpenDocumentTab.ID) throws -> DocumentProjectPath {
        try documentWorkspaceClient.createTabBackingStoreURL(tabID)
    }

    public func persistAutosaveSnapshot(
        _ backingStoreURL: DocumentProjectPath,
        _ tab: OpenDocumentTab
    ) throws {
        try documentWorkspaceClient.persistAutosaveSnapshot(backingStoreURL, tab)
    }

    public func discardAutosaveSnapshot(_ tab: OpenDocumentTab) throws {
        try documentWorkspaceClient.discardAutosaveSnapshot(tab)
    }

    public func persistSaveHistorySnapshot(
        _ backingStoreURL: DocumentProjectPath,
        _ tab: OpenDocumentTab,
        _ trigger: SaveHistoryTrigger
    ) throws {
        try documentWorkspaceClient.persistSaveHistorySnapshot(backingStoreURL, tab, trigger)
    }

    public func removeWorkspaceItem(_ url: DocumentProjectPath) throws {
        try documentWorkspaceClient.removeWorkspaceItem(url)
    }
}

public struct WorkspaceCatalogService: Sendable {
    public let documentWorkspaceClient: DocumentWorkspaceClient

    public init(documentWorkspaceClient: DocumentWorkspaceClient) {
        self.documentWorkspaceClient = documentWorkspaceClient
    }

    public func loadSavedProjects() throws -> [SavedProjectSummary] {
        try documentWorkspaceClient.loadSavedProjects()
    }

    public func moveSavedProject(
        _ url: DocumentProjectPath,
        to relativeFolderPath: RelativeProjectFolderPath?
    ) throws -> DocumentProjectPath {
        try documentWorkspaceClient.moveSavedProject(url, relativeFolderPath)
    }

    public func loadAutosaveRecoveryItems() throws -> [AutosaveRecoveryItem] {
        try documentWorkspaceClient.loadAutosaveRecoveryItems()
    }

    public func discardAutosaveEntry(_ id: WorkspaceItemID) throws {
        try documentWorkspaceClient.discardAutosaveEntry(id)
    }

    public func loadSaveHistoryEntries(for tab: OpenDocumentTab) throws -> [SaveHistoryEntry] {
        try documentWorkspaceClient.loadSaveHistoryEntries(tab)
    }
}

public struct WorkspaceArtifactService: Sendable {
    public let documentWorkspaceClient: DocumentWorkspaceClient

    public init(documentWorkspaceClient: DocumentWorkspaceClient) {
        self.documentWorkspaceClient = documentWorkspaceClient
    }

    public func timelapseTemporaryDirectory() -> URL {
        documentWorkspaceClient.timelapseTemporaryDirectory()
    }

    public func writePNGToTemporaryDirectory(_ data: Data) throws -> URL {
        try documentWorkspaceClient.writePNGToTemporaryDirectory(data)
    }
}

public struct WorkspaceIdentityService: Sendable {
    public let uuidClient: UUIDClient

    public init(uuidClient: UUIDClient) {
        self.uuidClient = uuidClient
    }

    public func generateTabID() -> OpenDocumentTab.ID {
        uuidClient.generate()
    }
}

public struct WorkspaceFeatureSupport: Sendable {
    public let backingStoreService: WorkspaceBackingStoreService
    public let catalogService: WorkspaceCatalogService
    public let artifactService: WorkspaceArtifactService
    public let identityService: WorkspaceIdentityService

    public init(
        documentPersistenceGateway: DocumentPersistenceGateway,
        documentWorkspaceClient: DocumentWorkspaceClient,
        uuidClient: UUIDClient
    ) {
        self.backingStoreService = WorkspaceBackingStoreService(
            documentPersistenceGateway: documentPersistenceGateway,
            documentWorkspaceClient: documentWorkspaceClient
        )
        self.catalogService = WorkspaceCatalogService(
            documentWorkspaceClient: documentWorkspaceClient
        )
        self.artifactService = WorkspaceArtifactService(
            documentWorkspaceClient: documentWorkspaceClient
        )
        self.identityService = WorkspaceIdentityService(
            uuidClient: uuidClient
        )
    }

    public var backingStoreGateway: WorkspaceBackingStoreGateway {
        WorkspaceBackingStoreGateway(
            saveProject: { fileURL, paperStyle in
                try backingStoreService.saveProject(at: fileURL, paperStyle: paperStyle)
            },
            persistProjectSnapshot: { sourceURL, preferredDestinationURL in
                try backingStoreService.persistProjectSnapshot(
                    sourceURL,
                    preferredDestinationURL: preferredDestinationURL
                )
            },
            createTabBackingStoreURL: { tabID in
                try backingStoreService.createTabBackingStoreURL(tabID)
            },
            persistAutosaveSnapshot: { backingStoreURL, tab in
                try backingStoreService.persistAutosaveSnapshot(backingStoreURL, tab)
            },
            discardAutosaveSnapshot: { tab in
                try backingStoreService.discardAutosaveSnapshot(tab)
            },
            persistSaveHistorySnapshot: { backingStoreURL, tab, trigger in
                try backingStoreService.persistSaveHistorySnapshot(backingStoreURL, tab, trigger)
            },
            removeWorkspaceItem: { url in
                try backingStoreService.removeWorkspaceItem(url)
            }
        )
    }

    public var catalogGateway: WorkspaceCatalogGateway {
        WorkspaceCatalogGateway(
            loadSavedProjects: {
                try catalogService.loadSavedProjects()
            },
            moveSavedProject: { sourceURL, relativeFolderPath in
                try catalogService.moveSavedProject(sourceURL, to: relativeFolderPath)
            },
            loadAutosaveRecoveryItems: {
                try catalogService.loadAutosaveRecoveryItems()
            },
            discardAutosaveEntry: { autosaveID in
                try catalogService.discardAutosaveEntry(autosaveID)
            },
            loadSaveHistoryEntries: { activeTab in
                try catalogService.loadSaveHistoryEntries(for: activeTab)
            }
        )
    }

    public var identityGenerator: WorkspaceIdentityGenerator {
        WorkspaceIdentityGenerator(
            generateTabID: {
                identityService.generateTabID()
            }
        )
    }

    public var persistenceUseCase: WorkspacePersistenceUseCase {
        WorkspacePersistenceUseCase(
            workspaceBackingStore: backingStoreGateway,
            workspaceCatalog: catalogGateway,
            identityGenerator: identityGenerator
        )
    }

    public var catalogUseCase: WorkspaceCatalogUseCase {
        WorkspaceCatalogUseCase(workspaceCatalog: catalogGateway)
    }

    public var projectPreparationUseCase: WorkspaceProjectPreparationUseCase {
        WorkspaceProjectPreparationUseCase(
            workspacePersistenceUseCase: persistenceUseCase
        )
    }

    public func projectCleanupService(
        documentImport: DocumentImportGateway
    ) -> WorkspaceProjectCleanupService {
        WorkspaceProjectCleanupService(
            workspaceBackingStore: backingStoreGateway,
            documentImport: documentImport
        )
    }

    public func projectLoadUseCase<LoadedProject>(
        projectLoader: ProjectLoadingGateway<LoadedProject>,
        documentImport: DocumentImportGateway
    ) -> WorkspaceProjectLoadUseCase<LoadedProject> where LoadedProject: Equatable {
        WorkspaceProjectLoadUseCase(
            projectLoader: projectLoader,
            documentImport: documentImport,
            cleanupService: projectCleanupService(documentImport: documentImport)
        )
    }

    public func projectLoadingService<LoadedProject>(
        projectLoader: ProjectLoadingGateway<LoadedProject>,
        documentImport: DocumentImportGateway
    ) -> WorkspaceProjectLoadingService<LoadedProject> where LoadedProject: Equatable {
        WorkspaceProjectLoadingService(
            preparationUseCase: projectPreparationUseCase,
            loadUseCase: projectLoadUseCase(
                projectLoader: projectLoader,
                documentImport: documentImport
            )
        )
    }
}
