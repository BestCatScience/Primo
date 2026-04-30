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

private extension GpuCommitMutation {
    static func materializedPreviewSurface(
        _ surface: GpuLayerSurface,
        dirtyRegion: GpuSurfaceRegion,
        refreshViaDirtyPresentation: Bool,
        commit: DocumentStrokeCommitUseCase
    ) -> GpuStrokeSessionOutcome {
        guard let pixelData = commit.materializedPixelData(for: surface) else {
            return .failure(.bridgeMutationFailed("GPU stroke commit materialization failed"))
        }
        return .commit(
            GpuCommitMutation(
                surface: surface.materialized(with: pixelData),
                dirtyRegion: dirtyRegion,
                refreshViaDirtyPresentation: refreshViaDirtyPresentation
            )
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

public enum StrokeCommitSelectionClearPolicy: Equatable, Sendable {
    case none
    case clearSelection
}

public struct StrokeCommitWorkflowRequest: Sendable {
    public let baseSnapshot: MetalDocumentSnapshot?
    public let renderSnapshot: MetalDocumentSnapshot?
    public let renderState: StrokeSessionRenderState?
    public let samples: [StylusSample]
    public let context: DocumentStrokeContext
    public let selectionClearPolicy: StrokeCommitSelectionClearPolicy
    public let refreshViaDirtyPresentation: Bool

    public init(
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        renderState: StrokeSessionRenderState?,
        samples: [StylusSample],
        context: DocumentStrokeContext,
        selectionClearPolicy: StrokeCommitSelectionClearPolicy,
        refreshViaDirtyPresentation: Bool
    ) {
        self.baseSnapshot = baseSnapshot
        self.renderSnapshot = renderSnapshot
        self.renderState = renderState
        self.samples = samples
        self.context = context
        self.selectionClearPolicy = selectionClearPolicy
        self.refreshViaDirtyPresentation = refreshViaDirtyPresentation
    }
}

public struct StrokeCommitPendingSnapshot: Sendable {
    public let baseSnapshot: MetalDocumentSnapshot
    public let surface: GpuLayerSurface

    public init(baseSnapshot: MetalDocumentSnapshot, surface: GpuLayerSurface) {
        self.baseSnapshot = baseSnapshot
        self.surface = surface
    }
}

public struct StrokeCommitWorkflowResult<Selection: Equatable & Sendable, Feedback: Equatable & Sendable>: Sendable {
    public let contract: DocumentMutationWorkflowOutcome<Selection, Feedback>
    public let transferredSurfaceHandle: MetalBufferHandle?
    public let pendingCommittedSnapshot: StrokeCommitPendingSnapshot?

    public init(
        contract: DocumentMutationWorkflowOutcome<Selection, Feedback>,
        transferredSurfaceHandle: MetalBufferHandle?,
        pendingCommittedSnapshot: StrokeCommitPendingSnapshot?
    ) {
        self.contract = contract
        self.transferredSurfaceHandle = transferredSurfaceHandle
        self.pendingCommittedSnapshot = pendingCommittedSnapshot
    }
}

public struct DocumentStrokeCommitWorkflowService: Sendable {
    public let layerCommands: DocumentLayerCommandService
    public let strokeInteraction: CanvasStrokeInteractionService

    public init(
        layerCommands: DocumentLayerCommandService,
        strokeInteraction: CanvasStrokeInteractionService
    ) {
        self.layerCommands = layerCommands
        self.strokeInteraction = strokeInteraction
    }

    public func resolveCommit<Selection: Equatable & Sendable, Feedback: Equatable & Sendable>(
        _ request: StrokeCommitWorkflowRequest,
        usesResponsivePreviewCommit: Bool
    ) -> Result<StrokeCommitWorkflowResult<Selection, Feedback>, DocumentMutationFailure> {
        if request.selectionClearPolicy == .clearSelection {
            switch layerCommands.ensureLayerVisible(request.context.activeLayerIndex) {
            case .success:
                break
            case let .failure(failure):
                return .failure(failure)
            }
        }

        let outcome = strokeInteraction.finish(
            renderState: request.renderState,
            baseSnapshot: request.baseSnapshot,
            renderSnapshot: request.renderSnapshot,
            samples: request.samples,
            context: request.context,
            allowsApproximatePreviewCommit: usesResponsivePreviewCommit,
            refreshViaDirtyPresentation: request.refreshViaDirtyPresentation
        )

        switch outcome {
        case let .commit(mutation):
            guard let payload = GpuLayerMutationPayload(
                validatingCanvasWidth: mutation.surface.width,
                canvasHeight: mutation.surface.height,
                dirtyRect: mutation.dirtyRegion.layerPixelRect,
                gpuBufferHandle: mutation.surface.handle.buffer,
                fallbackPixelData: mutation.surface.pixelData
            ) else {
                return .failure(.bridgeMutationFailed("GPU stroke commit invalid payload"))
            }
            let result = layerCommands.applyLayerSurfaceMutation(
                mutation.surface.layerIndex,
                payload
            )
            switch result {
            case .success:
                let commitBaseSnapshot = request.baseSnapshot ?? request.renderSnapshot
                return .success(
                    StrokeCommitWorkflowResult(
                        contract: DocumentMutationWorkflowOutcome<Selection, Feedback>(
                            canvasMutation: request.selectionClearPolicy == .clearSelection ? .clearSelection : .none,
                            refresh: mutation.refreshViaDirtyPresentation ? .dirty : .current,
                            updatesWorkspaceArtifacts: false
                        ),
                        transferredSurfaceHandle: mutation.surface.handle.buffer,
                        pendingCommittedSnapshot: commitBaseSnapshot.map {
                            StrokeCommitPendingSnapshot(baseSnapshot: $0, surface: mutation.surface)
                        }
                    )
                )
            case let .failure(failure):
                return .failure(failure)
            }
        case let .failure(failure):
            return .failure(failure)
        case .preview, .reset:
            return .failure(.bridgeMutationFailed("GPU stroke commit failed: unexpected session outcome"))
        }
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
        usesResponsivePreview: Bool
    ) -> DocumentStrokePreviewResolution? {
        let usesResponsivePreview = Self.effectiveResponsivePreview(
            requested: usesResponsivePreview,
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
                    usesResponsivePreview: usesResponsivePreview
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
        usesResponsivePreview: Bool
    ) -> DocumentStrokePreviewResolution? {
        guard !samples.isEmpty else { return nil }
        let usesResponsivePreview = Self.effectiveResponsivePreview(
            requested: usesResponsivePreview,
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
            } else if let incremental = responsiveIncrementalPreview(
                baseSnapshot: baseSnapshot,
                baseLayer: baseLayer,
                renderState: renderState,
                samples: samples,
                fullSamples: fullSamples,
                context: context,
                usesResponsivePreview: usesResponsivePreview
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
                    usesResponsivePreview: usesResponsivePreview
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
                    usesResponsivePreview: usesResponsivePreview
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

    private func responsiveIncrementalPreview(
        baseSnapshot: MetalDocumentSnapshot,
        baseLayer: MetalLayerSnapshot,
        renderState: StrokeSessionRenderState?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> (baseLayer: LayerSurfaceRef, samples: [StylusSample])? {
        guard
            usesResponsivePreview,
            !context.activeLayer.isAlphaLocked,
            let renderState,
            renderState.previewBrush == context.previewBrush,
            renderState.baseRevision == baseSnapshot.revision,
            renderState.layerIndex == context.activeLayerIndex,
            renderState.surfaceHandle.width == baseSnapshot.width,
            renderState.surfaceHandle.height == baseSnapshot.height,
            renderState.sampleCount + samples.count == fullSamples.count
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

    private static func effectiveResponsivePreview(
        requested: Bool,
        brush: BrushRuntimeSettings
    ) -> Bool {
        requested
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
        usesResponsivePreview: Bool
    )
    case append(
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        renderState: StrokeSessionRenderState?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
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
    public let resetInteractiveStrokeState: @Sendable () -> Void
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
        case let .begin(sample, baseSnapshot, context, usesResponsivePreview):
            guard let resolution = preview.resolveInitial(
                baseSnapshot: baseSnapshot,
                sample: sample,
                context: context,
                usesResponsivePreview: usesResponsivePreview
            ) else {
                return .failure(.bridgeMutationFailed("GPU stroke preview failed: missing base snapshot or surface"))
            }
            return previewOutcome(from: resolution)

        case let .append(baseSnapshot, renderSnapshot, renderState, samples, fullSamples, context, usesResponsivePreview):
            guard let resolution = preview.resolveAppended(
                activeStrokeBaseSnapshot: baseSnapshot,
                renderSnapshot: renderSnapshot,
                renderState: renderState,
                samples: samples,
                fullSamples: fullSamples,
                context: context,
                usesResponsivePreview: usesResponsivePreview
            ) else {
                return .failure(.bridgeMutationFailed("GPU stroke preview failed: missing render snapshot or surface"))
            }
            return previewOutcome(from: resolution)

        case let .finish(renderState, baseSnapshot, renderSnapshot, samples, context, allowsApproximatePreviewCommit, refreshViaDirtyPresentation):
            let snapshot = baseSnapshot ?? renderSnapshot
            let commitContext = Self.commitContext(renderState: renderState, fallback: context)
            if
                let renderState,
                let snapshot,
                !renderState.isApproximatePreview,
                renderState.baseRevision == snapshot.revision,
                renderState.layerIndex == commitContext.activeLayerIndex,
                renderState.previewBrush == commitContext.previewBrush,
                renderState.surfaceHandle.width == snapshot.width,
                renderState.surfaceHandle.height == snapshot.height,
                renderState.sampleCount == samples.count,
                renderState.previewBrush != nil
            {
                let surface = GpuLayerSurface(
                    layerIndex: renderState.layerIndex,
                    width: renderState.surfaceHandle.width,
                    height: renderState.surfaceHandle.height,
                    handle: GpuSurfaceHandle(buffer: renderState.surfaceHandle)
                )
                return GpuCommitMutation.materializedPreviewSurface(
                    surface,
                    dirtyRegion: GpuSurfaceRegion(renderState.dirtyRect),
                    refreshViaDirtyPresentation: refreshViaDirtyPresentation,
                    commit: commit
                )
            }
            if
                let renderState,
                let snapshot,
                renderState.isApproximatePreview,
                allowsApproximatePreviewCommit,
                renderState.baseRevision == snapshot.revision,
                renderState.layerIndex == commitContext.activeLayerIndex,
                renderState.previewBrush == commitContext.previewBrush,
                renderState.surfaceHandle.width == snapshot.width,
                renderState.surfaceHandle.height == snapshot.height,
                renderState.sampleCount == samples.count,
                renderState.previewBrush != nil,
                !commitContext.previewBrush.smudgeEngineEnabled
            {
                let surface = GpuLayerSurface(
                    layerIndex: renderState.layerIndex,
                    width: renderState.surfaceHandle.width,
                    height: renderState.surfaceHandle.height,
                    handle: GpuSurfaceHandle(buffer: renderState.surfaceHandle)
                )
                return GpuCommitMutation.materializedPreviewSurface(
                    surface,
                    dirtyRegion: GpuSurfaceRegion(renderState.dirtyRect),
                    refreshViaDirtyPresentation: refreshViaDirtyPresentation,
                    commit: commit
                )
            }

            guard let snapshot else {
                return .failure(.bridgeMutationFailed("GPU stroke commit failed: missing base snapshot"))
            }
            guard let result = commit.makeCommittedSurface(
                snapshot: snapshot,
                samples: samples,
                context: commitContext
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

    private static func commitContext(
        renderState: StrokeSessionRenderState?,
        fallback context: DocumentStrokeContext
    ) -> DocumentStrokeContext {
        guard let previewBrush = renderState?.previewBrush else {
            return context
        }
        return DocumentStrokeContext(
            activeLayer: context.activeLayer,
            activeLayerIndex: context.activeLayerIndex,
            brush: previewBrush,
            previewBrush: previewBrush
        )
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
