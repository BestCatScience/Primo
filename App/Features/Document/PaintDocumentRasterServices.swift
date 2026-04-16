import Accelerate
import CoreGraphics
import Foundation

struct PaintDocumentCanvasSize: Equatable {
    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        self.width = max(width, 1)
        self.height = max(height, 1)
    }

    var rgbaByteCount: Int {
        width * height * 4
    }

    var maskByteCount: Int {
        width * height
    }
}

struct PaintDocumentGeometryService {
    func scaledLayerPixelData(
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

    func scaledLayerMaskData(
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

    func translatedLayerPixelData(
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

    func translatedLayerMaskData(
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

struct PaintDocumentBlurService {
    func boxBlurredPixels(
        from original: [UInt8],
        size: PaintDocumentCanvasSize,
        radius: Double
    ) -> [UInt8]? {
        var source = original
        var destination = [UInt8](repeating: 0, count: original.count)
        var kernelSize = max(3, Int((radius * 0.9).rounded()))
        if kernelSize.isMultiple(of: 2) {
            kernelSize += 1
        }
        kernelSize = min(kernelSize, 63)

        for _ in 0..<2 {
            let error: vImage_Error = source.withUnsafeMutableBytes { sourceBytes in
                destination.withUnsafeMutableBytes { destinationBytes in
                    var sourceBuffer = vImage_Buffer(
                        data: sourceBytes.baseAddress!,
                        height: vImagePixelCount(size.height),
                        width: vImagePixelCount(size.width),
                        rowBytes: size.width * 4
                    )
                    var destinationBuffer = vImage_Buffer(
                        data: destinationBytes.baseAddress!,
                        height: vImagePixelCount(size.height),
                        width: vImagePixelCount(size.width),
                        rowBytes: size.width * 4
                    )
                    return vImageBoxConvolve_ARGB8888(
                        &sourceBuffer,
                        &destinationBuffer,
                        nil,
                        0,
                        0,
                        UInt32(kernelSize),
                        UInt32(kernelSize),
                        nil,
                        vImage_Flags(kvImageEdgeExtend)
                    )
                }
            }
            guard error == kvImageNoError else {
                return nil
            }
            swap(&source, &destination)
        }

        return source
    }

    func blendBlurredPixels(
        original: [UInt8],
        blurred: [UInt8],
        size: PaintDocumentCanvasSize,
        samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> [UInt8] {
        var output = original
        let influenceRadius = max(4.0, brush.radius * 1.35)
        let blurStrength = max(0.0, min(brush.flow, 1.0))
        let softness = max(0.12, 1.0 - brush.hardness)
        let sampleXs = samples.map { Double($0.point.x) }
        let sampleYs = samples.map { Double($0.point.y) }
        let minX = max(0, Int((sampleXs.min() ?? 0) - influenceRadius - 2))
        let maxX = min(size.width - 1, Int((sampleXs.max() ?? 0) + influenceRadius + 2))
        let minY = max(0, Int((sampleYs.min() ?? 0) - influenceRadius - 2))
        let maxY = min(size.height - 1, Int((sampleYs.max() ?? 0) + influenceRadius + 2))

        guard minX <= maxX, minY <= maxY else {
            return output
        }

        let maskWidth = maxX - minX + 1
        let maskHeight = maxY - minY + 1
        var mask = [Float](repeating: 0, count: maskWidth * maskHeight)

        for sample in samples {
            let centerX = Double(sample.point.x)
            let centerY = Double(sample.point.y)
            let sampleRadius = influenceRadius * max(0.35, Double(sample.pressure))
            let localMinX = max(minX, Int(floor(centerX - sampleRadius)))
            let localMaxX = min(maxX, Int(ceil(centerX + sampleRadius)))
            let localMinY = max(minY, Int(floor(centerY - sampleRadius)))
            let localMaxY = min(maxY, Int(ceil(centerY + sampleRadius)))

            for y in localMinY...localMaxY {
                let dy = Double(y) - centerY
                for x in localMinX...localMaxX {
                    let dx = Double(x) - centerX
                    let distance = sqrt((dx * dx) + (dy * dy))
                    guard distance <= sampleRadius else { continue }
                    let normalized = max(0.0, 1.0 - (distance / sampleRadius))
                    let feathered = pow(normalized, max(0.75, 2.4 - (softness * 1.6)))
                    let strength = Float(feathered * blurStrength)
                    let maskIndex = ((y - minY) * maskWidth) + (x - minX)
                    mask[maskIndex] = max(mask[maskIndex], strength)
                }
            }
        }

        for y in minY...maxY {
            for x in minX...maxX {
                let maskIndex = ((y - minY) * maskWidth) + (x - minX)
                let strength = max(0, min(mask[maskIndex], 1))
                guard strength > 0.001 else { continue }
                let pixelIndex = ((y * size.width) + x) * 4
                for channel in 0..<4 {
                    let originalValue = Float(original[pixelIndex + channel])
                    let blurredValue = Float(blurred[pixelIndex + channel])
                    output[pixelIndex + channel] = UInt8(
                        max(0, min(255, Int((originalValue + ((blurredValue - originalValue) * strength)).rounded())))
                    )
                }
            }
        }

        return output
    }
}
