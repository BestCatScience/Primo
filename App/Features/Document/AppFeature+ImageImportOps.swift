import CoreGraphics
import Foundation
import UIKit

extension AppFeature {
    struct InpaintCrop: Sendable {
        let pixelData: Data
        let width: Int
        let height: Int
        let originX: Int
        let originY: Int
        let selectionMask: [UInt8]
    }

    struct ImportedCanvasImage {
        let width: Int
        let height: Int
        let pixelData: Data
    }

    static func pngData(fromLayerPixelData pixelData: Data, width: Int, height: Int) -> Data? {
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
        return UIImage(cgImage: image).pngData()
    }

    static func inpaintCrop(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection,
        padding: Int = 64
    ) -> InpaintCrop? {
        let expectedCount = canvasWidth * canvasHeight * 4
        guard source.count == expectedCount else { return nil }

        let minX = max(Int(selection.bounds.minX.rounded(.down)) - padding, 0)
        let minY = max(Int(selection.bounds.minY.rounded(.down)) - padding, 0)
        let maxX = min(Int(selection.bounds.maxX.rounded(.up)) + padding, canvasWidth)
        let maxY = min(Int(selection.bounds.maxY.rounded(.up)) + padding, canvasHeight)
        let cropWidth = maxX - minX
        let cropHeight = maxY - minY
        guard cropWidth > 0, cropHeight > 0 else { return nil }

        let expandedSelectionMask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
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
                cropSelectionMask[cropIndex] = expandedSelectionMask[canvasIndex]
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

    static func applyingInpaintCrop(
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

    static func rawLayerPixelData(fromPNGData pngData: Data, width: Int, height: Int) -> Data? {
        guard width > 0, height > 0, let image = UIImage(data: pngData)?.cgImage else { return nil }

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

    static func fittedLayerPixelData(fromImageData imageData: Data, canvasSize: CGSize) -> Data? {
        guard
            canvasSize.width > 0,
            canvasSize.height > 0,
            let sourceImage = UIImage(data: imageData)
        else {
            return nil
        }

        let width = Int(canvasSize.width.rounded())
        let height = Int(canvasSize.height.rounded())
        guard width > 0, height > 0 else { return nil }

        let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)
        let imageSize = resolvedPixelSize(for: sourceImage)
        let scale = min(canvasRect.width / imageSize.width, canvasRect.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(
            x: (canvasRect.width - fittedSize.width) * 0.5,
            y: (canvasRect.height - fittedSize.height) * 0.5,
            width: fittedSize.width,
            height: fittedSize.height
        )

        let renderer = UIGraphicsImageRenderer(size: canvasRect.size)
        let renderedImage = renderer.image { _ in
            UIColor.clear.setFill()
            UIRectFill(canvasRect)
            sourceImage.draw(in: drawRect)
        }
        guard let renderedCGImage = renderedImage.cgImage else {
            return nil
        }
        return PaintDocumentSession.pixelData(from: renderedCGImage, size: canvasRect.size)
    }

    static func importedCanvasImage(from imageData: Data) -> ImportedCanvasImage? {
        guard let sourceImage = UIImage(data: imageData) else {
            return nil
        }

        let imageSize = resolvedPixelSize(for: sourceImage)
        let width = Int(imageSize.width.rounded())
        let height = Int(imageSize.height.rounded())
        guard width > 0, height > 0 else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let renderedImage = renderer.image { _ in
            UIColor.clear.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: width, height: height))
            sourceImage.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        guard let renderedCGImage = renderedImage.cgImage,
              let pixelData = PaintDocumentSession.pixelData(from: renderedCGImage, size: CGSize(width: width, height: height)) else {
            return nil
        }

        return ImportedCanvasImage(width: width, height: height, pixelData: pixelData)
    }

    private static func resolvedPixelSize(for image: UIImage) -> CGSize {
        let pixelWidth = max((image.size.width * image.scale).rounded(), 1)
        let pixelHeight = max((image.size.height * image.scale).rounded(), 1)
        return CGSize(width: pixelWidth, height: pixelHeight)
    }
}
