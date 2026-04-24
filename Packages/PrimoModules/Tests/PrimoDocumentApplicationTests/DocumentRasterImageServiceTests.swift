import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentMetalRuntimeInfrastructure
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
    func applyingInpaintCropReplacesSelectedPixels() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let base = Data([
            10, 20, 30, 255,
            40, 50, 60, 255,
            70, 80, 90, 255,
            100, 110, 120, 255,
        ])
        let edited = Data([
            200, 210, 220, 255,
        ])
        let crop = InpaintCrop(
            pixelData: Data([
                40, 50, 60, 255,
            ]),
            width: 1,
            height: 1,
            originX: 1,
            originY: 0,
            selectionMask: [255]
        )

        let output = DocumentRasterImageService.applyingInpaintCrop(
            edited,
            to: base,
            canvasWidth: 2,
            canvasHeight: 2,
            crop: crop,
            featherRadius: 0
        )

        if client.isAvailable {
            #expect(output == Data([
                10, 20, 30, 255,
                200, 210, 220, 255,
                70, 80, 90, 255,
                100, 110, 120, 255,
            ]))
        } else {
            #expect(output == nil)
        }
    }

    @Test
    func inpaintCropExtractsExpectedBoundsPixelsAndMask() throws {
        let client = PrimoMetalDocumentProcessingClient.shared
        let source = Data([
            1, 2, 3, 255, 11, 12, 13, 255, 21, 22, 23, 255,
            31, 32, 33, 255, 41, 42, 43, 255, 51, 52, 53, 255,
            61, 62, 63, 255, 71, 72, 73, 255, 81, 82, 83, 255,
        ])

        let crop = DocumentRasterImageService.inpaintCrop(
            source: source,
            canvasWidth: 3,
            canvasHeight: 3,
            selectionBounds: CGRect(x: 1, y: 1, width: 1, height: 1),
            expandedMask: [
                0, 0, 0,
                0, 255, 0,
                0, 0, 0,
            ],
            padding: 1
        )

        if client.isAvailable {
            let resolved = try #require(crop)
            #expect(resolved.width == 3)
            #expect(resolved.height == 3)
            #expect(resolved.originX == 0)
            #expect(resolved.originY == 0)
            #expect(resolved.pixelData == source)
            #expect(resolved.selectionMask == [
                0, 0, 0,
                0, 255, 0,
                0, 0, 0,
            ])
        } else {
            #expect(crop == nil)
        }
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
