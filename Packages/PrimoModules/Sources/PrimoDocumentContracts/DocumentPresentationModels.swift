import CoreGraphics
import Foundation
import PrimoDocumentDomain

public struct LayerRowModel: Identifiable, Equatable, Sendable {
    public var id: Int { index }
    public let index: Int
    public let name: String
    public let visible: Bool
    public let opacity: Double
    public let isLocked: Bool
    public let isAlphaLocked: Bool
    public let isClipped: Bool
    public let blendMode: LayerBlendMode
    public let folderID: Int?
    public let hasMask: Bool
    public let isTextLayer: Bool
    public let textLayer: TextLayerData?

    public init(
        index: Int,
        name: String,
        visible: Bool,
        opacity: Double,
        isLocked: Bool,
        isAlphaLocked: Bool,
        isClipped: Bool,
        blendMode: LayerBlendMode,
        folderID: Int?,
        hasMask: Bool,
        isTextLayer: Bool,
        textLayer: TextLayerData?
    ) {
        self.index = index
        self.name = name
        self.visible = visible
        self.opacity = opacity
        self.isLocked = isLocked
        self.isAlphaLocked = isAlphaLocked
        self.isClipped = isClipped
        self.blendMode = blendMode
        self.folderID = folderID
        self.hasMask = hasMask
        self.isTextLayer = isTextLayer
        self.textLayer = textLayer
    }
}

public struct LayerFolderModel: Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let visible: Bool
    public let isExpanded: Bool
    public let anchorLayerIndex: Int?
    public let childLayerIndices: [Int]

    public init(
        id: Int,
        name: String,
        visible: Bool,
        isExpanded: Bool,
        anchorLayerIndex: Int?,
        childLayerIndices: [Int]
    ) {
        self.id = id
        self.name = name
        self.visible = visible
        self.isExpanded = isExpanded
        self.anchorLayerIndex = anchorLayerIndex
        self.childLayerIndices = childLayerIndices
    }
}

public enum LayerSidebarRowModel: Identifiable, Equatable, Sendable {
    case folder(LayerFolderModel)
    case layer(LayerRowModel, depth: Int)

    public var id: String {
        switch self {
        case let .folder(folder):
            return "folder-\(folder.id)"
        case let .layer(layer, _):
            return "layer-\(layer.index)"
        }
    }
}

public struct StylusSample: Equatable, Sendable {
    public let point: CGPoint
    public let pressure: CGFloat
    public let altitude: CGFloat
    public let azimuth: CGFloat
    public let timestamp: TimeInterval

    public init(
        point: CGPoint,
        pressure: CGFloat,
        altitude: CGFloat,
        azimuth: CGFloat,
        timestamp: TimeInterval
    ) {
        self.point = point
        self.pressure = pressure
        self.altitude = altitude
        self.azimuth = azimuth
        self.timestamp = timestamp
    }
}

public struct MetalLayerSnapshot: Identifiable, Equatable, Sendable {
    public var id: Int { index }
    public let index: Int
    public let opacity: Float
    public let visible: Bool
    public let isClipped: Bool
    public let blendMode: LayerBlendMode
    public let thumbnailData: Data?
    public let pixelData: Data

    public init(
        index: Int,
        opacity: Float,
        visible: Bool,
        isClipped: Bool,
        blendMode: LayerBlendMode,
        thumbnailData: Data?,
        pixelData: Data
    ) {
        self.index = index
        self.opacity = opacity
        self.visible = visible
        self.isClipped = isClipped
        self.blendMode = blendMode
        self.thumbnailData = thumbnailData
        self.pixelData = pixelData
    }
}

public enum MetalSnapshotTransferKind: String, Equatable, Sendable {
    case fullSnapshot
    case dirtyRect
}

public struct MetalDocumentSnapshot: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let revision: Int
    public let transferKind: MetalSnapshotTransferKind
    public let compositePixelData: Data
    public let layers: [MetalLayerSnapshot]

    public init(
        width: Int,
        height: Int,
        revision: Int,
        transferKind: MetalSnapshotTransferKind = .fullSnapshot,
        compositePixelData: Data,
        layers: [MetalLayerSnapshot]
    ) {
        self.width = width
        self.height = height
        self.revision = revision
        self.transferKind = transferKind
        self.compositePixelData = compositePixelData
        self.layers = layers
    }
}

public struct IncrementalLayerUpdate: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let layerIndex: Int
    public let originX: Int
    public let originY: Int
    public let width: Int
    public let height: Int
    public let transferKind: MetalSnapshotTransferKind
    public let pixelData: Data

    public init(
        id: UUID = UUID(),
        layerIndex: Int,
        originX: Int,
        originY: Int,
        width: Int,
        height: Int,
        transferKind: MetalSnapshotTransferKind = .dirtyRect,
        pixelData: Data
    ) {
        self.id = id
        self.layerIndex = layerIndex
        self.originX = originX
        self.originY = originY
        self.width = width
        self.height = height
        self.transferKind = transferKind
        self.pixelData = pixelData
    }

    public var isEmpty: Bool { width <= 0 || height <= 0 || pixelData.isEmpty }
}

public struct PaintDocumentPresentation: Equatable, Sendable {
    public var canvasSize: CGSize
    public var activeLayerIndex: Int
    public var layerRows: [LayerRowModel]
    public var layerSidebarRows: [LayerSidebarRowModel]
    public var renderSnapshot: MetalDocumentSnapshot?

    public init(
        canvasSize: CGSize,
        activeLayerIndex: Int,
        layerRows: [LayerRowModel],
        layerSidebarRows: [LayerSidebarRowModel],
        renderSnapshot: MetalDocumentSnapshot?
    ) {
        self.canvasSize = canvasSize
        self.activeLayerIndex = activeLayerIndex
        self.layerRows = layerRows
        self.layerSidebarRows = layerSidebarRows
        self.renderSnapshot = renderSnapshot
    }
}

public struct LoadedPaintProject: Equatable, Sendable {
    public var presentation: PaintDocumentPresentation
    public var paperStyle: CanvasPaperStyle

    public init(
        presentation: PaintDocumentPresentation,
        paperStyle: CanvasPaperStyle
    ) {
        self.presentation = presentation
        self.paperStyle = paperStyle
    }
}
