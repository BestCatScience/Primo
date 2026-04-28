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

public struct MetalBufferHandle: Equatable, Hashable, Sendable {
    public let id: UUID
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int

    public init(
        id: UUID = UUID(),
        width: Int,
        height: Int,
        bytesPerRow: Int
    ) {
        self.id = id
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
    }
}

public struct MetalLayerSnapshot: Identifiable, Equatable, Sendable {
    public var id: Int { index }
    public let index: Int
    public let opacity: Float
    public let visible: Bool
    public let isClipped: Bool
    public let blendMode: LayerBlendMode
    public let thumbnailSurface: DocumentCompositeSurface?
    /// Legacy thumbnail bytes retained for fallback UI and persisted snapshots.
    public let thumbnailData: Data?
    public let gpuBufferHandle: MetalBufferHandle?
    public let pixelData: Data

    public init(
        index: Int,
        opacity: Float,
        visible: Bool,
        isClipped: Bool,
        blendMode: LayerBlendMode,
        thumbnailSurface: DocumentCompositeSurface? = nil,
        thumbnailData: Data?,
        gpuBufferHandle: MetalBufferHandle? = nil,
        pixelData: Data
    ) {
        self.index = index
        self.opacity = opacity
        self.visible = visible
        self.isClipped = isClipped
        self.blendMode = blendMode
        self.thumbnailSurface = thumbnailSurface
        self.thumbnailData = thumbnailData
        self.gpuBufferHandle = gpuBufferHandle
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
    public let compositeBufferHandle: MetalBufferHandle?
    public let compositePixelData: Data
    public let layers: [MetalLayerSnapshot]

    public init(
        width: Int,
        height: Int,
        revision: Int,
        transferKind: MetalSnapshotTransferKind = .fullSnapshot,
        compositeBufferHandle: MetalBufferHandle? = nil,
        compositePixelData: Data,
        layers: [MetalLayerSnapshot]
    ) {
        self.width = width
        self.height = height
        self.revision = revision
        self.transferKind = transferKind
        self.compositeBufferHandle = compositeBufferHandle
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
    public let gpuBufferHandle: MetalBufferHandle?
    public let pixelData: Data

    public init(
        id: UUID = UUID(),
        layerIndex: Int,
        originX: Int,
        originY: Int,
        width: Int,
        height: Int,
        transferKind: MetalSnapshotTransferKind = .dirtyRect,
        gpuBufferHandle: MetalBufferHandle? = nil,
        pixelData: Data
    ) {
        self.id = id
        self.layerIndex = layerIndex
        self.originX = originX
        self.originY = originY
        self.width = width
        self.height = height
        self.transferKind = transferKind
        self.gpuBufferHandle = gpuBufferHandle
        self.pixelData = pixelData
    }

    public var isEmpty: Bool { width <= 0 || height <= 0 || (pixelData.isEmpty && gpuBufferHandle == nil) }
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

public typealias DocumentCompositeSurface = PrimoDocumentDomain.DocumentCompositeSurface

public struct CanvasSelection: Equatable, Sendable {
    public let bounds: CGRect
    public let maskWidth: Int
    public let maskHeight: Int
    public let maskData: Data
    public let mode: SelectionToolMode

    public init(bounds: CGRect, maskWidth: Int, maskHeight: Int, maskData: Data, mode: SelectionToolMode) {
        self.bounds = bounds
        self.maskWidth = maskWidth
        self.maskHeight = maskHeight
        self.maskData = maskData
        self.mode = mode
    }

    public var isEmpty: Bool {
        maskWidth <= 0 || maskHeight <= 0 || maskData.isEmpty || bounds.isNull || bounds.isEmpty
    }
}

public struct LayerPixelRect: Equatable, Sendable {
    public let originX: Int
    public let originY: Int
    public let width: Int
    public let height: Int

    public init(originX: Int, originY: Int, width: Int, height: Int) {
        self.originX = originX
        self.originY = originY
        self.width = width
        self.height = height
    }

    public var isEmpty: Bool { width <= 0 || height <= 0 }
}

public struct DocumentLayerMutationPayload: Equatable, Sendable {
    public let canvasWidth: Int
    public let canvasHeight: Int
    public let dirtyRect: LayerPixelRect
    public let gpuBufferHandle: MetalBufferHandle?
    public let rectPixelData: Data
    public let fullPixelData: Data?

    public init(
        canvasWidth: Int,
        canvasHeight: Int,
        dirtyRect: LayerPixelRect,
        gpuBufferHandle: MetalBufferHandle? = nil,
        rectPixelData: Data = Data(),
        fullPixelData: Data? = nil
    ) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.dirtyRect = dirtyRect
        self.gpuBufferHandle = gpuBufferHandle
        self.rectPixelData = rectPixelData
        self.fullPixelData = fullPixelData
    }
}

public struct GpuLayerMutationPayload: Equatable, Sendable {
    public let canvasWidth: Int
    public let canvasHeight: Int
    public let dirtyRect: LayerPixelRect
    public let gpuBufferHandle: MetalBufferHandle
    public let fallbackPixelData: Data?

    public init(
        canvasWidth: Int,
        canvasHeight: Int,
        dirtyRect: LayerPixelRect,
        gpuBufferHandle: MetalBufferHandle,
        fallbackPixelData: Data? = nil
    ) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.dirtyRect = dirtyRect
        self.gpuBufferHandle = gpuBufferHandle
        self.fallbackPixelData = fallbackPixelData
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

public struct TransformQuad: Equatable, Sendable {
    public var topLeft: CGPoint
    public var topRight: CGPoint
    public var bottomLeft: CGPoint
    public var bottomRight: CGPoint

    public init(
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    public var points: [CGPoint] {
        [topLeft, topRight, bottomLeft, bottomRight]
    }

    public static func lerp(_ start: CGPoint, _ end: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + ((end.x - start.x) * t),
            y: start.y + ((end.y - start.y) * t)
        )
    }

    public var bounds: CGRect {
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

    public var center: CGPoint {
        CGPoint(
            x: (topLeft.x + topRight.x + bottomLeft.x + bottomRight.x) / 4.0,
            y: (topLeft.y + topRight.y + bottomLeft.y + bottomRight.y) / 4.0
        )
    }

    public var topMidpoint: CGPoint { Self.lerp(topLeft, topRight, t: 0.5) }
    public var leftMidpoint: CGPoint { Self.lerp(topLeft, bottomLeft, t: 0.5) }
    public var rightMidpoint: CGPoint { Self.lerp(topRight, bottomRight, t: 0.5) }
    public var bottomMidpoint: CGPoint { Self.lerp(bottomLeft, bottomRight, t: 0.5) }
}

public struct TransformQuadOffsets: Equatable, Sendable {
    public var topLeft: CGSize = .zero
    public var topRight: CGSize = .zero
    public var bottomLeft: CGSize = .zero
    public var bottomRight: CGSize = .zero

    public init(
        topLeft: CGSize = .zero,
        topRight: CGSize = .zero,
        bottomLeft: CGSize = .zero,
        bottomRight: CGSize = .zero
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    public static let zero = TransformQuadOffsets()

    public var isZero: Bool {
        topLeft == .zero && topRight == .zero && bottomLeft == .zero && bottomRight == .zero
    }

    public func applying(to quad: TransformQuad) -> TransformQuad {
        TransformQuad(
            topLeft: CGPoint(x: quad.topLeft.x + topLeft.width, y: quad.topLeft.y + topLeft.height),
            topRight: CGPoint(x: quad.topRight.x + topRight.width, y: quad.topRight.y + topRight.height),
            bottomLeft: CGPoint(x: quad.bottomLeft.x + bottomLeft.width, y: quad.bottomLeft.y + bottomLeft.height),
            bottomRight: CGPoint(x: quad.bottomRight.x + bottomRight.width, y: quad.bottomRight.y + bottomRight.height)
        )
    }
}
