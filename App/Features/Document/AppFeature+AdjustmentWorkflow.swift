import ComposableArchitecture
import Foundation
import PrimoDocumentContracts

extension AppIntegrationFeature {
    struct ActiveLayerPixelContext {
        let index: Int
        let pixelData: Data
    }

    struct AdjustmentWorkflowService {
        let documentMutationGateway: DocumentMutationGateway

        func applyLayerProcessing(
            _ layerIndex: Int,
            request: LayerProcessingRequest
        ) -> DocumentMutationResult {
            documentMutationGateway.applyLayerProcessing(layerIndex, request)
        }

        func replaceLayerPixels(_ layerIndex: Int, with pixelData: Data) -> DocumentMutationResult {
            documentMutationGateway.replaceLayerPixels(layerIndex, pixelData)
        }
    }

    var adjustmentWorkflowService: AdjustmentWorkflowService {
        AdjustmentWorkflowService(documentMutationGateway: documentMutationGateway)
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

    func previewAdjustedActiveLayer(
        state: inout State,
        request: LayerProcessingRequest?
    ) {
        let adjustedPixels = request.flatMap { request in
            processedActiveLayerPixels(in: state, request: request)
        }
        handleAdjustmentPreview(state: &state, adjustedPixels: adjustedPixels)
    }

    func adjustedActiveLayerPixels(
        in state: State,
        transform: (Data) -> Data?
    ) -> Data? {
        activeLayerPixelContext(in: state).flatMap { transform($0.pixelData) }
    }

    func processedActiveLayerPixels(
        in state: State,
        request: LayerProcessingRequest
    ) -> Data? {
        guard
            let snapshot = state.canvas.renderSnapshot,
            let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex })
        else {
            return nil
        }
        return documentGpuOperationGateway.processedLayerPixelData(
            layer.pixelData,
            snapshot.width,
            snapshot.height,
            request
        )
    }

    func handleAdjustmentPreview(
        state: inout State,
        adjustedPixels: Data?
    ) {
        guard
            let adjustedPixels,
            let snapshot = state.canvas.renderSnapshot,
            let composite = compositedPreviewPixelData(
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
        failureFeedback: ApplicationFeedback,
        apply: () -> DocumentMutationResult
    ) -> Effect<Action> {
        state.canvas.clearAdjustmentPreview()
        let activeLayerIndex = state.canvas.activeLayerIndex
        let mutationContract = DocumentMutationContract(
            canvasMutation: .finalizeLayer(
                LayerMutationFinalization(index: activeLayerIndex)
            )
        )
        return performDocumentMutation(
            state: &state,
            contract: mutationContract,
            failureFeedback: failureFeedback,
            mutation: apply
        )
    }

    @discardableResult
    func handleAdjustmentApplyRequest(
        state: inout State,
        request: LayerProcessingRequest,
        failureFeedback: ApplicationFeedback
    ) -> Effect<Action> {
        let activeLayerIndex = state.canvas.activeLayerIndex
        return handleAdjustmentApplyUsingProcessing(
            state: &state,
            failureFeedback: failureFeedback
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
        failureFeedback: ApplicationFeedback
    ) -> Effect<Action> {
        state.canvas.clearAdjustmentPreview()
        guard let adjustedPixels else {
            state.application.presentFeedback(failureFeedback)
            return .none
        }
        let activeLayerIndex = state.canvas.activeLayerIndex
        let mutationContract = DocumentMutationContract(
            canvasMutation: .finalizeLayer(
                LayerMutationFinalization(index: activeLayerIndex)
            )
        )
        return performDocumentMutation(
            state: &state,
            contract: mutationContract,
            failureFeedback: failureFeedback,
            mutation: {
                adjustmentWorkflowService.replaceLayerPixels(
                    activeLayerIndex,
                    with: adjustedPixels
                )
            }
        )
    }
}
