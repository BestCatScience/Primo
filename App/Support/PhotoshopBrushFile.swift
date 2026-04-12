import Foundation
import SwiftUI

struct ImportedPhotoshopBrush: Equatable, Sendable {
    let name: String
    let tip: BrushTipRaster
    let preset: BrushPreset
}

enum PhotoshopBrushFile {
    static func importABR(from sourceURL: URL) throws -> [ImportedPhotoshopBrush] {
        let data = try Data(contentsOf: sourceURL)
        try validateABRHeader(data)
        let parser = ABRParser(data: data, sourceName: sourceURL.deletingPathExtension().lastPathComponent)
        return try parser.parse().enumerated().map { index, sample in
            let suggestedName = sample.name.isEmpty ? "\(sourceURL.deletingPathExtension().lastPathComponent) \(index + 1)" : sample.name
            let raster = BrushTipRaster.normalizedABRTip(width: sample.width, height: sample.height, alpha: sample.alpha)
            let preset = BrushPreset.photoshopImported(name: suggestedName, tip: raster)
            return ImportedPhotoshopBrush(name: suggestedName, tip: raster, preset: preset)
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
        let directBorder = borderCoverage(alpha: direct.alpha, width: direct.width, height: direct.height, threshold: 12)
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

enum PhotoshopBrushImportError: Error {
    case invalidABR
    case htmlInsteadOfABR
    case missingSampleSection
    case unsupportedVersion(UInt16)
    case unsupportedSubversion(UInt16)
    case unsupportedCompression(UInt8)
}

extension PhotoshopBrushImportError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidABR:
            return "The selected file is not a valid Photoshop ABR brush file."
        case .htmlInsteadOfABR:
            return "The selected .abr file is actually an HTML page, not a Photoshop brush. Please re-download the real ABR file."
        case .missingSampleSection:
            return "This ABR file does not contain a sampled brush section that atelierprime can import yet."
        case let .unsupportedVersion(version):
            return "ABR version \(version) is not supported yet."
        case let .unsupportedSubversion(subversion):
            return "ABR subversion \(subversion) is not supported yet."
        case let .unsupportedCompression(compression):
            return "ABR compression method \(compression) is not supported yet."
        }
    }
}

extension BrushPreset {
    static func photoshopImported(name: String, tip: BrushTipRaster) -> BrushPreset {
        let analysis = BrushTipAnalyzer.analyze(tip)
        let importedRadius = Double(max(tip.width, tip.height)) * 0.5
        let radius = min(max(1.0, importedRadius), 48.0)
        return BrushPreset(
            name: name,
            tipKind: .ink,
            color: Color(red: 0.08, green: 0.08, blue: 0.09),
            radius: max(1.0, radius),
            sizeSpeedSensitivity: analysis.sizeSpeedSensitivity,
            taperIn: 0.0,
            taperOut: 0.0,
            opacity: 1.0,
            hardness: analysis.hardness,
            roundness: analysis.roundness,
            roundnessPressureSensitivity: analysis.roundnessPressureSensitivity,
            roundnessTiltSensitivity: analysis.roundnessTiltSensitivity,
            angle: analysis.angle,
            anglePressureSensitivity: analysis.anglePressureSensitivity,
            angleTiltSensitivity: analysis.angleTiltSensitivity,
            angleMode: .fixed,
            spacing: analysis.spacing,
            spacingJitter: analysis.spacingJitter,
            scatterEnabled: analysis.scatterEnabled,
            scatterMode: analysis.scatterMode,
            scatterLateral: analysis.scatterLateral,
            scatterLinear: analysis.scatterLinear,
            count: analysis.count,
            countJitter: analysis.countJitter,
            countSizeJitter: analysis.countSizeJitter,
            countOpacityJitter: analysis.countOpacityJitter,
            angleJitter: analysis.angleJitter,
            roundnessJitter: analysis.roundnessJitter,
            textureMode: analysis.textureMode,
            textureStrength: analysis.textureStrength,
            flow: analysis.flow,
            flowPressureSensitivity: analysis.flowPressureSensitivity,
            flowJitter: analysis.flowJitter,
            wetness: analysis.wetness,
            wetnessPressureSensitivity: analysis.wetnessPressureSensitivity,
            opacityPressureSensitivity: analysis.opacityPressureSensitivity,
            colorMixStrength: analysis.colorMixStrength,
            paintLoad: analysis.paintLoad,
            loadPressureSensitivity: analysis.loadPressureSensitivity,
            dualBrushEnabled: analysis.dualBrushEnabled,
            dualTipKind: analysis.dualTipKind,
            dualScale: analysis.dualScale,
            dualSpacing: analysis.dualSpacing,
            dualScatter: analysis.dualScatter,
            dualAngle: analysis.dualAngle,
            dualBlendMode: analysis.dualBlendMode,
            grainScale: analysis.grainScale,
            grainContrast: analysis.grainContrast,
            paperScale: analysis.paperScale,
            paperStrength: analysis.paperStrength,
            paperThreshold: analysis.paperThreshold,
            flipX: false,
            flipY: false,
            customTip: tip,
            pressureSensitivity: 0.35,
            red: 20,
            green: 20,
            blue: 22
        )
    }
}

private enum BrushTipAnalyzer {
    struct Result {
        let roundness: Double
        let roundnessPressureSensitivity: Double
        let roundnessTiltSensitivity: Double
        let angle: Double
        let anglePressureSensitivity: Double
        let angleTiltSensitivity: Double
        let spacing: Double
        let spacingJitter: Double
        let scatterEnabled: Bool
        let scatterMode: BrushScatterMode
        let scatterLateral: Double
        let scatterLinear: Double
        let count: Int
        let countJitter: Double
        let countSizeJitter: Double
        let countOpacityJitter: Double
        let angleJitter: Double
        let roundnessJitter: Double
        let hardness: Double
        let sizeSpeedSensitivity: Double
        let flow: Double
        let flowPressureSensitivity: Double
        let flowJitter: Double
        let textureMode: BrushTextureMode
        let textureStrength: Double
        let wetness: Double
        let wetnessPressureSensitivity: Double
        let opacityPressureSensitivity: Double
        let colorMixStrength: Double
        let paintLoad: Double
        let loadPressureSensitivity: Double
        let dualBrushEnabled: Bool
        let dualTipKind: BrushTipKind
        let dualScale: Double
        let dualSpacing: Double
        let dualScatter: Double
        let dualAngle: Double
        let dualBlendMode: BrushDualBlendMode
        let grainScale: Double
        let grainContrast: Double
        let paperScale: Double
        let paperStrength: Double
        let paperThreshold: Double
    }

    static func analyze(_ tip: BrushTipRaster) -> Result {
        let width = tip.width
        let height = tip.height
        let alpha = [UInt8](tip.alphaData)
        guard width > 0, height > 0, !alpha.isEmpty else {
            return Result(
                roundness: 1.0,
                roundnessPressureSensitivity: 0.0,
                roundnessTiltSensitivity: 0.0,
                angle: 0.0,
                anglePressureSensitivity: 0.0,
                angleTiltSensitivity: 0.0,
                spacing: 0.25,
                spacingJitter: 0.0,
                scatterEnabled: false,
                scatterMode: .directional,
                scatterLateral: 0.0,
                scatterLinear: 0.0,
                count: 1,
                countJitter: 0.0,
                countSizeJitter: 0.0,
                countOpacityJitter: 0.0,
                angleJitter: 0.0,
                roundnessJitter: 0.0,
                hardness: 0.95,
                sizeSpeedSensitivity: 0.0,
                flow: 1.0,
                flowPressureSensitivity: 0.08,
                flowJitter: 0.0,
                textureMode: .off,
                textureStrength: 0.0,
                wetness: 0.0,
                wetnessPressureSensitivity: 0.0,
                opacityPressureSensitivity: 0.4,
                colorMixStrength: 0.0,
                paintLoad: 1.0,
                loadPressureSensitivity: 0.0,
                dualBrushEnabled: false,
                dualTipKind: .ink,
                dualScale: 0.72,
                dualSpacing: 0.26,
                dualScatter: 0.18,
                dualAngle: 0.0,
                dualBlendMode: .multiply,
                grainScale: 1.2,
                grainContrast: 1.5,
                paperScale: 0.12,
                paperStrength: 0.2,
                paperThreshold: 0.42
            )
        }

        var totalWeight = 0.0
        var meanX = 0.0
        var meanY = 0.0
        var occupiedCount = 0
        var softEdgeCount = 0
        for y in 0..<height {
            for x in 0..<width {
                let value = Double(alpha[(y * width) + x]) / 255.0
                totalWeight += value
                meanX += Double(x) * value
                meanY += Double(y) * value
                if value > 0.08 { occupiedCount += 1 }
                if value > 0.08 && value < 0.92 { softEdgeCount += 1 }
            }
        }
        guard totalWeight > 0.0001 else {
            return Result(
                roundness: 1.0, roundnessPressureSensitivity: 0.0, roundnessTiltSensitivity: 0.0, angle: 0.0, anglePressureSensitivity: 0.0, angleTiltSensitivity: 0.0, spacing: 0.25, spacingJitter: 0.0, scatterEnabled: false, scatterMode: .directional, scatterLateral: 0.0, scatterLinear: 0.0,
                count: 1, countJitter: 0.0, countSizeJitter: 0.0, countOpacityJitter: 0.0, angleJitter: 0.0, roundnessJitter: 0.0, hardness: 0.95, sizeSpeedSensitivity: 0.0, flow: 1.0, flowPressureSensitivity: 0.08, flowJitter: 0.0,
                textureMode: .off, textureStrength: 0.0, wetness: 0.0, wetnessPressureSensitivity: 0.0, opacityPressureSensitivity: 0.4, colorMixStrength: 0.0, paintLoad: 1.0, loadPressureSensitivity: 0.0, dualBrushEnabled: false, dualTipKind: .ink,
                dualScale: 0.72, dualSpacing: 0.26, dualScatter: 0.18, dualAngle: 0.0, dualBlendMode: .multiply,
                grainScale: 1.2, grainContrast: 1.5, paperScale: 0.12, paperStrength: 0.2, paperThreshold: 0.42
            )
        }
        meanX /= totalWeight
        meanY /= totalWeight

        var covXX = 0.0
        var covYY = 0.0
        var covXY = 0.0
        for y in 0..<height {
            for x in 0..<width {
                let value = Double(alpha[(y * width) + x]) / 255.0
                if value <= 0 { continue }
                let dx = Double(x) - meanX
                let dy = Double(y) - meanY
                covXX += dx * dx * value
                covYY += dy * dy * value
                covXY += dx * dy * value
            }
        }
        covXX /= totalWeight
        covYY /= totalWeight
        covXY /= totalWeight
        let trace = covXX + covYY
        let determinant = (covXX * covYY) - (covXY * covXY)
        let root = sqrt(max(0.0, (trace * trace * 0.25) - determinant))
        let major = max(trace * 0.5 + root, 0.0001)
        let minor = max(trace * 0.5 - root, 0.0001)
        let roundness = max(0.12, min(1.0, sqrt(minor / major)))
        let angle = 0.5 * atan2(2.0 * covXY, covXX - covYY)

        let coverage = Double(occupiedCount) / Double(width * height)
        let softness = occupiedCount > 0 ? Double(softEdgeCount) / Double(occupiedCount) : 0.0
        let components = connectedComponentStats(alpha: alpha, width: width, height: height)
        let detachedCoverage = max(0.0, components.detachedCoverage)
        let islands = max(0, components.count - 1)
        let sparseTip = coverage < 0.34 || detachedCoverage > 0.03 || islands >= 2
        let elongated = roundness < 0.62
        let textureStrength = min(0.92, max(0.12, (softness * 0.55) + (detachedCoverage * 2.8)))
        let paperStrength = min(0.72, max(0.12, (1.0 - coverage) * 0.34 + softness * 0.28))

        return Result(
            roundness: roundness,
            roundnessPressureSensitivity: min(0.32, max(0.0, (1.0 - roundness) * 0.20)),
            roundnessTiltSensitivity: min(0.42, max(0.0, (1.0 - roundness) * 0.34)),
            angle: angle,
            anglePressureSensitivity: min(0.16, max(0.0, (1.0 - roundness) * 0.10)),
            angleTiltSensitivity: min(0.34, max(0.0, (1.0 - roundness) * 0.22)),
            spacing: min(0.55, max(0.08, 0.18 + ((1.0 - coverage) * 0.22))),
            spacingJitter: min(0.24, detachedCoverage * 0.35),
            scatterEnabled: sparseTip || detachedCoverage > 0.015 || islands >= 2,
            scatterMode: sparseTip ? .spray : .directional,
            scatterLateral: min(0.32, detachedCoverage * 0.8 + Double(islands) * 0.03),
            scatterLinear: min(0.16, detachedCoverage * 0.28),
            count: islands >= 2 ? 2 : 1,
            countJitter: islands >= 2 ? min(0.35, Double(islands) * 0.08) : 0.0,
            countSizeJitter: sparseTip ? min(0.48, 0.12 + detachedCoverage * 1.4 + softness * 0.18) : min(0.18, softness * 0.14),
            countOpacityJitter: sparseTip ? min(0.44, 0.10 + detachedCoverage * 1.1 + softness * 0.14) : min(0.14, softness * 0.10),
            angleJitter: min(0.22, (1.0 - roundness) * 0.12),
            roundnessJitter: min(0.18, softness * 0.2),
            hardness: min(0.98, max(0.55, 0.98 - (softness * 0.45))),
            sizeSpeedSensitivity: min(0.22, max(0.0, detachedCoverage * 0.9 + softness * 0.10)),
            flow: min(1.0, max(0.55, 0.88 + (coverage * 0.18) - (softness * 0.12))),
            flowPressureSensitivity: min(0.48, max(0.06, softness * 0.30 + detachedCoverage * 0.42)),
            flowJitter: min(0.36, max(0.0, detachedCoverage * 1.6 + softness * 0.12)),
            textureMode: textureStrength > 0.16 ? .eachTip : .strokeLocked,
            textureStrength: textureStrength,
            wetness: min(0.72, max(0.0, detachedCoverage * 1.35 + softness * 0.24)),
            wetnessPressureSensitivity: min(0.74, max(0.0, softness * 0.55 + detachedCoverage * 1.1)),
            opacityPressureSensitivity: min(0.88, max(0.18, 0.32 + softness * 0.44)),
            colorMixStrength: min(0.56, max(0.0, detachedCoverage * 1.8 + softness * 0.18)),
            paintLoad: min(1.0, max(0.42, 0.94 - softness * 0.34 - detachedCoverage * 1.2)),
            loadPressureSensitivity: min(0.66, max(0.0, softness * 0.42 + detachedCoverage * 0.9)),
            dualBrushEnabled: sparseTip,
            dualTipKind: elongated ? .ink : .pencil,
            dualScale: elongated ? 0.58 : 0.72,
            dualSpacing: sparseTip ? min(0.52, 0.22 + detachedCoverage * 2.1 + Double(islands) * 0.04) : 0.22,
            dualScatter: sparseTip ? min(0.45, detachedCoverage * 3.2 + Double(islands) * 0.05) : 0.08,
            dualAngle: angle * 0.65,
            dualBlendMode: sparseTip ? .multiply : .darker,
            grainScale: min(2.4, max(0.8, 1.08 + softness * 1.4)),
            grainContrast: min(2.6, max(1.1, 1.35 + (1.0 - coverage) * 1.2)),
            paperScale: min(0.28, max(0.08, 0.10 + detachedCoverage * 1.6 + softness * 0.06)),
            paperStrength: paperStrength,
            paperThreshold: min(0.68, max(0.28, 0.38 + (1.0 - coverage) * 0.12))
        )
    }

    private struct ComponentStats {
        let count: Int
        let detachedCoverage: Double
    }

    private static func connectedComponentStats(alpha: [UInt8], width: Int, height: Int) -> ComponentStats {
        var visited = [Bool](repeating: false, count: width * height)
        var componentAreas: [Int] = []
        let threshold: UInt8 = 32
        let directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width) + x
                if visited[index] || alpha[index] < threshold { continue }
                var queue: [(Int, Int)] = [(x, y)]
                visited[index] = true
                var area = 0
                while !queue.isEmpty {
                    let (cx, cy) = queue.removeLast()
                    area += 1
                    for (dx, dy) in directions {
                        let nx = cx + dx
                        let ny = cy + dy
                        guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                        let nIndex = (ny * width) + nx
                        if visited[nIndex] || alpha[nIndex] < threshold { continue }
                        visited[nIndex] = true
                        queue.append((nx, ny))
                    }
                }
                componentAreas.append(area)
            }
        }

        guard let largest = componentAreas.max(), largest > 0 else {
            return ComponentStats(count: 0, detachedCoverage: 0.0)
        }
        let detached = componentAreas.reduce(0, +) - largest
        let detachedCoverage = Double(detached) / Double(max(width * height, 1))
        return ComponentStats(count: componentAreas.count, detachedCoverage: detachedCoverage)
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
