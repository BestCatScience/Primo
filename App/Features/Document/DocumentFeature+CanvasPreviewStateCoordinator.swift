import Foundation
import PrimoDocumentContracts

extension DocumentFeature {
    struct CanvasPreviewStateCoordinator {
        @discardableResult
        func applyLiveCompositeSurface(
            _ compositeSurface: DocumentCompositeSurface,
            to state: inout DocumentFeature.State
        ) -> Bool {
            guard compositeSurface.width > 0, compositeSurface.height > 0 else {
                return false
            }
            guard compositeSurface.pixelData.count == compositeSurface.width * compositeSurface.height * 4 else {
                return false
            }
            state.canvas.applyIncrementalRenderUpdate(
                IncrementalLayerUpdate(
                    layerIndex: -1,
                    originX: 0,
                    originY: 0,
                    width: compositeSurface.width,
                    height: compositeSurface.height,
                    pixelData: compositeSurface.pixelData
                )
            )
            return true
        }

        @discardableResult
        func applyLiveStrokePreview(
            baseSnapshot: MetalDocumentSnapshot,
            activeLayerIndex: Int,
            adjustedActiveLayerPixels: Data,
            gpuOperations: DocumentGpuOperationGateway,
            to state: inout DocumentFeature.State
        ) -> Bool {
            guard let composite = gpuOperations.compositedPreviewPixelData(
                baseSnapshot,
                activeLayerIndex,
                adjustedActiveLayerPixels
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
                    thumbnailSurface: layer.thumbnailSurface,
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
