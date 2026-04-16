import Foundation

extension AppFeature {
    struct AppFeatureCanvasPreviewStateCoordinator {
        func applyLiveCompositePixelData(
            _ compositePixelData: Data,
            to state: inout AppFeature.State
        ) {
            let width = state.canvas.renderSnapshot?.width ?? max(Int(state.canvas.canvasSize.width.rounded()), 1)
            let height = state.canvas.renderSnapshot?.height ?? max(Int(state.canvas.canvasSize.height.rounded()), 1)
            guard compositePixelData.count == width * height * 4 else {
                return
            }

            let layerSnapshots: [MetalLayerSnapshot]
            if let existingLayers = state.canvas.renderSnapshot?.layers, !existingLayers.isEmpty {
                layerSnapshots = existingLayers
            } else {
                layerSnapshots = state.canvas.layerBuffers.map { buffer in
                    MetalLayerSnapshot(
                        index: buffer.index,
                        opacity: Float(buffer.opacity),
                        visible: buffer.visible,
                        isClipped: false,
                        blendMode: buffer.blendMode,
                        thumbnailData: nil,
                        pixelData: Data()
                    )
                }
            }

            let nextRevision = max(state.canvas.renderSnapshot?.revision ?? 0, state.canvas.lastCommittedRenderRevision) + 1
            state.canvas.renderSnapshot = MetalDocumentSnapshot(
                width: width,
                height: height,
                revision: nextRevision,
                compositePixelData: compositePixelData,
                layers: layerSnapshots
            )
            state.canvas.pendingIncrementalUpdate = nil
            state.isHydrating = false
        }

        func applyLiveStrokePreview(
            baseSnapshot: MetalDocumentSnapshot,
            activeLayerIndex: Int,
            adjustedActiveLayerPixels: Data,
            to state: inout AppFeature.State
        ) {
            guard let composite = AppFeature.compositedPreviewPixelData(
                snapshot: baseSnapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerPixels: adjustedActiveLayerPixels
            ) else {
                return
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
            state.canvas.renderSnapshot = MetalDocumentSnapshot(
                width: baseSnapshot.width,
                height: baseSnapshot.height,
                revision: nextRevision,
                compositePixelData: composite,
                layers: nextLayers
            )
            state.canvas.activeStrokePreviewLayerPixelData = adjustedActiveLayerPixels
            state.canvas.pendingIncrementalUpdate = nil
            state.isHydrating = false
        }
    }
}
