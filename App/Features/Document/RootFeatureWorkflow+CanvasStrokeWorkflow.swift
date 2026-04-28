import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoDocumentGPUContracts
import PrimoDocumentStrokeApplication

extension RootFeatureWorkflowReducer {
    typealias CanvasStrokeContext = DocumentFeature.CanvasStrokeContext
    typealias StrokeCommitResolution = DocumentFeature.StrokeCommitResolution

    func routeDocumentEditorEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case .document(.layerSidebar):
            return .none

        case let .document(.canvas(.delegate(.beginStroke(sample)))):
            return handleBeginStroke(state: &state, sample: sample)

        case let .document(.canvas(.delegate(.appendSamples(samples)))):
            return handleAppendStrokeSamples(state: &state, samples: samples)

        case let .document(.canvas(.delegate(.previewShapeStroke(samples)))):
            return handlePreviewShapeStroke(state: &state, samples: samples)

        case .document(.canvas(.delegate(.commitPreviewShapeStroke))):
            return handleCommitPreviewShapeStroke(state: &state)

        case let .document(.canvas(.delegate(.endStroke(samples)))):
            return handleFinishStroke(
                state: &state,
                samples: samples,
                keepsSelectionCleared: false,
                refreshViaDirtyPresentation: true
            )

        case .document(.canvas(.delegate(.cancelStroke))):
            return handleCancelStroke(state: &state)

        case let .document(.canvas(.delegate(.commitStroke(samples)))):
            return handleFinishStroke(
                state: &state,
                samples: samples,
                keepsSelectionCleared: true,
                refreshViaDirtyPresentation: false
            )

        case let .document(.canvas(.delegate(.blurSamples(samples)))):
            return handleBlurSamples(state: &state, samples: samples)

        case .document(.canvas(.delegate(.endBlurStroke))):
            return handleEndBlurStroke(state: &state)

        case let .document(.canvas(.delegate(.fill(sample)))):
            return handleFill(state: &state, sample: sample)

        case .document(.canvas):
            return .none

        default:
            return nil
        }
    }

    func routeCanvasInteractionAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        routeDocumentEditorEditingAction(state: &state, action: action)
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
                activeLayerIndex: state.document.canvas.activeLayerIndex,
                brush: brush,
                previewBrush: previewBrush(for: brush)
            )
        }
    }

    struct CanvasStrokeStateCoordinator {
        let layerCommands: DocumentLayerCommandService
        let strokeCommands: DocumentStrokeCommandService

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
            guard state.document.canvas.renderSnapshot == nil else { return }
            performDocumentMutation(&state, .currentPresentation)
        }

        func captureBaseSnapshotIfNeeded(
            state: inout State,
            ensureCurrentPresentationLoaded: (inout State) -> Void
        ) {
            guard state.document.canvas.strokeSession.baseSnapshot == nil else { return }
            if let pendingCommittedSnapshot = state.document.canvas.pendingCommittedSnapshot {
                state.document.canvas.captureStrokeBaseSnapshot(pendingCommittedSnapshot)
                return
            }
            ensureCurrentPresentationLoaded(&state)
            if let renderSnapshot = state.document.canvas.renderSnapshot {
                state.document.canvas.captureStrokeBaseSnapshot(renderSnapshot)
            }
        }

        func prepareEditing(
            state: inout State,
            clearSelectionWithoutRefresh: (inout State) -> Void
        ) -> DocumentMutationResult {
            switch layerCommands.ensureLayerVisible(state.document.canvas.activeLayerIndex) {
            case .success:
                break
            case let .failure(failure):
                return .failure(failure)
            }
            clearSelectionWithoutRefresh(&state)
            strokeCommands.cancelStroke()
            return .success(())
        }
    }

    struct CanvasStrokeEffectCoordinator {
        func complete(
            _ resolution: StrokeCommitResolution,
            state: inout State,
            resetPreview: (inout State, MetalBufferHandle?) -> Void,
            completeMutation: (inout State, DocumentMutationContract) -> Effect<Action>,
            applyFailureFeedback: (DocumentMutationFailure, inout State) -> Effect<Action>,
            cancelEffects: () -> Effect<Action>
        ) -> Effect<Action> {
            let transferredSurfaceHandle: MetalBufferHandle?
            if case let .committed(_, handle) = resolution {
                transferredSurfaceHandle = handle
            } else {
                transferredSurfaceHandle = nil
            }
            if case .failed = resolution {
                state.document.canvas.isAwaitingCommittedRender = false
            }
            resetPreview(&state, transferredSurfaceHandle)
            switch resolution {
            case let .committed(contract, _):
                return completeMutation(&state, contract)
            case let .failed(failure):
                return .merge(
                    applyFailureFeedback(failure, &state),
                    cancelEffects()
                )
            }
        }
    }

    struct CanvasStrokeInteractionCoordinator {
        func begin(
            state: inout State,
            sample: StylusSample,
            resolveContext: (State) -> CanvasStrokeContext?,
            prepareEditing: (inout State) -> DocumentMutationResult,
            applyFailureFeedback: (DocumentMutationFailure, inout State) -> Effect<Action>,
            captureBaseSnapshot: (inout State) -> Void,
            resolveInitialPreview: (State, StylusSample, CanvasStrokeContext) -> GpuStrokeSessionOutcome,
            applyPreview: (GpuStrokeSessionOutcome, Int, inout State) -> Effect<Action>,
            cancelEffects: () -> Effect<Action>
        ) -> Effect<Action> {
            guard let context = resolveContext(state) else {
                return .none
            }
            switch prepareEditing(&state) {
            case .success:
                break
            case let .failure(failure):
                return applyFailureFeedback(failure, &state)
            }
            captureBaseSnapshot(&state)
            let previewOutcome = resolveInitialPreview(
                state,
                sample,
                context
            )
            return .merge(
                applyPreview(
                    previewOutcome,
                    context.activeLayerIndex,
                    &state
                ),
                cancelEffects()
            )
        }

        func append(
            state: inout State,
            samples: [StylusSample],
            resolveContext: (State) -> CanvasStrokeContext?,
            resolvePreview: (State, [StylusSample], CanvasStrokeContext) -> GpuStrokeSessionOutcome,
            applyPreview: (GpuStrokeSessionOutcome, Int, inout State) -> Effect<Action>
        ) -> Effect<Action> {
            guard let context = resolveContext(state) else {
                return .none
            }
            let previewOutcome = resolvePreview(
                state,
                samples,
                context
            )
            return applyPreview(
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

    var documentCanvasStrokeStateCoordinator: DocumentFeature.CanvasStrokeStateCoordinator {
        DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: documentLayerCommandService,
            strokeCommands: documentStrokeCommandService
        )
    }

    var documentCanvasStrokeSessionCoordinator: DocumentFeature.CanvasStrokeSessionCoordinator {
        DocumentFeature.CanvasStrokeSessionCoordinator(
            layerCommands: documentLayerCommandService,
            strokeInteraction: canvasStrokeInteractionService
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
        documentCanvasStrokeStateCoordinator.resetPreviewState(
            state: &state.document,
            preserving: transferredSurfaceHandle
        ) { handle in
            documentGpuOperationGateway.releaseSurfaceHandle(handle)
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
    ) -> Effect<Action> {
        documentMutationFeedbackCoordinator.effect(
            for: documentMutationFeedbackMapper.feedback(for: failure)
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
            baseSnapshot: state.document.canvas.strokeSession.baseSnapshot,
            context: DocumentStrokeContext(context),
            usesResponsiveOilPreview: state.usesResponsiveOilPreview(for: context.previewBrush)
        )
    }

    func resolveAppendedStrokePreview(
        state: State,
        samples: [StylusSample],
        context: CanvasStrokeContext
    ) -> GpuStrokeSessionOutcome {
        documentCanvasStrokeSessionCoordinator.resolveAppendedStrokePreview(
            state: state.document,
            samples: samples,
            context: context
        )
    }

    func applyStrokePreviewOutcome(
        _ outcome: GpuStrokeSessionOutcome,
        activeLayerIndex: Int,
        state: inout State
    ) -> Effect<Action> {
        switch outcome {
        case let .preview(mutation):
            documentCanvasStrokeStateCoordinator.applyPreviewMutation(
                mutation,
                state: &state.document,
                releaseSurfaceHandle: { handle in
                    documentGpuOperationGateway.releaseSurfaceHandle(handle)
                }
            )
            return .none
        case let .failure(failure):
            return applyCanvasStrokeFailure(failure, state: &state)
        case .commit, .reset:
            return .none
        }
    }

    func resolveStrokeCommit(
        state: inout State,
        samples: [StylusSample],
        context: CanvasStrokeContext,
        keepsSelectionCleared: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> StrokeCommitResolution {
        let resolvesSelectionClear = keepsSelectionCleared
        if keepsSelectionCleared {
            switch documentLayerCommandService.ensureLayerVisible(context.activeLayerIndex) {
            case .success:
                clearCanvasSelectionWithoutRefresh(state: &state)
            case let .failure(failure):
                return .failed(failure)
            }
        }

        let resolution = documentCanvasStrokeSessionCoordinator.resolveStrokeCommit(
            state: &state.document,
            samples: samples,
            context: context,
            keepsSelectionCleared: false,
            refreshViaDirtyPresentation: refreshViaDirtyPresentation
        )

        guard resolvesSelectionClear,
              case let .committed(contract, transferredSurfaceHandle) = resolution
        else {
            return resolution
        }
        return .committed(
            DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: contract.refresh,
                feedback: contract.feedback,
                updatesWorkspaceArtifacts: contract.updatesWorkspaceArtifacts
            ),
            transferredSurfaceHandle: transferredSurfaceHandle
        )
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
        guard let activeLayer = state.document.layerSidebar.layers.first(where: { $0.index == state.document.canvas.activeLayerIndex }),
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
    ) -> Effect<Action> {
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
            return applyCanvasStrokeFailure(failure, state: &state)
        }
        documentStrokeCommandService.beginStroke(first, resolvedBrushSettings(for: state))
        for sample in samples.dropFirst() {
            documentStrokeCommandService.appendStroke(sample)
        }
        return .merge(
            applyLiveCompositeSurface(documentCanvasCommandService.compositeSurface(), state: &state),
            cancelStartupPresentationEffects()
        )
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
                if state.document.canvas.currentTool == .shape {
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
        let activeLayerIndex = state.document.canvas.activeLayerIndex
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
        let activeLayerIndex = state.document.canvas.activeLayerIndex
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
    init(_ context: DocumentFeature.CanvasStrokeContext) {
        self.init(
            activeLayer: context.activeLayer,
            activeLayerIndex: context.activeLayerIndex,
            brush: context.brush,
            previewBrush: context.previewBrush
        )
    }
}

private extension PrimoRootFeature.State {
    func usesResponsiveOilPreview(for brush: BrushRuntimeSettings) -> Bool {
        document.brushPalette.ui.oilLivePreviewQuality == .responsive &&
        brush.tipKind == .oil
    }
}
