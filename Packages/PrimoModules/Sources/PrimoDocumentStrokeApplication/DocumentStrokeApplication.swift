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

public enum GpuStrokeSessionCommand: Sendable {
    case begin(
        sample: StylusSample,
        baseSnapshot: MetalDocumentSnapshot?,
        context: DocumentStrokeContext,
        usesResponsiveOilPreview: Bool
    )
    case append(
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext,
        usesResponsiveOilPreview: Bool
    )
    case finish(
        renderState: StrokeSessionRenderState?,
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        samples: [StylusSample],
        context: DocumentStrokeContext,
        allowsApproximatePreviewCommit: Bool,
        refreshViaDirtyPresentation: Bool
    )
    case cancel
}

public enum GpuStrokeSessionOutcome: Sendable {
    case preview(GpuPreviewMutation)
    case commit(GpuCommitMutation)
    case reset
    case failure(DocumentMutationFailure)
}

public struct DocumentStrokeSessionUseCase: Sendable {
    public var preview: DocumentStrokePreviewUseCase
    public var commit: DocumentStrokeCommitUseCase
    public var resetInteractiveStrokeState: @Sendable () -> Void
    private var executeOverride: (@Sendable (GpuStrokeSessionCommand) -> GpuStrokeSessionOutcome)?

    public init(
        preview: DocumentStrokePreviewUseCase,
        commit: DocumentStrokeCommitUseCase,
        resetInteractiveStrokeState: @escaping @Sendable () -> Void,
        executeOverride: (@Sendable (GpuStrokeSessionCommand) -> GpuStrokeSessionOutcome)? = nil
    ) {
        self.preview = preview
        self.commit = commit
        self.resetInteractiveStrokeState = resetInteractiveStrokeState
        self.executeOverride = executeOverride
    }

    public func execute(_ command: GpuStrokeSessionCommand) -> GpuStrokeSessionOutcome {
        if let executeOverride {
            return executeOverride(command)
        }
        switch command {
        case let .begin(sample, baseSnapshot, context, usesResponsiveOilPreview):
            guard let resolution = preview.resolveInitial(
                baseSnapshot: baseSnapshot,
                sample: sample,
                context: context,
                usesResponsiveOilPreview: usesResponsiveOilPreview
            ) else {
                return .failure(.bridgeMutationFailed("GPU stroke preview failed: missing base snapshot or surface"))
            }
            return previewOutcome(from: resolution)

        case let .append(baseSnapshot, renderSnapshot, samples, fullSamples, context, usesResponsiveOilPreview):
            guard let resolution = preview.resolveAppended(
                activeStrokeBaseSnapshot: baseSnapshot,
                renderSnapshot: renderSnapshot,
                samples: samples,
                fullSamples: fullSamples,
                context: context,
                usesResponsiveOilPreview: usesResponsiveOilPreview
            ) else {
                return .failure(.bridgeMutationFailed("GPU stroke preview failed: missing render snapshot or surface"))
            }
            return previewOutcome(from: resolution)

        case let .finish(renderState, baseSnapshot, renderSnapshot, samples, context, allowsApproximatePreviewCommit, refreshViaDirtyPresentation):
            if
                let renderState,
                (!renderState.isApproximatePreview || allowsApproximatePreviewCommit)
            {
                return .commit(
                    GpuCommitMutation(
                        surface: GpuLayerSurface(
                            layerIndex: renderState.layerIndex,
                            width: renderState.surfaceHandle.width,
                            height: renderState.surfaceHandle.height,
                            handle: GpuSurfaceHandle(buffer: renderState.surfaceHandle)
                        ),
                        dirtyRegion: GpuSurfaceRegion(renderState.dirtyRect),
                        refreshViaDirtyPresentation: refreshViaDirtyPresentation
                    )
                )
            }

            let snapshot = baseSnapshot ?? renderSnapshot
            guard let snapshot else {
                return .failure(.bridgeMutationFailed("GPU stroke commit failed: missing base snapshot"))
            }
            guard let result = commit.makeCommittedPixels(
                snapshot: snapshot,
                samples: samples,
                context: context
            ) else {
                return .failure(.bridgeMutationFailed("GPU stroke commit failed: missing committed surface"))
            }
            return .commit(
                GpuCommitMutation(
                    surface: result.surface,
                    dirtyRegion: result.dirtyRegion,
                    refreshViaDirtyPresentation: refreshViaDirtyPresentation
                )
            )

        case .cancel:
            resetInteractiveStrokeState()
            return .reset
        }
    }

    private func previewOutcome(from resolution: DocumentStrokePreviewResolution) -> GpuStrokeSessionOutcome {
        guard
            let surface = resolution.result.surface,
            let dirtyRegion = resolution.result.dirtyRegion
        else {
            return .failure(.bridgeMutationFailed("GPU stroke preview failed: missing surface handle"))
        }
        return .preview(
            GpuPreviewMutation(
                baseSnapshot: resolution.result.baseSnapshot,
                surface: surface,
                dirtyRegion: dirtyRegion,
                incrementalUpdate: resolution.result.incrementalUpdate,
                isApproximatePreview: resolution.result.isApproximatePreview,
                baseSnapshotToCapture: resolution.baseSnapshotToCapture
            )
        )
    }
}
