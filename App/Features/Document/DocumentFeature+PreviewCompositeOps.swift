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
        ).value ?? snapshot.compositePixelData

        return DocumentCompositeSurface(
            validatingWidth: snapshot.width,
            height: snapshot.height,
            pixelData: pixelData
        ) ?? DocumentCompositeSurface(
            validatingWidth: snapshot.width,
            height: snapshot.height,
            pixelData: snapshot.compositePixelData
        )!
    }
}
