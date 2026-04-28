import Foundation
import PrimoDocumentRenderingContracts

public enum DocumentGpuOperationGatewayFactory {
    public static func live() -> DocumentGpuOperationGateway {
        gateway(backend: MetalDocumentGpuOperationBackendFactory.live())
    }

    static func gateway(backend: DocumentGpuOperationBackend) -> DocumentGpuOperationGateway {
        DocumentGpuOperationGateway(
            compositedPaperPreviewRGBA: backend.compositedPaperPreviewRGBA,
            compositedPreviewPixelData: backend.compositedPreviewPixelData,
            compositedPreviewIncrementalUpdate: backend.compositedPreviewIncrementalUpdate,
            selectionOverlayRGBA: backend.selectionOverlayRGBA,
            eyedropperLoupeRGBA: backend.eyedropperLoupeRGBA,
            shapePreviewSurface: backend.shapePreviewSurface,
            textLayerSurface: backend.textLayerSurface,
            textLayoutRect: backend.textLayoutRect,
            processedLayerPixelData: backend.processedLayerPixelData,
            alphaMask: backend.alphaMask,
            croppedSelectionMask: backend.croppedSelectionMask,
            combinedSelectionMask: backend.combinedSelectionMask,
            expandedSelectionMask: backend.expandedSelectionMask,
            lassoSelection: backend.lassoSelection,
            autoSelection: backend.autoSelection,
            colorRangeSelection: backend.colorRangeSelection,
            expandedMask: backend.expandedMask,
            contractedMask: backend.contractedMask,
            featheredMask: backend.featheredMask,
            invertMask: backend.invertMask,
            transformedSelectionMask: backend.transformedSelectionMask,
            transformedLayerPixelData: backend.transformedLayerPixelData,
            scaledPixelData: backend.scaledPixelData,
            translatedPixelData: backend.translatedPixelData,
            releaseSurfaceHandle: backend.releaseSurfaceHandle
        )
    }
}
