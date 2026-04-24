import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts

public struct DocumentStrokeContext: Equatable, Sendable {
    public let activeLayer: LayerRowModel
    public let activeLayerIndex: Int
    public let brush: BrushRuntimeSettings
    public let previewBrush: BrushRuntimeSettings

    public init(
        activeLayer: LayerRowModel,
        activeLayerIndex: Int,
        brush: BrushRuntimeSettings,
        previewBrush: BrushRuntimeSettings
    ) {
        self.activeLayer = activeLayer
        self.activeLayerIndex = activeLayerIndex
        self.brush = brush
        self.previewBrush = previewBrush
    }
}

public struct DocumentStrokePreviewResolution: Sendable {
    public let result: StrokePreviewResult
    public let baseSnapshotToCapture: MetalDocumentSnapshot?

    public init(
        result: StrokePreviewResult,
        baseSnapshotToCapture: MetalDocumentSnapshot? = nil
    ) {
        self.result = result
        self.baseSnapshotToCapture = baseSnapshotToCapture
    }
}

public struct DocumentStrokePreviewUseCase: Sendable {
    public var planner: any StrokePreviewPlanning

    public init(planner: any StrokePreviewPlanning) {
        self.planner = planner
    }

    public func resolveInitial(
        baseSnapshot: MetalDocumentSnapshot?,
        sample: StylusSample,
        context: DocumentStrokeContext,
        usesResponsiveOilPreview: Bool
    ) -> DocumentStrokePreviewResolution? {
        guard
            let baseSnapshot,
            let baseLayer = baseSnapshot.layers.first(where: { $0.index == context.activeLayerIndex }),
            let result = planner.makePreview(
                StrokePreviewRequest(
                    snapshot: baseSnapshot,
                    activeLayerIndex: context.activeLayerIndex,
                    baseLayer: baseLayer.surfaceRef(canvasWidth: baseSnapshot.width, canvasHeight: baseSnapshot.height),
                    samples: [sample],
                    brush: context.previewBrush,
                    preserveAlphaLockedPixels: context.activeLayer.isAlphaLocked,
                    usesResponsiveOilPreview: usesResponsiveOilPreview
                )
            )
        else {
            return nil
        }
        return DocumentStrokePreviewResolution(result: result)
    }

    public func resolveAppended(
        activeStrokeBaseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext,
        usesResponsiveOilPreview: Bool
    ) -> DocumentStrokePreviewResolution? {
        guard !samples.isEmpty else { return nil }

        if
            let baseSnapshot = activeStrokeBaseSnapshot,
            let baseLayer = baseSnapshot.layers.first(where: { $0.index == context.activeLayerIndex })
        {
            let previewSamples = fullSamples.isEmpty ? samples : fullSamples
            guard let result = planner.makePreview(
                StrokePreviewRequest(
                    snapshot: baseSnapshot,
                    activeLayerIndex: context.activeLayerIndex,
                    baseLayer: baseLayer.surfaceRef(canvasWidth: baseSnapshot.width, canvasHeight: baseSnapshot.height),
                    samples: previewSamples,
                    brush: context.previewBrush,
                    preserveAlphaLockedPixels: context.activeLayer.isAlphaLocked,
                    usesResponsiveOilPreview: usesResponsiveOilPreview
                )
            ) else {
                return nil
            }
            return DocumentStrokePreviewResolution(result: result)
        }

        guard
            let snapshot = renderSnapshot,
            let baseLayer = snapshot.layers.first(where: { $0.index == context.activeLayerIndex }),
            let result = planner.makePreview(
                StrokePreviewRequest(
                    snapshot: snapshot,
                    activeLayerIndex: context.activeLayerIndex,
                    baseLayer: baseLayer.surfaceRef(canvasWidth: snapshot.width, canvasHeight: snapshot.height),
                    samples: samples,
                    brush: context.previewBrush,
                    preserveAlphaLockedPixels: context.activeLayer.isAlphaLocked,
                    usesResponsiveOilPreview: usesResponsiveOilPreview
                )
            )
        else {
            return nil
        }
        return DocumentStrokePreviewResolution(result: result, baseSnapshotToCapture: snapshot)
    }
}

public struct DocumentStrokeCommitUseCase: Sendable {
    public var renderer: any StrokeCommitRendering

    public init(renderer: any StrokeCommitRendering) {
        self.renderer = renderer
    }

    public func makeCommittedPixels(
        snapshot: MetalDocumentSnapshot,
        samples: [StylusSample],
        context: DocumentStrokeContext
    ) -> StrokeCommitResult? {
        renderer.makeCommittedPixels(
            StrokeCommitRequest(
                snapshot: snapshot,
                activeLayerIndex: context.activeLayerIndex,
                samples: samples,
                brush: context.previewBrush,
                preserveAlphaLockedPixels: context.activeLayer.isAlphaLocked
            )
        )
    }
}
