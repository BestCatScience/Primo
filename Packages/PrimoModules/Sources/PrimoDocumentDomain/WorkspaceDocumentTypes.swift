import CoreGraphics
import Foundation

public struct DocumentCompositeSurface: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixelData: Data

    public init(width: Int, height: Int, pixelData: Data) {
        self.width = width
        self.height = height
        self.pixelData = pixelData
    }
}

public struct CanvasPaperStyle: Equatable, Sendable {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float
    public var isTransparent: Bool

    public init(
        red: Float,
        green: Float,
        blue: Float,
        alpha: Float,
        isTransparent: Bool
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.isTransparent = isTransparent
    }

    public static let `default` = CanvasPaperStyle(
        red: 1.0,
        green: 1.0,
        blue: 1.0,
        alpha: 1.0,
        isTransparent: false
    )
}

public struct DocumentProjectPath: Hashable, Codable, Sendable, Identifiable {
    public let fileURL: URL

    public init(_ fileURL: URL) {
        self.fileURL = fileURL.standardizedFileURL
    }

    public var id: URL { fileURL }
    public var displayName: String { fileURL.deletingPathExtension().lastPathComponent }
    public var path: String { fileURL.path }
}

public struct WorkspaceItemID: Hashable, Codable, Sendable, Identifiable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else {
            throw DocumentWorkspaceError.invalidIdentifier(rawValue)
        }
        guard normalized.unicodeScalars.allSatisfy(WorkspaceItemID.isAllowedScalar(_:)) else {
            throw DocumentWorkspaceError.invalidIdentifier(rawValue)
        }
        self.rawValue = normalized
    }

    public init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    public var id: String { rawValue }

    private static func isAllowedScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 45, 48...57, 97...122:
            return true
        default:
            return false
        }
    }
}

public struct RelativeProjectFolderPath: Hashable, Codable, Sendable {
    public let components: [String]

    public init(components: [String]) {
        self.components = components
    }

    public init(validating rawValue: String?) throws {
        let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            self.components = []
            return
        }
        guard !trimmed.hasPrefix("/") else {
            throw DocumentWorkspaceError.invalidRelativeFolderPath(trimmed)
        }

        let components = trimmed
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard !components.isEmpty else {
            throw DocumentWorkspaceError.invalidRelativeFolderPath(trimmed)
        }
        guard components.allSatisfy({ $0 != "." && $0 != ".." }) else {
            throw DocumentWorkspaceError.invalidRelativeFolderPath(trimmed)
        }
        self.components = components
    }

    public var rawValue: String {
        components.joined(separator: "/")
    }

    public func appending(to rootDirectory: URL) -> URL {
        components.reduce(rootDirectory) { partialResult, component in
            partialResult.appendingPathComponent(component, isDirectory: true)
        }
    }
}

public enum DocumentWorkspaceError: LocalizedError {
    case invalidIdentifier(String)
    case invalidRelativeFolderPath(String)
    case invalidLayerIndex(Int)
    case invalidFolderID(Int)
    case missingProjectDirectory(String, URL)
    case invalidProjectDirectory(String, URL)
    case destinationAlreadyExists(URL)

    public var errorDescription: String? {
        switch self {
        case let .invalidIdentifier(value):
            return "Invalid workspace identifier: \(value)"
        case let .invalidRelativeFolderPath(value):
            return "Invalid destination folder path: \(value)"
        case let .invalidLayerIndex(value):
            return "Invalid layer index: \(value)"
        case let .invalidFolderID(value):
            return "Invalid folder ID: \(value)"
        case let .missingProjectDirectory(label, url):
            return "Missing \(label) at \(url.lastPathComponent)"
        case let .invalidProjectDirectory(label, url):
            return "Invalid \(label) at \(url.lastPathComponent)"
        case let .destinationAlreadyExists(url):
            return "A project already exists at \(url.lastPathComponent)"
        }
    }
}

public struct SavedProjectSummary: Equatable, Sendable, Identifiable {
    public let url: DocumentProjectPath
    public let name: String
    public let relativeFolderPath: RelativeProjectFolderPath?
    public let modifiedAt: Date
    public let canvasSize: CGSize
    public let layerCount: Int
    public let previewSurface: DocumentCompositeSurface?
    /// Legacy preview bytes retained for migration and fallback UI.
    public let previewImageData: Data?

    public init(
        url: DocumentProjectPath,
        name: String,
        relativeFolderPath: RelativeProjectFolderPath?,
        modifiedAt: Date,
        canvasSize: CGSize,
        layerCount: Int,
        previewSurface: DocumentCompositeSurface? = nil,
        previewImageData: Data?
    ) {
        self.url = url
        self.name = name
        self.relativeFolderPath = relativeFolderPath
        self.modifiedAt = modifiedAt
        self.canvasSize = canvasSize
        self.layerCount = layerCount
        self.previewSurface = previewSurface
        self.previewImageData = previewImageData
    }

    public var id: DocumentProjectPath { url }
}

public enum WorkspacePane: String, CaseIterable, Equatable, Sendable {
    case primary
    case secondary
}

public struct OpenDocumentTab: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var title: String
    public var backingStoreURL: DocumentProjectPath
    public var sourceProjectURL: DocumentProjectPath?
    public var canvasSize: CGSize
    public var isDirty: Bool
    public var pane: WorkspacePane
    public var previewSurface: DocumentCompositeSurface?
    /// Legacy preview bytes retained for migration and fallback UI.
    public var previewImageData: Data?

    public init(
        id: UUID,
        title: String,
        backingStoreURL: DocumentProjectPath,
        sourceProjectURL: DocumentProjectPath?,
        canvasSize: CGSize,
        isDirty: Bool,
        pane: WorkspacePane,
        previewSurface: DocumentCompositeSurface? = nil,
        previewImageData: Data?
    ) {
        self.id = id
        self.title = title
        self.backingStoreURL = backingStoreURL
        self.sourceProjectURL = sourceProjectURL
        self.canvasSize = canvasSize
        self.isDirty = isDirty
        self.pane = pane
        self.previewSurface = previewSurface
        self.previewImageData = previewImageData
    }
}

public struct AutosaveRecoveryItem: Equatable, Sendable, Identifiable {
    public let id: WorkspaceItemID
    public let title: String
    public let sourceProjectURL: DocumentProjectPath?
    public let autosaveProjectURL: DocumentProjectPath
    public let updatedAt: Date
    public let previewSurface: DocumentCompositeSurface?
    /// Legacy preview bytes retained for migration and fallback UI.
    public let previewImageData: Data?

    public init(
        id: WorkspaceItemID,
        title: String,
        sourceProjectURL: DocumentProjectPath?,
        autosaveProjectURL: DocumentProjectPath,
        updatedAt: Date,
        previewSurface: DocumentCompositeSurface? = nil,
        previewImageData: Data?
    ) {
        self.id = id
        self.title = title
        self.sourceProjectURL = sourceProjectURL
        self.autosaveProjectURL = autosaveProjectURL
        self.updatedAt = updatedAt
        self.previewSurface = previewSurface
        self.previewImageData = previewImageData
    }
}

public enum SaveHistoryTrigger: String, Codable, Equatable, Sendable {
    case manualSave
    case autoSave
    case closeSave
}

public struct SaveHistoryEntry: Equatable, Sendable, Identifiable {
    public let id: WorkspaceItemID
    public let title: String
    public let projectURL: DocumentProjectPath
    public let createdAt: Date
    public let trigger: SaveHistoryTrigger
    public let previewSurface: DocumentCompositeSurface?
    /// Legacy preview bytes retained for migration and fallback UI.
    public let previewImageData: Data?

    public init(
        id: WorkspaceItemID,
        title: String,
        projectURL: DocumentProjectPath,
        createdAt: Date,
        trigger: SaveHistoryTrigger,
        previewSurface: DocumentCompositeSurface? = nil,
        previewImageData: Data?
    ) {
        self.id = id
        self.title = title
        self.projectURL = projectURL
        self.createdAt = createdAt
        self.trigger = trigger
        self.previewSurface = previewSurface
        self.previewImageData = previewImageData
    }
}
