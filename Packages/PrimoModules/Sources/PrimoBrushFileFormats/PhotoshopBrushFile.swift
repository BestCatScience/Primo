import Foundation
import PrimoCoreTypes

public struct ImportedPhotoshopBrushSample: Equatable, Sendable {
    public let name: String
    public let tip: BrushTipRaster

    public init(name: String, tip: BrushTipRaster) {
        self.name = name
        self.tip = tip
    }
}

public enum PhotoshopBrushFile {
    public static func importABR(
        from sourceURL: URL,
        fileClient: FileClient = .live
    ) throws -> [ImportedPhotoshopBrushSample] {
        let data = try fileClient.readData(sourceURL)
        try validateABRHeader(data)
        let parser = ABRParser(data: data, sourceName: sourceURL.deletingPathExtension().lastPathComponent)
        return try parser.parse().enumerated().map { index, sample in
            let suggestedName = sample.name.isEmpty
                ? "\(sourceURL.deletingPathExtension().lastPathComponent) \(index + 1)"
                : sample.name
            let raster = BrushTipRaster.normalizedABRTip(
                width: sample.width,
                height: sample.height,
                alpha: sample.alpha
            )
            return ImportedPhotoshopBrushSample(name: suggestedName, tip: raster)
        }
    }

    private static func validateABRHeader(_ data: Data) throws {
        guard data.count >= 2 else {
            throw PhotoshopBrushImportError.invalidABR
        }

        if data.starts(with: Data("<!DOCTYPE".utf8)) || data.starts(with: Data("<html".utf8)) {
            throw PhotoshopBrushImportError.htmlInsteadOfABR
        }

        let version = data.prefix(2).withUnsafeBytes { rawBuffer in
            rawBuffer.load(as: UInt16.self).bigEndian
        }
        guard [1, 2, 6].contains(version) else {
            throw PhotoshopBrushImportError.invalidABR
        }
    }
}

private extension BrushTipRaster {
    static func normalizedABRTip(width: Int, height: Int, alpha: [UInt8]) -> BrushTipRaster {
        guard width > 0, height > 0, alpha.count == width * height else {
            return BrushTipRaster(width: 1, height: 1, alphaData: Data([255]))
        }

        let direct = crop(alpha: alpha, width: width, height: height)
        let invertedSource = alpha.map { 255 &- $0 }
        let inverted = crop(alpha: invertedSource, width: width, height: height)

        let directCoverage = coverage(alpha: direct.alpha)
        let directBorder = borderCoverage(
            alpha: direct.alpha,
            width: direct.width,
            height: direct.height,
            threshold: 12
        )
        let looksInvalidAsPaintMask =
            directCoverage < 0.005 ||
            directCoverage > 0.94 ||
            directBorder > 0.72

        let best: (width: Int, height: Int, alpha: [UInt8])
        if looksInvalidAsPaintMask {
            let directScore = score(alpha: direct.alpha, width: direct.width, height: direct.height)
            let invertedScore = score(alpha: inverted.alpha, width: inverted.width, height: inverted.height)
            best = invertedScore > directScore ? inverted : direct
        } else {
            best = direct
        }

        return downsampleIfNeeded(
            BrushTipRaster(width: best.width, height: best.height, alphaData: Data(best.alpha)),
            maxDimension: 160
        )
    }

    private static func score(alpha: [UInt8], width: Int, height: Int) -> Double {
        guard width > 0, height > 0, !alpha.isEmpty else { return -Double.infinity }
        let threshold: UInt8 = 12
        let occupied = occupiedCount(alpha: alpha, threshold: threshold)
        guard occupied > 0 else { return -Double.infinity }

        let coverage = Double(occupied) / Double(width * height)
        let border = borderCoverage(alpha: alpha, width: width, height: height, threshold: threshold)
        let compactness = 1.0 - min(1.0, abs(coverage - 0.38))
        return compactness - (border * 1.35)
    }

    private static func coverage(alpha: [UInt8], threshold: UInt8 = 12) -> Double {
        guard !alpha.isEmpty else { return 0.0 }
        return Double(occupiedCount(alpha: alpha, threshold: threshold)) / Double(alpha.count)
    }

    private static func occupiedCount(alpha: [UInt8], threshold: UInt8) -> Int {
        alpha.reduce(into: 0) { result, value in
            if value > threshold { result += 1 }
        }
    }

    private static func borderCoverage(alpha: [UInt8], width: Int, height: Int, threshold: UInt8) -> Double {
        var borderPixels = 0
        var occupiedBorderPixels = 0

        for y in 0..<height {
            for x in 0..<width where x == 0 || y == 0 || x == width - 1 || y == height - 1 {
                borderPixels += 1
                if alpha[(y * width) + x] > threshold {
                    occupiedBorderPixels += 1
                }
            }
        }

        guard borderPixels > 0 else { return 0.0 }
        return Double(occupiedBorderPixels) / Double(borderPixels)
    }

    private static func crop(alpha: [UInt8], width: Int, height: Int) -> (width: Int, height: Int, alpha: [UInt8]) {
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let value = alpha[(y * width) + x]
                if value <= 2 { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return (width: 1, height: 1, alpha: [255])
        }

        let croppedWidth = maxX - minX + 1
        let croppedHeight = maxY - minY + 1
        var cropped = [UInt8](repeating: 0, count: croppedWidth * croppedHeight)
        for y in 0..<croppedHeight {
            for x in 0..<croppedWidth {
                cropped[(y * croppedWidth) + x] = alpha[((minY + y) * width) + (minX + x)]
            }
        }
        return (width: croppedWidth, height: croppedHeight, alpha: cropped)
    }

    private static func downsampleIfNeeded(_ raster: BrushTipRaster, maxDimension: Int) -> BrushTipRaster {
        let largestDimension = max(raster.width, raster.height)
        guard largestDimension > maxDimension, maxDimension > 0 else {
            return raster
        }

        let scale = Double(maxDimension) / Double(largestDimension)
        let targetWidth = max(1, Int((Double(raster.width) * scale).rounded()))
        let targetHeight = max(1, Int((Double(raster.height) * scale).rounded()))
        let source = [UInt8](raster.alphaData)
        var output = [UInt8](repeating: 0, count: targetWidth * targetHeight)

        let sourceWidth = Double(raster.width)
        let sourceHeight = Double(raster.height)

        for y in 0..<targetHeight {
            let v = (Double(y) + 0.5) / Double(targetHeight)
            let sampleY = max(0.0, min(sourceHeight - 1.0, (v * sourceHeight) - 0.5))
            let y0 = max(0, min(raster.height - 1, Int(floor(sampleY))))
            let y1 = max(0, min(raster.height - 1, y0 + 1))
            let ty = Float(sampleY - Double(y0))

            for x in 0..<targetWidth {
                let u = (Double(x) + 0.5) / Double(targetWidth)
                let sampleX = max(0.0, min(sourceWidth - 1.0, (u * sourceWidth) - 0.5))
                let x0 = max(0, min(raster.width - 1, Int(floor(sampleX))))
                let x1 = max(0, min(raster.width - 1, x0 + 1))
                let tx = Float(sampleX - Double(x0))

                let top = lerp(
                    Float(source[(y0 * raster.width) + x0]),
                    Float(source[(y0 * raster.width) + x1]),
                    tx
                )
                let bottom = lerp(
                    Float(source[(y1 * raster.width) + x0]),
                    Float(source[(y1 * raster.width) + x1]),
                    tx
                )
                let value = lerp(top, bottom, ty)
                output[(y * targetWidth) + x] = UInt8(max(0.0, min(255.0, value)).rounded())
            }
        }

        return BrushTipRaster(width: targetWidth, height: targetHeight, alphaData: Data(output))
    }

    private static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + ((b - a) * t)
    }
}

private struct ABRSample {
    let name: String
    let width: Int
    let height: Int
    let alpha: [UInt8]
}

private struct ABRHeader {
    let version: UInt16
    let subversion: UInt16
    let count: Int
    let sampleDataOffset: Int
}

private struct ABRParser {
    let data: Data
    let sourceName: String

    func parse() throws -> [ABRSample] {
        var cursor = 0
        let header = try readHeader(cursor: &cursor)
        var sampleCursor = header.sampleDataOffset
        var samples: [ABRSample] = []
        samples.reserveCapacity(header.count)
        for index in 0..<header.count {
            switch header.version {
            case 1, 2:
                if let sample = try parseV12Sample(cursor: &sampleCursor, version: header.version, index: index) {
                    samples.append(sample)
                }
            case 6:
                if let sample = try parseV6Sample(cursor: &sampleCursor, subversion: header.subversion, index: index) {
                    samples.append(sample)
                }
            default:
                break
            }
        }
        return samples
    }

    private func readHeader(cursor: inout Int) throws -> ABRHeader {
        let version = try data.abrReadBEUInt16(cursor: &cursor)
        switch version {
        case 1, 2:
            let count = Int(try data.abrReadBEUInt16(cursor: &cursor))
            return ABRHeader(version: version, subversion: 0, count: count, sampleDataOffset: cursor)
        case 6:
            let subversion = try data.abrReadBEUInt16(cursor: &cursor)
            let sampleOffset = try findSection(named: "samp", from: cursor)
            var sampleCursor = sampleOffset
            let sectionLength = Int(try data.abrReadBEUInt32(cursor: &sampleCursor))
            let sectionEnd = sampleCursor + sectionLength
            var count = 0
            var probe = sampleCursor
            while probe < sectionEnd {
                let brushSize = Int(try data.abrReadBEUInt32(cursor: &probe))
                let padded = brushSize + ((4 - (brushSize % 4)) % 4)
                probe += padded
                count += 1
            }
            return ABRHeader(version: version, subversion: subversion, count: count, sampleDataOffset: sampleCursor)
        default:
            throw PhotoshopBrushImportError.unsupportedVersion(version)
        }
    }

    private func findSection(named name: String, from offset: Int) throws -> Int {
        var cursor = offset
        while cursor + 12 <= data.count {
            let signature = try data.abrReadASCII(length: 4, cursor: &cursor)
            guard signature == "8BIM" else {
                throw PhotoshopBrushImportError.invalidABR
            }
            let tag = try data.abrReadASCII(length: 4, cursor: &cursor)
            if tag == name {
                return cursor
            }
            let length = Int(try data.abrReadBEUInt32(cursor: &cursor))
            cursor += length
        }
        throw PhotoshopBrushImportError.missingSampleSection
    }

    private func parseV12Sample(cursor: inout Int, version: UInt16, index: Int) throws -> ABRSample? {
        let brushType = try data.abrReadBEUInt16(cursor: &cursor)
        let brushSize = Int(try data.abrReadBEUInt32(cursor: &cursor))
        let nextBrush = cursor + brushSize
        guard brushType == 2 else {
            cursor = nextBrush
            return nil
        }

        cursor += 6
        let name: String
        if version == 2, let parsed = try readUCS2String(cursor: &cursor) {
            name = parsed
        } else {
            name = "\(sourceName) \(index + 1)"
        }
        cursor += 9
        let top = Int(try data.abrReadBEUInt32(cursor: &cursor))
        let left = Int(try data.abrReadBEUInt32(cursor: &cursor))
        let bottom = Int(try data.abrReadBEUInt32(cursor: &cursor))
        let right = Int(try data.abrReadBEUInt32(cursor: &cursor))
        let depth = Int(try data.abrReadBEUInt16(cursor: &cursor))
        let compression = try data.abrReadUInt8(cursor: &cursor)

        let width = right - left
        let height = bottom - top
        guard width > 0, height > 0, depth == 8 else {
            cursor = nextBrush
            return nil
        }

        let alpha = try readBitmap(cursor: &cursor, width: width, height: height, compression: compression)
        cursor = nextBrush
        return ABRSample(name: name, width: width, height: height, alpha: alpha)
    }

    private func parseV6Sample(cursor: inout Int, subversion: UInt16, index: Int) throws -> ABRSample? {
        let brushSize = Int(try data.abrReadBEUInt32(cursor: &cursor))
        let paddedSize = brushSize + ((4 - (brushSize % 4)) % 4)
        let nextBrush = cursor + paddedSize

        cursor += 37
        if subversion == 1 {
            cursor += 10
        } else if subversion == 2 {
            cursor += 264
        } else {
            throw PhotoshopBrushImportError.unsupportedSubversion(subversion)
        }

        let top = Int(try data.abrReadBEUInt32(cursor: &cursor))
        let left = Int(try data.abrReadBEUInt32(cursor: &cursor))
        let bottom = Int(try data.abrReadBEUInt32(cursor: &cursor))
        let right = Int(try data.abrReadBEUInt32(cursor: &cursor))
        let depth = Int(try data.abrReadBEUInt16(cursor: &cursor))
        let compression = try data.abrReadUInt8(cursor: &cursor)
        let width = right - left
        let height = bottom - top
        guard width > 0, height > 0, depth == 8 else {
            cursor = nextBrush
            return nil
        }

        let alpha = try readBitmap(cursor: &cursor, width: width, height: height, compression: compression)
        cursor = nextBrush
        return ABRSample(name: "\(sourceName) \(index + 1)", width: width, height: height, alpha: alpha)
    }

    private func readBitmap(cursor: inout Int, width: Int, height: Int, compression: UInt8) throws -> [UInt8] {
        if compression == 0 {
            return try data.abrReadBytes(length: width * height, cursor: &cursor)
        }
        if compression == 1 {
            return try decodeRLE(cursor: &cursor, width: width, height: height)
        }
        throw PhotoshopBrushImportError.unsupportedCompression(compression)
    }

    private func decodeRLE(cursor: inout Int, width: Int, height: Int) throws -> [UInt8] {
        var scanlineLengths: [Int] = []
        scanlineLengths.reserveCapacity(height)
        for _ in 0..<height {
            scanlineLengths.append(Int(try data.abrReadBEUInt16(cursor: &cursor)))
        }

        var output: [UInt8] = []
        output.reserveCapacity(width * height)

        for scanlineLength in scanlineLengths {
            let lineEnd = cursor + scanlineLength
            while cursor < lineEnd && output.count < width * height {
                let nByte = try data.abrReadUInt8(cursor: &cursor)
                let n = Int(Int8(bitPattern: nByte))
                if n < 0 {
                    if n == -128 { continue }
                    let value = try data.abrReadUInt8(cursor: &cursor)
                    for _ in 0..<(-n + 1) {
                        output.append(value)
                    }
                } else {
                    let count = n + 1
                    output.append(contentsOf: try data.abrReadBytes(length: count, cursor: &cursor))
                }
            }
        }
        if output.count > width * height {
            output = Array(output.prefix(width * height))
        }
        return output
    }

    private func readUCS2String(cursor: inout Int) throws -> String? {
        let characterCount = Int(try data.abrReadBEUInt32(cursor: &cursor))
        if characterCount == 0 {
            return nil
        }
        let raw = try data.abrReadData(length: characterCount * 2, cursor: &cursor)
        return String(data: raw, encoding: .utf16BigEndian)?.trimmingCharacters(in: .controlCharacters)
    }
}

public enum PhotoshopBrushImportError: Error {
    case invalidABR
    case htmlInsteadOfABR
    case missingSampleSection
    case unsupportedVersion(UInt16)
    case unsupportedSubversion(UInt16)
    case unsupportedCompression(UInt8)
}

extension PhotoshopBrushImportError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidABR:
            return "The selected file is not a valid Photoshop ABR brush file."
        case .htmlInsteadOfABR:
            return "The selected .abr file is actually an HTML page, not a Photoshop brush. Please re-download the real ABR file."
        case .missingSampleSection:
            return "This ABR file does not contain a sampled brush section that primo can import yet."
        case let .unsupportedVersion(version):
            return "ABR version \(version) is not supported yet."
        case let .unsupportedSubversion(subversion):
            return "ABR subversion \(subversion) is not supported yet."
        case let .unsupportedCompression(compression):
            return "ABR compression method \(compression) is not supported yet."
        }
    }
}

private extension Data {
    func abrReadUInt8(cursor: inout Int) throws -> UInt8 {
        guard cursor < count else { throw PhotoshopBrushImportError.invalidABR }
        defer { cursor += 1 }
        return self[startIndex.advanced(by: cursor)]
    }

    func abrReadBEUInt16(cursor: inout Int) throws -> UInt16 {
        let chunk = try abrReadData(length: 2, cursor: &cursor)
        let bytes = [UInt8](chunk)
        return (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
    }

    func abrReadBEUInt32(cursor: inout Int) throws -> UInt32 {
        let chunk = try abrReadData(length: 4, cursor: &cursor)
        let bytes = [UInt8](chunk)
        return (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
    }

    func abrReadASCII(length: Int, cursor: inout Int) throws -> String {
        let chunk = try abrReadData(length: length, cursor: &cursor)
        guard let string = String(data: chunk, encoding: .ascii) else {
            throw PhotoshopBrushImportError.invalidABR
        }
        return string
    }

    func abrReadBytes(length: Int, cursor: inout Int) throws -> [UInt8] {
        Array(try abrReadData(length: length, cursor: &cursor))
    }

    func abrReadData(length: Int, cursor: inout Int) throws -> Data {
        guard length >= 0, cursor >= 0, cursor + length <= count else {
            throw PhotoshopBrushImportError.invalidABR
        }
        let range = cursor..<(cursor + length)
        cursor += length
        return subdata(in: range)
    }
}
