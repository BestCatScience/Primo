import CoreGraphics
import Foundation
import PrimoDocumentApplication
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
            let alphaMask = gpuOperations.alphaMask(
                pixelData,
                canvasWidth,
                canvasHeight
            ).value,
            let cropped = gpuOperations.croppedSelectionMask(
                alphaMask,
                canvasWidth,
                canvasHeight
            )
        else {
            return nil
        }
        return cropped.bounds
    }

}
