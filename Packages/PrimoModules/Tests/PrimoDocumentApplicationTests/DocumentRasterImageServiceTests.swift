import Foundation
import PrimoDocumentApplication
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
}
