import Foundation

extension AppFeature {
    struct ActiveLayerPixelContext {
        let index: Int
        let pixelData: Data
    }

    struct AdjustmentWorkflowService {
        let paintDocumentClient: PaintDocumentClient

        func applyLayerProcessing(
            _ layerIndex: Int,
            request: LayerProcessingRequest
        ) -> Bool {
            paintDocumentClient.applyLayerProcessing(layerIndex, request)
        }

        func replaceLayerPixels(_ layerIndex: Int, with pixelData: Data) {
            paintDocumentClient.replaceLayerPixels(layerIndex, pixelData)
        }
    }

    var adjustmentWorkflowService: AdjustmentWorkflowService {
        AdjustmentWorkflowService(paintDocumentClient: paintDocumentClient)
    }

    func activeLayerPixelContext(in state: State) -> ActiveLayerPixelContext? {
        guard let snapshot = state.canvas.renderSnapshot,
              let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex })
        else {
            return nil
        }
        return ActiveLayerPixelContext(index: layer.index, pixelData: layer.pixelData)
    }

    func previewAdjustedActiveLayer(
        state: inout State,
        transform: (Data) -> Data?
    ) {
        let adjustedPixels = activeLayerPixelContext(in: state)
            .flatMap { transform($0.pixelData) }
        handleAdjustmentPreview(state: &state, adjustedPixels: adjustedPixels)
    }

    func adjustedActiveLayerPixels(
        in state: State,
        transform: (Data) -> Data?
    ) -> Data? {
        activeLayerPixelContext(in: state).flatMap { transform($0.pixelData) }
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
            state.canvas.clearAdjustmentPreview()
            return
        }
        state.canvas.setAdjustmentPreviewPixelData(composite)
    }

    @discardableResult
    func handleAdjustmentApplyUsingProcessing(
        state: inout State,
        failureMessage: String,
        apply: () -> Bool
    ) -> Bool {
        state.canvas.clearAdjustmentPreview()
        guard apply() else {
            state.application.presentBanner(failureMessage)
            return false
        }
        state.canvas.finalizeLayerMutation(at: state.canvas.activeLayerIndex)
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
            adjustmentWorkflowService.applyLayerProcessing(
                activeLayerIndex,
                request: request
            )
        }
    }

    @discardableResult
    func handleAdjustmentApplyUsingPixels(
        state: inout State,
        adjustedPixels: Data?,
        failureMessage: String
    ) -> Bool {
        state.canvas.clearAdjustmentPreview()
        guard let adjustedPixels else {
            state.application.presentBanner(failureMessage)
            return false
        }
        adjustmentWorkflowService.replaceLayerPixels(state.canvas.activeLayerIndex, with: adjustedPixels)
        state.canvas.finalizeLayerMutation(at: state.canvas.activeLayerIndex)
        applyDirtyPresentation(state: &state)
        return true
    }
}
