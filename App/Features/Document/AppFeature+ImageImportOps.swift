import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts

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
        padding: Int = 64,
        gpuOperations: DocumentGpuOperationGateway
    ) -> InpaintCrop? {
        guard let expandedMask = expandedMask(
            from: selection,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            gpuOperations: gpuOperations
        ) else {
            return nil
        }

        return DocumentRasterImageService.inpaintCrop(
            source: source,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            selectionBounds: selection.bounds,
            expandedMask: expandedMask,
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

    static func decodedImageSurface(from imageData: Data) -> DocumentCompositeSurface? {
        guard let decoded = DocumentRasterImageService.decodedImage(fromEncodedData: imageData) else {
            return nil
        }
        return DocumentCompositeSurface(
            width: decoded.width,
            height: decoded.height,
            pixelData: decoded.pixelData
        )
    }

    static func fittedLayerPixelData(fromImageData imageData: Data, canvasSize: CGSize) -> Data? {
        guard
            canvasSize.width > 0,
            canvasSize.height > 0,
            let sourceSurface = decodedImageSurface(from: imageData)
        else {
            return nil
        }

        let width = Int(canvasSize.width.rounded())
        let height = Int(canvasSize.height.rounded())
        guard width > 0, height > 0 else { return nil }
        let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)
        let imageSize = CGSize(width: sourceSurface.width, height: sourceSurface.height)
        let scale = min(canvasRect.width / imageSize.width, canvasRect.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        let layerService = MetalLayerMutationService()
        guard let scaled = layerService.scaledPixelData(
            sourceSurface.pixelData,
            sourceWidth: sourceSurface.width,
            sourceHeight: sourceSurface.height,
            targetWidth: max(Int(fittedSize.width.rounded()), 1),
            targetHeight: max(Int(fittedSize.height.rounded()), 1)
        ) else {
            return nil
        }

        let fittedSurface = DocumentCompositeSurface(
            width: max(Int(fittedSize.width.rounded()), 1),
            height: max(Int(fittedSize.height.rounded()), 1),
            pixelData: scaled
        )
        return composedSurface(
            fittedSurface,
            in: CGSize(width: width, height: height)
        )?.pixelData
    }

    static func importedCanvasImage(from imageData: Data) -> ImportedCanvasImage? {
        guard let sourceSurface = decodedImageSurface(from: imageData) else {
            return nil
        }
        let width = sourceSurface.width
        let height = sourceSurface.height
        guard width > 0, height > 0 else {
            return nil
        }
        return ImportedCanvasImage(width: width, height: height, pixelData: sourceSurface.pixelData)
    }

    private static func composedSurface(
        _ source: DocumentCompositeSurface,
        in canvasSize: CGSize
    ) -> DocumentCompositeSurface? {
        let width = max(Int(canvasSize.width.rounded()), 1)
        let height = max(Int(canvasSize.height.rounded()), 1)
        let offsetX = max((width - source.width) / 2, 0)
        let offsetY = max((height - source.height) / 2, 0)
        let translated = MetalLayerMutationService().translatedPixelData(
            source.pixelData,
            sourceWidth: source.width,
            sourceHeight: source.height,
            targetWidth: width,
            targetHeight: height,
            offsetX: offsetX,
            offsetY: offsetY
        )
        guard let translated else { return nil }
        return DocumentCompositeSurface(width: width, height: height, pixelData: translated)
    }
}
