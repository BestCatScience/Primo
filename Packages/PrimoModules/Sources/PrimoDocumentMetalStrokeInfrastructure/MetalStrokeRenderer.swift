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
        return StrokePreviewResult(
            baseSnapshot: plan.baseSnapshot,
            adjustedPixels: plan.adjustedPixels,
            adjustedHandle: plan.adjustedBufferHandle.map(GpuSurfaceHandle.init(buffer:)),
            dirtyRect: plan.dirtyRect.map {
                LayerPixelRect(originX: $0.originX, originY: $0.originY, width: $0.width, height: $0.height)
            },
            rectPixelData: plan.rectPixelData,
            incrementalUpdate: plan.incrementalUpdate,
            isApproximatePreview: plan.isApproximatePreview
        )
    }

    public func makeCommittedPixels(_ request: StrokeCommitRequest) -> StrokeCommitResult? {
        processingService.makeCommittedPixels(
            snapshot: request.snapshot,
            activeLayerIndex: request.activeLayerIndex,
            samples: request.samples,
            brush: request.brush,
            preserveAlphaLockedPixels: request.preserveAlphaLockedPixels
        ).map(StrokeCommitResult.init(committedPixels:))
    }
}
