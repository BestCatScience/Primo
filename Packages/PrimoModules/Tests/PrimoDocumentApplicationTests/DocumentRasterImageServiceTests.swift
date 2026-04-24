import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import Testing

struct DocumentRasterImageServiceTests {
    @Test
    func pngRoundTripPreservesPixelCount() throws {
        let pixelData = Data([
            255, 0, 0, 255,
            0, 255, 0, 255,
            0, 0, 255, 255,
            255, 255, 255, 255,
        ])

        let pngData = try #require(
            DocumentRasterImageService.pngData(
                fromLayerPixelData: pixelData,
                width: 2,
                height: 2
            )
        )
        let roundTripped = try #require(
            DocumentRasterImageService.rawLayerPixelData(
                fromPNGData: pngData,
                width: 2,
                height: 2
            )
        )

        #expect(roundTripped.count == pixelData.count)
    }

    @Test
    func decodedImageFromEncodedDataMatchesOriginalDimensions() throws {
        let surface = DocumentCompositeSurface(
            width: 2,
            height: 1,
            pixelData: Data([
                255, 0, 0, 255,
                0, 255, 0, 255,
            ])
        )

        let pngData = try #require(DocumentRasterImageService.pngData(from: surface))
        let decoded = try #require(
            DocumentRasterImageService.decodedImage(fromEncodedData: pngData)
        )

        #expect(decoded.width == 2)
        #expect(decoded.height == 1)
        #expect(decoded.pixelData.count == surface.pixelData.count)
    }

    @Test
    func mutationValidatorRejectsInvalidTargetsAndLockedLayers() {
        let validator = DocumentMutationValidator()
        let context = DocumentMutationValidationContext(
            layerCount: 3,
            folderIDs: [4, 9],
            isLayerLocked: { $0 == 1 }
        )

        #expect(
            validator.validate(.layer(index: 7), in: context) == .invalidLayerIndex(7)
        )
        #expect(
            validator.validate(.folder(folderID: 12), in: context) == .invalidFolderID(12)
        )
        #expect(
            validator.validate(.layer(index: 1, requiresUnlocked: true), in: context) == .layerLocked(1)
        )
        #expect(
            validator.validate(.layerAnchor(index: -1), in: context) == nil
        )
    }
}
