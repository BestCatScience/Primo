import Foundation
import PrimoDocumentDomain

public struct ImportedDocumentStageRequest: Equatable, Sendable {
    public let sourceURL: URL

    public init(sourceURL: URL) {
        self.sourceURL = sourceURL
    }
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
    public var saveProject: @Sendable (URL, CanvasPaperStyle) throws -> Void
    public var persistProjectSnapshot: @Sendable (DocumentProjectPath, DocumentProjectPath?) throws -> DocumentProjectPath
    public var createTabBackingStoreURL: @Sendable (UUID) throws -> DocumentProjectPath
    public var persistAutosaveSnapshot: @Sendable (DocumentProjectPath, OpenDocumentTab) throws -> Void
    public var discardAutosaveSnapshot: @Sendable (OpenDocumentTab) throws -> Void
    public var persistSaveHistorySnapshot: @Sendable (DocumentProjectPath, OpenDocumentTab, SaveHistoryTrigger) throws -> Void
    public var removeWorkspaceItem: @Sendable (DocumentProjectPath) throws -> Void

    public init(
        saveProject: @escaping @Sendable (URL, CanvasPaperStyle) throws -> Void,
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
    public var loadSavedProjects: @Sendable () throws -> [SavedProjectSummary]
    public var moveSavedProject: @Sendable (DocumentProjectPath, RelativeProjectFolderPath?) throws -> DocumentProjectPath
    public var loadAutosaveRecoveryItems: @Sendable () throws -> [AutosaveRecoveryItem]
    public var discardAutosaveEntry: @Sendable (WorkspaceItemID) throws -> Void
    public var loadSaveHistoryEntries: @Sendable (OpenDocumentTab) throws -> [SaveHistoryEntry]

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
    public var generateTabID: @Sendable () -> UUID

    public init(generateTabID: @escaping @Sendable () -> UUID) {
        self.generateTabID = generateTabID
    }
}

public struct DocumentImportGateway: Sendable {
    public var stageImportedDocument: @Sendable (ImportedDocumentStageRequest) -> Result<ImportedDocumentStageResult, ImportedDocumentStageFailure>
    public var discardStagedDocument: @Sendable (DocumentProjectPath) -> Result<Void, ImportedDocumentStageFailure>

    public init(
        stageImportedDocument: @escaping @Sendable (ImportedDocumentStageRequest) -> Result<ImportedDocumentStageResult, ImportedDocumentStageFailure>,
        discardStagedDocument: @escaping @Sendable (DocumentProjectPath) -> Result<Void, ImportedDocumentStageFailure>
    ) {
        self.stageImportedDocument = stageImportedDocument
        self.discardStagedDocument = discardStagedDocument
    }
}

public struct ProjectLoadingGateway<LoadedProject>: Sendable {
    public var loadProject: @Sendable (URL) throws -> LoadedProject

    public init(
        loadProject: @escaping @Sendable (URL) throws -> LoadedProject
    ) {
        self.loadProject = loadProject
    }
}
