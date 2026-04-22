import ComposableArchitecture
import CoreGraphics
import Foundation
import PrimoDocumentApplication

extension AppFeature {
    typealias SelectionTransformCommit = PrimoDocumentApplication.SelectionTransformCommit
    typealias SelectionTransformService = PrimoDocumentApplication.DocumentContentService

    var selectionTransformService: SelectionTransformService {
        SelectionTransformService(
            documentQueryGateway: documentQueryGateway,
            documentMutationGateway: documentMutationGateway,
            textLayerGateway: textLayerGateway
        )
    }

    func discardTransformPreview(state: inout State) {
        completeDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .resetTransformPreview,
                refresh: .none
            )
        )
    }

    func selectionTransformCommit(in state: State) -> SelectionTransformCommit? {
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
        let source = selectionTransformService.pixelDataForLayer(activeLayerIndex)
        let canvasWidth = max(Int(state.canvas.canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(state.canvas.canvasSize.height.rounded()), 1)
        guard let transformed = Self.transformedLayerPixels(
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
                selection: Self.transformedSelection(
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

    func applyTransform(state: inout State) -> Effect<Action> {
        guard state.canvas.transformHasPreview else { return .none }
        guard let commit = selectionTransformCommit(in: state) else {
            discardTransformPreview(state: &state)
            return .none
        }
        switch commit.payload {
        case let .text(layerIndex, textLayer):
            return performDocumentMutation(
                state: &state,
                contract: DocumentMutationContract(
                    canvasMutation: .resetTransformPreview
                ),
                mutation: {
                    selectionTransformService.setTextLayer(layerIndex, textLayer)
                }
            )
        case let .pixels(layerIndex, pixelData, selection):
            return performDocumentMutation(
                state: &state,
                contract: DocumentMutationContract(
                    canvasMutation: .completeTransform(
                        layerIndex: layerIndex,
                        selection: selection
                    )
                ),
                mutation: {
                    selectionTransformService.replaceLayerPixels(layerIndex, pixelData)
                }
            )
        }
    }
}
