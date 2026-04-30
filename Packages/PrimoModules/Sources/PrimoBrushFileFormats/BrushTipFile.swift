import CoreGraphics
import Foundation
import ImageIO
import PrimoDocumentDomain
import UniformTypeIdentifiers

@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
public extension UTType {
    static let primoBrushTip = UTType(exportedAs: "com.bestcatscience.primo.brush-tip", conformingTo: .data)
    static let primoDocument = UTType(exportedAs: "com.bestcatscience.primo.document", conformingTo: .package)
}

public struct BrushTipRaster: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let alphaData: Data

    public init(width: Int, height: Int, alphaData: Data) {
        self.width = width
        self.height = height
        self.alphaData = alphaData
    }
}

public struct BrushTipFile: Equatable, Sendable {
    public static let fileExtension = "aptip"
    public static let maxEncodedByteCount = 32 * 1024 * 1024
    public static let maxNameByteCount = 256

    public let name: String
    public let width: Int
    public let height: Int
    public let alphaData: Data

    public init(name: String, width: Int, height: Int, alphaData: Data) {
        self.name = name
        self.width = width
        self.height = height
        self.alphaData = alphaData
    }

    public var raster: BrushTipRaster {
        BrushTipRaster(width: width, height: height, alphaData: alphaData)
    }

    public func encodedData() throws -> Data {
        guard let geometry = PixelGeometry(width: width, height: height),
              alphaData.count == geometry.maskByteCount,
              width <= Int(UInt32.max),
              height <= Int(UInt32.max) else {
            throw BrushTipFileError.invalidPayload
        }
        let nameData = Data(name.utf8)
        guard nameData.count <= Self.maxNameByteCount,
              nameData.count <= Int(UInt32.max),
              alphaData.count <= Int(UInt32.max) else {
            throw BrushTipFileError.invalidPayload
        }
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

    public static func decode(from data: Data) throws -> BrushTipFile {
        guard data.count <= maxEncodedByteCount else {
            throw BrushTipFileError.invalidPayload
        }
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
        guard nameLength <= maxNameByteCount, payloadLength <= maxEncodedByteCount else {
            throw BrushTipFileError.invalidPayload
        }
        guard let geometry = PixelGeometry(width: width, height: height) else {
            throw BrushTipFileError.invalidPayload
        }
        guard payloadLength == geometry.maskByteCount else {
            throw BrushTipFileError.invalidPayload
        }
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
        guard alphaData.count == geometry.maskByteCount else {
            throw BrushTipFileError.invalidPayload
        }
        return BrushTipFile(name: name, width: width, height: height, alphaData: alphaData)
    }

    public static func importPNG(data: Data, suggestedName: String) throws -> BrushTipFile {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let metadata = validatedPNGMetadata(from: source),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw BrushTipFileError.invalidPNG
        }
        guard image.width == metadata.width, image.height == metadata.height else {
            throw BrushTipFileError.invalidPNG
        }
        let raster = try Self.makeRaster(from: image)
        return BrushTipFile(name: suggestedName, width: raster.width, height: raster.height, alphaData: raster.alphaData)
    }

    private static func makeRaster(from image: CGImage) throws -> BrushTipRaster {
        let width = image.width
        let height = image.height
        guard let geometry = PixelGeometry(width: width, height: height) else {
            throw BrushTipFileError.invalidPNG
        }

        let bytesPerPixel = 4
        let bytesPerRow = geometry.width * bytesPerPixel
        var rgba = [UInt8](repeating: 0, count: geometry.rgbaByteCount)
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

        var alpha = [UInt8](repeating: 0, count: geometry.maskByteCount)
        for index in 0..<geometry.pixelCount {
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
        guard let croppedCount = CanvasSizePolicy.safeMaskByteCount(width: croppedWidth, height: croppedHeight) else {
            return (width: 1, height: 1, alpha: [255])
        }
        var cropped = [UInt8](repeating: 0, count: croppedCount)
        for y in 0..<croppedHeight {
            for x in 0..<croppedWidth {
                cropped[(y * croppedWidth) + x] = alpha[((minY + y) * width) + (minX + x)]
            }
        }
        return (width: croppedWidth, height: croppedHeight, alpha: cropped)
    }

    private static func validatedPNGMetadata(from source: CGImageSource) -> (width: Int, height: Int)? {
        guard CGImageSourceGetCount(source) >= 1 else { return nil }
        if let typeIdentifier = CGImageSourceGetType(source) as String? {
            guard typeIdentifier == "public.png" else { return nil }
        }
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let widthValue = properties[kCGImagePropertyPixelWidth] as? NSNumber,
            let heightValue = properties[kCGImagePropertyPixelHeight] as? NSNumber
        else {
            return nil
        }
        let width = widthValue.intValue
        let height = heightValue.intValue
        guard PixelGeometry(width: width, height: height) != nil else { return nil }
        return (width, height)
    }
}

public enum BrushTipFileError: Error {
    case invalidHeader
    case unsupportedVersion
    case unsupportedCompression
    case invalidPayload
    case invalidName
    case invalidPNG
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
        let bytes = [UInt8](try readData(length: MemoryLayout<UInt16>.size, cursor: &cursor))
        return UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
    }

    func readUInt32(cursor: inout Int) throws -> UInt32 {
        let bytes = [UInt8](try readData(length: MemoryLayout<UInt32>.size, cursor: &cursor))
        return UInt32(bytes[0]) |
            (UInt32(bytes[1]) << 8) |
            (UInt32(bytes[2]) << 16) |
            (UInt32(bytes[3]) << 24)
    }
}
