import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure

public typealias MetalStrokeExecutionRequest = PrimoMetalStrokeExecutionRequest
public typealias MetalStrokeExecutionResult = PrimoMetalStrokeExecutionResult
public typealias MetalStrokeMutationResult = PrimoMetalStrokeMutationResult

public struct DocumentInteractiveStrokePreviewResult: Sendable {
    public let pixelData: Data?
    public let gpuBufferHandle: MetalBufferHandle?
    public let dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?
    public let rectPixelData: Data?
    public let incrementalUpdate: IncrementalLayerUpdate?
    public let isApproximatePreview: Bool

    public init(
        pixelData: Data?,
        gpuBufferHandle: MetalBufferHandle? = nil,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?,
        rectPixelData: Data?,
        incrementalUpdate: IncrementalLayerUpdate?,
        isApproximatePreview: Bool = false
    ) {
        self.pixelData = pixelData
        self.gpuBufferHandle = gpuBufferHandle
        self.dirtyRect = dirtyRect
        self.rectPixelData = rectPixelData
        self.incrementalUpdate = incrementalUpdate
        self.isApproximatePreview = isApproximatePreview
    }
}

public struct GpuStrokeRenderingService: Sendable {
    private let executor: MetalStrokeExecutor
    private let surfaceStore: MetalSurfaceStore

    public init(
        executor: MetalStrokeExecutor = MetalStrokeExecutor(),
        surfaceStore: MetalSurfaceStore = MetalSurfaceStore()
    ) {
        self.executor = executor
        self.surfaceStore = surfaceStore
    }

    public func resetExecutionSession() {
        executor.resetSession()
    }

    public func executeStroke(_ request: MetalStrokeExecutionRequest) -> MetalStrokeExecutionResult? {
        executor.executeStroke(request)
    }

    public func executeStrokeMutation(_ request: MetalStrokeExecutionRequest) -> MetalStrokeMutationResult? {
        executor.executeStrokeMutation(request)
    }

    public func release(_ handle: MetalBufferHandle?) {
        surfaceStore.release(handle)
    }
}

public struct GpuLayerCompositingService: Sendable {
    private let compositor: MetalCompositor

    public init(compositor: MetalCompositor = MetalCompositor()) {
        self.compositor = compositor
    }

    public func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        compositor.compositedPreviewPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    public func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        compositor.compositedPreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
        )
    }

    public func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerBufferHandle: MetalBufferHandle,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        compositor.compositedPreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerBufferHandle: adjustedActiveLayerBufferHandle,
            dirtyRect: dirtyRect
        )
    }

    public func compositedPaperPreviewRGBA(
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle
    ) -> Data? {
        compositor.compositedPaperPreviewRGBA(
            pixelData: pixelData,
            width: width,
            height: height,
            paperStyle: paperStyle
        )
    }
}

public struct GpuSurfaceMaterializationService: Sendable {
    private let surfaceStore: MetalSurfaceStore
    private let layerMutationExecutor: MetalLayerMutationExecutor

    public init(
        surfaceStore: MetalSurfaceStore = MetalSurfaceStore(),
        layerMutationExecutor: MetalLayerMutationExecutor = MetalLayerMutationExecutor()
    ) {
        self.surfaceStore = surfaceStore
        self.layerMutationExecutor = layerMutationExecutor
    }

    public func materializedPixelData(for handle: MetalBufferHandle) -> Data? {
        surfaceStore.materializedPixelData(for: handle)
    }

    public func preservingExistingAlpha(
        source: Data,
        existing: Data,
        width: Int,
        height: Int
    ) -> Data? {
        layerMutationExecutor.preservingExistingAlpha(source: source, existing: existing, width: width, height: height)
    }

    public func preservingExistingAlphaBufferHandle(
        sourceHandle: MetalBufferHandle,
        existingHandle: MetalBufferHandle?,
        existingPixelData: Data,
        width: Int,
        height: Int
    ) -> MetalBufferHandle? {
        layerMutationExecutor.preservingExistingAlphaBufferHandle(
            sourceHandle: sourceHandle,
            existingHandle: existingHandle,
            existingPixelData: existingPixelData,
            width: width,
            height: height
        )
    }
}

public enum GpuRenderingSupport {
    public static func shouldUseIncrementalPreviewUpdate(for brush: BrushRuntimeSettings) -> Bool {
        StrokePreviewContinuationPolicy.shouldUseIncrementalPreviewUpdate(for: brush)
    }

    public static func shouldUseGpuOnlyResponsivePreview(for brush: BrushRuntimeSettings) -> Bool {
        StrokePreviewContinuationPolicy.shouldUseGpuOnlyResponsivePreview(for: brush)
    }

    public static func responsivePreviewBrush(from brush: BrushRuntimeSettings) -> BrushRuntimeSettings {
        guard StrokePreviewContinuationPolicy.shouldUseGpuOnlyResponsivePreview(for: brush) else {
            return brush
        }

        var preview = brush
        preview.smudgeEngineEnabled = false
        preview.stampSpacing = max(brush.stampSpacing, 0.18)
        preview.textureStrength = min(brush.textureStrength, 0.12)
        preview.wetness = 0
        preview.wetnessPressureSensitivity = 0
        preview.colorMixStrength = 0
        preview.smudgeRadius = 0
        preview.smudgeLength = 0
        return preview
    }

    public static func strokePreviewDirtyRect(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> (originX: Int, originY: Int, width: Int, height: Int)? {
        guard !samples.isEmpty, canvasWidth > 0, canvasHeight > 0 else { return nil }

        let scatterExtent = brush.scatterEnabled ? max(CGFloat(brush.scatterLateral), CGFloat(brush.scatterLinear)) : 0
        let spread = max(2, Int(ceil(CGFloat(brush.radius) * 2 + scatterExtent * CGFloat(brush.radius))))
        let xs = samples.map { Int($0.point.x.rounded()) }
        let ys = samples.map { Int($0.point.y.rounded()) }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }

        let originX = max(0, minX - spread)
        let originY = max(0, minY - spread)
        let limitX = min(canvasWidth, maxX + spread + 1)
        let limitY = min(canvasHeight, maxY + spread + 1)
        guard limitX > originX, limitY > originY else { return nil }
        return (originX, originY, limitX - originX, limitY - originY)
    }
}
