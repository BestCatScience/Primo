import CoreGraphics
import Foundation
import ImageIO
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

public enum DocumentRasterImageService {
    public static func pngData(fromLayerPixelData pixelData: Data, width: Int, height: Int) -> Data? {
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
        guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return output as Data
    }

    public static func inpaintCrop(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selectionBounds: CGRect,
        expandedMask: [UInt8],
        padding: Int = 64
    ) -> InpaintCrop? {
        let expectedCount = canvasWidth * canvasHeight * 4
        guard source.count == expectedCount else { return nil }

        let minX = max(Int(selectionBounds.minX.rounded(.down)) - padding, 0)
        let minY = max(Int(selectionBounds.minY.rounded(.down)) - padding, 0)
        let maxX = min(Int(selectionBounds.maxX.rounded(.up)) + padding, canvasWidth)
        let maxY = min(Int(selectionBounds.maxY.rounded(.up)) + padding, canvasHeight)
        let cropWidth = maxX - minX
        let cropHeight = maxY - minY
        guard cropWidth > 0, cropHeight > 0 else { return nil }

        let sourceBytes = [UInt8](source)
        var cropBytes = [UInt8](repeating: 0, count: cropWidth * cropHeight * 4)
        var cropSelectionMask = [UInt8](repeating: 0, count: cropWidth * cropHeight)

        for y in 0..<cropHeight {
            for x in 0..<cropWidth {
                let canvasX = minX + x
                let canvasY = minY + y
                let canvasIndex = (canvasY * canvasWidth) + canvasX
                let cropIndex = (y * cropWidth) + x
                let sourceOffset = canvasIndex * 4
                let cropOffset = cropIndex * 4

                cropBytes[cropOffset] = sourceBytes[sourceOffset]
                cropBytes[cropOffset + 1] = sourceBytes[sourceOffset + 1]
                cropBytes[cropOffset + 2] = sourceBytes[sourceOffset + 2]
                cropBytes[cropOffset + 3] = sourceBytes[sourceOffset + 3]
                cropSelectionMask[cropIndex] = expandedMask[canvasIndex]
            }
        }

        return InpaintCrop(
            pixelData: Data(cropBytes),
            width: cropWidth,
            height: cropHeight,
            originX: minX,
            originY: minY,
            selectionMask: cropSelectionMask
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

        let editedBytes = [UInt8](editedCropPixelData)
        let baseBytes = [UInt8](baseLayerPixelData)
        var outputBytes = baseBytes
        let blendMask = featheredBlendMask(
            selectionMask: crop.selectionMask,
            width: crop.width,
            height: crop.height,
            radius: featherRadius
        )

        for y in 0..<crop.height {
            for x in 0..<crop.width {
                let cropIndex = (y * crop.width) + x
                let blendAlpha = blendMask[cropIndex]
                guard blendAlpha > 0 else { continue }

                let canvasX = crop.originX + x
                let canvasY = crop.originY + y
                guard canvasX >= 0, canvasX < canvasWidth, canvasY >= 0, canvasY < canvasHeight else { continue }

                let canvasOffset = ((canvasY * canvasWidth) + canvasX) * 4
                let cropOffset = cropIndex * 4

                if blendAlpha >= 0.999 {
                    outputBytes[canvasOffset] = editedBytes[cropOffset]
                    outputBytes[canvasOffset + 1] = editedBytes[cropOffset + 1]
                    outputBytes[canvasOffset + 2] = editedBytes[cropOffset + 2]
                    outputBytes[canvasOffset + 3] = editedBytes[cropOffset + 3]
                    continue
                }

                for channel in 0..<4 {
                    let baseValue = Double(baseBytes[canvasOffset + channel])
                    let editedValue = Double(editedBytes[cropOffset + channel])
                    let blendedValue = (baseValue * (1.0 - blendAlpha)) + (editedValue * blendAlpha)
                    outputBytes[canvasOffset + channel] = UInt8(max(0, min(255, Int(blendedValue.rounded()))))
                }
            }
        }

        return Data(outputBytes)
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

    private static func featheredBlendMask(
        selectionMask: [UInt8],
        width: Int,
        height: Int,
        radius: Int
    ) -> [Double] {
        guard width > 0, height > 0 else { return [] }
        guard radius > 0 else {
            return selectionMask.map { $0 == 0 ? 0 : 1 }
        }

        let radiusSquared = radius * radius
        var result = [Double](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width) + x
                if selectionMask[index] != 0 {
                    result[index] = 1
                    continue
                }

                var nearestDistanceSquared: Int?
                let minSearchY = max(0, y - radius)
                let maxSearchY = min(height - 1, y + radius)
                let minSearchX = max(0, x - radius)
                let maxSearchX = min(width - 1, x + radius)

                for searchY in minSearchY...maxSearchY {
                    for searchX in minSearchX...maxSearchX {
                        let searchIndex = (searchY * width) + searchX
                        guard selectionMask[searchIndex] != 0 else { continue }

                        let dx = searchX - x
                        let dy = searchY - y
                        let distanceSquared = (dx * dx) + (dy * dy)
                        guard distanceSquared <= radiusSquared else { continue }

                        if let currentNearestDistanceSquared = nearestDistanceSquared {
                            if distanceSquared < currentNearestDistanceSquared {
                                nearestDistanceSquared = distanceSquared
                            }
                        } else {
                            nearestDistanceSquared = distanceSquared
                        }
                    }
                }

                guard let nearestDistanceSquared else { continue }
                let distance = sqrt(Double(nearestDistanceSquared))
                let normalized = max(0, min(1, 1 - (distance / Double(radius))))
                result[index] = normalized
            }
        }

        return result
    }
}
