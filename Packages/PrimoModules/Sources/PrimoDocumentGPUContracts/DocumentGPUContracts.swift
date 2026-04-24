import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

public struct GpuSurfaceHandle: Equatable, Hashable, Sendable {
    public let buffer: MetalBufferHandle

    public init(buffer: MetalBufferHandle) {
        self.buffer = buffer
    }
}

public struct LayerSurfaceRef: Equatable, Sendable {
    public let layerIndex: Int
    public let width: Int
    public let height: Int
    public let pixelData: Data
    public let gpuHandle: GpuSurfaceHandle?

    public init(
        layerIndex: Int,
        width: Int,
        height: Int,
        pixelData: Data,
        gpuHandle: GpuSurfaceHandle? = nil
    ) {
        self.layerIndex = layerIndex
        self.width = width
        self.height = height
        self.pixelData = pixelData
        self.gpuHandle = gpuHandle
    }
}

public struct StrokePreviewRequest: Sendable {
    public let snapshot: MetalDocumentSnapshot
    public let activeLayerIndex: Int
    public let baseLayer: LayerSurfaceRef
    public let samples: [StylusSample]
    public let brush: BrushRuntimeSettings
    public let preserveAlphaLockedPixels: Bool
    public let usesResponsiveOilPreview: Bool

    public init(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        baseLayer: LayerSurfaceRef,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool,
        usesResponsiveOilPreview: Bool = false
    ) {
        self.snapshot = snapshot
        self.activeLayerIndex = activeLayerIndex
        self.baseLayer = baseLayer
        self.samples = samples
        self.brush = brush
        self.preserveAlphaLockedPixels = preserveAlphaLockedPixels
        self.usesResponsiveOilPreview = usesResponsiveOilPreview
    }
}

public struct StrokePreviewResult: Sendable {
    public let baseSnapshot: MetalDocumentSnapshot
    public let adjustedPixels: Data?
    public let adjustedHandle: GpuSurfaceHandle?
    public let dirtyRect: LayerPixelRect?
    public let rectPixelData: Data?
    public let incrementalUpdate: IncrementalLayerUpdate?
    public let isApproximatePreview: Bool

    public init(
        baseSnapshot: MetalDocumentSnapshot,
        adjustedPixels: Data?,
        adjustedHandle: GpuSurfaceHandle? = nil,
        dirtyRect: LayerPixelRect?,
        rectPixelData: Data?,
        incrementalUpdate: IncrementalLayerUpdate?,
        isApproximatePreview: Bool = false
    ) {
        self.baseSnapshot = baseSnapshot
        self.adjustedPixels = adjustedPixels
        self.adjustedHandle = adjustedHandle
        self.dirtyRect = dirtyRect
        self.rectPixelData = rectPixelData
        self.incrementalUpdate = incrementalUpdate
        self.isApproximatePreview = isApproximatePreview
    }
}

public struct StrokeCommitRequest: Sendable {
    public let snapshot: MetalDocumentSnapshot
    public let activeLayerIndex: Int
    public let samples: [StylusSample]
    public let brush: BrushRuntimeSettings
    public let preserveAlphaLockedPixels: Bool

    public init(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool
    ) {
        self.snapshot = snapshot
        self.activeLayerIndex = activeLayerIndex
        self.samples = samples
        self.brush = brush
        self.preserveAlphaLockedPixels = preserveAlphaLockedPixels
    }
}

public struct StrokeCommitResult: Sendable {
    public let committedPixels: Data

    public init(committedPixels: Data) {
        self.committedPixels = committedPixels
    }
}

public struct RenderFrameUpdate: Sendable {
    public let snapshot: MetalDocumentSnapshot?
    public let activeLayerIndex: Int
    public let incrementalUpdate: IncrementalLayerUpdate?
    public let documentSize: CGSize
    public let viewportOffset: CGSize
    public let zoomScale: CGFloat
    public let paperStyle: CanvasPaperStyle
    public let previewResetNonce: Int

    public init(
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        incrementalUpdate: IncrementalLayerUpdate?,
        documentSize: CGSize,
        viewportOffset: CGSize,
        zoomScale: CGFloat,
        paperStyle: CanvasPaperStyle,
        previewResetNonce: Int
    ) {
        self.snapshot = snapshot
        self.activeLayerIndex = activeLayerIndex
        self.incrementalUpdate = incrementalUpdate
        self.documentSize = documentSize
        self.viewportOffset = viewportOffset
        self.zoomScale = zoomScale
        self.paperStyle = paperStyle
        self.previewResetNonce = previewResetNonce
    }
}

public struct GpuResourceLifetime: Sendable {
    public var release: @Sendable (GpuSurfaceHandle) -> Void

    public init(release: @escaping @Sendable (GpuSurfaceHandle) -> Void) {
        self.release = release
    }

    public func release(_ handle: GpuSurfaceHandle?) {
        guard let handle else { return }
        release(handle)
    }
}

public protocol StrokePreviewPlanning: Sendable {
    func makePreview(_ request: StrokePreviewRequest) -> StrokePreviewResult?
}

public protocol StrokeCommitRendering: Sendable {
    func makeCommittedPixels(_ request: StrokeCommitRequest) -> StrokeCommitResult?
}

public extension MetalLayerSnapshot {
    func surfaceRef(canvasWidth: Int, canvasHeight: Int) -> LayerSurfaceRef {
        LayerSurfaceRef(
            layerIndex: index,
            width: canvasWidth,
            height: canvasHeight,
            pixelData: pixelData,
            gpuHandle: gpuBufferHandle.map(GpuSurfaceHandle.init(buffer:))
        )
    }
}
