import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMetalStrokeInfrastructure
import PrimoDocumentRenderingInfrastructure
import PrimoDocumentStrokeApplication

extension AppFeature {
    typealias StrokePreviewPlan = DocumentStrokePreviewPlan

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

    struct CanvasStrokeCommitService {
        let layerCommands: DocumentLayerCommandService
        let strokeProcessingService: DocumentStrokeProcessingService

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
                switch layerCommands.ensureLayerVisible(context.activeLayerIndex) {
                case .success:
                    break
                case let .failure(failure):
                    return .failed(failure)
                }
                clearSelectionWithoutRefresh(&state)
            }
            let commitResult: DocumentMutationResult
            let canCommitPreviewPixels = Self.shouldCommitPreviewPixels(
                state: state,
                context: context
            )
            if canCommitPreviewPixels,
               let dirtyRect = state.canvas.activeStrokePreviewDirtyRect,
                let rectPixelData = state.canvas.activeStrokePreviewRectPixelData {
                commitResult = layerCommands.replaceLayerPixelsInRect(
                    context.activeLayerIndex,
                    dirtyRect,
                    rectPixelData
                )
            } else if canCommitPreviewPixels,
                      let previewPixels = state.canvas.activeStrokePreviewLayerPixelData {
                commitResult = layerCommands.replaceLayerPixels(
                    context.activeLayerIndex,
                    previewPixels
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
                    activeLayerIndex: context.activeLayerIndex,
                    canCommitPreviewPixels: canCommitPreviewPixels,
                    strokeProcessingService: strokeProcessingService
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
            activeLayerIndex: Int,
            canCommitPreviewPixels: Bool,
            strokeProcessingService: DocumentStrokeProcessingService
        ) -> MetalDocumentSnapshot? {
            guard
                let baseSnapshot = state.canvas.activeStrokeBaseSnapshot,
                let committedPixels = committedPreviewLayerPixelData(
                    state: state,
                    baseSnapshot: baseSnapshot,
                    activeLayerIndex: activeLayerIndex,
                    canCommitPreviewPixels: canCommitPreviewPixels
                )
            else {
                return nil
            }

            return strokeProcessingService.stageCommittedSnapshot(
                baseSnapshot: baseSnapshot,
                committedPixels: committedPixels,
                lastCommittedRenderRevision: state.canvas.lastCommittedRenderRevision,
                activeLayerIndex: activeLayerIndex,
                stagedCompositePixelData: state.canvas.stagedPreviewCompositePixelData(baseSnapshot: baseSnapshot)
            )
        }

        private static func committedPreviewLayerPixelData(
            state: State,
            baseSnapshot: MetalDocumentSnapshot,
            activeLayerIndex: Int,
            canCommitPreviewPixels: Bool
        ) -> Data? {
            guard canCommitPreviewPixels else { return nil }
            if let previewLayerPixelData = state.canvas.activeStrokePreviewLayerPixelData {
                return previewLayerPixelData
            }
            guard
                let dirtyRect = state.canvas.activeStrokePreviewDirtyRect,
                let rectPixelData = state.canvas.activeStrokePreviewRectPixelData,
                let baseLayer = baseSnapshot.layers.first(where: { $0.index == activeLayerIndex }),
                baseLayer.pixelData.count == baseSnapshot.width * baseSnapshot.height * 4,
                dirtyRect.originX >= 0,
                dirtyRect.originY >= 0,
                dirtyRect.originX + dirtyRect.width <= baseSnapshot.width,
                dirtyRect.originY + dirtyRect.height <= baseSnapshot.height,
                rectPixelData.count >= dirtyRect.width * dirtyRect.height * 4
            else {
                return nil
            }

            var committedPixels = baseLayer.pixelData
            committedPixels.withUnsafeMutableBytes { destinationBytes in
                rectPixelData.withUnsafeBytes { sourceBytes in
                    guard
                        let destinationBase = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        let sourceBase = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                    else {
                        return
                    }
                    for row in 0..<dirtyRect.height {
                        let sourceOffset = row * dirtyRect.width * 4
                        let destinationOffset = ((dirtyRect.originY + row) * baseSnapshot.width + dirtyRect.originX) * 4
                        memcpy(destinationBase + destinationOffset, sourceBase + sourceOffset, dirtyRect.width * 4)
                    }
                }
            }
            return committedPixels
        }

        private static func shouldCommitPreviewPixels(
            state: State,
            context: CanvasStrokeContext
        ) -> Bool {
            if !state.canvas.activeStrokePreviewIsApproximate {
                return true
            }
            return state.usesResponsiveOilPreview(for: context.previewBrush)
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
        CanvasStrokeStateCoordinator(
            layerCommands: documentLayerCommandService,
            strokeCommands: documentStrokeCommandService
        )
    }

    var canvasStrokeCommitService: CanvasStrokeCommitService {
        CanvasStrokeCommitService(
            layerCommands: documentLayerCommandService,
            strokeProcessingService: canvasStrokeProcessingService
        )
    }

    var canvasStrokeProcessingService: DocumentStrokeProcessingService {
        DocumentStrokeProcessingService()
    }

    var canvasStrokePreviewUseCase: DocumentStrokePreviewUseCase {
        DocumentStrokePreviewUseCase(
            planner: MetalStrokeRenderer(processingService: canvasStrokeProcessingService)
        )
    }

    var canvasStrokeCommitUseCase: DocumentStrokeCommitUseCase {
        DocumentStrokeCommitUseCase(
            renderer: MetalStrokeRenderer(processingService: canvasStrokeProcessingService)
        )
    }

    var canvasStrokeEffectCoordinator: CanvasStrokeEffectCoordinator {
        CanvasStrokeEffectCoordinator()
    }

    var canvasStrokeInteractionCoordinator: CanvasStrokeInteractionCoordinator {
        CanvasStrokeInteractionCoordinator()
    }

    func resetStrokePreviewState(state: inout State) {
        canvasStrokeProcessingService.resetInteractiveStrokeState()
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
        canvasStrokeProcessingService.resetInteractiveStrokeState()
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
        canvasStrokePreviewUseCase.resolveInitial(
            baseSnapshot: state.canvas.activeStrokeBaseSnapshot,
            sample: sample,
            context: DocumentStrokeContext(context),
            usesResponsiveOilPreview: state.usesResponsiveOilPreview(for: context.previewBrush)
        ).flatMap(StrokePreviewResolution.init(_:))
    }

    func resolveAppendedStrokePreview(
        state: State,
        samples: [StylusSample],
        context: CanvasStrokeContext
    ) -> StrokePreviewResolution? {
        let fullSamples = !state.canvas.pendingStrokeFinalizationSamples.isEmpty
            ? state.canvas.pendingStrokeFinalizationSamples
            : (state.canvas.activeStroke?.points.map(\.stylusSample) ?? samples)
        return canvasStrokePreviewUseCase.resolveAppended(
            activeStrokeBaseSnapshot: state.canvas.activeStrokeBaseSnapshot,
            renderSnapshot: state.canvas.renderSnapshot,
            samples: samples,
            fullSamples: fullSamples,
            context: DocumentStrokeContext(context),
            usesResponsiveOilPreview: state.usesResponsiveOilPreview(for: context.previewBrush)
        ).flatMap(StrokePreviewResolution.init(_:))
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
                commitStrokeUsingCommittedPixels(
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

    func applyStrokePreviewPlan(
        _ plan: StrokePreviewPlan,
        activeLayerIndex: Int,
        state: inout State
    ) {
        state.canvas.setStrokePreviewLayerPixelData(plan.adjustedPixels)
        state.canvas.setStrokePreviewIsApproximate(plan.isApproximatePreview)
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
        } else if let adjustedPixels = plan.adjustedPixels {
            applyLiveStrokePreview(
                baseSnapshot: plan.baseSnapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerPixels: adjustedPixels,
                state: &state
            )
        }
    }

    func commitStrokeUsingCommittedPixels(
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
            let committedResult = canvasStrokeCommitUseCase.makeCommittedPixels(
                snapshot: snapshot,
                samples: samples,
                context: DocumentStrokeContext(
                    activeLayer: activeLayer,
                    activeLayerIndex: state.canvas.activeLayerIndex,
                    brush: brush,
                    previewBrush: brush
                )
            )
        else {
            return .failure(.bridgeMutationFailed("Missing GPU committed stroke snapshot"))
        }
        return documentLayerCommandService.replaceLayerPixels(
            state.canvas.activeLayerIndex,
            committedResult.committedPixels
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

private extension AppFeature.StrokePreviewResolution {
    init?(_ resolution: DocumentStrokePreviewResolution) {
        self.init(
            plan: DocumentStrokePreviewPlan(resolution.result),
            baseSnapshotToCapture: resolution.baseSnapshotToCapture
        )
    }
}

private extension DocumentStrokePreviewPlan {
    init(_ result: StrokePreviewResult) {
        self.init(
            baseSnapshot: result.baseSnapshot,
            adjustedPixels: result.adjustedPixels,
            adjustedBufferHandle: result.adjustedHandle?.buffer,
            dirtyRect: result.dirtyRect.map {
                (originX: $0.originX, originY: $0.originY, width: $0.width, height: $0.height)
            },
            rectPixelData: result.rectPixelData,
            incrementalUpdate: result.incrementalUpdate,
            isApproximatePreview: result.isApproximatePreview
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
