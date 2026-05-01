import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentRuntime

extension DocumentFeature {
    struct CanvasPreviewStateCoordinator {
        @discardableResult
        func applyLiveCompositeSurface(
            _ compositeSurface: DocumentCompositeSurface,
            to state: inout DocumentEditingState
        ) -> Bool {
            guard compositeSurface.width > 0, compositeSurface.height > 0 else {
                return false
            }
            guard compositeSurface.pixelData.count == compositeSurface.width * compositeSurface.height * 4 else {
                return false
            }
            guard let update = IncrementalLayerUpdate(
                validatingID: UUID(),
                layerIndex: -1,
                originX: 0,
                originY: 0,
                width: compositeSurface.width,
                height: compositeSurface.height,
                pixelData: compositeSurface.pixelData
            ) else {
                return false
            }
            state.canvas.applyIncrementalRenderUpdate(update)
            return true
        }

        @discardableResult
        func applyLiveStrokePreview(
            baseSnapshot: MetalDocumentSnapshot,
            activeLayerIndex: Int,
            adjustedActiveLayerPixels: Data,
            gpuOperations: DocumentRenderingWorkflow,
            to state: inout DocumentEditingState
        ) -> Bool {
            guard let composite = gpuOperations.compositedPreviewPixelData(
                baseSnapshot,
                activeLayerIndex,
                adjustedActiveLayerPixels
            ).value else {
                return false
            }

            let nextLayers = baseSnapshot.layers.map { layer in
                guard layer.index == activeLayerIndex else { return layer }
                return MetalLayerSnapshot(
                    validatingIndex: layer.index,
                    opacity: layer.opacity,
                    visible: layer.visible,
                    isClipped: layer.isClipped,
                    blendMode: layer.blendMode,
                    canvasWidth: baseSnapshot.width,
                    canvasHeight: baseSnapshot.height,
                    thumbnailSurface: layer.thumbnailSurface,
                    thumbnailData: layer.thumbnailData,
                    pixelData: adjustedActiveLayerPixels
                ) ?? layer
            }

            let nextRevision = max(state.canvas.renderSnapshot?.revision ?? 0, state.canvas.lastCommittedRenderRevision) + 1
            guard let snapshot = MetalDocumentSnapshot(
                validatingWidth: baseSnapshot.width,
                height: baseSnapshot.height,
                revision: nextRevision,
                compositePixelData: composite,
                layers: nextLayers
            ) else {
                return false
            }
            state.canvas.applyPreviewRenderSnapshot(snapshot)
            return true
        }
    }
}
