import CoreGraphics
import ComposableArchitecture
import Foundation
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentContracts

extension CanvasEditingWorkflowReducer {
    typealias SelectionTransformCommit = PrimoDocumentApplication.SelectionTransformCommit
    typealias SelectionTransformService = PrimoDocumentApplication.DocumentContentService

    static func selectionTransformCommit(
        in state: State,
        contentService: SelectionTransformService,
        layerTransformProcessor: any LayerTransformProcessing
    ) -> SelectionTransformCommit? {
        let translation = CGSize(
            width: state.canvas.transformPreviewOffset.width.rounded(),
            height: state.canvas.transformPreviewOffset.height.rounded()
        )
        let scaleX = state.canvas.transformPreviewScaleX
        let scaleY = state.canvas.transformPreviewScaleY
        let rotationDegrees = state.canvas.transformPreviewRotationDegrees
        let transformMode = state.canvas.transformMode
        let transformPivot = state.canvas.transformPivot
        let quadOffsets = state.canvas.transformQuadOffsets
        let activeLayerIndex = state.canvas.activeLayerIndex
        if state.canvas.selection == nil,
           var textLayer = state.canvas.activeTextLayer {
            textLayer.position = CGPoint(
                x: textLayer.position.x + translation.width,
                y: textLayer.position.y + translation.height
            )
            textLayer.scale = min(max(textLayer.scale * Double((scaleX + scaleY) * 0.5), 0.2), 6.0)
            textLayer.rotationDegrees += rotationDegrees
            return SelectionTransformCommit(
                payload: .text(layerIndex: activeLayerIndex, textLayer: textLayer)
            )
        }
        let source = contentService.pixelDataForLayer(activeLayerIndex)
        let canvasWidth = max(Int(state.canvas.canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(state.canvas.canvasSize.height.rounded()), 1)
        guard let transformed = layerTransformProcessor.transformedLayerPixels(
            source: source,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            selection: state.canvas.selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: transformPivot,
            mode: transformMode,
            quadOffsets: quadOffsets
        ) else {
            return nil
        }
        return SelectionTransformCommit(
            payload: .pixels(
                layerIndex: activeLayerIndex,
                pixelData: transformed,
                selection: layerTransformProcessor.transformedSelection(
                    state.canvas.selection,
                    translation: translation,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    rotationDegrees: rotationDegrees,
                    pivot: transformPivot,
                    mode: transformMode,
                    quadOffsets: quadOffsets,
                    canvasSize: state.canvas.canvasSize
                )
            )
        )
    }

    var selectionTransformService: SelectionTransformService {
        documentContentService
    }

    func handleApplyTransform(state: inout State) -> Effect<Action> {
        guard state.canvas.transformHasPreview else { return .none }
        guard let commit = Self.selectionTransformCommit(
            in: state,
            contentService: selectionTransformService,
            layerTransformProcessor: layerTransformProcessor
        ) else {
            _ = completeDocumentMutation(
                state: &state,
                contract: DocumentMutationContract(
                    canvasMutation: .resetTransformPreview,
                    refresh: .none,
                    successFeedback: nil
                )
            )
            return .none
        }

        switch commit.payload {
        case let .text(layerIndex, textLayer):
            switch selectionTransformService.setTextLayer(layerIndex, textLayer) {
            case .success:
                return completeDocumentMutation(
                    state: &state,
                    contract: DocumentMutationContract(
                        canvasMutation: .resetTransformPreview,
                        successFeedback: nil
                    )
                )

            case let .failure(failure):
                return transformFailureEffect(failure)
            }

        case let .pixels(layerIndex, pixelData, selection):
            switch selectionTransformService.replaceLayerPixels(layerIndex, pixelData) {
            case .success:
                return completeDocumentMutation(
                    state: &state,
                    contract: DocumentMutationContract(
                        canvasMutation: .completeTransform(
                            layerIndex: layerIndex,
                            selection: selection
                        ),
                        successFeedback: nil
                    )
                )

            case let .failure(failure):
                return transformFailureEffect(failure)
            }
        }
    }

    private func transformFailureEffect(
        _ failure: DocumentMutationFailure
    ) -> Effect<Action> {
        guard let feedback = DocumentMutationFeedbackMapper().feedback(for: failure) else {
            return .none
        }
        return .send(.delegate(.documentMutationFeedback(feedback)))
    }
}
