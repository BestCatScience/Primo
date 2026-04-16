import CoreGraphics
import Foundation

struct DocumentProjectPath: Hashable, Codable, Sendable, Identifiable {
    let fileURL: URL

    init(_ fileURL: URL) {
        self.fileURL = fileURL.standardizedFileURL
    }

    var id: URL { fileURL }
    var displayName: String { fileURL.deletingPathExtension().lastPathComponent }
    var path: String { fileURL.path }
}

struct WorkspaceItemID: Hashable, Codable, Sendable, Identifiable {
    let rawValue: String

    init(validating rawValue: String) throws {
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

    init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    var id: String { rawValue }

    private static func isAllowedScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 45, 48...57, 97...122:
            return true
        default:
            return false
        }
    }
}

struct RelativeProjectFolderPath: Hashable, Codable, Sendable {
    let components: [String]

    init(components: [String]) {
        self.components = components
    }

    init(validating rawValue: String?) throws {
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

    var rawValue: String {
        components.joined(separator: "/")
    }

    func appending(to rootDirectory: URL) -> URL {
        components.reduce(rootDirectory) { partialResult, component in
            partialResult.appendingPathComponent(component, isDirectory: true)
        }
    }
}

enum DocumentWorkspaceError: LocalizedError {
    case invalidIdentifier(String)
    case invalidRelativeFolderPath(String)
    case missingProjectDirectory(String, URL)
    case invalidProjectDirectory(String, URL)
    case destinationAlreadyExists(URL)

    var errorDescription: String? {
        switch self {
        case let .invalidIdentifier(value):
            return "Invalid workspace identifier: \(value)"
        case let .invalidRelativeFolderPath(value):
            return "Invalid destination folder path: \(value)"
        case let .missingProjectDirectory(label, url):
            return "Missing \(label) at \(url.lastPathComponent)"
        case let .invalidProjectDirectory(label, url):
            return "Invalid \(label) at \(url.lastPathComponent)"
        case let .destinationAlreadyExists(url):
            return "A project already exists at \(url.lastPathComponent)"
        }
    }
}

struct SavedProjectSummary: Equatable, Sendable, Identifiable {
    let url: DocumentProjectPath
    let name: String
    let relativeFolderPath: RelativeProjectFolderPath?
    let modifiedAt: Date
    let canvasSize: CGSize
    let layerCount: Int
    let previewImageData: Data?

    var id: DocumentProjectPath { url }
}

struct PaintDocumentPresentation: Equatable, Sendable {
    var canvasSize: CGSize
    var activeLayerIndex: Int
    var layerRows: [LayerRowModel]
    var layerSidebarRows: [LayerSidebarRowModel]
    var renderSnapshot: MetalDocumentSnapshot?
}

struct LoadedPaintProject: Equatable, Sendable {
    var presentation: PaintDocumentPresentation
    var paperStyle: CanvasPaperStyle
}

enum WorkspacePane: String, CaseIterable, Equatable, Sendable {
    case primary
    case secondary
}

enum WorkspaceLayoutMode: Equatable, Sendable {
    case single
    case split
}

struct OpenDocumentTab: Equatable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var backingStoreURL: DocumentProjectPath
    var sourceProjectURL: DocumentProjectPath?
    var canvasSize: CGSize
    var isDirty: Bool
    var pane: WorkspacePane
    var previewImageData: Data?
}

struct AutosaveRecoveryItem: Equatable, Sendable, Identifiable {
    let id: WorkspaceItemID
    let title: String
    let sourceProjectURL: DocumentProjectPath?
    let autosaveProjectURL: DocumentProjectPath
    let updatedAt: Date
    let previewImageData: Data?
}

enum SaveHistoryTrigger: String, Codable, Equatable, Sendable {
    case manualSave
    case autoSave
    case closeSave

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .manualSave:
            return language.localized("手動保存")
        case .autoSave:
            return language.localized("自動保存")
        case .closeSave:
            return language.localized("閉じる前に保存")
        }
    }
}

struct SaveHistoryEntry: Equatable, Sendable, Identifiable {
    let id: WorkspaceItemID
    let title: String
    let projectURL: DocumentProjectPath
    let createdAt: Date
    let trigger: SaveHistoryTrigger
    let previewImageData: Data?
}

enum ColorRangeSelectionSource: String, CaseIterable, Equatable, Sendable, Identifiable {
    case activeLayer
    case canvas

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .activeLayer:
            return language.localized("アクティブレイヤー")
        case .canvas:
            return language.localized("キャンバス合成")
        }
    }
}

struct ColorRangeSelectionRequest: Equatable, Sendable {
    let source: ColorRangeSelectionSource
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let tolerance: Double
    let minimumAlpha: Double
    let expansion: Int
}

enum CanvasTransformMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case standard
    case freeform

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .standard:
            return language.localized("拡大、縮小、回転")
        case .freeform:
            return language.localized("自由変形")
        }
    }
}

struct TransformQuad: Equatable, Sendable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomLeft: CGPoint
    var bottomRight: CGPoint

    var points: [CGPoint] {
        [topLeft, topRight, bottomLeft, bottomRight]
    }

    static func lerp(_ start: CGPoint, _ end: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + ((end.x - start.x) * t),
            y: start.y + ((end.y - start.y) * t)
        )
    }

    var bounds: CGRect {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard
            let minX = xs.min(),
            let maxX = xs.max(),
            let minY = ys.min(),
            let maxY = ys.max()
        else {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    var center: CGPoint {
        CGPoint(
            x: (topLeft.x + topRight.x + bottomLeft.x + bottomRight.x) / 4.0,
            y: (topLeft.y + topRight.y + bottomLeft.y + bottomRight.y) / 4.0
        )
    }

    var topMidpoint: CGPoint { Self.lerp(topLeft, topRight, t: 0.5) }
    var leftMidpoint: CGPoint { Self.lerp(topLeft, bottomLeft, t: 0.5) }
    var rightMidpoint: CGPoint { Self.lerp(topRight, bottomRight, t: 0.5) }
    var bottomMidpoint: CGPoint { Self.lerp(bottomLeft, bottomRight, t: 0.5) }
}

struct TransformQuadOffsets: Equatable, Sendable {
    var topLeft: CGSize = .zero
    var topRight: CGSize = .zero
    var bottomLeft: CGSize = .zero
    var bottomRight: CGSize = .zero

    static let zero = TransformQuadOffsets()

    var isZero: Bool {
        topLeft == .zero && topRight == .zero && bottomLeft == .zero && bottomRight == .zero
    }

    func applying(to quad: TransformQuad) -> TransformQuad {
        TransformQuad(
            topLeft: CGPoint(x: quad.topLeft.x + topLeft.width, y: quad.topLeft.y + topLeft.height),
            topRight: CGPoint(x: quad.topRight.x + topRight.width, y: quad.topRight.y + topRight.height),
            bottomLeft: CGPoint(x: quad.bottomLeft.x + bottomLeft.width, y: quad.bottomLeft.y + bottomLeft.height),
            bottomRight: CGPoint(x: quad.bottomRight.x + bottomRight.width, y: quad.bottomRight.y + bottomRight.height)
        )
    }
}
