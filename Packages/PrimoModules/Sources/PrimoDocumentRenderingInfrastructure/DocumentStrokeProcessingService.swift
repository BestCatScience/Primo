import Foundation
import PrimoDocumentContracts

public struct DocumentStrokePreviewPlan: Sendable {
    public let baseSnapshot: MetalDocumentSnapshot
    public let adjustedBufferHandle: MetalBufferHandle
    public let dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    public let incrementalUpdate: IncrementalLayerUpdate?
    public let isApproximatePreview: Bool

    public init(
        baseSnapshot: MetalDocumentSnapshot,
        adjustedBufferHandle: MetalBufferHandle,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int),
        incrementalUpdate: IncrementalLayerUpdate?,
        isApproximatePreview: Bool = false
    ) {
        self.baseSnapshot = baseSnapshot
        self.adjustedBufferHandle = adjustedBufferHandle
        self.dirtyRect = dirtyRect
        self.incrementalUpdate = incrementalUpdate
        self.isApproximatePreview = isApproximatePreview
    }
}

public struct DocumentStrokeProcessingService: Sendable {
    public let renderingClient: DocumentRenderingClient

    public init(renderingClient: DocumentRenderingClient = .live) {
        self.renderingClient = renderingClient
    }

    public func resetInteractiveStrokeState() {
        renderingClient.resetInteractiveStrokeState()
    }

    public func makePreviewPlan(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        basePixelData: Data,
        baseBufferHandle: MetalBufferHandle? = nil,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool,
        usesResponsiveOilPreview: Bool = false
    ) -> DocumentStrokePreviewPlan? {
        guard let preview = renderingClient.makeInteractiveStrokePreview(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            basePixelData: basePixelData,
            baseBufferHandle: baseBufferHandle,
            samples: samples,
            brush: brush,
            preserveAlphaLockedPixels: preserveAlphaLockedPixels,
            usesResponsiveOilPreview: usesResponsiveOilPreview
        ) else {
            return nil
        }

        guard let gpuBufferHandle = preview.gpuBufferHandle,
              let dirtyRect = preview.dirtyRect else {
            return nil
        }

        return DocumentStrokePreviewPlan(
            baseSnapshot: snapshot,
            adjustedBufferHandle: gpuBufferHandle,
            dirtyRect: dirtyRect,
            incrementalUpdate: preview.incrementalUpdate,
            isApproximatePreview: preview.isApproximatePreview
        )
    }

    public func makeCommittedSurface(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool
    ) -> (handle: MetalBufferHandle, dirtyRect: (originX: Int, originY: Int, width: Int, height: Int), fallbackPixelData: Data?)? {
        guard let baseLayer = snapshot.layers.first(where: { $0.index == activeLayerIndex }) else {
            return nil
        }

        guard let gpuOutput = renderingClient.executeStroke(
            MetalStrokeExecutionRequest(
                basePixelData: baseLayer.pixelData,
                baseBufferHandle: baseLayer.gpuBufferHandle,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                samples: samples,
                brush: brush,
                mode: .interactive,
                snapshotRevision: snapshot.revision,
                activeLayerIndex: activeLayerIndex
            )
        ) else {
            return nil
        }
        guard !preserveAlphaLockedPixels else { return nil }
        guard let handle = gpuOutput.gpuBufferHandle else {
            return nil
        }
        return (handle, gpuOutput.dirtyRect, gpuOutput.pixelData)
    }

    public func makeCommittedPixels(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool
    ) -> Data? {
        guard let baseLayer = snapshot.layers.first(where: { $0.index == activeLayerIndex }) else {
            return nil
        }

        if let gpuOutput = renderingClient.rasterizedStrokePixelData(
            basePixelData: baseLayer.pixelData,
            baseBufferHandle: baseLayer.gpuBufferHandle,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            samples: samples,
            brush: brush,
            mode: .interactive,
            snapshotRevision: snapshot.revision,
            activeLayerIndex: activeLayerIndex
        ) {
            if preserveAlphaLockedPixels {
                return renderingClient.preservingExistingAlpha(
                    source: gpuOutput,
                    existing: baseLayer.pixelData,
                    width: snapshot.width,
                    height: snapshot.height
                )
            }
            return gpuOutput
        }
        return nil
    }

    public func stageCommittedSnapshot(
        baseSnapshot: MetalDocumentSnapshot,
        committedPixels: Data,
        lastCommittedRenderRevision: Int,
        activeLayerIndex: Int,
        stagedCompositePixelData: Data?
    ) -> MetalDocumentSnapshot? {
        let compositePixelData: Data
        if let stagedCompositePixelData {
            compositePixelData = stagedCompositePixelData
        } else if let composited = renderingClient.compositedPreviewPixelData(
            snapshot: baseSnapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: committedPixels
        ) {
            compositePixelData = composited
        } else {
            return nil
        }

        let layers = baseSnapshot.layers.map { layer in
            guard layer.index == activeLayerIndex else { return layer }
            return MetalLayerSnapshot(
                index: layer.index,
                opacity: layer.opacity,
                visible: layer.visible,
                isClipped: layer.isClipped,
                blendMode: layer.blendMode,
                thumbnailSurface: layer.thumbnailSurface,
                thumbnailData: layer.thumbnailData,
                pixelData: committedPixels
            )
        }

        return MetalDocumentSnapshot(
            width: baseSnapshot.width,
            height: baseSnapshot.height,
            revision: max(baseSnapshot.revision, lastCommittedRenderRevision) + 1,
            compositePixelData: compositePixelData,
            layers: layers
        )
    }
}
