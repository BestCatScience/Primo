import Accelerate
import Foundation

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
