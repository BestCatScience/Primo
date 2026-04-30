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

    @Test
    func decodeRejectsHugeDimensionsBeforePayloadMathOverflows() throws {
        var data = Data()
        data.append(contentsOf: [0x41, 0x50, 0x54, 0x49, 0x50, 0x31])
        data.appendUInt16(1)
        data.appendUInt16(0)
        data.appendUInt32(UInt32.max)
        data.appendUInt32(UInt32.max)
        data.appendUInt32(4)
        data.appendUInt32(0)
        data.appendUInt32(0)
        data.append(Data("test".utf8))

        #expect(throws: BrushTipFileError.invalidPayload) {
            _ = try BrushTipFile.decode(from: data)
        }
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8(value & 0x00FF))
        append(UInt8((value >> 8) & 0x00FF))
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(UInt8(value & 0x0000_00FF))
        append(UInt8((value >> 8) & 0x0000_00FF))
        append(UInt8((value >> 16) & 0x0000_00FF))
        append(UInt8((value >> 24) & 0x0000_00FF))
    }
}
