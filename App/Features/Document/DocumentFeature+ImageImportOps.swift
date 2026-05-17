import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentRuntime

extension DocumentFeature {
    typealias InpaintCrop = PrimoDocumentApplication.InpaintCrop

    struct ImportedCanvasImage {
        let width: Int
        let height: Int
        let pixelData: Data
    }

    static func pngData(from surface: RgbaSurface) -> Data? {
        DocumentRasterImageService.pngData(from: surface)
    }

    static func inpaintCrop(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection,
        padding: Int = 64,
        selectionWorkflow: any SelectionWorkflowRequesting
    ) -> InpaintCrop? {
        guard
            let canvasGeometry = PixelGeometry(width: canvasWidth, height: canvasHeight),
            let expandedMask = selectionWorkflow.expandedMask(
                from: selection,
                canvasGeometry: canvasGeometry
            )
        else {
            return nil
        }

        return DocumentRasterImageService.inpaintCrop(
            source: source,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            selectionBounds: selection.bounds,
            expandedMask: [UInt8](expandedMask.data),
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
            validatingWidth: decoded.width,
            height: decoded.height,
            pixelData: decoded.pixelData
        )
    }

    static func fittedLayerPixelData(
        fromImageData imageData: Data,
        canvasSize: CGSize,
        gpuOperations: DocumentRenderingWorkflow
    ) -> Data? {
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

        let fittedWidth = max(Int(fittedSize.width.rounded()), 1)
        let fittedHeight = max(Int(fittedSize.height.rounded()), 1)
        guard
            let source = RgbaSurface(width: sourceSurface.width, height: sourceSurface.height, data: sourceSurface.pixelData),
            let targetGeometry = PixelGeometry(width: fittedWidth, height: fittedHeight),
            let scaled = gpuOperations.scaledPixelData(source, targetGeometry: targetGeometry).value
        else {
            return nil
        }

        guard let fittedSurface = DocumentCompositeSurface(
            validatingWidth: fittedWidth,
            height: fittedHeight,
            pixelData: scaled
        ) else { return nil }
        return composedSurface(
            fittedSurface,
            in: CGSize(width: width, height: height),
            gpuOperations: gpuOperations
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
        in canvasSize: CGSize,
        gpuOperations: DocumentRenderingWorkflow
    ) -> DocumentCompositeSurface? {
        let width = max(Int(canvasSize.width.rounded()), 1)
        let height = max(Int(canvasSize.height.rounded()), 1)
        let offsetX = max((width - source.width) / 2, 0)
        let offsetY = max((height - source.height) / 2, 0)
        let translated = RgbaSurface(width: source.width, height: source.height, data: source.pixelData)
            .flatMap { sourceSurface in
                PixelGeometry(width: width, height: height).flatMap { targetGeometry in
                    gpuOperations.translatedPixelData(
                        sourceSurface,
                        targetGeometry: targetGeometry,
                        offsetX: offsetX,
                        offsetY: offsetY
                    ).value
                }
            }
        guard let translated else { return nil }
        return DocumentCompositeSurface(
            validatingWidth: width,
            height: height,
            pixelData: translated
        )
    }
}
