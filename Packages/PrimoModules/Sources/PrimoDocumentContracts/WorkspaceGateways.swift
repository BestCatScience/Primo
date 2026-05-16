import Foundation
import PrimoDocumentDomain

public struct ImportedDocumentStageRequest: Equatable, Sendable {
    public let source: SecurityScopedResourceLease

    public init(source: SecurityScopedResourceLease) {
        self.source = source
    }

    public init(sourceURL: URL) {
        self.init(source: SecurityScopedResourceLease(sourceURL))
    }

    public var sourceURL: URL { source.fileURL }
}

public struct ImportedDocumentStageResult: Equatable, Sendable {
    public let stagedProjectURL: DocumentProjectPath
    public let suggestedTitle: String

    public init(
        stagedProjectURL: DocumentProjectPath,
        suggestedTitle: String
    ) {
        self.stagedProjectURL = stagedProjectURL
        self.suggestedTitle = suggestedTitle
    }
}

public enum ImportedDocumentStageFailure: LocalizedError, Equatable, Sendable {
    case stagingFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .stagingFailed(message):
            return message
        }
    }
}

public struct WorkspaceBackingStoreGateway: Sendable {
    public let saveProject: @Sendable (WritableProjectLocation, CanvasPaperStyle) throws -> Void
    public let persistProjectSnapshot: @Sendable (DocumentProjectPath, DocumentProjectPath?) throws -> DocumentProjectPath
    public let createTabBackingStoreURL: @Sendable (UUID) throws -> DocumentProjectPath
    public let persistAutosaveSnapshot: @Sendable (DocumentProjectPath, OpenDocumentTab) throws -> Void
    public let discardAutosaveSnapshot: @Sendable (OpenDocumentTab) throws -> Void
    public let persistSaveHistorySnapshot: @Sendable (DocumentProjectPath, OpenDocumentTab, SaveHistoryTrigger) throws -> Void
    public let removeWorkspaceItem: @Sendable (DocumentProjectPath) throws -> Void

    public init(
        saveProject: @escaping @Sendable (WritableProjectLocation, CanvasPaperStyle) throws -> Void,
        persistProjectSnapshot: @escaping @Sendable (DocumentProjectPath, DocumentProjectPath?) throws -> DocumentProjectPath,
        createTabBackingStoreURL: @escaping @Sendable (UUID) throws -> DocumentProjectPath,
        persistAutosaveSnapshot: @escaping @Sendable (DocumentProjectPath, OpenDocumentTab) throws -> Void,
        discardAutosaveSnapshot: @escaping @Sendable (OpenDocumentTab) throws -> Void,
        persistSaveHistorySnapshot: @escaping @Sendable (DocumentProjectPath, OpenDocumentTab, SaveHistoryTrigger) throws -> Void,
        removeWorkspaceItem: @escaping @Sendable (DocumentProjectPath) throws -> Void
    ) {
        self.saveProject = saveProject
        self.persistProjectSnapshot = persistProjectSnapshot
        self.createTabBackingStoreURL = createTabBackingStoreURL
        self.persistAutosaveSnapshot = persistAutosaveSnapshot
        self.discardAutosaveSnapshot = discardAutosaveSnapshot
        self.persistSaveHistorySnapshot = persistSaveHistorySnapshot
        self.removeWorkspaceItem = removeWorkspaceItem
    }

}

public struct WorkspaceCatalogGateway: Sendable {
    public let loadSavedProjects: @Sendable () throws -> [SavedProjectSummary]
    public let moveSavedProject: @Sendable (DocumentProjectPath, RelativeProjectFolderPath?) throws -> DocumentProjectPath
    public let loadAutosaveRecoveryItems: @Sendable () throws -> [AutosaveRecoveryItem]
    public let discardAutosaveEntry: @Sendable (WorkspaceItemID) throws -> Void
    public let loadSaveHistoryEntries: @Sendable (OpenDocumentTab) throws -> [SaveHistoryEntry]

    public init(
        loadSavedProjects: @escaping @Sendable () throws -> [SavedProjectSummary],
        moveSavedProject: @escaping @Sendable (DocumentProjectPath, RelativeProjectFolderPath?) throws -> DocumentProjectPath,
        loadAutosaveRecoveryItems: @escaping @Sendable () throws -> [AutosaveRecoveryItem],
        discardAutosaveEntry: @escaping @Sendable (WorkspaceItemID) throws -> Void,
        loadSaveHistoryEntries: @escaping @Sendable (OpenDocumentTab) throws -> [SaveHistoryEntry]
    ) {
        self.loadSavedProjects = loadSavedProjects
        self.moveSavedProject = moveSavedProject
        self.loadAutosaveRecoveryItems = loadAutosaveRecoveryItems
        self.discardAutosaveEntry = discardAutosaveEntry
        self.loadSaveHistoryEntries = loadSaveHistoryEntries
    }
}

public struct WorkspaceIdentityGenerator: Sendable {
    public let generateTabID: @Sendable () -> UUID

    public init(generateTabID: @escaping @Sendable () -> UUID) {
        self.generateTabID = generateTabID
    }
}

public struct DocumentImportGateway: Sendable {
    public let stageImportedDocument: @Sendable (ImportedDocumentStageRequest) -> Result<ImportedDocumentStageResult, ImportedDocumentStageFailure>
    public let discardStagedDocument: @Sendable (DocumentProjectPath) -> Result<Void, ImportedDocumentStageFailure>

    public init(
        stageImportedDocument: @escaping @Sendable (ImportedDocumentStageRequest) -> Result<ImportedDocumentStageResult, ImportedDocumentStageFailure>,
        discardStagedDocument: @escaping @Sendable (DocumentProjectPath) -> Result<Void, ImportedDocumentStageFailure>
    ) {
        self.stageImportedDocument = stageImportedDocument
        self.discardStagedDocument = discardStagedDocument
    }
}

public struct ProjectLoadingGateway<LoadedProject>: Sendable {
    public let loadProject: @Sendable (ProjectPackageURL) throws -> LoadedProject

    public init(
        loadProject: @escaping @Sendable (ProjectPackageURL) throws -> LoadedProject
    ) {
        self.loadProject = loadProject
    }
}
