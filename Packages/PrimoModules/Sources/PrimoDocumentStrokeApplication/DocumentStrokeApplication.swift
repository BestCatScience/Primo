import Foundation
import PrimoDocumentApplication
import PrimoBrushRuntimeContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts

private extension GpuLayerSurface {
    func materialized(with pixelData: Data?) -> GpuLayerSurface {
        GpuLayerSurface(
            layerIndex: layerIndex,
            width: width,
            height: height,
            handle: handle,
            pixelData: pixelData
        )
    }
}

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
    public let previewBrush: BrushRuntimeSettings
    public let sampleCount: Int
    public let supportsIncrementalContinuation: Bool

    public init(
        result: StrokePreviewResult,
        baseSnapshotToCapture: MetalDocumentSnapshot? = nil,
        previewBrush: BrushRuntimeSettings,
        sampleCount: Int,
        supportsIncrementalContinuation: Bool
    ) {
        self.result = result
        self.baseSnapshotToCapture = baseSnapshotToCapture
        self.previewBrush = previewBrush
        self.sampleCount = sampleCount
        self.supportsIncrementalContinuation = supportsIncrementalContinuation
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
        let usesResponsiveOilPreview = Self.effectiveResponsiveOilPreview(
            requested: usesResponsiveOilPreview,
            brush: context.previewBrush
        )
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
        return DocumentStrokePreviewResolution(
            result: result,
            previewBrush: context.previewBrush,
            sampleCount: 1,
            supportsIncrementalContinuation: Self.supportsIncrementalContinuation(for: context.previewBrush, context: context)
        )
    }

    public func resolveAppended(
        activeStrokeBaseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        renderState: StrokeSessionRenderState?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext,
        usesResponsiveOilPreview: Bool
    ) -> DocumentStrokePreviewResolution? {
        guard !samples.isEmpty else { return nil }
        let usesResponsiveOilPreview = Self.effectiveResponsiveOilPreview(
            requested: usesResponsiveOilPreview,
            brush: context.previewBrush
        )

        if
            let baseSnapshot = activeStrokeBaseSnapshot,
            let baseLayer = baseSnapshot.layers.first(where: { $0.index == context.activeLayerIndex })
        {
            let baseLayerRef: LayerSurfaceRef
            let previewSamples: [StylusSample]
            let supportsIncrementalContinuation = Self.supportsIncrementalContinuation(
                for: context.previewBrush,
                context: context
            )
            if let incremental = exactIncrementalPreview(
                baseSnapshot: baseSnapshot,
                baseLayer: baseLayer,
                renderState: renderState,
                samples: samples,
                fullSamples: fullSamples,
                context: context
            ) {
                baseLayerRef = incremental.baseLayer
                previewSamples = incremental.samples
            } else if let incremental = responsiveOilIncrementalPreview(
                baseSnapshot: baseSnapshot,
                baseLayer: baseLayer,
                renderState: renderState,
                samples: samples,
                fullSamples: fullSamples,
                context: context,
                usesResponsiveOilPreview: usesResponsiveOilPreview
            ) {
                baseLayerRef = incremental.baseLayer
                previewSamples = incremental.samples
            } else {
                baseLayerRef = baseLayer.surfaceRef(canvasWidth: baseSnapshot.width, canvasHeight: baseSnapshot.height)
                previewSamples = fullSamples.isEmpty ? samples : fullSamples
            }
            guard let result = planner.makePreview(
                StrokePreviewRequest(
                    snapshot: baseSnapshot,
                    activeLayerIndex: context.activeLayerIndex,
                    baseLayer: baseLayerRef,
                    samples: previewSamples,
                    brush: context.previewBrush,
                    preserveAlphaLockedPixels: context.activeLayer.isAlphaLocked,
                    usesResponsiveOilPreview: usesResponsiveOilPreview
                )
            ) else {
                return nil
            }
            return DocumentStrokePreviewResolution(
                result: result,
                previewBrush: context.previewBrush,
                sampleCount: fullSamples.isEmpty ? samples.count : fullSamples.count,
                supportsIncrementalContinuation: supportsIncrementalContinuation
            )
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
        return DocumentStrokePreviewResolution(
            result: result,
            baseSnapshotToCapture: snapshot,
            previewBrush: context.previewBrush,
            sampleCount: samples.count,
            supportsIncrementalContinuation: Self.supportsIncrementalContinuation(for: context.previewBrush, context: context)
        )
    }

    private func exactIncrementalPreview(
        baseSnapshot: MetalDocumentSnapshot,
        baseLayer: MetalLayerSnapshot,
        renderState: StrokeSessionRenderState?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext
    ) -> (baseLayer: LayerSurfaceRef, samples: [StylusSample])? {
        guard
            !context.activeLayer.isAlphaLocked,
            let renderState,
            !renderState.isApproximatePreview,
            renderState.supportsIncrementalContinuation,
            renderState.previewBrush == context.previewBrush,
            renderState.baseRevision == baseSnapshot.revision,
            renderState.layerIndex == context.activeLayerIndex,
            renderState.surfaceHandle.width == baseSnapshot.width,
            renderState.surfaceHandle.height == baseSnapshot.height,
            renderState.sampleCount + samples.count == fullSamples.count,
            Self.supportsIncrementalContinuation(for: context.previewBrush, context: context)
        else {
            return nil
        }

        let connectionSample = previousSample(in: fullSamples, beforeSuffix: samples)
        let incrementalSamples = connectionSample.map { [$0] + samples } ?? samples
        guard !incrementalSamples.isEmpty else { return nil }

        return (
            LayerSurfaceRef(
                layerIndex: baseLayer.index,
                width: baseSnapshot.width,
                height: baseSnapshot.height,
                pixelData: baseLayer.pixelData,
                gpuHandle: GpuSurfaceHandle(buffer: renderState.surfaceHandle)
            ),
            incrementalSamples
        )
    }

    private func responsiveOilIncrementalPreview(
        baseSnapshot: MetalDocumentSnapshot,
        baseLayer: MetalLayerSnapshot,
        renderState: StrokeSessionRenderState?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext,
        usesResponsiveOilPreview: Bool
    ) -> (baseLayer: LayerSurfaceRef, samples: [StylusSample])? {
        guard
            usesResponsiveOilPreview,
            !context.activeLayer.isAlphaLocked,
            let renderState,
            renderState.isApproximatePreview,
            renderState.baseRevision == baseSnapshot.revision,
            renderState.layerIndex == context.activeLayerIndex,
            renderState.surfaceHandle.width == baseSnapshot.width,
            renderState.surfaceHandle.height == baseSnapshot.height
        else {
            return nil
        }

        let connectionSample = previousSample(in: fullSamples, beforeSuffix: samples)
        let incrementalSamples = connectionSample.map { [$0] + samples } ?? samples
        guard !incrementalSamples.isEmpty else { return nil }

        return (
            LayerSurfaceRef(
                layerIndex: baseLayer.index,
                width: baseSnapshot.width,
                height: baseSnapshot.height,
                pixelData: baseLayer.pixelData,
                gpuHandle: GpuSurfaceHandle(buffer: renderState.surfaceHandle)
            ),
            incrementalSamples
        )
    }

    private func previousSample(
        in fullSamples: [StylusSample],
        beforeSuffix samples: [StylusSample]
    ) -> StylusSample? {
        guard !samples.isEmpty, fullSamples.count > samples.count else { return nil }
        return fullSamples[fullSamples.count - samples.count - 1]
    }

    private static func supportsIncrementalContinuation(
        for brush: BrushRuntimeSettings,
        context: DocumentStrokeContext
    ) -> Bool {
        !context.activeLayer.isAlphaLocked &&
            StrokePreviewContinuationPolicy.shouldUseIncrementalPreviewUpdate(for: brush)
    }

    private static func effectiveResponsiveOilPreview(
        requested: Bool,
        brush: BrushRuntimeSettings
    ) -> Bool {
        requested && brush.tipKind == .oil
    }
}

public struct DocumentStrokeCommitUseCase: Sendable {
    public var renderer: any StrokeCommitRendering

    public init(renderer: any StrokeCommitRendering) {
        self.renderer = renderer
    }

    public func makeCommittedSurface(
        snapshot: MetalDocumentSnapshot,
        samples: [StylusSample],
        context: DocumentStrokeContext
    ) -> StrokeCommitResult? {
        renderer.makeCommittedSurface(
            StrokeCommitRequest(
                snapshot: snapshot,
                activeLayerIndex: context.activeLayerIndex,
                samples: samples,
                brush: context.brush,
                preserveAlphaLockedPixels: context.activeLayer.isAlphaLocked
            )
        )
    }

    public func materializedPixelData(for surface: GpuLayerSurface) -> Data? {
        renderer.materializedPixelData(for: surface)
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
        renderState: StrokeSessionRenderState?,
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

        case let .append(baseSnapshot, renderSnapshot, renderState, samples, fullSamples, context, usesResponsiveOilPreview):
            guard let resolution = preview.resolveAppended(
                activeStrokeBaseSnapshot: baseSnapshot,
                renderSnapshot: renderSnapshot,
                renderState: renderState,
                samples: samples,
                fullSamples: fullSamples,
                context: context,
                usesResponsiveOilPreview: usesResponsiveOilPreview
            ) else {
                return .failure(.bridgeMutationFailed("GPU stroke preview failed: missing render snapshot or surface"))
            }
            return previewOutcome(from: resolution)

        case let .finish(renderState, baseSnapshot, renderSnapshot, samples, context, allowsApproximatePreviewCommit, refreshViaDirtyPresentation):
            let snapshot = baseSnapshot ?? renderSnapshot
            if
                let renderState,
                let snapshot,
                !renderState.isApproximatePreview,
                renderState.baseRevision == snapshot.revision,
                renderState.layerIndex == context.activeLayerIndex,
                renderState.previewBrush == context.previewBrush,
                renderState.sampleCount == samples.count,
                renderState.surfaceHandle.width == snapshot.width,
                renderState.surfaceHandle.height == snapshot.height
            {
                let surface = GpuLayerSurface(
                    layerIndex: renderState.layerIndex,
                    width: renderState.surfaceHandle.width,
                    height: renderState.surfaceHandle.height,
                    handle: GpuSurfaceHandle(buffer: renderState.surfaceHandle)
                )
                return .commit(
                    GpuCommitMutation(
                        surface: surface.materialized(with: commit.materializedPixelData(for: surface)),
                        dirtyRegion: GpuSurfaceRegion(renderState.dirtyRect),
                        refreshViaDirtyPresentation: refreshViaDirtyPresentation
                    )
                )
            }
            if
                let renderState,
                renderState.isApproximatePreview,
                allowsApproximatePreviewCommit,
                !context.previewBrush.smudgeEngineEnabled
            {
                let surface = GpuLayerSurface(
                    layerIndex: renderState.layerIndex,
                    width: renderState.surfaceHandle.width,
                    height: renderState.surfaceHandle.height,
                    handle: GpuSurfaceHandle(buffer: renderState.surfaceHandle)
                )
                return .commit(
                    GpuCommitMutation(
                        surface: surface.materialized(with: commit.materializedPixelData(for: surface)),
                        dirtyRegion: GpuSurfaceRegion(renderState.dirtyRect),
                        refreshViaDirtyPresentation: refreshViaDirtyPresentation
                    )
                )
            }

            guard let snapshot else {
                return .failure(.bridgeMutationFailed("GPU stroke commit failed: missing base snapshot"))
            }
            guard let result = commit.makeCommittedSurface(
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
                baseSnapshotToCapture: resolution.baseSnapshotToCapture,
                previewBrush: resolution.previewBrush,
                sampleCount: resolution.sampleCount,
                supportsIncrementalContinuation: resolution.supportsIncrementalContinuation
            )
        )
    }
}
