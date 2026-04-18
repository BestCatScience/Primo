import CoreGraphics
import Foundation
import PrimoDocumentDomain
import PrimoLocalization

typealias CanvasPaperStyle = PrimoDocumentDomain.CanvasPaperStyle
typealias DocumentProjectPath = PrimoDocumentDomain.DocumentProjectPath
typealias WorkspaceItemID = PrimoDocumentDomain.WorkspaceItemID
typealias RelativeProjectFolderPath = PrimoDocumentDomain.RelativeProjectFolderPath
typealias DocumentWorkspaceError = PrimoDocumentDomain.DocumentWorkspaceError
typealias SavedProjectSummary = PrimoDocumentDomain.SavedProjectSummary
typealias WorkspacePane = PrimoDocumentDomain.WorkspacePane
typealias OpenDocumentTab = PrimoDocumentDomain.OpenDocumentTab
typealias AutosaveRecoveryItem = PrimoDocumentDomain.AutosaveRecoveryItem
typealias SaveHistoryTrigger = PrimoDocumentDomain.SaveHistoryTrigger
typealias SaveHistoryEntry = PrimoDocumentDomain.SaveHistoryEntry
typealias TextFontOption = PrimoDocumentDomain.TextFontOption
typealias TextLayerData = PrimoDocumentDomain.TextLayerData
typealias TextLayerDraft = PrimoDocumentDomain.TextLayerDraft

struct DocumentLayerIndex: Hashable, Codable, Sendable, Identifiable, Comparable {
    let rawValue: Int

    init(validating rawValue: Int) throws {
        guard rawValue >= 0 else {
            throw DocumentWorkspaceError.invalidLayerIndex(rawValue)
        }
        self.rawValue = rawValue
    }

    init(unchecked rawValue: Int) {
        self.rawValue = rawValue
    }

    static func unchecked(_ rawValue: Int) -> Self {
        Self(unchecked: rawValue)
    }

    var id: Int { rawValue }

    static func < (lhs: DocumentLayerIndex, rhs: DocumentLayerIndex) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        do {
            try self.init(validating: rawValue)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid layer index: \(rawValue)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct DocumentFolderID: Hashable, Codable, Sendable, Identifiable, Comparable {
    let rawValue: Int

    init(validating rawValue: Int) throws {
        guard rawValue >= 0 else {
            throw DocumentWorkspaceError.invalidFolderID(rawValue)
        }
        self.rawValue = rawValue
    }

    init(unchecked rawValue: Int) {
        self.rawValue = rawValue
    }

    static func unchecked(_ rawValue: Int) -> Self {
        Self(unchecked: rawValue)
    }

    var id: Int { rawValue }

    static func < (lhs: DocumentFolderID, rhs: DocumentFolderID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        do {
            try self.init(validating: rawValue)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid folder ID: \(rawValue)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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

enum WorkspaceLayoutMode: Equatable, Sendable {
    case single
    case split
}

extension SaveHistoryTrigger {
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
