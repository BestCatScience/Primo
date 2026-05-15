import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentRuntime

extension DocumentFeature {
    static func layerMaskData(
        from selection: CanvasSelection?,
        canvasSize: CGSize,
        selectionWorkflow: any SelectionWorkflowRequesting
    ) -> Data? {
        guard let selection else { return nil }
        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
        guard let mask = selectionWorkflow.expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight) else {
            return nil
        }
        return Data(mask)
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
