import Foundation
import PrimoBrushFileFormats
import Testing

struct BrushTipFileTests {
    @Test
    func encodeDecodeRoundTripPreservesPayload() throws {
        let original = BrushTipFile(
            name: "Sample",
            width: 2,
            height: 2,
            alphaData: Data([0, 64, 128, 255])
        )

        let encoded = try original.encodedData()
        let decoded = try BrushTipFile.decode(from: encoded)

        #expect(decoded == original)
        #expect(decoded.raster == BrushTipRaster(width: 2, height: 2, alphaData: Data([0, 64, 128, 255])))
    }
}
