import CoreGraphics
import PrimoDocumentApplication
import PrimoDocumentContracts
import XCTest
@testable import Primo

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
                gpuOperations: imageImportGpuOperations()
            )
        )

        XCTAssertEqual(fitted.count, 6 * 4 * 4)
    }

    private func imageImportGpuOperations() -> DocumentGpuOperationGateway {
        DocumentGpuOperationGateway(
            compositedPaperPreviewRGBA: { _, _, _, _ in nil },
            compositedPreviewPixelData: { _, _, _ in nil },
            compositedPreviewIncrementalUpdate: { _, _, _, _ in nil },
            selectionOverlayRGBA: { _, _, _ in nil },
            eyedropperLoupeRGBA: { _, _, _, _, _, _, _, _ in nil },
            shapePreviewSurface: { _, _, _, _ in nil },
            textLayerSurface: { _, _ in nil },
            textLayoutRect: { _, _ in nil },
            processedLayerPixelData: { _, _, _, _ in nil },
            alphaMask: { _, _, _ in nil },
            croppedSelectionMask: { _, _, _ in nil },
            combinedSelectionMask: { _, _, _, _, _ in nil },
            expandedSelectionMask: { _ in nil },
            lassoSelection: { _, _, _ in nil },
            autoSelection: { _, _, _, _, _, _, _, _, _ in nil },
            colorRangeSelection: { _, _, _, _ in nil },
            expandedMask: { _, _, _, _ in nil },
            contractedMask: { _, _, _, _ in nil },
            featheredMask: { _, _, _, _ in nil },
            invertMask: { _ in nil },
            transformedSelectionMask: { _ in nil },
            transformedLayerPixelData: { _ in nil },
            scaledPixelData: { data, _, _, targetWidth, targetHeight in
                let pixel = data.prefix(4)
                return Data(Array(repeating: Array(pixel), count: targetWidth * targetHeight).flatMap { $0 })
            },
            translatedPixelData: { data, sourceWidth, sourceHeight, targetWidth, targetHeight, offsetX, offsetY in
                var output = Data(repeating: 0, count: targetWidth * targetHeight * 4)
                for y in 0..<sourceHeight {
                    for x in 0..<sourceWidth {
                        let sourceIndex = (y * sourceWidth + x) * 4
                        let targetX = x + offsetX
                        let targetY = y + offsetY
                        guard targetX >= 0, targetX < targetWidth, targetY >= 0, targetY < targetHeight else {
                            continue
                        }
                        let targetIndex = (targetY * targetWidth + targetX) * 4
                        output.replaceSubrange(targetIndex..<(targetIndex + 4), with: data[sourceIndex..<(sourceIndex + 4)])
                    }
                }
                return output
            },
            releaseSurfaceHandle: { _ in }
        )
    }
}
