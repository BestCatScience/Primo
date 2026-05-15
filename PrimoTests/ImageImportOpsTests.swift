import CoreGraphics
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime
import XCTest
@testable import Primo

private func imageImportRenderingFailure<Value>() -> DocumentRenderingResult<Value> {
    .failure(.kernelFailed(operation: "imageImportTest"))
}

final class ImageImportOpsTests: XCTestCase {
    private func sampleSurface() -> DocumentCompositeSurface {
        DocumentCompositeSurface(
            unsafeUncheckedWidth: 2,
            height: 2,
            pixelData: Data([
                255, 0, 0, 255,
                0, 255, 0, 255,
                0, 0, 255, 255,
                255, 255, 255, 255,
            ])
        )
    }

    func testImportedCanvasImageDecodesSurfaceDimensions() throws {
        let encoded = try XCTUnwrap(
            DocumentRasterImageService.pngData(from: sampleSurface())
        )

        let imported = try XCTUnwrap(DocumentFeature.importedCanvasImage(from: encoded))

        XCTAssertEqual(imported.width, 2)
        XCTAssertEqual(imported.height, 2)
        XCTAssertEqual(imported.pixelData.count, 16)
    }

    func testFittedLayerPixelDataReturnsCanvasSizedPixels() throws {
        let encoded = try XCTUnwrap(
            DocumentRasterImageService.pngData(from: sampleSurface())
        )

        let fitted = try XCTUnwrap(
            DocumentFeature.fittedLayerPixelData(
                fromImageData: encoded,
                canvasSize: CGSize(width: 6, height: 4),
                gpuOperations: imageImportRenderingWorkflow()
            )
        )

        XCTAssertEqual(fitted.count, 6 * 4 * 4)
    }

    private func imageImportRenderingWorkflow() -> DocumentRenderingWorkflow {
        DocumentApplicationRuntime.stub().workflows.presentation.renderingWorkflow
    }

}
