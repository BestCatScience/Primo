import Foundation
import PrimoDocumentContracts
import PrimoDocumentGPUContracts
import PrimoDocumentRenderingInfrastructure

public struct MetalStrokeRenderer: StrokePreviewPlanning, StrokeCommitRendering {
    private let processingService: DocumentStrokeProcessingService

    public init(processingService: DocumentStrokeProcessingService = DocumentStrokeProcessingService()) {
        self.processingService = processingService
    }

    public func makePreview(_ request: StrokePreviewRequest) -> StrokePreviewResult? {
        guard let plan = processingService.makePreviewPlan(
            snapshot: request.snapshot,
            activeLayerIndex: request.activeLayerIndex,
            basePixelData: request.baseLayer.pixelData,
            baseBufferHandle: request.baseLayer.gpuHandle?.buffer,
            samples: request.samples,
            brush: request.brush,
            preserveAlphaLockedPixels: request.preserveAlphaLockedPixels,
            usesResponsiveOilPreview: request.usesResponsiveOilPreview
        ) else {
            return nil
        }
        let region = GpuSurfaceRegion(
            originX: plan.dirtyRect.originX,
            originY: plan.dirtyRect.originY,
            width: plan.dirtyRect.width,
            height: plan.dirtyRect.height
        )
        return StrokePreviewResult(
            baseSnapshot: plan.baseSnapshot,
            surface: GpuLayerSurface(
                layerIndex: request.activeLayerIndex,
                width: request.snapshot.width,
                height: request.snapshot.height,
                handle: GpuSurfaceHandle(buffer: plan.adjustedBufferHandle)
            ),
            dirtyRegion: region,
            incrementalUpdate: plan.incrementalUpdate,
            isApproximatePreview: plan.isApproximatePreview
        )
    }

    public func makeCommittedPixels(_ request: StrokeCommitRequest) -> StrokeCommitResult? {
        guard let committed = processingService.makeCommittedSurface(
            snapshot: request.snapshot,
            activeLayerIndex: request.activeLayerIndex,
            samples: request.samples,
            brush: request.brush,
            preserveAlphaLockedPixels: request.preserveAlphaLockedPixels
        ) else {
            return nil
        }
        return StrokeCommitResult(
            surface: GpuLayerSurface(
                layerIndex: request.activeLayerIndex,
                width: request.snapshot.width,
                height: request.snapshot.height,
                handle: GpuSurfaceHandle(buffer: committed.handle)
            ),
            dirtyRegion: GpuSurfaceRegion(
                originX: committed.dirtyRect.originX,
                originY: committed.dirtyRect.originY,
                width: committed.dirtyRect.width,
                height: committed.dirtyRect.height
            )
        )
    }
}
