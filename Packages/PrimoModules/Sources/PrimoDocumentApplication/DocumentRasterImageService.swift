import CoreGraphics
import Foundation
import ImageIO
import PrimoDocumentContracts
import PrimoDocumentDomain

public struct InpaintCrop: Sendable, Equatable {
    public let pixelData: Data
    public let width: Int
    public let height: Int
    public let originX: Int
    public let originY: Int
    public let selectionMask: [UInt8]

    public init(
        pixelData: Data,
        width: Int,
        height: Int,
        originX: Int,
        originY: Int,
        selectionMask: [UInt8]
    ) {
        self.pixelData = pixelData
        self.width = width
        self.height = height
        self.originX = originX
        self.originY = originY
        self.selectionMask = selectionMask
    }
}

public struct DecodedRasterImage: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let pixelData: Data

    public init(width: Int, height: Int, pixelData: Data) {
        self.width = width
        self.height = height
        self.pixelData = pixelData
    }
}

public enum DocumentRasterImageService {
    public static func decodedImage(fromEncodedData encodedData: Data) -> DecodedRasterImage? {
        guard
            let source = CGImageSourceCreateWithData(encodedData as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        guard let pixelData = rgbaPixelData(from: image, width: width, height: height) else {
            return nil
        }
        return DecodedRasterImage(width: width, height: height, pixelData: pixelData)
    }

    public static func pngData(from surface: DocumentCompositeSurface) -> Data? {
        pngData(fromLayerPixelData: surface.pixelData, width: surface.width, height: surface.height)
    }

    public static func jpegData(
        from surface: DocumentCompositeSurface,
        compressionQuality: CGFloat = 0.72
    ) -> Data? {
        encodedData(
            fromPixelData: surface.pixelData,
            width: surface.width,
            height: surface.height,
            typeIdentifier: "public.jpeg" as CFString,
            compressionQuality: compressionQuality
        )
    }

    public static func pngData(fromLayerPixelData pixelData: Data, width: Int, height: Int) -> Data? {
        encodedData(
            fromPixelData: pixelData,
            width: width,
            height: height,
            typeIdentifier: "public.png" as CFString
        )
    }

    public static func inpaintCrop(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selectionBounds: CGRect,
        expandedMask: [UInt8],
        padding: Int = 64
    ) -> InpaintCrop? {
        guard source.count == canvasWidth * canvasHeight * 4,
              expandedMask.count == canvasWidth * canvasHeight,
              canvasWidth > 0,
              canvasHeight > 0 else {
            return nil
        }
        let minX = max(0, Int(floor(selectionBounds.minX)) - padding)
        let minY = max(0, Int(floor(selectionBounds.minY)) - padding)
        let maxX = min(canvasWidth, Int(ceil(selectionBounds.maxX)) + padding)
        let maxY = min(canvasHeight, Int(ceil(selectionBounds.maxY)) + padding)
        let cropWidth = max(0, maxX - minX)
        let cropHeight = max(0, maxY - minY)
        guard cropWidth > 0, cropHeight > 0 else { return nil }
        var pixelData = Data(count: cropWidth * cropHeight * 4)
        var selectionMask = [UInt8](repeating: 0, count: cropWidth * cropHeight)
        pixelData.withUnsafeMutableBytes { destinationBytes in
            source.withUnsafeBytes { sourceBytes in
                guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let sourceBase = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else { return }
                for row in 0..<cropHeight {
                    let sourceOffset = (((minY + row) * canvasWidth) + minX) * 4
                    let destinationOffset = row * cropWidth * 4
                    memcpy(destination + destinationOffset, sourceBase + sourceOffset, cropWidth * 4)
                }
            }
        }
        for row in 0..<cropHeight {
            for column in 0..<cropWidth {
                selectionMask[row * cropWidth + column] = expandedMask[(minY + row) * canvasWidth + minX + column]
            }
        }
        return InpaintCrop(
            pixelData: pixelData,
            width: cropWidth,
            height: cropHeight,
            originX: minX,
            originY: minY,
            selectionMask: selectionMask
        )
    }

    public static func applyingInpaintCrop(
        _ editedCropPixelData: Data,
        to baseLayerPixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        crop: InpaintCrop,
        featherRadius: Int = 10
    ) -> Data? {
        guard baseLayerPixelData.count == canvasWidth * canvasHeight * 4 else { return nil }
        guard editedCropPixelData.count == crop.width * crop.height * 4 else { return nil }
        guard crop.selectionMask.count == crop.width * crop.height else { return nil }
        var output = baseLayerPixelData
        output.withUnsafeMutableBytes { destinationBytes in
            editedCropPixelData.withUnsafeBytes { sourceBytes in
                guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else { return }
                for row in 0..<crop.height {
                    let canvasY = crop.originY + row
                    guard (0..<canvasHeight).contains(canvasY) else { continue }
                    for column in 0..<crop.width {
                        let canvasX = crop.originX + column
                        guard (0..<canvasWidth).contains(canvasX) else { continue }
                        let maskIndex = row * crop.width + column
                        guard crop.selectionMask[maskIndex] > 0 else { continue }
                        let sourceOffset = maskIndex * 4
                        let destinationOffset = ((canvasY * canvasWidth) + canvasX) * 4
                        destination[destinationOffset] = source[sourceOffset]
                        destination[destinationOffset + 1] = source[sourceOffset + 1]
                        destination[destinationOffset + 2] = source[sourceOffset + 2]
                        destination[destinationOffset + 3] = source[sourceOffset + 3]
                    }
                }
            }
        }
        return output
    }

    public static func rawLayerPixelData(fromPNGData pngData: Data, width: Int, height: Int) -> Data? {
        guard
            width > 0,
            height > 0,
            let source = CGImageSourceCreateWithData(pngData as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        return rgbaPixelData(from: image, width: width, height: height)
    }

    private static func rgbaPixelData(from image: CGImage, width: Int, height: Int) -> Data? {
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Data(buffer)
    }

    private static func encodedData(
        fromPixelData pixelData: Data,
        width: Int,
        height: Int,
        typeIdentifier: CFString,
        compressionQuality: CGFloat? = nil
    ) -> Data? {
        guard width > 0, height > 0, pixelData.count == width * height * 4 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: pixelData as CFData) else { return nil }
        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, typeIdentifier, 1, nil) else {
            return nil
        }
        let options: CFDictionary?
        if let compressionQuality {
            options = [kCGImageDestinationLossyCompressionQuality: compressionQuality] as CFDictionary
        } else {
            options = nil
        }
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return output as Data
    }

}
