import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentRuntime

extension DocumentFeature {
    static func renderedCompositeSurface(
        snapshot: MetalDocumentSnapshot,
        paperStyle: CanvasPaperStyle,
        gpuOperations: DocumentRenderingWorkflow
    ) -> DocumentCompositeSurface {
        renderedCompositeSurfaceIfAvailable(
            snapshot: snapshot,
            paperStyle: paperStyle,
            gpuOperations: gpuOperations
        ) ?? DocumentCompositeSurface(
            validatingWidth: snapshot.width,
            height: snapshot.height,
            pixelData: Data(repeating: 0, count: max(0, snapshot.width * snapshot.height * 4))
        ) ?? DocumentCompositeSurface(
            validatingWidth: 1,
            height: 1,
            pixelData: Data([0, 0, 0, 0])
        )!
    }

    static func renderedCompositeSurfaceIfAvailable(
        snapshot: MetalDocumentSnapshot,
        paperStyle: CanvasPaperStyle,
        gpuOperations: DocumentRenderingWorkflow
    ) -> DocumentCompositeSurface? {
        let expectedByteCount = snapshot.width * snapshot.height * 4
        guard snapshot.width > 0,
              snapshot.height > 0,
              snapshot.compositePixelData.count == expectedByteCount
        else {
            return nil
        }

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
        )
    }
}
