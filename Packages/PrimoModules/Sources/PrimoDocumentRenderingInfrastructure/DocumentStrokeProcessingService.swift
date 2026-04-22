import Foundation
import PrimoDocumentContracts
import PrimoDocumentStrokeInfrastructure

public struct DocumentStrokePreviewPlan: Sendable {
    public let baseSnapshot: MetalDocumentSnapshot
    public let adjustedPixels: Data
    public let dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?
    public let rectPixelData: Data?
    public let incrementalUpdate: IncrementalLayerUpdate?

    public init(
        baseSnapshot: MetalDocumentSnapshot,
        adjustedPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?,
        rectPixelData: Data?,
        incrementalUpdate: IncrementalLayerUpdate?
    ) {
        self.baseSnapshot = baseSnapshot
        self.adjustedPixels = adjustedPixels
        self.dirtyRect = dirtyRect
        self.rectPixelData = rectPixelData
        self.incrementalUpdate = incrementalUpdate
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
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool
    ) -> DocumentStrokePreviewPlan? {
        guard let preview = renderingClient.makeInteractiveStrokePreview(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            basePixelData: basePixelData,
            samples: samples,
            brush: brush,
            preserveAlphaLockedPixels: preserveAlphaLockedPixels
        ) else {
            return nil
        }

        return DocumentStrokePreviewPlan(
            baseSnapshot: snapshot,
            adjustedPixels: preview.pixelData,
            dirtyRect: preview.dirtyRect,
            rectPixelData: preview.rectPixelData,
            incrementalUpdate: preview.incrementalUpdate
        )
    }

    public func makeFallbackCommittedPixels(
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
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            samples: samples,
            brush: brush,
            mode: .interactive,
            snapshotRevision: snapshot.revision,
            activeLayerIndex: activeLayerIndex
        ) {
            return preserveAlphaLockedPixels
                ? DocumentStrokeRasterizer.pixelDataByPreservingExistingAlpha(
                    source: gpuOutput,
                    existing: baseLayer.pixelData
                )
                : gpuOutput
        }

        return DocumentStrokeRasterizer.layerPixelDataByApplyingCommittedStroke(
            basePixelData: baseLayer.pixelData,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            samples: samples,
            brush: brush,
            preserveAlphaLockedPixels: preserveAlphaLockedPixels
        )
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
