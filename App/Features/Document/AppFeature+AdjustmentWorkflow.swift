import Foundation

extension AppFeature {
    struct AdjustmentWorkflowService {
        let paintDocumentClient: PaintDocumentClient

        func applyLayerProcessing(_ apply: () -> Bool) -> Bool {
            apply()
        }

        func replaceLayerPixels(_ layerIndex: Int, with pixelData: Data) {
            paintDocumentClient.replaceLayerPixels(layerIndex, pixelData)
        }
    }

    var adjustmentWorkflowService: AdjustmentWorkflowService {
        AdjustmentWorkflowService(paintDocumentClient: paintDocumentClient)
    }

    func handleAdjustmentPreview(
        state: inout State,
        adjustedPixels: Data?
    ) {
        guard
            let adjustedPixels,
            let snapshot = state.canvas.renderSnapshot,
            let composite = Self.compositedPreviewPixelData(
                snapshot: snapshot,
                activeLayerIndex: state.canvas.activeLayerIndex,
                adjustedActiveLayerPixels: adjustedPixels
            )
        else {
            state.canvas.adjustmentPreviewPixelData = nil
            return
        }
        state.canvas.adjustmentPreviewPixelData = composite
    }

    @discardableResult
    func handleAdjustmentApplyUsingProcessing(
        state: inout State,
        failureMessage: String,
        apply: () -> Bool
    ) -> Bool {
        state.canvas.adjustmentPreviewPixelData = nil
        guard adjustmentWorkflowService.applyLayerProcessing(apply) else {
            state.bannerMessage = failureMessage
            return false
        }
        if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
            state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
        }
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
        return true
    }

    @discardableResult
    func handleAdjustmentApplyRequest(
        state: inout State,
        request: LayerProcessingRequest,
        failureMessage: String
    ) -> Bool {
        let activeLayerIndex = state.canvas.activeLayerIndex
        return handleAdjustmentApplyUsingProcessing(
            state: &state,
            failureMessage: failureMessage
        ) {
            paintDocumentClient.applyLayerProcessing(activeLayerIndex, request)
        }
    }

    @discardableResult
    func handleAdjustmentApplyUsingPixels(
        state: inout State,
        adjustedPixels: Data?,
        failureMessage: String
    ) -> Bool {
        state.canvas.adjustmentPreviewPixelData = nil
        guard let adjustedPixels else {
            state.bannerMessage = failureMessage
            return false
        }
        adjustmentWorkflowService.replaceLayerPixels(state.canvas.activeLayerIndex, with: adjustedPixels)
        if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
            state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
        }
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
        return true
    }
}
