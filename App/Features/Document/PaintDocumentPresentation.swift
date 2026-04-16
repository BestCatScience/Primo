import CoreGraphics
import Foundation

struct SavedProjectSummary: Equatable, Sendable, Identifiable {
    let url: URL
    let name: String
    let relativeFolderPath: String?
    let modifiedAt: Date
    let canvasSize: CGSize
    let layerCount: Int
    let previewImageData: Data?

    var id: URL { url }
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
    var backingStoreURL: URL
    var sourceProjectURL: URL?
    var canvasSize: CGSize
    var isDirty: Bool
    var pane: WorkspacePane
    var previewImageData: Data?
}

struct AutosaveRecoveryItem: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let sourceProjectURL: URL?
    let autosaveProjectURL: URL
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
    let id: String
    let title: String
    let projectURL: URL
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
