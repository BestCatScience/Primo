import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentRuntime

extension DocumentFeature {
    static func layerMaskData(
        from selection: CanvasSelection?,
        canvasGeometry: PixelGeometry,
        selectionWorkflow: any SelectionWorkflowRequesting
    ) -> Data? {
        guard let selection else { return nil }
        guard
            let mask = selectionWorkflow.expandedMask(from: selection, canvasGeometry: canvasGeometry)
        else {
            return nil
        }
        return mask.data
    }

    static func transformationBounds(
        selection: CanvasSelection?,
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        gpuOperations: DocumentRenderingWorkflow
    ) -> CGRect? {
        if let selection, !selection.isEmpty {
            return selection.bounds
        }
        guard
            let surface = RgbaSurface(width: canvasWidth, height: canvasHeight, data: pixelData),
            let alphaMask = gpuOperations.alphaMask(surface).value,
            let maskSurface = MaskSurface(width: canvasWidth, height: canvasHeight, data: Data(alphaMask)),
            let cropped = gpuOperations.croppedSelectionMask(maskSurface)
        else {
            return nil
        }
        return cropped.bounds
    }

}
