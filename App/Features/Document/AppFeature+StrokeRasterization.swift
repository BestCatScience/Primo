import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentRenderingInfrastructure

extension AppFeature {
    static func layerPixelDataByApplyingCommittedShortStroke(
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool = false
    ) -> Data? {
        guard
            let snapshot,
            let layer = snapshot.layers.first(where: { $0.index == activeLayerIndex })
        else {
            return nil
        }

        let expectedCount = snapshot.width * snapshot.height * 4
        guard layer.pixelData.count == expectedCount else { return nil }
        guard let output = MetalDocumentProcessingClient.shared.rasterizedStrokePixelData(
            basePixelData: layer.pixelData,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            samples: samples,
            brush: brush,
            mode: .commit,
            snapshotRevision: snapshot.revision,
            activeLayerIndex: activeLayerIndex
        ) else {
            return nil
        }
        if preserveAlphaLockedPixels {
            return pixelDataByPreservingExistingAlpha(
                source: output,
                existing: layer.pixelData,
                width: snapshot.width,
                height: snapshot.height
            )
        }
        return output
    }

    static func layerPixelDataByApplyingCommittedStroke(
        basePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        mode: MetalStrokeExecutionMode = .commit,
        snapshotRevision: Int? = nil,
        activeLayerIndex: Int? = nil,
        preserveAlphaLockedPixels: Bool = false
    ) -> Data? {
        if let gpuOutput = MetalDocumentProcessingClient.shared.rasterizedStrokePixelData(
            basePixelData: basePixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            samples: samples,
            brush: brush,
            mode: mode,
            snapshotRevision: snapshotRevision,
            activeLayerIndex: activeLayerIndex
        ) {
            if preserveAlphaLockedPixels {
                return pixelDataByPreservingExistingAlpha(
                    source: gpuOutput,
                    existing: basePixelData,
                    width: canvasWidth,
                    height: canvasHeight
                )
            }
            return gpuOutput
        }
        return nil
    }

    static func pixelDataByPreservingExistingAlpha(
        source: Data,
        existing: Data,
        width: Int,
        height: Int
    ) -> Data? {
        MetalDocumentProcessingClient.shared.preservingExistingAlpha(
            source: source,
            existing: existing,
            width: width,
            height: height
        )
    }

}
