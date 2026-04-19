import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentInfrastructure
import UIKit

extension AppFeature {
    typealias InpaintCrop = PrimoDocumentApplication.InpaintCrop

    struct ImportedCanvasImage {
        let width: Int
        let height: Int
        let pixelData: Data
    }

    static func pngData(fromLayerPixelData pixelData: Data, width: Int, height: Int) -> Data? {
        DocumentRasterImageService.pngData(
            fromLayerPixelData: pixelData,
            width: width,
            height: height
        )
    }

    static func inpaintCrop(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection,
        padding: Int = 64
    ) -> InpaintCrop? {
        DocumentRasterImageService.inpaintCrop(
            source: source,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            selectionBounds: selection.bounds,
            expandedMask: expandedMask(
                from: selection,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight
            ),
            padding: padding
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
        DocumentRasterImageService.applyingInpaintCrop(
            editedCropPixelData,
            to: baseLayerPixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            crop: crop,
            featherRadius: featherRadius
        )
    }

    static func rawLayerPixelData(fromPNGData pngData: Data, width: Int, height: Int) -> Data? {
        DocumentRasterImageService.rawLayerPixelData(
            fromPNGData: pngData,
            width: width,
            height: height
        )
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
        return DocumentTextRasterizer.pixelData(from: renderedCGImage, size: canvasRect.size)
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
              let pixelData = DocumentTextRasterizer.pixelData(
                from: renderedCGImage,
                size: CGSize(width: width, height: height)
              ) else {
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
