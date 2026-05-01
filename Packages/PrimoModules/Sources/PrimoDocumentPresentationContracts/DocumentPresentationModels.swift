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

    init(
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

    package static func unsafeUnchecked(id: UUID = UUID(), width: Int, height: Int, bytesPerRow: Int) -> Self {
        Self(id: id, width: width, height: height, bytesPerRow: bytesPerRow)
    }

    public init?(validatingWidth width: Int, height: Int, bytesPerRow: Int, id: UUID = UUID()) {
        guard let geometry = PixelGeometry(width: width, height: height) else { return nil }
        guard bytesPerRow >= geometry.width * 4 else { return nil }
        self.id = id
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
    }

    public func isCompatible(with geometry: PixelGeometry) -> Bool {
        width == geometry.width &&
        height == geometry.height &&
        bytesPerRow >= geometry.width * 4
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

    init(
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

    package static func unsafeUnchecked(
        index: Int,
        opacity: Float,
        visible: Bool,
        isClipped: Bool,
        blendMode: LayerBlendMode,
        thumbnailSurface: DocumentCompositeSurface? = nil,
        thumbnailData: Data?,
        gpuBufferHandle: MetalBufferHandle? = nil,
        pixelData: Data
    ) -> Self {
        Self(
            index: index,
            opacity: opacity,
            visible: visible,
            isClipped: isClipped,
            blendMode: blendMode,
            thumbnailSurface: thumbnailSurface,
            thumbnailData: thumbnailData,
            gpuBufferHandle: gpuBufferHandle,
            pixelData: pixelData
        )
    }

    public init?(
        validatingIndex index: Int,
        opacity: Float,
        visible: Bool,
        isClipped: Bool,
        blendMode: LayerBlendMode,
        canvasWidth: Int,
        canvasHeight: Int,
        thumbnailSurface: DocumentCompositeSurface? = nil,
        thumbnailData: Data?,
        gpuBufferHandle: MetalBufferHandle? = nil,
        pixelData: Data
    ) {
        guard let geometry = PixelGeometry(width: canvasWidth, height: canvasHeight) else { return nil }
        if let gpuBufferHandle {
            guard gpuBufferHandle.isCompatible(with: geometry) else { return nil }
        } else {
            guard pixelData.count == geometry.rgbaByteCount else { return nil }
        }
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

    init(
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

    package static func unsafeUnchecked(
        width: Int,
        height: Int,
        revision: Int,
        transferKind: MetalSnapshotTransferKind = .fullSnapshot,
        compositeBufferHandle: MetalBufferHandle? = nil,
        compositePixelData: Data,
        layers: [MetalLayerSnapshot]
    ) -> Self {
        Self(
            width: width,
            height: height,
            revision: revision,
            transferKind: transferKind,
            compositeBufferHandle: compositeBufferHandle,
            compositePixelData: compositePixelData,
            layers: layers
        )
    }

    public init?(
        validatingWidth width: Int,
        height: Int,
        revision: Int,
        transferKind: MetalSnapshotTransferKind = .fullSnapshot,
        compositeBufferHandle: MetalBufferHandle? = nil,
        compositePixelData: Data,
        layers: [MetalLayerSnapshot]
    ) {
        guard let geometry = PixelGeometry(width: width, height: height) else { return nil }
        if let compositeBufferHandle {
            guard compositeBufferHandle.isCompatible(with: geometry) else { return nil }
        } else {
            guard compositePixelData.count == geometry.rgbaByteCount else { return nil }
        }
        guard layers.count <= CanvasSizePolicy.maxLayerCountForCanvas(geometry) else { return nil }
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
    /// Ownership of this handle transfers to the presentation session that consumes the update.
    /// Producers must not release it after publishing the update; consumers release it when replaced,
    /// reset, or deinitialized.
    public let gpuBufferHandle: MetalBufferHandle?
    public let pixelData: Data

    init(
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

    package static func unsafeUnchecked(
        id: UUID = UUID(),
        layerIndex: Int,
        originX: Int,
        originY: Int,
        width: Int,
        height: Int,
        transferKind: MetalSnapshotTransferKind = .dirtyRect,
        gpuBufferHandle: MetalBufferHandle? = nil,
        pixelData: Data
    ) -> Self {
        Self(
            id: id,
            layerIndex: layerIndex,
            originX: originX,
            originY: originY,
            width: width,
            height: height,
            transferKind: transferKind,
            gpuBufferHandle: gpuBufferHandle,
            pixelData: pixelData
        )
    }

    public var isEmpty: Bool { width <= 0 || height <= 0 || (pixelData.isEmpty && gpuBufferHandle == nil) }

    public init?(
        validatingID id: UUID = UUID(),
        layerIndex: Int,
        originX: Int,
        originY: Int,
        width: Int,
        height: Int,
        transferKind: MetalSnapshotTransferKind = .dirtyRect,
        gpuBufferHandle: MetalBufferHandle? = nil,
        pixelData: Data
    ) {
        guard originX >= 0, originY >= 0 else { return nil }
        guard let geometry = PixelGeometry(width: width, height: height) else { return nil }
        if let gpuBufferHandle {
            guard gpuBufferHandle.isCompatible(with: geometry) else { return nil }
        } else {
            guard pixelData.count == geometry.rgbaByteCount else { return nil }
        }
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
}

public struct PaintDocumentPresentation: Equatable, Sendable {
    public var canvasSize: CGSize
    public var activeLayerIndex: Int
    public var layerRows: [LayerRowModel]
    public var layerSidebarRows: [LayerSidebarRowModel]
    public var renderSnapshot: MetalDocumentSnapshot?
    public var revision: DocumentRevision

    public init(
        canvasSize: CGSize,
        activeLayerIndex: Int,
        layerRows: [LayerRowModel],
        layerSidebarRows: [LayerSidebarRowModel],
        renderSnapshot: MetalDocumentSnapshot?
    ) {
        self.init(
            canvasSize: canvasSize,
            activeLayerIndex: activeLayerIndex,
            layerRows: layerRows,
            layerSidebarRows: layerSidebarRows,
            renderSnapshot: renderSnapshot,
            revision: .initial
        )
    }

    public init(
        canvasSize: CGSize,
        activeLayerIndex: Int,
        layerRows: [LayerRowModel],
        layerSidebarRows: [LayerSidebarRowModel],
        renderSnapshot: MetalDocumentSnapshot?,
        revision: DocumentRevision
    ) {
        self.canvasSize = canvasSize
        self.activeLayerIndex = activeLayerIndex
        self.layerRows = layerRows
        self.layerSidebarRows = layerSidebarRows
        self.renderSnapshot = renderSnapshot
        self.revision = revision
    }
}

public typealias DocumentCompositeSurface = PrimoDocumentDomain.DocumentCompositeSurface

public struct CanvasSelection: Equatable, Sendable {
    public let bounds: CGRect
    public let maskWidth: Int
    public let maskHeight: Int
    public let maskData: Data
    public let mode: SelectionToolMode

    init(bounds: CGRect, maskWidth: Int, maskHeight: Int, maskData: Data, mode: SelectionToolMode) {
        self.bounds = bounds
        self.maskWidth = maskWidth
        self.maskHeight = maskHeight
        self.maskData = maskData
        self.mode = mode
    }

    package static func unsafeUnchecked(
        bounds: CGRect,
        maskWidth: Int,
        maskHeight: Int,
        maskData: Data,
        mode: SelectionToolMode
    ) -> Self {
        Self(
            bounds: bounds,
            maskWidth: maskWidth,
            maskHeight: maskHeight,
            maskData: maskData,
            mode: mode
        )
    }

    public init?(validatingBounds bounds: CGRect, maskWidth: Int, maskHeight: Int, maskData: Data, mode: SelectionToolMode) {
        guard let geometry = PixelGeometry(width: maskWidth, height: maskHeight) else { return nil }
        guard maskData.count == geometry.maskByteCount else { return nil }
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

    init(originX: Int, originY: Int, width: Int, height: Int) {
        self.originX = originX
        self.originY = originY
        self.width = width
        self.height = height
    }

    package static func unsafeUnchecked(originX: Int, originY: Int, width: Int, height: Int) -> Self {
        Self(originX: originX, originY: originY, width: width, height: height)
    }

    public init?(validatingOriginX originX: Int, originY: Int, width: Int, height: Int) {
        guard originX >= 0, originY >= 0 else { return nil }
        guard PixelGeometry(width: width, height: height) != nil else { return nil }
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

    init(
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

    package static func unsafeUnchecked(
        canvasWidth: Int,
        canvasHeight: Int,
        dirtyRect: LayerPixelRect,
        gpuBufferHandle: MetalBufferHandle? = nil,
        rectPixelData: Data = Data(),
        fullPixelData: Data? = nil
    ) -> Self {
        Self(
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            dirtyRect: dirtyRect,
            gpuBufferHandle: gpuBufferHandle,
            rectPixelData: rectPixelData,
            fullPixelData: fullPixelData
        )
    }

    public init?(
        validatingCanvasWidth canvasWidth: Int,
        canvasHeight: Int,
        dirtyRect: LayerPixelRect,
        gpuBufferHandle: MetalBufferHandle? = nil,
        rectPixelData: Data = Data(),
        fullPixelData: Data? = nil
    ) {
        guard let canvasGeometry = PixelGeometry(width: canvasWidth, height: canvasHeight) else { return nil }
        guard dirtyRect.originX >= 0, dirtyRect.originY >= 0 else { return nil }
        guard dirtyRect.originX + dirtyRect.width <= canvasWidth,
              dirtyRect.originY + dirtyRect.height <= canvasHeight else { return nil }
        guard let rectGeometry = PixelGeometry(width: dirtyRect.width, height: dirtyRect.height) else { return nil }
        if let gpuBufferHandle {
            guard gpuBufferHandle.isCompatible(with: canvasGeometry) || gpuBufferHandle.isCompatible(with: rectGeometry) else {
                return nil
            }
        } else {
            guard rectPixelData.count == rectGeometry.rgbaByteCount else { return nil }
        }
        if let fullPixelData {
            guard fullPixelData.count == canvasGeometry.rgbaByteCount else { return nil }
        }
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

    init(
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

    package static func unsafeUnchecked(
        canvasWidth: Int,
        canvasHeight: Int,
        dirtyRect: LayerPixelRect,
        gpuBufferHandle: MetalBufferHandle,
        fallbackPixelData: Data? = nil
    ) -> Self {
        Self(
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            dirtyRect: dirtyRect,
            gpuBufferHandle: gpuBufferHandle,
            fallbackPixelData: fallbackPixelData
        )
    }

    public init?(
        validatingCanvasWidth canvasWidth: Int,
        canvasHeight: Int,
        dirtyRect: LayerPixelRect,
        gpuBufferHandle: MetalBufferHandle,
        fallbackPixelData: Data? = nil
    ) {
        guard let canvasGeometry = PixelGeometry(width: canvasWidth, height: canvasHeight) else { return nil }
        guard dirtyRect.originX >= 0, dirtyRect.originY >= 0 else { return nil }
        guard dirtyRect.originX + dirtyRect.width <= canvasWidth,
              dirtyRect.originY + dirtyRect.height <= canvasHeight else { return nil }
        guard gpuBufferHandle.isCompatible(with: canvasGeometry) else { return nil }
        if let fallbackPixelData {
            guard fallbackPixelData.count == canvasGeometry.rgbaByteCount else { return nil }
        }
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
