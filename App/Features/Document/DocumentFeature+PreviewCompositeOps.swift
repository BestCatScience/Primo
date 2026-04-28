import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain

extension DocumentFeature {
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
}
