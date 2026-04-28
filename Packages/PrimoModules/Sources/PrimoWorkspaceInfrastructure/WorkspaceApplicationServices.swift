import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication
import PrimoWorkspaceDomain

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

public struct WorkspaceApplicationServices: Sendable {
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

    public var persistenceUseCase: PrimoWorkspaceApplication.WorkspacePersistenceUseCase {
        PrimoWorkspaceApplication.WorkspacePersistenceUseCase(
            workspaceBackingStore: backingStoreGateway,
            workspaceCatalog: catalogGateway,
            identityGenerator: identityGenerator
        )
    }

    public var catalogUseCase: PrimoWorkspaceApplication.WorkspaceCatalogUseCase {
        PrimoWorkspaceApplication.WorkspaceCatalogUseCase(workspaceCatalog: catalogGateway)
    }

    public var projectPreparationUseCase: PrimoWorkspaceApplication.WorkspaceProjectPreparationUseCase {
        PrimoWorkspaceApplication.WorkspaceProjectPreparationUseCase(
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
    ) -> PrimoWorkspaceApplication.WorkspaceProjectLoadUseCase<LoadedProject> where LoadedProject: Equatable {
        PrimoWorkspaceApplication.WorkspaceProjectLoadUseCase(
            projectLoader: projectLoader,
            documentImport: documentImport,
            cleanupService: projectCleanupService(documentImport: documentImport)
        )
    }

    public func projectLoadingService<LoadedProject>(
        projectLoader: ProjectLoadingGateway<LoadedProject>,
        documentImport: DocumentImportGateway
    ) -> PrimoWorkspaceApplication.WorkspaceProjectLoadingService<LoadedProject> where LoadedProject: Equatable {
        PrimoWorkspaceApplication.WorkspaceProjectLoadingService(
            preparationUseCase: projectPreparationUseCase.base,
            loadUseCase: projectLoadUseCase(
                projectLoader: projectLoader,
                documentImport: documentImport
            ).base
        )
    }
}
