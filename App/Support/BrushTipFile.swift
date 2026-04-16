import ComposableArchitecture
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension UTType {
    static let primoBrushTip = UTType(exportedAs: "com.bestcatscience.primo.brush-tip", conformingTo: .data)
    static let primoDocument = UTType(exportedAs: "com.bestcatscience.primo.document", conformingTo: .package)
}

struct BrushTipRaster: Equatable, Sendable {
    let width: Int
    let height: Int
    let alphaData: Data
}

struct BrushTipFile: Equatable, Sendable {
    static let fileExtension = "aptip"

    let name: String
    let width: Int
    let height: Int
    let alphaData: Data

    init(name: String, width: Int, height: Int, alphaData: Data) {
        self.name = name
        self.width = width
        self.height = height
        self.alphaData = alphaData
    }

    var raster: BrushTipRaster {
        BrushTipRaster(width: width, height: height, alphaData: alphaData)
    }

    func encodedData() throws -> Data {
        let nameData = Data(name.utf8)
        var data = Data()
        data.append(contentsOf: [0x41, 0x50, 0x54, 0x49, 0x50, 0x31])
        data.appendUInt16(1)
        data.appendUInt16(0)
        data.appendUInt32(UInt32(width))
        data.appendUInt32(UInt32(height))
        data.appendUInt32(UInt32(nameData.count))
        data.appendUInt32(UInt32(alphaData.count))
        data.appendUInt32(UInt32(alphaData.count))
        data.append(nameData)
        data.append(alphaData)
        return data
    }

    static func decode(from data: Data) throws -> BrushTipFile {
        var cursor = 0
        let magic = try data.readData(length: 6, cursor: &cursor)
        guard magic == Data([0x41, 0x50, 0x54, 0x49, 0x50, 0x31]) else {
            throw BrushTipFileError.invalidHeader
        }
        let version = try data.readUInt16(cursor: &cursor)
        guard version == 1 else {
            throw BrushTipFileError.unsupportedVersion
        }
        let compression = try data.readUInt16(cursor: &cursor)
        let width = Int(try data.readUInt32(cursor: &cursor))
        let height = Int(try data.readUInt32(cursor: &cursor))
        let nameLength = Int(try data.readUInt32(cursor: &cursor))
        _ = Int(try data.readUInt32(cursor: &cursor))
        let payloadLength = Int(try data.readUInt32(cursor: &cursor))
        let nameData = try data.readData(length: nameLength, cursor: &cursor)
        guard let name = String(data: nameData, encoding: .utf8) else {
            throw BrushTipFileError.invalidName
        }
        let payload = try data.readData(length: payloadLength, cursor: &cursor)
        let alphaData: Data
        switch compression {
        case 0:
            alphaData = payload
        default:
            throw BrushTipFileError.unsupportedCompression
        }
        guard alphaData.count == width * height else {
            throw BrushTipFileError.invalidPayload
        }
        return BrushTipFile(name: name, width: width, height: height, alphaData: alphaData)
    }

    static func importPNG(data: Data, suggestedName: String) throws -> BrushTipFile {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw BrushTipFileError.invalidPNG
        }
        let raster = try Self.makeRaster(from: image)
        return BrushTipFile(name: suggestedName, width: raster.width, height: raster.height, alphaData: raster.alphaData)
    }

    private static func makeRaster(from image: CGImage) throws -> BrushTipRaster {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            throw BrushTipFileError.invalidPNG
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var rgba = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(
            data: &rgba,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw BrushTipFileError.invalidPNG
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var alpha = [UInt8](repeating: 0, count: width * height)
        for index in 0..<(width * height) {
            let offset = index * bytesPerPixel
            let r = Float(rgba[offset]) / 255.0
            let g = Float(rgba[offset + 1]) / 255.0
            let b = Float(rgba[offset + 2]) / 255.0
            let a = Float(rgba[offset + 3]) / 255.0
            let luminance = (0.299 * r) + (0.587 * g) + (0.114 * b)
            let mask = max(0.0, min(1.0, (1.0 - luminance) * a))
            alpha[index] = UInt8((mask * 255.0).rounded())
        }

        let cropped = crop(alpha: alpha, width: width, height: height)
        return BrushTipRaster(width: cropped.width, height: cropped.height, alphaData: Data(cropped.alpha))
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
}

enum BrushTipFileError: Error {
    case invalidHeader
    case unsupportedVersion
    case unsupportedCompression
    case invalidPayload
    case invalidName
    case invalidPNG
}

struct BrushTipLibraryClient: Sendable {
    var loadRaster: @Sendable (URL) throws -> BrushTipRaster
    var prepareBrushTipFile: @Sendable (URL) throws -> URL
    var importPhotoshopBrushes: @Sendable (URL) throws -> [ImportedPhotoshopBrush]

    static func live(fileClient: FileClient) -> BrushTipLibraryClient {
        let storage = BrushTipLibraryStorage(fileClient: fileClient)
        return BrushTipLibraryClient(
            loadRaster: { try storage.loadRaster(from: $0) },
            prepareBrushTipFile: { try storage.prepareBrushTipFile(from: $0) },
            importPhotoshopBrushes: { try storage.importPhotoshopBrushes(from: $0) }
        )
    }
}

private enum BrushTipLibraryClientKey: DependencyKey {
    static var liveValue: BrushTipLibraryClient {
        @Dependency(\.fileClient) var fileClient
        return .live(fileClient: fileClient)
    }
}

extension DependencyValues {
    var brushTipLibraryClient: BrushTipLibraryClient {
        get { self[BrushTipLibraryClientKey.self] }
        set { self[BrushTipLibraryClientKey.self] = newValue }
    }
}

private struct BrushTipLibraryStorage {
    let fileClient: FileClient

    func loadRaster(from sourceURL: URL) throws -> BrushTipRaster {
        let resolvedURL = try prepareBrushTipFile(from: sourceURL)
        let data = try fileClient.readData(resolvedURL)
        return try BrushTipFile.decode(from: data).raster
    }

    func prepareBrushTipFile(from sourceURL: URL) throws -> URL {
        if sourceURL.pathExtension.lowercased() == BrushTipFile.fileExtension {
            return sourceURL
        }

        guard sourceURL.pathExtension.lowercased() == "png" else {
            throw BrushTipFileError.invalidPNG
        }

        let pngData = try fileClient.readData(sourceURL)
        let fileHash = SHA256.hash(data: pngData).compactMap { String(format: "%02x", $0) }.joined()
        let sanitizedName = sourceURL.deletingPathExtension().lastPathComponent
        let fileName = "\(sanitizedName)-\(fileHash.prefix(12)).\(BrushTipFile.fileExtension)"
        let targetURL = try brushTipCacheDirectory().appendingPathComponent(fileName, isDirectory: false)
        if fileClient.fileExists(targetURL.path) {
            return targetURL
        }

        let brushTipFile = try BrushTipFile.importPNG(data: pngData, suggestedName: sanitizedName)
        try fileClient.writeData(brushTipFile.encodedData(), targetURL, .atomic)
        return targetURL
    }

    func importPhotoshopBrushes(from sourceURL: URL) throws -> [ImportedPhotoshopBrush] {
        try PhotoshopBrushFile.importABR(from: sourceURL, fileClient: fileClient)
    }

    private func brushTipCacheDirectory() throws -> URL {
        let base = fileClient.urls(.applicationSupportDirectory, .userDomainMask)[0]
        let directory = base
            .appendingPathComponent("primo", isDirectory: true)
            .appendingPathComponent("BrushTips", isDirectory: true)
        try fileClient.createDirectory(directory, true)
        return directory
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    func readData(length: Int, cursor: inout Int) throws -> Data {
        guard length >= 0, cursor >= 0, cursor + length <= count else {
            throw BrushTipFileError.invalidPayload
        }
        let range = cursor..<(cursor + length)
        cursor += length
        return subdata(in: range)
    }

    func readUInt16(cursor: inout Int) throws -> UInt16 {
        let data = try readData(length: MemoryLayout<UInt16>.size, cursor: &cursor)
        guard data.count == MemoryLayout<UInt16>.size else {
            throw BrushTipFileError.invalidPayload
        }
        return data.withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
    }

    func readUInt32(cursor: inout Int) throws -> UInt32 {
        let data = try readData(length: MemoryLayout<UInt32>.size, cursor: &cursor)
        guard data.count == MemoryLayout<UInt32>.size else {
            throw BrushTipFileError.invalidPayload
        }
        return data.withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
    }
}
