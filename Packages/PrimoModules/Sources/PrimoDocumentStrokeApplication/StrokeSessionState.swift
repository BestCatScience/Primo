import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts

public struct StrokeSessionRenderState: Equatable, Sendable {
    public let baseRevision: Int
    public let layerIndex: Int
    public let surfaceHandle: MetalBufferHandle
    public let dirtyRect: LayerPixelRect
    public let isApproximatePreview: Bool
    public let previewBrush: BrushRuntimeSettings?
    public let sampleCount: Int
    public let supportsIncrementalContinuation: Bool

    public init(
        baseRevision: Int,
        layerIndex: Int,
        surfaceHandle: MetalBufferHandle,
        dirtyRect: LayerPixelRect,
        isApproximatePreview: Bool,
        previewBrush: BrushRuntimeSettings? = nil,
        sampleCount: Int = 0,
        supportsIncrementalContinuation: Bool = false
    ) {
        self.baseRevision = baseRevision
        self.layerIndex = layerIndex
        self.surfaceHandle = surfaceHandle
        self.dirtyRect = dirtyRect
        self.isApproximatePreview = isApproximatePreview
        self.previewBrush = previewBrush
        self.sampleCount = sampleCount
        self.supportsIncrementalContinuation = supportsIncrementalContinuation
    }
}

public struct StrokeSessionState: Equatable, Sendable {
    public var baseSnapshot: MetalDocumentSnapshot?
    public var renderState: StrokeSessionRenderState?
    public var pendingIncrementalUpdate: IncrementalLayerUpdate?
    public var committedPointCount: Int

    public init(
        baseSnapshot: MetalDocumentSnapshot? = nil,
        renderState: StrokeSessionRenderState? = nil,
        pendingIncrementalUpdate: IncrementalLayerUpdate? = nil,
        committedPointCount: Int = 0
    ) {
        self.baseSnapshot = baseSnapshot
        self.renderState = renderState
        self.pendingIncrementalUpdate = pendingIncrementalUpdate
        self.committedPointCount = committedPointCount
    }

    public var hasCommittedPoints: Bool {
        committedPointCount > 0
    }

    public mutating func captureBaseSnapshot(_ snapshot: MetalDocumentSnapshot) {
        baseSnapshot = snapshot
    }

    public mutating func applyPreview(
        baseSnapshot: MetalDocumentSnapshot,
        surface: GpuLayerSurface,
        dirtyRegion: GpuSurfaceRegion,
        isApproximatePreview: Bool,
        incrementalUpdate: IncrementalLayerUpdate?,
        previewBrush: BrushRuntimeSettings?,
        sampleCount: Int,
        supportsIncrementalContinuation: Bool
    ) {
        self.baseSnapshot = baseSnapshot
        renderState = StrokeSessionRenderState(
            baseRevision: baseSnapshot.revision,
            layerIndex: surface.layerIndex,
            surfaceHandle: surface.handle.buffer,
            dirtyRect: dirtyRegion.layerPixelRect,
            isApproximatePreview: isApproximatePreview,
            previewBrush: previewBrush,
            sampleCount: sampleCount,
            supportsIncrementalContinuation: supportsIncrementalContinuation
        )
        if let incrementalUpdate {
            pendingIncrementalUpdate = incrementalUpdate
        }
    }

    public mutating func markCommittedPointCount(_ pointCount: Int) {
        committedPointCount = max(committedPointCount, pointCount)
    }

    public mutating func resetPreview() {
        baseSnapshot = nil
        renderState = nil
        pendingIncrementalUpdate = nil
    }

    public mutating func resetInteraction() {
        resetPreview()
        committedPointCount = 0
    }

    public static func trimmingDuplicateLeadingSamples(
        _ samples: [StylusSample],
        after previousSample: StylusSample?
    ) -> [StylusSample] {
        guard let previousSample else { return samples }
        var trimmed = samples
        while trimmed.first == previousSample {
            trimmed.removeFirst()
        }
        return trimmed
    }

    public static func trimmingDuplicateTrailingSamples(_ samples: [StylusSample]) -> [StylusSample] {
        guard samples.count >= 2 else { return samples }
        var trimmed = samples
        while trimmed.count >= 2, trimmed[trimmed.count - 1] == trimmed[trimmed.count - 2] {
            trimmed.removeLast()
        }
        return trimmed
    }
}
