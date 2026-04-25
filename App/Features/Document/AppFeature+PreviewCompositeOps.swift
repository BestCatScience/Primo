import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain

extension AppFeature {
    static func renderedCompositeSurface(
        snapshot: MetalDocumentSnapshot,
        paperStyle: CanvasPaperStyle,
        gpuOperations: DocumentGpuOperationGateway
    ) -> DocumentCompositeSurface {
        let pixelData = gpuOperations.compositedPaperPreviewRGBA(
            snapshot.compositePixelData,
            snapshot.width,
            snapshot.height,
            paperStyle
        ) ?? snapshot.compositePixelData

        return DocumentCompositeSurface(
            width: snapshot.width,
            height: snapshot.height,
            pixelData: pixelData
        )
    }

    func renderedCompositeSurface(
        snapshot: MetalDocumentSnapshot,
        paperStyle: CanvasPaperStyle
    ) -> DocumentCompositeSurface {
        Self.renderedCompositeSurface(
            snapshot: snapshot,
            paperStyle: paperStyle,
            gpuOperations: documentGpuOperationGateway
        )
    }

    func renderedCompositePNGData(
        snapshot: MetalDocumentSnapshot,
        paperStyle: CanvasPaperStyle
    ) -> Data? {
        DocumentRasterImageService.pngData(
            from: renderedCompositeSurface(snapshot: snapshot, paperStyle: paperStyle)
        )
    }

    func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        documentGpuOperationGateway.compositedPreviewPixelData(
            snapshot,
            activeLayerIndex,
            adjustedActiveLayerPixels
        )
    }

    func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: LayerPixelRect
    ) -> IncrementalLayerUpdate? {
        documentGpuOperationGateway.compositedPreviewIncrementalUpdate(
            snapshot,
            activeLayerIndex,
            adjustedActiveLayerPixels,
            dirtyRect
        )
    }
}
