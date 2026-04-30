import Foundation

public enum CanvasSizePolicy: Sendable {
    public static let maxCanvasDimension = 8192
    public static let maxPixelCount = 8192 * 8192
    public static let maxLayerCount = 512
    public static let maxDocumentLayerPixelBytes = 1024 * 1024 * 1024
    public static let maxFolderCount = 256
    public static let maxLayerNameLength = 256
    public static let maxTimelapseOperationCount = 250_000
    public static let maxLassoPointCount = 4096
    public static let maxStrokeSampleCount = 262_144
    public static let maxInterpolatedSamplesPerEvent = 512
    public static let maxVideoDimension = 4096

    public static func safePixelCount(
        width: Int,
        height: Int,
        maxPixels: Int = maxPixelCount
    ) -> Int? {
        guard width > 0, height > 0 else { return nil }
        guard width <= maxCanvasDimension, height <= maxCanvasDimension else { return nil }
        let pixels = width.multipliedReportingOverflow(by: height)
        guard !pixels.overflow, pixels.partialValue <= maxPixels else { return nil }
        return pixels.partialValue
    }

    public static func safeRGBAByteCount(width: Int, height: Int) -> Int? {
        guard let pixels = safePixelCount(width: width, height: height) else { return nil }
        let bytes = pixels.multipliedReportingOverflow(by: 4)
        guard !bytes.overflow else { return nil }
        return bytes.partialValue
    }

    public static func safeMaskByteCount(width: Int, height: Int) -> Int? {
        safePixelCount(width: width, height: height)
    }

    public static func fitsUInt32(_ value: Int) -> Bool {
        value >= 0 && value <= Int(UInt32.max)
    }

    public static func fitsPositiveUInt32(_ value: Int) -> Bool {
        value > 0 && value <= Int(UInt32.max)
    }

    public static func safeRectRGBAByteCount(width: Int, height: Int) -> Int? {
        safeRGBAByteCount(width: width, height: height)
    }

    public static func safeRectMaskByteCount(width: Int, height: Int) -> Int? {
        safeMaskByteCount(width: width, height: height)
    }

    public static func maxLayerCountForCanvas(_ geometry: PixelGeometry) -> Int {
        maxLayerCount(canvasRGBAByteCount: geometry.rgbaByteCount)
    }

    public static func maxLayerCount(canvasRGBAByteCount: Int) -> Int {
        guard canvasRGBAByteCount > 0 else { return 0 }
        return max(1, min(maxLayerCount, maxDocumentLayerPixelBytes / canvasRGBAByteCount))
    }

    public static func layerPixelBytesFitDocumentBudget(canvasRGBAByteCount: Int, layerCount: Int) -> Bool {
        guard layerCount >= 0, canvasRGBAByteCount >= 0 else { return false }
        let bytes = canvasRGBAByteCount.multipliedReportingOverflow(by: layerCount)
        return !bytes.overflow && bytes.partialValue <= maxDocumentLayerPixelBytes
    }
}

public struct PixelGeometry: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixelCount: Int
    public let rgbaByteCount: Int
    public let maskByteCount: Int

    public init?(
        width: Int,
        height: Int,
        maxPixels: Int = CanvasSizePolicy.maxPixelCount
    ) {
        guard
            let pixels = CanvasSizePolicy.safePixelCount(
                width: width,
                height: height,
                maxPixels: maxPixels
            )
        else {
            return nil
        }
        let rgba = pixels.multipliedReportingOverflow(by: 4)
        guard !rgba.overflow else { return nil }
        self.width = width
        self.height = height
        self.pixelCount = pixels
        self.rgbaByteCount = rgba.partialValue
        self.maskByteCount = pixels
    }

    public var fitsMetalUInt32: Bool {
        CanvasSizePolicy.fitsPositiveUInt32(width) &&
        CanvasSizePolicy.fitsPositiveUInt32(height)
    }
}
