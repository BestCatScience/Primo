import CoreGraphics
import PrimoDocumentApplication
import PrimoDocumentContracts
import XCTest
@testable import Primo

final class ImageImportOpsTests: XCTestCase {
    private func sampleSurface() -> DocumentCompositeSurface {
        DocumentCompositeSurface(
            width: 2,
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

        let imported = try XCTUnwrap(AppFeature.importedCanvasImage(from: encoded))

        XCTAssertEqual(imported.width, 2)
        XCTAssertEqual(imported.height, 2)
        XCTAssertEqual(imported.pixelData.count, 16)
    }

    func testFittedLayerPixelDataReturnsCanvasSizedPixels() throws {
        let encoded = try XCTUnwrap(
            DocumentRasterImageService.pngData(from: sampleSurface())
        )

        let fitted = try XCTUnwrap(
            AppFeature.fittedLayerPixelData(
                fromImageData: encoded,
                canvasSize: CGSize(width: 6, height: 4)
            )
        )

        XCTAssertEqual(fitted.count, 6 * 4 * 4)
    }
}
