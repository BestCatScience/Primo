import ComposableArchitecture
import Foundation
import PrimoDocumentApplication

extension AppFeature {
    struct StrokePreviewPlan {
        let baseSnapshot: MetalDocumentSnapshot
        let adjustedPixels: Data
        let dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?
        let rectPixelData: Data?
        let incrementalUpdate: IncrementalLayerUpdate?
    }

    struct CanvasStrokeContext {
        let activeLayer: LayerRowModel
        let activeLayerIndex: Int
        let brush: BrushRuntimeSettings
        let previewBrush: BrushRuntimeSettings
    }

    struct StrokePreviewResolution {
        let plan: StrokePreviewPlan
        var baseSnapshotToCapture: MetalDocumentSnapshot? = nil
    }

    enum StrokeCommitResolution {
        case committed(DocumentMutationContract)
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
        let workflowService: DocumentInteractionService

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
            guard state.canvas.activeStrokeBaseSnapshot == nil else { return }
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
            switch workflowService.ensureLayerVisible(state.canvas.activeLayerIndex) {
            case .success:
                break
            case let .failure(failure):
                return .failure(failure)
            }
            clearSelectionWithoutRefresh(&state)
            workflowService.cancelStroke()
            return .success(())
        }

        func applyPreviewResolution(
            _ resolution: StrokePreviewResolution,
            activeLayerIndex: Int,
            state: inout State,
            applyPreviewPlan: (StrokePreviewPlan, Int, inout State) -> Void
        ) {
            if let baseSnapshotToCapture = resolution.baseSnapshotToCapture {
                state.canvas.captureStrokeBaseSnapshot(baseSnapshotToCapture)
            }
            applyPreviewPlan(
                resolution.plan,
                activeLayerIndex,
                &state
            )
        }
    }

    struct CanvasStrokePreviewResolver {
        fileprivate func resolveInitial(
            state: State,
            sample: StylusSample,
            context: CanvasStrokeContext,
            makePreviewPlan: (
                MetalDocumentSnapshot,
                Int,
                Data,
                [StylusSample],
                BrushRuntimeSettings,
                Bool
            ) -> StrokePreviewPlan?
        ) -> StrokePreviewResolution? {
            guard let baseSnapshot = state.canvas.activeStrokeBaseSnapshot,
                  let baseLayer = baseSnapshot.layers.first(where: { $0.index == context.activeLayerIndex }),
                  let previewPlan = makePreviewPlan(
                    baseSnapshot,
                    context.activeLayerIndex,
                    baseLayer.pixelData,
                    [sample],
                    context.previewBrush,
                    context.activeLayer.isAlphaLocked
                  )
            else {
                return nil
            }
            return StrokePreviewResolution(plan: previewPlan)
        }

        fileprivate func resolveAppended(
            state: State,
            samples: [StylusSample],
            context: CanvasStrokeContext,
            makePreviewPlan: (
                MetalDocumentSnapshot,
                Int,
                Data,
                [StylusSample],
                BrushRuntimeSettings,
                Bool
            ) -> StrokePreviewPlan?
        ) -> StrokePreviewResolution? {
            guard !samples.isEmpty else { return nil }
            if
                let baseSnapshot = state.canvas.activeStrokeBaseSnapshot,
                let baseLayer = baseSnapshot.layers.first(where: { $0.index == context.activeLayerIndex })
            {
                let fullSamples = !state.canvas.pendingStrokeFinalizationSamples.isEmpty
                    ? state.canvas.pendingStrokeFinalizationSamples
                    : (state.canvas.activeStroke?.points.map(\.stylusSample) ?? samples)
                guard let previewPlan = makePreviewPlan(
                    baseSnapshot,
                    context.activeLayerIndex,
                    baseLayer.pixelData,
                    fullSamples,
                    context.previewBrush,
                    context.activeLayer.isAlphaLocked
                ) else {
                    return nil
                }
                return StrokePreviewResolution(plan: previewPlan)
            }

            guard
                let snapshot = state.canvas.renderSnapshot,
                let baseLayer = snapshot.layers.first(where: { $0.index == context.activeLayerIndex }),
                let previewPlan = makePreviewPlan(
                    snapshot,
                    context.activeLayerIndex,
                    baseLayer.pixelData,
                    samples,
                    context.previewBrush,
                    context.activeLayer.isAlphaLocked
                )
            else {
                return nil
            }
            return StrokePreviewResolution(
                plan: previewPlan,
                baseSnapshotToCapture: snapshot
            )
        }
    }

    struct CanvasStrokeCommitService {
        let workflowService: DocumentInteractionService

        fileprivate func resolve(
            state: inout State,
            samples: [StylusSample],
            context: CanvasStrokeContext,
            keepsSelectionCleared: Bool,
            refreshViaDirtyPresentation: Bool,
            clearSelectionWithoutRefresh: (inout State) -> Void,
            commitFallbackPixels: (inout State, [StylusSample], BrushRuntimeSettings, LayerRowModel, Bool) -> DocumentMutationResult
        ) -> StrokeCommitResolution {
            if keepsSelectionCleared {
                switch workflowService.ensureLayerVisible(context.activeLayerIndex) {
                case .success:
                    break
                case let .failure(failure):
                    return .failed(failure)
                }
                clearSelectionWithoutRefresh(&state)
            }
            let commitResult: DocumentMutationResult
            if let dirtyRect = state.canvas.activeStrokePreviewDirtyRect,
               let rectPixelData = state.canvas.activeStrokePreviewRectPixelData {
                commitResult = workflowService.replaceLayerPixels(
                    context.activeLayerIndex,
                    in: dirtyRect,
                    pixelData: rectPixelData
                )
            } else if let previewPixels = state.canvas.activeStrokePreviewLayerPixelData {
                commitResult = workflowService.replaceLayerPixels(
                    context.activeLayerIndex,
                    pixelData: previewPixels
                )
            } else {
                commitResult = commitFallbackPixels(
                    &state,
                    samples,
                    context.previewBrush,
                    context.activeLayer,
                    refreshViaDirtyPresentation
                )
            }
            switch commitResult {
            case .success:
                if let stagedSnapshot = Self.stagedCommittedSnapshot(
                    state: state,
                    activeLayerIndex: context.activeLayerIndex
                ) {
                    state.canvas.stagePendingCommittedSnapshot(stagedSnapshot)
                }
                break
            case let .failure(failure):
                return .failed(failure)
            }
            return .committed(
                DocumentMutationContract(
                    canvasMutation: keepsSelectionCleared ? .clearSelection : .none,
                    refresh: refreshViaDirtyPresentation ? .dirty : .current,
                    updatesWorkspaceArtifacts: false
                )
            )
        }

        private static func stagedCommittedSnapshot(
            state: State,
            activeLayerIndex: Int
        ) -> MetalDocumentSnapshot? {
            guard
                let baseSnapshot = state.canvas.activeStrokeBaseSnapshot,
                let committedPixels = state.canvas.activeStrokePreviewLayerPixelData
            else {
                return nil
            }

            let compositePixelData: Data
            if let stagedCompositePixelData = state.canvas.stagedPreviewCompositePixelData(baseSnapshot: baseSnapshot) {
                compositePixelData = stagedCompositePixelData
            } else if let composited = AppFeature.compositedPreviewPixelData(
                snapshot: baseSnapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerPixels: committedPixels
            ) {
                compositePixelData = composited
            } else {
                return nil
            }

            let layers = baseSnapshot.layers.map { layer in
                guard layer.index == activeLayerIndex else { return layer }
                return MetalLayerSnapshot(
                    index: layer.index,
                    opacity: layer.opacity,
                    visible: layer.visible,
                    isClipped: layer.isClipped,
                    blendMode: layer.blendMode,
                    thumbnailData: layer.thumbnailData,
                    pixelData: committedPixels
                )
            }

            return MetalDocumentSnapshot(
                width: baseSnapshot.width,
                height: baseSnapshot.height,
                revision: max(baseSnapshot.revision, state.canvas.lastCommittedRenderRevision) + 1,
                compositePixelData: compositePixelData,
                layers: layers
            )
        }
    }

    struct CanvasStrokeEffectCoordinator {
        func complete(
            _ resolution: StrokeCommitResolution,
            state: inout State,
            resetPreview: (inout State) -> Void,
            completeMutation: (inout State, DocumentMutationContract) -> Effect<Action>,
            applyFailureFeedback: (DocumentMutationFailure, inout State) -> Void,
            cancelEffects: () -> Effect<Action>
        ) -> Effect<Action> {
            if case .failed = resolution {
                state.canvas.isAwaitingCommittedRender = false
            }
            resetPreview(&state)
            switch resolution {
            case let .committed(contract):
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
            resolveInitialPreview: (State, StylusSample, CanvasStrokeContext) -> StrokePreviewResolution?,
            applyPreview: (StrokePreviewResolution, Int, inout State) -> Void,
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
            if let previewResolution = resolveInitialPreview(
                state,
                sample,
                context
            ) {
                applyPreview(
                    previewResolution,
                    context.activeLayerIndex,
                    &state
                )
            }
            return cancelEffects()
        }

        func append(
            state: inout State,
            samples: [StylusSample],
            resolveContext: (State) -> CanvasStrokeContext?,
            resolvePreview: (State, [StylusSample], CanvasStrokeContext) -> StrokePreviewResolution?,
            applyPreview: (StrokePreviewResolution, Int, inout State) -> Void
        ) {
            guard let context = resolveContext(state) else {
                return
            }
            guard let previewResolution = resolvePreview(
                state,
                samples,
                context
            ) else {
                return
            }
            applyPreview(
                previewResolution,
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
            resetPreview: (inout State) -> Void,
            resolveCommit: (inout State, [StylusSample], CanvasStrokeContext, Bool, Bool) -> StrokeCommitResolution,
            completeCommit: (StrokeCommitResolution, inout State) -> Effect<Action>
        ) -> Effect<Action> {
            guard let context = resolveContext(state) else {
                resetPreview(&state)
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
        CanvasStrokeStateCoordinator(workflowService: documentInteractionService)
    }

    var canvasStrokePreviewResolver: CanvasStrokePreviewResolver {
        CanvasStrokePreviewResolver()
    }

    var canvasStrokeCommitService: CanvasStrokeCommitService {
        CanvasStrokeCommitService(workflowService: documentInteractionService)
    }

    var canvasStrokeEffectCoordinator: CanvasStrokeEffectCoordinator {
        CanvasStrokeEffectCoordinator()
    }

    var canvasStrokeInteractionCoordinator: CanvasStrokeInteractionCoordinator {
        CanvasStrokeInteractionCoordinator()
    }

    func resetStrokePreviewState(state: inout State) {
        MetalDocumentProcessingClient.shared.resetInteractiveStrokeState()
        canvasStrokeStateCoordinator.resetPreview(state: &state)
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
        MetalDocumentProcessingClient.shared.resetInteractiveStrokeState()
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
    ) -> StrokePreviewResolution? {
        canvasStrokePreviewResolver.resolveInitial(
            state: state,
            sample: sample,
            context: context,
            makePreviewPlan: { snapshot, activeLayerIndex, basePixelData, samples, brush, preserveAlphaLockedPixels in
                makeStrokePreviewPlan(
                    snapshot: snapshot,
                    activeLayerIndex: activeLayerIndex,
                    basePixelData: basePixelData,
                    samples: samples,
                    brush: brush,
                    preserveAlphaLockedPixels: preserveAlphaLockedPixels
                )
            }
        )
    }

    func resolveAppendedStrokePreview(
        state: State,
        samples: [StylusSample],
        context: CanvasStrokeContext
    ) -> StrokePreviewResolution? {
        canvasStrokePreviewResolver.resolveAppended(
            state: state,
            samples: samples,
            context: context,
            makePreviewPlan: { snapshot, activeLayerIndex, basePixelData, samples, brush, preserveAlphaLockedPixels in
                makeStrokePreviewPlan(
                    snapshot: snapshot,
                    activeLayerIndex: activeLayerIndex,
                    basePixelData: basePixelData,
                    samples: samples,
                    brush: brush,
                    preserveAlphaLockedPixels: preserveAlphaLockedPixels
                )
            }
        )
    }

    func applyStrokePreviewResolution(
        _ resolution: StrokePreviewResolution,
        activeLayerIndex: Int,
        state: inout State
    ) {
        canvasStrokeStateCoordinator.applyPreviewResolution(
            resolution,
            activeLayerIndex: activeLayerIndex,
            state: &state,
            applyPreviewPlan: { plan, activeLayerIndex, state in
                applyStrokePreviewPlan(
                    plan,
                    activeLayerIndex: activeLayerIndex,
                    state: &state
                )
            }
        )
    }

    func resolveStrokeCommit(
        state: inout State,
        samples: [StylusSample],
        context: CanvasStrokeContext,
        keepsSelectionCleared: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> StrokeCommitResolution {
        canvasStrokeCommitService.resolve(
            state: &state,
            samples: samples,
            context: context,
            keepsSelectionCleared: keepsSelectionCleared,
            refreshViaDirtyPresentation: refreshViaDirtyPresentation,
            clearSelectionWithoutRefresh: { state in
                clearCanvasSelectionWithoutRefresh(state: &state)
            },
            commitFallbackPixels: { state, samples, brush, activeLayer, refreshViaDirtyPresentation in
                commitStrokeUsingFallbackPixels(
                    state: &state,
                    samples: samples,
                    brush: brush,
                    activeLayer: activeLayer,
                    refreshViaDirtyPresentation: refreshViaDirtyPresentation
                )
            }
        )
    }

    func completeResolvedStrokeCommit(
        _ resolution: StrokeCommitResolution,
        state: inout State
    ) -> Effect<Action> {
        canvasStrokeEffectCoordinator.complete(
            resolution,
            state: &state,
            resetPreview: { state in
                resetStrokePreviewState(state: &state)
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

    fileprivate func makeStrokePreviewPlan(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        basePixelData: Data,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool
    ) -> StrokePreviewPlan? {
        guard let preview = MetalDocumentProcessingClient.shared.makeInteractiveStrokePreview(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            basePixelData: basePixelData,
            samples: samples,
            brush: brush,
            preserveAlphaLockedPixels: preserveAlphaLockedPixels
        ) else {
            return nil
        }
        return StrokePreviewPlan(
            baseSnapshot: snapshot,
            adjustedPixels: preview.pixelData,
            dirtyRect: preview.dirtyRect,
            rectPixelData: preview.rectPixelData,
            incrementalUpdate: preview.incrementalUpdate
        )
    }

    func applyStrokePreviewPlan(
        _ plan: StrokePreviewPlan,
        activeLayerIndex: Int,
        state: inout State
    ) {
        state.canvas.setStrokePreviewLayerPixelData(plan.adjustedPixels)
        state.canvas.setStrokePreviewRectPixelData(
            plan.rectPixelData,
            dirtyRect: plan.dirtyRect.map {
                LayerPixelRect(
                    originX: $0.originX,
                    originY: $0.originY,
                    width: $0.width,
                    height: $0.height
                )
            }
        )
        if let incrementalUpdate = plan.incrementalUpdate {
            state.canvas.applyIncrementalRenderUpdate(
                incrementalUpdate,
                activeLayerIndex: activeLayerIndex,
                activeLayerPixelData: plan.adjustedPixels
            )
        } else {
            applyLiveStrokePreview(
                baseSnapshot: plan.baseSnapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerPixels: plan.adjustedPixels,
                state: &state
            )
        }
    }

    func commitStrokeUsingFallbackPixels(
        state: inout State,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        activeLayer: LayerRowModel,
        refreshViaDirtyPresentation: Bool
    ) -> DocumentMutationResult {
        if !refreshViaDirtyPresentation {
            ensureCurrentCanvasPresentationLoaded(state: &state)
        }
        let fallbackSnapshot = refreshViaDirtyPresentation
            ? state.canvas.activeStrokeBaseSnapshot
            : (state.canvas.activeStrokeBaseSnapshot ?? state.canvas.renderSnapshot)
        guard
            let snapshot = fallbackSnapshot,
            let baseLayer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
            let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                basePixelData: baseLayer.pixelData,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                samples: samples,
                brush: brush,
                mode: .interactive,
                snapshotRevision: snapshot.revision,
                activeLayerIndex: state.canvas.activeLayerIndex,
                preserveAlphaLockedPixels: activeLayer.isAlphaLocked
            )
        else {
            return .failure(.bridgeMutationFailed("Missing fallback stroke snapshot"))
        }
        return documentInteractionService.replaceLayerPixels(
            state.canvas.activeLayerIndex,
            pixelData: adjustedPixels
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
            applyPreview: { resolution, activeLayerIndex, state in
                applyStrokePreviewResolution(
                    resolution,
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
            applyPreview: { resolution, activeLayerIndex, state in
                applyStrokePreviewResolution(
                    resolution,
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
        documentInteractionService.beginStroke(first, brush: resolvedBrushSettings(for: state))
        for sample in samples.dropFirst() {
            documentInteractionService.appendStroke(sample)
        }
        applyLiveCompositePixelData(documentInteractionService.compositePixelData(), state: &state)
        return cancelStartupPresentationEffects()
    }

    func handleCommitPreviewShapeStroke(state: inout State) -> Effect<Action> {
        documentInteractionService.endStroke()
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
            resetPreview: { state in
                resetStrokePreviewState(state: &state)
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
                    documentInteractionService.cancelStroke()
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
                switch documentInteractionService.revealLayerForEditing(activeLayerIndex) {
                case .success:
                    return documentInteractionService.blurStroke(
                        samples,
                        brush: brush,
                        layerIndex: activeLayerIndex,
                        clearSelectionAfterBlur: false
                    )
                case let .failure(failure):
                    return .failure(failure)
                }
            }
        )
    }

    func handleEndBlurStroke(state: inout State) -> Effect<Action> {
        documentInteractionService.endBlurStroke()
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
                switch documentInteractionService.ensureLayerVisible(activeLayerIndex) {
                case .success:
                    return documentInteractionService.fill(
                        sample,
                        brush: brush
                    )
                case let .failure(failure):
                    return .failure(failure)
                }
            }
        )
    }
}
