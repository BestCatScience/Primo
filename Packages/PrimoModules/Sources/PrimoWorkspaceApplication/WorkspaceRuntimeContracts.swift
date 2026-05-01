import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts

public enum DocumentWorkspaceCatalogError: LocalizedError, Equatable, OperationFailure {
    case projectLoadFailed(String)
    case metadataReadFailed(String)
    case metadataDecodeFailed(String)
    case resourceLookupFailed(String)
    case invalidRelativeFolderPath(String)
    case invalidWorkspaceEntry(String)

    public var errorDescription: String? {
        switch self {
        case let .projectLoadFailed(message),
             let .metadataReadFailed(message),
             let .metadataDecodeFailed(message),
             let .resourceLookupFailed(message),
             let .invalidRelativeFolderPath(message),
             let .invalidWorkspaceEntry(message):
            return message
        }
    }
}

public struct DocumentWorkspacePreview: Equatable, Sendable {
    public let canvasSize: CGSize
    public let layerCount: Int
    public let previewSurface: DocumentCompositeSurface?
    public let previewImageData: Data?

    public init(
        canvasSize: CGSize,
        layerCount: Int,
        previewSurface: DocumentCompositeSurface? = nil,
        previewImageData: Data?
    ) {
        self.canvasSize = canvasSize
        self.layerCount = layerCount
        self.previewSurface = previewSurface
        self.previewImageData = previewImageData
    }
}

public struct DocumentWorkspacePreviewGateway: Sendable {
    public let loadProjectPreview: @Sendable (URL) throws -> DocumentWorkspacePreview

    public init(
        loadProjectPreview: @escaping @Sendable (URL) throws -> DocumentWorkspacePreview
    ) {
        self.loadProjectPreview = loadProjectPreview
    }
}

public struct DocumentWorkspaceClient: Sendable {
    public let createTabBackingStoreURL: @Sendable (UUID) throws -> DocumentProjectPath
    public let createProjectURL: @Sendable () throws -> DocumentProjectPath
    public let writePNGToTemporaryDirectory: @Sendable (Data) throws -> URL
    public let timelapseTemporaryDirectory: @Sendable () -> URL
    public let loadSavedProjects: @Sendable () throws -> [SavedProjectSummary]
    public let moveSavedProject: @Sendable (DocumentProjectPath, RelativeProjectFolderPath?) throws -> DocumentProjectPath
    public let loadAutosaveRecoveryItems: @Sendable () throws -> [AutosaveRecoveryItem]
    public let discardAutosaveEntry: @Sendable (WorkspaceItemID) throws -> Void
    public let discardAutosaveSnapshot: @Sendable (OpenDocumentTab) throws -> Void
    public let persistAutosaveSnapshot: @Sendable (DocumentProjectPath, OpenDocumentTab) throws -> Void
    public let persistProjectSnapshot: @Sendable (DocumentProjectPath, DocumentProjectPath?) throws -> DocumentProjectPath
    public let loadSaveHistoryEntries: @Sendable (OpenDocumentTab) throws -> [SaveHistoryEntry]
    public let persistSaveHistorySnapshot: @Sendable (DocumentProjectPath, OpenDocumentTab, SaveHistoryTrigger) throws -> Void
    public let removeWorkspaceItem: @Sendable (DocumentProjectPath) throws -> Void

    public init(
        createTabBackingStoreURL: @escaping @Sendable (UUID) throws -> DocumentProjectPath,
        createProjectURL: @escaping @Sendable () throws -> DocumentProjectPath,
        writePNGToTemporaryDirectory: @escaping @Sendable (Data) throws -> URL,
        timelapseTemporaryDirectory: @escaping @Sendable () -> URL,
        loadSavedProjects: @escaping @Sendable () throws -> [SavedProjectSummary],
        moveSavedProject: @escaping @Sendable (DocumentProjectPath, RelativeProjectFolderPath?) throws -> DocumentProjectPath,
        loadAutosaveRecoveryItems: @escaping @Sendable () throws -> [AutosaveRecoveryItem],
        discardAutosaveEntry: @escaping @Sendable (WorkspaceItemID) throws -> Void,
        discardAutosaveSnapshot: @escaping @Sendable (OpenDocumentTab) throws -> Void,
        persistAutosaveSnapshot: @escaping @Sendable (DocumentProjectPath, OpenDocumentTab) throws -> Void,
        persistProjectSnapshot: @escaping @Sendable (DocumentProjectPath, DocumentProjectPath?) throws -> DocumentProjectPath,
        loadSaveHistoryEntries: @escaping @Sendable (OpenDocumentTab) throws -> [SaveHistoryEntry],
        persistSaveHistorySnapshot: @escaping @Sendable (DocumentProjectPath, OpenDocumentTab, SaveHistoryTrigger) throws -> Void,
        removeWorkspaceItem: @escaping @Sendable (DocumentProjectPath) throws -> Void
    ) {
        self.createTabBackingStoreURL = createTabBackingStoreURL
        self.createProjectURL = createProjectURL
        self.writePNGToTemporaryDirectory = writePNGToTemporaryDirectory
        self.timelapseTemporaryDirectory = timelapseTemporaryDirectory
        self.loadSavedProjects = loadSavedProjects
        self.moveSavedProject = moveSavedProject
        self.loadAutosaveRecoveryItems = loadAutosaveRecoveryItems
        self.discardAutosaveEntry = discardAutosaveEntry
        self.discardAutosaveSnapshot = discardAutosaveSnapshot
        self.persistAutosaveSnapshot = persistAutosaveSnapshot
        self.persistProjectSnapshot = persistProjectSnapshot
        self.loadSaveHistoryEntries = loadSaveHistoryEntries
        self.persistSaveHistorySnapshot = persistSaveHistorySnapshot
        self.removeWorkspaceItem = removeWorkspaceItem
    }
}

public typealias ImportedDocumentStageRequest = PrimoDocumentContracts.ImportedDocumentStageRequest
public typealias ImportedDocumentStageResult = PrimoDocumentContracts.ImportedDocumentStageResult
public typealias ImportedDocumentStageFailure = PrimoDocumentContracts.ImportedDocumentStageFailure

public struct DocumentImportClient: Sendable {
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
