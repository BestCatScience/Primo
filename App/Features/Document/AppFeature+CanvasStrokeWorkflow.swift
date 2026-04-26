import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoDocumentGPUContracts
import PrimoDocumentStrokeApplication

extension AppFeature {
    struct CanvasStrokeContext {
        let activeLayer: LayerRowModel
        let activeLayerIndex: Int
        let brush: BrushRuntimeSettings
        let previewBrush: BrushRuntimeSettings
    }

    enum StrokeCommitResolution {
        case committed(DocumentMutationContract, transferredSurfaceHandle: MetalBufferHandle?)
        case failed(DocumentMutationFailure)
    }

    struct CanvasStrokeContextResolver {
        func previewBrush(for brush: BrushRuntimeSettings) -> BrushRuntimeSettings {
            brush
        }

        func resolve(
            in state: State,
            resolvedBrushSettings: (State) -> BrushRuntimeSettings,
            activeEditableLayer: (State) -> LayerRowModel?
        ) -> CanvasStrokeContext? {
            guard let activeLayer = activeEditableLayer(state) else {
                return nil
            }
            let brush = resolvedBrushSettings(state)
            return CanvasStrokeContext(
                activeLayer: activeLayer,
                activeLayerIndex: state.canvas.activeLayerIndex,
                brush: brush,
                previewBrush: previewBrush(for: brush)
            )
        }
    }

    struct CanvasStrokeStateCoordinator {
        let layerCommands: DocumentLayerCommandService
        let strokeCommands: DocumentStrokeCommandService

        func resetPreview(state: inout State) {
            state.canvas.resetStrokePreview()
        }

        func clearSelectionWithoutRefresh(
            state: inout State,
            performDocumentMutation: (inout State, DocumentMutationContract) -> Void
        ) {
            performDocumentMutation(
                &state,
                DocumentMutationContract(
                    canvasMutation: .clearSelection,
                    refresh: .none
                )
            )
        }

        func ensureCurrentPresentationLoaded(
            state: inout State,
            performDocumentMutation: (inout State, DocumentMutationContract) -> Void
        ) {
            guard state.canvas.renderSnapshot == nil else { return }
            performDocumentMutation(&state, .currentPresentation)
        }

        func captureBaseSnapshotIfNeeded(
            state: inout State,
            ensureCurrentPresentationLoaded: (inout State) -> Void
        ) {
            guard state.canvas.strokeSession.baseSnapshot == nil else { return }
            if let pendingCommittedSnapshot = state.canvas.pendingCommittedSnapshot {
                state.canvas.captureStrokeBaseSnapshot(pendingCommittedSnapshot)
                return
            }
            ensureCurrentPresentationLoaded(&state)
            if let renderSnapshot = state.canvas.renderSnapshot {
                state.canvas.captureStrokeBaseSnapshot(renderSnapshot)
            }
        }

        func prepareEditing(
            state: inout State,
            clearSelectionWithoutRefresh: (inout State) -> Void
        ) -> DocumentMutationResult {
            switch layerCommands.ensureLayerVisible(state.canvas.activeLayerIndex) {
            case .success:
                break
            case let .failure(failure):
                return .failure(failure)
            }
            clearSelectionWithoutRefresh(&state)
            strokeCommands.cancelStroke()
            return .success(())
        }

        func applyPreviewMutation(
            _ mutation: GpuPreviewMutation,
            activeLayerIndex: Int,
            state: inout State,
            releaseSurfaceHandle: (MetalBufferHandle?) -> Void
        ) {
            let previousSurfaceHandle = state.canvas.strokeSession.renderState?.surfaceHandle
            if let baseSnapshotToCapture = mutation.baseSnapshotToCapture {
                state.canvas.captureStrokeBaseSnapshot(baseSnapshotToCapture)
            }
            state.canvas.strokeSession.applyPreview(
                baseSnapshot: mutation.baseSnapshot,
                surface: mutation.surface,
                dirtyRegion: mutation.dirtyRegion,
                isApproximatePreview: mutation.isApproximatePreview,
                incrementalUpdate: mutation.incrementalUpdate,
                previewBrush: mutation.previewBrush,
                sampleCount: mutation.sampleCount,
                supportsIncrementalContinuation: mutation.supportsIncrementalContinuation
            )
            let nextSurfaceHandle = state.canvas.strokeSession.renderState?.surfaceHandle
            if previousSurfaceHandle != nextSurfaceHandle {
                releaseSurfaceHandle(previousSurfaceHandle)
            }
        }
    }

    struct CanvasStrokeEffectCoordinator {
        func complete(
            _ resolution: StrokeCommitResolution,
            state: inout State,
            resetPreview: (inout State, MetalBufferHandle?) -> Void,
            completeMutation: (inout State, DocumentMutationContract) -> Effect<Action>,
            applyFailureFeedback: (DocumentMutationFailure, inout State) -> Void,
            cancelEffects: () -> Effect<Action>
        ) -> Effect<Action> {
            let transferredSurfaceHandle: MetalBufferHandle?
            if case let .committed(_, handle) = resolution {
                transferredSurfaceHandle = handle
            } else {
                transferredSurfaceHandle = nil
            }
            if case .failed = resolution {
                state.canvas.isAwaitingCommittedRender = false
            }
            resetPreview(&state, transferredSurfaceHandle)
            switch resolution {
            case let .committed(contract, _):
                return completeMutation(&state, contract)
            case let .failed(failure):
                applyFailureFeedback(failure, &state)
                return cancelEffects()
            }
        }
    }

    struct CanvasStrokeInteractionCoordinator {
        func begin(
            state: inout State,
            sample: StylusSample,
            resolveContext: (State) -> CanvasStrokeContext?,
            prepareEditing: (inout State) -> DocumentMutationResult,
            applyFailureFeedback: (DocumentMutationFailure, inout State) -> Void,
            captureBaseSnapshot: (inout State) -> Void,
            resolveInitialPreview: (State, StylusSample, CanvasStrokeContext) -> GpuStrokeSessionOutcome,
            applyPreview: (GpuStrokeSessionOutcome, Int, inout State) -> Void,
            cancelEffects: () -> Effect<Action>
        ) -> Effect<Action> {
            guard let context = resolveContext(state) else {
                return .none
            }
            switch prepareEditing(&state) {
            case .success:
                break
            case let .failure(failure):
                applyFailureFeedback(failure, &state)
                return .none
            }
            captureBaseSnapshot(&state)
            let previewOutcome = resolveInitialPreview(
                state,
                sample,
                context
            )
            applyPreview(
                previewOutcome,
                context.activeLayerIndex,
                &state
            )
            return cancelEffects()
        }

        func append(
            state: inout State,
            samples: [StylusSample],
            resolveContext: (State) -> CanvasStrokeContext?,
            resolvePreview: (State, [StylusSample], CanvasStrokeContext) -> GpuStrokeSessionOutcome,
            applyPreview: (GpuStrokeSessionOutcome, Int, inout State) -> Void
        ) {
            guard let context = resolveContext(state) else {
                return
            }
            let previewOutcome = resolvePreview(
                state,
                samples,
                context
            )
            applyPreview(
                previewOutcome,
                context.activeLayerIndex,
                &state
            )
        }

        func finish(
            state: inout State,
            samples: [StylusSample],
            keepsSelectionCleared: Bool,
            refreshViaDirtyPresentation: Bool,
            resolveContext: (State) -> CanvasStrokeContext?,
            resetPreview: (inout State, MetalBufferHandle?) -> Void,
            resolveCommit: (inout State, [StylusSample], CanvasStrokeContext, Bool, Bool) -> StrokeCommitResolution,
            completeCommit: (StrokeCommitResolution, inout State) -> Effect<Action>
        ) -> Effect<Action> {
            guard let context = resolveContext(state) else {
                resetPreview(&state, nil)
                return .none
            }
            let commitResolution = resolveCommit(
                &state,
                samples,
                context,
                keepsSelectionCleared,
                refreshViaDirtyPresentation
            )
            return completeCommit(commitResolution, &state)
        }

        func cancel(
            state: inout State,
            cancelShapeStrokeIfNeeded: (inout State) -> Void,
            resetPreview: (inout State) -> Void,
            completeMutation: (inout State, DocumentMutationContract) -> Effect<Action>
        ) -> Effect<Action> {
            cancelShapeStrokeIfNeeded(&state)
            resetPreview(&state)
            return completeMutation(
                &state,
                .currentPresentation
            )
        }
    }

    var canvasStrokeContextResolver: CanvasStrokeContextResolver {
        CanvasStrokeContextResolver()
    }

    var canvasStrokeStateCoordinator: CanvasStrokeStateCoordinator {
        CanvasStrokeStateCoordinator(
            layerCommands: documentLayerCommandService,
            strokeCommands: documentStrokeCommandService
        )
    }

    var canvasStrokeEffectCoordinator: CanvasStrokeEffectCoordinator {
        CanvasStrokeEffectCoordinator()
    }

    var canvasStrokeInteractionCoordinator: CanvasStrokeInteractionCoordinator {
        CanvasStrokeInteractionCoordinator()
    }

    func resetStrokePreviewState(
        state: inout State,
        preserving transferredSurfaceHandle: MetalBufferHandle? = nil
    ) {
        _ = canvasStrokeInteractionService.cancel()
        let previewSurfaceHandle = state.canvas.strokeSession.renderState?.surfaceHandle
        canvasStrokeStateCoordinator.resetPreview(state: &state)
        if previewSurfaceHandle != transferredSurfaceHandle {
            documentGpuOperationGateway.releaseSurfaceHandle(previewSurfaceHandle)
        }
    }

    func clearCanvasSelectionWithoutRefresh(state: inout State) {
        canvasStrokeStateCoordinator.clearSelectionWithoutRefresh(
            state: &state,
            performDocumentMutation: { mutableState, contract in
                completeDocumentMutation(state: &mutableState, contract: contract)
            }
        )
    }

    func ensureCurrentCanvasPresentationLoaded(state: inout State) {
        canvasStrokeStateCoordinator.ensureCurrentPresentationLoaded(
            state: &state,
            performDocumentMutation: { mutableState, contract in
                completeDocumentMutation(state: &mutableState, contract: contract)
            }
        )
    }

    func captureActiveStrokeBaseSnapshotIfNeeded(state: inout State) {
        _ = canvasStrokeInteractionService.cancel()
        canvasStrokeStateCoordinator.captureBaseSnapshotIfNeeded(
            state: &state,
            ensureCurrentPresentationLoaded: { mutableState in
                ensureCurrentCanvasPresentationLoaded(state: &mutableState)
            }
        )
    }

    func applyCanvasStrokeFailure(
        _ failure: DocumentMutationFailure,
        state: inout State
    ) {
        documentMutationFeedbackCoordinator.apply(
            documentMutationFeedbackMapper.feedback(for: failure),
            to: &state
        )
    }

    func prepareCanvasStrokeEditing(state: inout State) -> DocumentMutationResult {
        canvasStrokeStateCoordinator.prepareEditing(
            state: &state,
            clearSelectionWithoutRefresh: { state in
                clearCanvasSelectionWithoutRefresh(state: &state)
            }
        )
    }

    func previewBrush(for brush: BrushRuntimeSettings) -> BrushRuntimeSettings {
        canvasStrokeContextResolver.previewBrush(for: brush)
    }

    func canvasStrokeContext(in state: State) -> CanvasStrokeContext? {
        canvasStrokeContextResolver.resolve(
            in: state,
            resolvedBrushSettings: { state in
                resolvedBrushSettings(for: state)
            },
            activeEditableLayer: { state in
                activeEditableCanvasLayer(in: state)
            }
        )
    }

    func resolveInitialStrokePreview(
        state: State,
        sample: StylusSample,
        context: CanvasStrokeContext
    ) -> GpuStrokeSessionOutcome {
        canvasStrokeInteractionService.beginPreview(
            sample: sample,
            baseSnapshot: state.canvas.strokeSession.baseSnapshot,
            context: DocumentStrokeContext(context),
            usesResponsiveOilPreview: state.usesResponsiveOilPreview(for: context.previewBrush)
        )
    }

    func resolveAppendedStrokePreview(
        state: State,
        samples: [StylusSample],
        context: CanvasStrokeContext
    ) -> GpuStrokeSessionOutcome {
        canvasStrokeInteractionService.appendPreview(
            baseSnapshot: state.canvas.strokeSession.baseSnapshot,
            renderSnapshot: state.canvas.renderSnapshot,
            renderState: state.canvas.strokeSession.renderState,
            samples: samples,
            fullSamples: state.canvas.activeStroke?.points.map(\.stylusSample) ?? samples,
            context: DocumentStrokeContext(context),
            usesResponsiveOilPreview: state.usesResponsiveOilPreview(for: context.previewBrush)
        )
    }

    func applyStrokePreviewOutcome(
        _ outcome: GpuStrokeSessionOutcome,
        activeLayerIndex: Int,
        state: inout State
    ) {
        switch outcome {
        case let .preview(mutation):
            canvasStrokeStateCoordinator.applyPreviewMutation(
                mutation,
                activeLayerIndex: activeLayerIndex,
                state: &state,
                releaseSurfaceHandle: { handle in
                    documentGpuOperationGateway.releaseSurfaceHandle(handle)
                }
            )
        case let .failure(failure):
            applyCanvasStrokeFailure(failure, state: &state)
        case .commit, .reset:
            break
        }
    }

    func resolveStrokeCommit(
        state: inout State,
        samples: [StylusSample],
        context: CanvasStrokeContext,
        keepsSelectionCleared: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> StrokeCommitResolution {
        if keepsSelectionCleared {
            switch documentLayerCommandService.ensureLayerVisible(context.activeLayerIndex) {
            case .success:
                clearCanvasSelectionWithoutRefresh(state: &state)
            case let .failure(failure):
                return .failed(failure)
            }
        }

        let outcome = canvasStrokeInteractionService.finish(
            renderState: state.canvas.strokeSession.renderState,
            baseSnapshot: state.canvas.strokeSession.baseSnapshot,
            renderSnapshot: state.canvas.renderSnapshot,
            samples: samples,
            context: DocumentStrokeContext(context),
            allowsApproximatePreviewCommit: state.usesResponsiveOilPreview(for: context.previewBrush),
            refreshViaDirtyPresentation: refreshViaDirtyPresentation
        )

        switch outcome {
        case let .commit(mutation):
            let result = documentLayerCommandService.applyLayerSurfaceMutation(
                mutation.surface.layerIndex,
                GpuLayerMutationPayload(
                    canvasWidth: mutation.surface.width,
                    canvasHeight: mutation.surface.height,
                    dirtyRect: mutation.dirtyRegion.layerPixelRect,
                    gpuBufferHandle: mutation.surface.handle.buffer
                )
            )
            switch result {
            case .success:
                return .committed(
                    DocumentMutationContract(
                        canvasMutation: keepsSelectionCleared ? .clearSelection : .none,
                        refresh: mutation.refreshViaDirtyPresentation ? .dirty : .current,
                        updatesWorkspaceArtifacts: false
                    ),
                    transferredSurfaceHandle: mutation.surface.handle.buffer
                )
            case let .failure(failure):
                return .failed(failure)
            }
        case let .failure(failure):
            return .failed(failure)
        case .preview, .reset:
            return .failed(.bridgeMutationFailed("GPU stroke commit failed: unexpected session outcome"))
        }
    }

    func completeResolvedStrokeCommit(
        _ resolution: StrokeCommitResolution,
        state: inout State
    ) -> Effect<Action> {
        canvasStrokeEffectCoordinator.complete(
            resolution,
            state: &state,
            resetPreview: { state, transferredSurfaceHandle in
                resetStrokePreviewState(
                    state: &state,
                    preserving: transferredSurfaceHandle
                )
            },
            completeMutation: { state, contract in
                completeCanvasStrokeMutation(
                    state: &state,
                    contract: contract
                )
            },
            applyFailureFeedback: { failure, state in
                applyCanvasStrokeFailure(failure, state: &state)
            },
            cancelEffects: {
                cancelStartupPresentationEffects()
            }
        )
    }

    func activeEditableCanvasLayer(in state: State) -> LayerRowModel? {
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
              !activeLayer.isLocked
        else {
            return nil
        }
        return activeLayer
    }

    func completeCanvasStrokeMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty
    ) -> Effect<Action> {
        .merge(
            completeDocumentMutation(state: &state, contract: contract),
            cancelStartupPresentationEffects()
        )
    }

    func handleBeginStroke(
        state: inout State,
        sample: StylusSample
    ) -> Effect<Action> {
        canvasStrokeInteractionCoordinator.begin(
            state: &state,
            sample: sample,
            resolveContext: { state in
                canvasStrokeContext(in: state)
            },
            prepareEditing: { state in
                prepareCanvasStrokeEditing(state: &state)
            },
            applyFailureFeedback: { failure, state in
                applyCanvasStrokeFailure(failure, state: &state)
            },
            captureBaseSnapshot: { state in
                captureActiveStrokeBaseSnapshotIfNeeded(state: &state)
            },
            resolveInitialPreview: { state, sample, context in
                resolveInitialStrokePreview(
                    state: state,
                    sample: sample,
                    context: context
                )
            },
            applyPreview: { outcome, activeLayerIndex, state in
                applyStrokePreviewOutcome(
                    outcome,
                    activeLayerIndex: activeLayerIndex,
                    state: &state
                )
            },
            cancelEffects: {
                cancelStartupPresentationEffects()
            }
        )
    }

    func handleAppendStrokeSamples(
        state: inout State,
        samples: [StylusSample]
    ) {
        canvasStrokeInteractionCoordinator.append(
            state: &state,
            samples: samples,
            resolveContext: { state in
                canvasStrokeContext(in: state)
            },
            resolvePreview: { state, samples, context in
                resolveAppendedStrokePreview(
                    state: state,
                    samples: samples,
                    context: context
                )
            },
            applyPreview: { outcome, activeLayerIndex, state in
                applyStrokePreviewOutcome(
                    outcome,
                    activeLayerIndex: activeLayerIndex,
                    state: &state
                )
            }
        )
    }

    func handlePreviewShapeStroke(
        state: inout State,
        samples: [StylusSample]
    ) -> Effect<Action> {
        guard let first = samples.first else { return .none }
        switch prepareCanvasStrokeEditing(state: &state) {
        case .success:
            break
        case let .failure(failure):
            applyCanvasStrokeFailure(failure, state: &state)
            return .none
        }
        documentStrokeCommandService.beginStroke(first, resolvedBrushSettings(for: state))
        for sample in samples.dropFirst() {
            documentStrokeCommandService.appendStroke(sample)
        }
        applyLiveCompositeSurface(documentCanvasCommandService.compositeSurface(), state: &state)
        return cancelStartupPresentationEffects()
    }

    func handleCommitPreviewShapeStroke(state: inout State) -> Effect<Action> {
        documentStrokeCommandService.endStroke()
        return completeCanvasStrokeMutation(state: &state)
    }

    func handleFinishStroke(
        state: inout State,
        samples: [StylusSample],
        keepsSelectionCleared: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> Effect<Action> {
        canvasStrokeInteractionCoordinator.finish(
            state: &state,
            samples: samples,
            keepsSelectionCleared: keepsSelectionCleared,
            refreshViaDirtyPresentation: refreshViaDirtyPresentation,
            resolveContext: { state in
                canvasStrokeContext(in: state)
            },
            resetPreview: { state, transferredSurfaceHandle in
                resetStrokePreviewState(
                    state: &state,
                    preserving: transferredSurfaceHandle
                )
            },
            resolveCommit: { state, samples, context, keepsSelectionCleared, refreshViaDirtyPresentation in
                resolveStrokeCommit(
                    state: &state,
                    samples: samples,
                    context: context,
                    keepsSelectionCleared: keepsSelectionCleared,
                    refreshViaDirtyPresentation: refreshViaDirtyPresentation
                )
            },
            completeCommit: { resolution, state in
                completeResolvedStrokeCommit(
                    resolution,
                    state: &state
                )
            }
        )
    }

    func handleCancelStroke(state: inout State) -> Effect<Action> {
        canvasStrokeInteractionCoordinator.cancel(
            state: &state,
            cancelShapeStrokeIfNeeded: { state in
                if state.canvas.currentTool == .shape {
                    documentStrokeCommandService.cancelStroke()
                }
            },
            resetPreview: { state in
                resetStrokePreviewState(state: &state)
            },
            completeMutation: { state, contract in
                completeCanvasStrokeMutation(
                    state: &state,
                    contract: contract
                )
            }
        )
    }

    func handleBlurSamples(
        state: inout State,
        samples: [StylusSample]
    ) -> Effect<Action> {
        guard !samples.isEmpty else { return .none }
        guard activeEditableCanvasLayer(in: state) != nil else {
            return .none
        }
        let activeLayerIndex = state.canvas.activeLayerIndex
        let brush = resolvedBrushSettings(for: state)
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection),
            mutation: {
                switch documentLayerCommandService.revealLayerForEditing(activeLayerIndex) {
                case .success:
                    return documentStrokeCommandService.blurStroke(
                        samples,
                        brush,
                        activeLayerIndex,
                        false
                    )
                case let .failure(failure):
                    return .failure(failure)
                }
            }
        )
    }

    func handleEndBlurStroke(state: inout State) -> Effect<Action> {
        documentStrokeCommandService.endBlurStroke()
        return completeCanvasStrokeMutation(state: &state)
    }

    func handleFill(
        state: inout State,
        sample: StylusSample
    ) -> Effect<Action> {
        guard activeEditableCanvasLayer(in: state) != nil else {
            return .none
        }
        let activeLayerIndex = state.canvas.activeLayerIndex
        let brush = resolvedBrushSettings(for: state)
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection),
            mutation: {
                switch documentLayerCommandService.ensureLayerVisible(activeLayerIndex) {
                case .success:
                    return documentStrokeCommandService.fill(
                        sample,
                        brush
                    )
                case let .failure(failure):
                    return .failure(failure)
                }
            }
        )
    }
}

private extension DocumentStrokeContext {
    init(_ context: AppFeature.CanvasStrokeContext) {
        self.init(
            activeLayer: context.activeLayer,
            activeLayerIndex: context.activeLayerIndex,
            brush: context.brush,
            previewBrush: context.previewBrush
        )
    }
}

private extension AppFeature.State {
    func usesResponsiveOilPreview(for brush: BrushRuntimeSettings) -> Bool {
        brushPalette.ui.oilLivePreviewQuality == .responsive &&
        brush.tipKind == .oil &&
        brush.smudgeEngineEnabled
    }
}
