import ComposableArchitecture
import Foundation

extension AppFeature {
    struct StrokePreviewPlan {
        let baseSnapshot: MetalDocumentSnapshot
        let adjustedPixels: Data
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
            var previewBrush = brush
            previewBrush.taperIn = 0
            previewBrush.taperOut = 0
            return previewBrush
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
        let workflowService: CanvasStrokeWorkflowService

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
        func resolveInitial(
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

        func resolveAppended(
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
                let fullSamples = state.canvas.activeStroke?.points.map(\.stylusSample) ?? samples
                let anchorIndex = max(fullSamples.count - samples.count - 1, 0)
                let anchor = fullSamples.indices.contains(anchorIndex) ? fullSamples[anchorIndex] : nil
                let previewSamples = anchor.map { [$0] + samples } ?? samples
                let basePixelData = state.canvas.activeStrokePreviewLayerPixelData ?? baseLayer.pixelData
                guard let previewPlan = makePreviewPlan(
                    baseSnapshot,
                    context.activeLayerIndex,
                    basePixelData,
                    previewSamples,
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
        let workflowService: CanvasStrokeWorkflowService

        func resolve(
            state: inout State,
            samples: [StylusSample],
            context: CanvasStrokeContext,
            keepsSelectionCleared: Bool,
            refreshViaDirtyPresentation: Bool,
            clearSelectionWithoutRefresh: (inout State) -> Void,
            commitFallbackPixels: (inout State, [StylusSample], BrushRuntimeSettings, LayerRowModel, Bool) -> DocumentMutationResult
        ) -> StrokeCommitResolution {
            let shouldApplyTaperOnCommit = context.brush.taperIn > 0.001 || context.brush.taperOut > 0.001
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
            if let previewPixels = state.canvas.activeStrokePreviewLayerPixelData, !shouldApplyTaperOnCommit {
                commitResult = workflowService.replaceLayerPixels(
                    context.activeLayerIndex,
                    pixelData: previewPixels
                )
            } else {
                switch workflowService.applySoftwareStroke(
                    samples,
                    brush: context.brush,
                    layerIndex: context.activeLayerIndex
                ) {
                case .success:
                    commitResult = .success(())
                case .failure:
                    commitResult = commitFallbackPixels(
                        &state,
                        samples,
                        context.brush,
                        context.activeLayer,
                        refreshViaDirtyPresentation
                    )
                }
            }
            switch commitResult {
            case .success:
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

    struct CanvasStrokeWorkflowService {
        let documentQueryGateway: DocumentQueryGateway
        let documentMutationGateway: DocumentMutationGateway
        let strokeInputGateway: StrokeInputGateway

        func ensureLayerVisible(_ layerIndex: Int) -> DocumentMutationResult {
            documentMutationGateway.setLayerVisibility(layerIndex, true)
        }

        func cancelStroke() {
            strokeInputGateway.cancelStroke()
        }

        func beginStroke(
            _ sample: StylusSample,
            brush: BrushRuntimeSettings
        ) {
            strokeInputGateway.beginStroke(sample, brush)
        }

        func appendStroke(_ sample: StylusSample) {
            strokeInputGateway.appendStroke(sample)
        }

        func compositePixelData() -> Data {
            documentQueryGateway.compositePixelData()
        }

        func endStroke() {
            strokeInputGateway.endStroke()
        }

        func replaceLayerPixels(
            _ layerIndex: Int,
            pixelData: Data
        ) -> DocumentMutationResult {
            documentMutationGateway.replaceLayerPixels(layerIndex, pixelData)
        }

        func applySoftwareStroke(
            _ samples: [StylusSample],
            brush: BrushRuntimeSettings,
            layerIndex: Int
        ) -> DocumentMutationResult {
            strokeInputGateway.applySoftwareStroke(samples, brush, layerIndex)
        }

        func revealLayerForEditing(_ layerIndex: Int) -> DocumentMutationResult {
            documentMutationGateway.revealLayerForEditing(layerIndex)
        }

        func blurStroke(
            _ samples: [StylusSample],
            brush: BrushRuntimeSettings,
            layerIndex: Int,
            clearSelectionAfterBlur: Bool
        ) -> DocumentMutationResult {
            strokeInputGateway.blurStroke(samples, brush, layerIndex, clearSelectionAfterBlur)
        }

        func endBlurStroke() {
            strokeInputGateway.endBlurStroke()
        }

        func fill(
            _ sample: StylusSample,
            brush: BrushRuntimeSettings
        ) -> DocumentMutationResult {
            strokeInputGateway.fill(sample, brush)
        }
    }

    var canvasStrokeWorkflowService: CanvasStrokeWorkflowService {
        CanvasStrokeWorkflowService(
            documentQueryGateway: documentQueryGateway,
            documentMutationGateway: documentMutationGateway,
            strokeInputGateway: strokeInputGateway
        )
    }

    var canvasStrokeContextResolver: CanvasStrokeContextResolver {
        CanvasStrokeContextResolver()
    }

    var canvasStrokeStateCoordinator: CanvasStrokeStateCoordinator {
        CanvasStrokeStateCoordinator(workflowService: canvasStrokeWorkflowService)
    }

    var canvasStrokePreviewResolver: CanvasStrokePreviewResolver {
        CanvasStrokePreviewResolver()
    }

    var canvasStrokeCommitService: CanvasStrokeCommitService {
        CanvasStrokeCommitService(workflowService: canvasStrokeWorkflowService)
    }

    var canvasStrokeEffectCoordinator: CanvasStrokeEffectCoordinator {
        CanvasStrokeEffectCoordinator()
    }

    var canvasStrokeInteractionCoordinator: CanvasStrokeInteractionCoordinator {
        CanvasStrokeInteractionCoordinator()
    }

    func resetStrokePreviewState(state: inout State) {
        MetalDocumentProcessingClient.shared.resetStrokeExecutionSession()
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
        MetalDocumentProcessingClient.shared.resetStrokeExecutionSession()
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

    func makeStrokePreviewPlan(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        basePixelData: Data,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool
    ) -> StrokePreviewPlan? {
        guard let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
            basePixelData: basePixelData,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            samples: samples,
            brush: brush,
            mode: .interactive,
            preserveAlphaLockedPixels: preserveAlphaLockedPixels
        ) else {
            return nil
        }
        let incrementalUpdate: IncrementalLayerUpdate?
        if Self.shouldUseIncrementalPreviewUpdate(for: brush),
           let dirtyRect = Self.strokePreviewDirtyRect(
            samples: samples,
            brush: brush,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height
           ) {
            incrementalUpdate = Self.compositedPreviewIncrementalUpdate(
                snapshot: snapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerPixels: adjustedPixels,
                dirtyRect: dirtyRect
            )
        } else {
            incrementalUpdate = nil
        }
        return StrokePreviewPlan(
            baseSnapshot: snapshot,
            adjustedPixels: adjustedPixels,
            incrementalUpdate: incrementalUpdate
        )
    }

    func applyStrokePreviewPlan(
        _ plan: StrokePreviewPlan,
        activeLayerIndex: Int,
        state: inout State
    ) {
        state.canvas.setStrokePreviewLayerPixelData(plan.adjustedPixels)
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
                preserveAlphaLockedPixels: activeLayer.isAlphaLocked
            )
        else {
            return .failure(.bridgeMutationFailed("Missing fallback stroke snapshot"))
        }
        return canvasStrokeWorkflowService.replaceLayerPixels(
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
        canvasStrokeWorkflowService.beginStroke(first, brush: resolvedBrushSettings(for: state))
        for sample in samples.dropFirst() {
            canvasStrokeWorkflowService.appendStroke(sample)
        }
        applyLiveCompositePixelData(canvasStrokeWorkflowService.compositePixelData(), state: &state)
        return cancelStartupPresentationEffects()
    }

    func handleCommitPreviewShapeStroke(state: inout State) -> Effect<Action> {
        canvasStrokeWorkflowService.endStroke()
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
                    canvasStrokeWorkflowService.cancelStroke()
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
                switch canvasStrokeWorkflowService.revealLayerForEditing(activeLayerIndex) {
                case .success:
                    return canvasStrokeWorkflowService.blurStroke(
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
        canvasStrokeWorkflowService.endBlurStroke()
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
                switch canvasStrokeWorkflowService.ensureLayerVisible(activeLayerIndex) {
                case .success:
                    return canvasStrokeWorkflowService.fill(
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
