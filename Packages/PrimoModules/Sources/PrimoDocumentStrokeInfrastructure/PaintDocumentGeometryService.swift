import CoreGraphics
import Foundation

public struct PaintDocumentGeometryService {
    public init() {}
    public func scaledLayerPixelData(
        _ source: Data,
        from sourceSize: PaintDocumentCanvasSize,
        to targetSize: PaintDocumentCanvasSize
    ) -> Data? {
        guard source.count == sourceSize.rgbaByteCount else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: source as CFData),
              let image = CGImage(
                width: sourceSize.width,
                height: sourceSize.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: sourceSize.width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }

        var bytes = [UInt8](repeating: 0, count: targetSize.rgbaByteCount)
        guard let context = CGContext(
            data: &bytes,
            width: targetSize.width,
            height: targetSize.height,
            bitsPerComponent: 8,
            bytesPerRow: targetSize.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))
        return Data(bytes)
    }

    public func scaledLayerMaskData(
        _ source: Data,
        from sourceSize: PaintDocumentCanvasSize,
        to targetSize: PaintDocumentCanvasSize
    ) -> Data? {
        guard source.count == sourceSize.maskByteCount else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let provider = CGDataProvider(data: source as CFData),
              let image = CGImage(
                width: sourceSize.width,
                height: sourceSize.height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: sourceSize.width,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }

        var bytes = [UInt8](repeating: 0, count: targetSize.maskByteCount)
        guard let context = CGContext(
            data: &bytes,
            width: targetSize.width,
            height: targetSize.height,
            bitsPerComponent: 8,
            bytesPerRow: targetSize.width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))
        return Data(bytes)
    }

    public func translatedLayerPixelData(
        _ source: Data,
        from sourceSize: PaintDocumentCanvasSize,
        to targetSize: PaintDocumentCanvasSize,
        offsetX: Int,
        offsetY: Int
    ) -> Data? {
        guard source.count == sourceSize.rgbaByteCount else { return nil }
        var bytes = [UInt8](repeating: 0, count: targetSize.rgbaByteCount)
        source.withUnsafeBytes { sourceBytes in
            guard let sourceBase = sourceBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<sourceSize.height {
                let destinationY = y + offsetY
                guard destinationY >= 0, destinationY < targetSize.height else { continue }
                for x in 0..<sourceSize.width {
                    let destinationX = x + offsetX
                    guard destinationX >= 0, destinationX < targetSize.width else { continue }
                    let sourceOffset = ((y * sourceSize.width) + x) * 4
                    let destinationOffset = ((destinationY * targetSize.width) + destinationX) * 4
                    bytes[destinationOffset] = sourceBase[sourceOffset]
                    bytes[destinationOffset + 1] = sourceBase[sourceOffset + 1]
                    bytes[destinationOffset + 2] = sourceBase[sourceOffset + 2]
                    bytes[destinationOffset + 3] = sourceBase[sourceOffset + 3]
                }
            }
        }
        return Data(bytes)
    }

    public func translatedLayerMaskData(
        _ source: Data,
        from sourceSize: PaintDocumentCanvasSize,
        to targetSize: PaintDocumentCanvasSize,
        offsetX: Int,
        offsetY: Int
    ) -> Data? {
        guard source.count == sourceSize.maskByteCount else { return nil }
        var bytes = [UInt8](repeating: 0, count: targetSize.maskByteCount)
        source.withUnsafeBytes { sourceBytes in
            guard let sourceBase = sourceBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<sourceSize.height {
                let destinationY = y + offsetY
                guard destinationY >= 0, destinationY < targetSize.height else { continue }
                for x in 0..<sourceSize.width {
                    let destinationX = x + offsetX
                    guard destinationX >= 0, destinationX < targetSize.width else { continue }
                    let sourceOffset = (y * sourceSize.width) + x
                    let destinationOffset = (destinationY * targetSize.width) + destinationX
                    bytes[destinationOffset] = sourceBase[sourceOffset]
                }
            }
        }
        return Data(bytes)
    }
}
