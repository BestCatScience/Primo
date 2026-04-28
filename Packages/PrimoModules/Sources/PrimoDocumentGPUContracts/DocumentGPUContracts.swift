import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain

public struct GpuSurfaceHandle: Equatable, Hashable, Sendable {
    public let buffer: MetalBufferHandle

    public init(buffer: MetalBufferHandle) {
        self.buffer = buffer
    }
}

public struct GpuSurfaceRegion: Equatable, Sendable {
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

    public init(_ rect: LayerPixelRect) {
        self.init(originX: rect.originX, originY: rect.originY, width: rect.width, height: rect.height)
    }

    public var layerPixelRect: LayerPixelRect {
        LayerPixelRect(originX: originX, originY: originY, width: width, height: height)
    }

    public var isEmpty: Bool { width <= 0 || height <= 0 }
}

public enum StrokePreviewContinuationPolicy {
    public static func shouldUseIncrementalPreviewUpdate(for brush: BrushRuntimeSettings) -> Bool {
        if brush.tipKind == .oil && brush.smudgeEngineEnabled {
            return false
        }
        let scatterExtent = brush.scatterEnabled ? max(CGFloat(brush.scatterLateral), CGFloat(brush.scatterLinear)) : 0
        let effectiveDiameter = (CGFloat(brush.radius) * 2.0) * (1.0 + scatterExtent)
        let softness = 1.0 - CGFloat(brush.hardness)

        if brush.tipKind == .airbrush && effectiveDiameter >= 42 {
            return false
        }
        if softness >= 0.34 && effectiveDiameter >= 56 {
            return false
        }
        return true
    }
}

public struct GpuLayerSurface: Equatable, Sendable {
    public let layerIndex: Int
    public let width: Int
    public let height: Int
    public let handle: GpuSurfaceHandle

    public init(layerIndex: Int, width: Int, height: Int, handle: GpuSurfaceHandle) {
        self.layerIndex = layerIndex
        self.width = width
        self.height = height
        self.handle = handle
    }
}

public struct GpuDocumentSurfaceSnapshot: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let revision: Int
    public let composite: GpuSurfaceHandle?
    public let layers: [GpuLayerSurface]

    public init(
        width: Int,
        height: Int,
        revision: Int,
        composite: GpuSurfaceHandle?,
        layers: [GpuLayerSurface]
    ) {
        self.width = width
        self.height = height
        self.revision = revision
        self.composite = composite
        self.layers = layers
    }
}

public struct GpuIncrementalUpdate: Equatable, Sendable {
    public let layerIndex: Int
    public let region: GpuSurfaceRegion
    public let handle: GpuSurfaceHandle

    public init(layerIndex: Int, region: GpuSurfaceRegion, handle: GpuSurfaceHandle) {
        self.layerIndex = layerIndex
        self.region = region
        self.handle = handle
    }
}

public struct MaterializedSurfaceRequest: Equatable, Sendable {
    public let handle: GpuSurfaceHandle
    public let region: GpuSurfaceRegion?

    public init(handle: GpuSurfaceHandle, region: GpuSurfaceRegion? = nil) {
        self.handle = handle
        self.region = region
    }
}

public struct MaterializedSurfaceResult: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixelData: Data

    public init(width: Int, height: Int, pixelData: Data) {
        self.width = width
        self.height = height
        self.pixelData = pixelData
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
    public let surface: GpuLayerSurface?
    public let dirtyRegion: GpuSurfaceRegion?
    public let incrementalUpdate: IncrementalLayerUpdate?
    public let isApproximatePreview: Bool

    public init(
        baseSnapshot: MetalDocumentSnapshot,
        surface: GpuLayerSurface?,
        dirtyRegion: GpuSurfaceRegion?,
        incrementalUpdate: IncrementalLayerUpdate?,
        isApproximatePreview: Bool = false
    ) {
        self.baseSnapshot = baseSnapshot
        self.surface = surface
        self.dirtyRegion = dirtyRegion
        self.incrementalUpdate = incrementalUpdate
        self.isApproximatePreview = isApproximatePreview
    }

    public var dirtyRect: LayerPixelRect? {
        dirtyRegion?.layerPixelRect
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
    public let surface: GpuLayerSurface
    public let dirtyRegion: GpuSurfaceRegion

    public init(surface: GpuLayerSurface, dirtyRegion: GpuSurfaceRegion) {
        self.surface = surface
        self.dirtyRegion = dirtyRegion
    }
}

public struct GpuPreviewMutation: Sendable {
    public let baseSnapshot: MetalDocumentSnapshot
    public let surface: GpuLayerSurface
    public let dirtyRegion: GpuSurfaceRegion
    public let incrementalUpdate: IncrementalLayerUpdate?
    public let isApproximatePreview: Bool
    public let baseSnapshotToCapture: MetalDocumentSnapshot?
    public let previewBrush: BrushRuntimeSettings?
    public let sampleCount: Int
    public let supportsIncrementalContinuation: Bool

    public init(
        baseSnapshot: MetalDocumentSnapshot,
        surface: GpuLayerSurface,
        dirtyRegion: GpuSurfaceRegion,
        incrementalUpdate: IncrementalLayerUpdate?,
        isApproximatePreview: Bool,
        baseSnapshotToCapture: MetalDocumentSnapshot? = nil,
        previewBrush: BrushRuntimeSettings? = nil,
        sampleCount: Int = 0,
        supportsIncrementalContinuation: Bool = false
    ) {
        self.baseSnapshot = baseSnapshot
        self.surface = surface
        self.dirtyRegion = dirtyRegion
        self.incrementalUpdate = incrementalUpdate
        self.isApproximatePreview = isApproximatePreview
        self.baseSnapshotToCapture = baseSnapshotToCapture
        self.previewBrush = previewBrush
        self.sampleCount = sampleCount
        self.supportsIncrementalContinuation = supportsIncrementalContinuation
    }
}

public struct GpuCommitMutation: Sendable {
    public let surface: GpuLayerSurface
    public let dirtyRegion: GpuSurfaceRegion
    public let refreshViaDirtyPresentation: Bool

    public init(
        surface: GpuLayerSurface,
        dirtyRegion: GpuSurfaceRegion,
        refreshViaDirtyPresentation: Bool
    ) {
        self.surface = surface
        self.dirtyRegion = dirtyRegion
        self.refreshViaDirtyPresentation = refreshViaDirtyPresentation
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
    func makeCommittedSurface(_ request: StrokeCommitRequest) -> StrokeCommitResult?
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
