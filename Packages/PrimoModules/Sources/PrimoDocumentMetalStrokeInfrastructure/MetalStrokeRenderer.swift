import Foundation
import PrimoDocumentGPUContracts

public struct MetalStrokeRenderer: StrokePreviewPlanning, StrokeCommitRendering {
    private let processingService: DocumentStrokeProcessingService

    public init(processingService: DocumentStrokeProcessingService = DocumentStrokeProcessingService()) {
        self.processingService = processingService
    }

    public func makePreview(_ request: StrokePreviewRequest) -> StrokePreviewResult? {
        processingService.makePreviewSurface(
            snapshot: request.snapshot,
            activeLayerIndex: request.activeLayerIndex,
            basePixelData: request.baseLayer.pixelData,
            baseBufferHandle: request.baseLayer.gpuHandle?.buffer,
            samples: request.samples,
            brush: request.brush,
            preserveAlphaLockedPixels: request.preserveAlphaLockedPixels,
            usesResponsiveOilPreview: request.usesResponsiveOilPreview
        )
    }

    public func makeCommittedSurface(_ request: StrokeCommitRequest) -> StrokeCommitResult? {
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
