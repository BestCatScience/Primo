import Foundation
import PrimoDocumentContracts

extension AppFeature {
    struct AppFeatureCanvasPreviewStateCoordinator {
        @discardableResult
        func applyLiveCompositePixelData(
            _ compositePixelData: Data,
            to state: inout AppFeature.State
        ) -> Bool {
            let width = state.canvas.renderSnapshot?.width ?? max(Int(state.canvas.canvasSize.width.rounded()), 1)
            let height = state.canvas.renderSnapshot?.height ?? max(Int(state.canvas.canvasSize.height.rounded()), 1)
            guard compositePixelData.count == width * height * 4 else {
                return false
            }
            state.canvas.setStrokePreviewCompositePixelData(compositePixelData)
            state.canvas.clearPendingIncrementalUpdate()
            return true
        }

        @discardableResult
        func applyLiveStrokePreview(
            baseSnapshot: MetalDocumentSnapshot,
            activeLayerIndex: Int,
            adjustedActiveLayerPixels: Data,
            to state: inout AppFeature.State
        ) -> Bool {
            guard let composite = AppFeature.compositedPreviewPixelData(
                snapshot: baseSnapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerPixels: adjustedActiveLayerPixels
            ) else {
                return false
            }

            let nextLayers = baseSnapshot.layers.map { layer in
                guard layer.index == activeLayerIndex else { return layer }
                return MetalLayerSnapshot(
                    index: layer.index,
                    opacity: layer.opacity,
                    visible: layer.visible,
                    isClipped: layer.isClipped,
                    blendMode: layer.blendMode,
                    thumbnailData: layer.thumbnailData,
                    pixelData: adjustedActiveLayerPixels
                )
            }

            let nextRevision = max(state.canvas.renderSnapshot?.revision ?? 0, state.canvas.lastCommittedRenderRevision) + 1
            state.canvas.applyPreviewRenderSnapshot(
                MetalDocumentSnapshot(
                    width: baseSnapshot.width,
                    height: baseSnapshot.height,
                    revision: nextRevision,
                    compositePixelData: composite,
                    layers: nextLayers
                ),
                previewLayerPixelData: adjustedActiveLayerPixels
            )
            return true
        }
    }
}
