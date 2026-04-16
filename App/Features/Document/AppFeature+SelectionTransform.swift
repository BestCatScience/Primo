import ComposableArchitecture
import CoreGraphics
import Foundation

extension AppFeature {
    func applyTransform(state: inout State) -> Effect<Action> {
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
        guard state.canvas.transformHasPreview else { return .none }
        if
            state.canvas.selection == nil,
            var textLayer = state.canvas.activeTextLayer
        {
            textLayer.position = CGPoint(
                x: textLayer.position.x + translation.width,
                y: textLayer.position.y + translation.height
            )
            textLayer.scale = min(max(textLayer.scale * Double((scaleX + scaleY) * 0.5), 0.2), 6.0)
            textLayer.rotationDegrees += rotationDegrees
            guard paintDocumentClient.setTextLayer(state.canvas.activeLayerIndex, textLayer) else {
                state.canvas.resetTransformPreview()
                return .none
            }
            state.canvas.resetTransformPreview()
            applyDirtyPresentation(state: &state)
            return .none
        }
        let activeLayerIndex = state.canvas.activeLayerIndex
        let source = paintDocumentClient.pixelDataForLayer(activeLayerIndex)
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
            state.canvas.resetTransformPreview()
            return .none
        }
        paintDocumentClient.replaceLayerPixels(activeLayerIndex, transformed)
        state.canvas.discardBufferedStrokes(for: activeLayerIndex, incrementsRevision: true)
        state.canvas.setSelection(Self.transformedSelection(
            state.canvas.selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: transformPivot,
            mode: transformMode,
            quadOffsets: quadOffsets,
            canvasSize: state.canvas.canvasSize
        ))
        state.canvas.resetTransformPreview()
        applyDirtyPresentation(state: &state)
        return .none
    }
}
