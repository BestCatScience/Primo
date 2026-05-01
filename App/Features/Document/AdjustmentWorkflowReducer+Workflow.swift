import Foundation
import ComposableArchitecture
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentMutationContracts
import PrimoDocumentRuntime

extension AdjustmentWorkflowReducer {
    struct AdjustmentWorkflowService {
        let documentMutationWorkflowService: DocumentMutationWorkflowService

        func applyLayerProcessing(
            _ layerIndex: Int,
            request: LayerProcessingRequest
        ) -> DocumentMutationResult {
            documentMutationWorkflowService.applyLayerProcessing(layerIndex, request: request)
        }
    }

    var adjustmentWorkflowService: AdjustmentWorkflowService {
        AdjustmentWorkflowService(documentMutationWorkflowService: documentMutationWorkflowService)
    }

    struct ActiveLayerPixelContext {
        let index: Int
        let pixelData: Data
    }

    static func activeLayerPixelContext(in state: State) -> ActiveLayerPixelContext? {
        guard let snapshot = state.canvas.renderSnapshot,
              let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex })
        else {
            return nil
        }
        return ActiveLayerPixelContext(index: layer.index, pixelData: layer.pixelData)
    }

    static func adjustedActiveLayerPixels(
        in state: State,
        transform: (Data) -> Data?
    ) -> Data? {
        activeLayerPixelContext(in: state).flatMap { transform($0.pixelData) }
    }

    static func processedActiveLayerPixels(
        in state: State,
        request: LayerProcessingRequest,
        gpuOperations: DocumentRenderingWorkflow
    ) -> Data? {
        guard
            let snapshot = state.canvas.renderSnapshot,
            let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex })
        else {
            return nil
        }
        return gpuOperations.processedLayerPixelData(
            layer.pixelData,
            snapshot.width,
            snapshot.height,
            request
        ).value
    }

    static func previewAdjustedActiveLayer(
        state: inout State,
        transform: (Data) -> Data?,
        gpuOperations: DocumentRenderingWorkflow
    ) {
        let adjustedPixels = adjustedActiveLayerPixels(in: state, transform: transform)
        handleAdjustmentPreview(
            state: &state,
            adjustedPixels: adjustedPixels,
            gpuOperations: gpuOperations
        )
    }

    static func previewAdjustedActiveLayer(
        state: inout State,
        request: LayerProcessingRequest?,
        gpuOperations: DocumentRenderingWorkflow
    ) {
        let adjustedPixels = request.flatMap { request in
            processedActiveLayerPixels(
                in: state,
                request: request,
                gpuOperations: gpuOperations
            )
        }
        handleAdjustmentPreview(
            state: &state,
            adjustedPixels: adjustedPixels,
            gpuOperations: gpuOperations
        )
    }

    static func handleAdjustmentPreview(
        state: inout State,
        adjustedPixels: Data?,
        gpuOperations: DocumentRenderingWorkflow
    ) {
        guard
            let adjustedPixels,
            let snapshot = state.canvas.renderSnapshot,
            DocumentFeature.canvasPreviewStateCoordinator.applyLiveStrokePreview(
                baseSnapshot: snapshot,
                activeLayerIndex: state.canvas.activeLayerIndex,
                adjustedActiveLayerPixels: adjustedPixels,
                gpuOperations: gpuOperations,
                to: &state
            )
        else {
            state.canvas.clearAdjustmentPreview()
            return
        }
    }

    @discardableResult
    func handleAdjustmentApplyUsingProcessing(
        state: inout State,
        failureFeedback: ApplicationFeature.Feedback,
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
        failureFeedback: ApplicationFeature.Feedback
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
}
