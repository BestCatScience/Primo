import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentStrokeApplication

extension CanvasEditingWorkflowReducer {
    func synchronizePaperStyleEffect(_ paperStyle: CanvasPaperStyle) -> Effect<Action> {
        .run { [documentPersistenceGateway] _ in
            documentPersistenceGateway.setPaperStyle(paperStyle)
        }
    }

    func routeDocumentEditorEditingAction(
        state: inout DocumentFeature.State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case .layerSidebar:
            return .none

        case let .canvas(.delegate(.beginStroke(sample))):
            return handleBeginStroke(state: &state, sample: sample)

        case let .canvas(.delegate(.appendSamples(samples))):
            return handleAppendStrokeSamples(state: &state, samples: samples)

        case let .canvas(.delegate(.previewShapeStroke(samples))):
            return handlePreviewShapeStroke(state: &state, samples: samples)

        case let .canvas(.delegate(.endStroke(samples))):
            return handleFinishStroke(
                state: &state,
                samples: samples,
                keepsSelectionCleared: false,
                refreshViaDirtyPresentation: true
            )

        case .canvas(.delegate(.cancelStroke)):
            return handleCancelStroke(state: &state)

        case let .canvas(.delegate(.commitStroke(samples))):
            return handleFinishStroke(
                state: &state,
                samples: samples,
                keepsSelectionCleared: true,
                refreshViaDirtyPresentation: false
            )

        case let .canvas(.delegate(.blurSamples(samples))):
            return handleBlurSamples(state: &state, samples: samples)

        case .canvas(.delegate(.endBlurStroke)):
            return handleEndBlurStroke(state: &state)

        case let .canvas(.delegate(.fill(sample))):
            return handleFill(state: &state, sample: sample)

        case .canvas:
            return .none

        default:
            return nil
        }
    }

    func routeCanvasInteractionAction(
        state: inout DocumentFeature.State,
        action: Action
    ) -> Effect<Action>? {
        routeDocumentEditorEditingAction(state: &state, action: action)
    }

    struct CanvasStrokeContextResolver {
        func previewBrush(for brush: BrushRuntimeSettings) -> BrushRuntimeSettings {
            brush
        }

        func resolve(
            in state: DocumentFeature.State,
            resolvedBrushSettings: (DocumentFeature.State) -> BrushRuntimeSettings,
            activeEditableLayer: (DocumentFeature.State) -> LayerRowModel?
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

    struct CanvasStrokeEffectCoordinator {
        func complete(
            _ resolution: StrokeCommitResolution,
            state: inout DocumentFeature.State,
            resetPreview: (inout DocumentFeature.State, MetalBufferHandle?) -> Void,
            completeMutation: (inout DocumentFeature.State, DocumentMutationContract) -> Effect<Action>,
            applyFailureFeedback: (DocumentMutationFailure, inout DocumentFeature.State) -> Effect<Action>,
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
                return .merge(
                    applyFailureFeedback(failure, &state),
                    cancelEffects()
                )
            }
        }
    }

    struct CanvasStrokeInteractionCoordinator {
        func begin(
            state: inout DocumentFeature.State,
            sample: StylusSample,
            resolveContext: (DocumentFeature.State) -> CanvasStrokeContext?,
            prepareEditing: (inout DocumentFeature.State) -> DocumentMutationResult,
            applyFailureFeedback: (DocumentMutationFailure, inout DocumentFeature.State) -> Effect<Action>,
            captureBaseSnapshot: (inout DocumentFeature.State) -> Void,
            resolveInitialPreview: (DocumentFeature.State, StylusSample, CanvasStrokeContext) -> GpuStrokeSessionOutcome,
            applyPreview: (GpuStrokeSessionOutcome, Int, inout DocumentFeature.State) -> Effect<Action>,
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
            state: inout DocumentFeature.State,
            samples: [StylusSample],
            resolveContext: (DocumentFeature.State) -> CanvasStrokeContext?,
            resolvePreview: (DocumentFeature.State, [StylusSample], CanvasStrokeContext) -> GpuStrokeSessionOutcome,
            applyPreview: (GpuStrokeSessionOutcome, Int, inout DocumentFeature.State) -> Effect<Action>
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
            state: inout DocumentFeature.State,
            samples: [StylusSample],
            keepsSelectionCleared: Bool,
            refreshViaDirtyPresentation: Bool,
            resolveContext: (DocumentFeature.State) -> CanvasStrokeContext?,
            resetPreview: (inout DocumentFeature.State, MetalBufferHandle?) -> Void,
            resolveCommit: (inout DocumentFeature.State, [StylusSample], CanvasStrokeContext, Bool, Bool) -> StrokeCommitResolution,
            completeCommit: (StrokeCommitResolution, inout DocumentFeature.State) -> Effect<Action>
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
            state: inout DocumentFeature.State,
            cancelShapeStrokeIfNeeded: (inout DocumentFeature.State) -> Void,
            resetPreview: (inout DocumentFeature.State) -> Void,
            completeMutation: (inout DocumentFeature.State, DocumentMutationContract) -> Effect<Action>
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
        let strokeInteraction = canvasStrokeInteractionService
        return DocumentFeature.CanvasStrokeSessionCoordinator(
            layerCommands: documentLayerCommandService,
            strokeInteraction: strokeInteraction,
            commitWorkflow: DocumentStrokeCommitWorkflowService(
                layerCommands: documentLayerCommandService,
                strokeInteraction: strokeInteraction
            )
        )
    }

    var canvasStrokeEffectCoordinator: CanvasStrokeEffectCoordinator {
        CanvasStrokeEffectCoordinator()
    }

    var canvasStrokeInteractionCoordinator: CanvasStrokeInteractionCoordinator {
        CanvasStrokeInteractionCoordinator()
    }

    func resetStrokePreviewState(
        state: inout DocumentFeature.State,
        preserving transferredSurfaceHandle: MetalBufferHandle? = nil
    ) {
        _ = canvasStrokeInteractionService.cancel()
        documentCanvasStrokeStateCoordinator.resetPreviewState(
            state: &state,
            preserving: transferredSurfaceHandle
        ) { handle in
            documentGpuOperationGateway.releaseSurfaceHandle(handle)
        }
    }

    func clearCanvasSelectionWithoutRefresh(state: inout DocumentFeature.State) {
        canvasStrokeStateCoordinator.clearSelectionWithoutRefresh(
            state: &state,
            performDocumentMutation: { mutableState, contract in
                completeDocumentMutation(state: &mutableState, contract: contract)
            }
        )
    }

    func ensureCurrentCanvasPresentationLoaded(state: inout DocumentFeature.State) {
        canvasStrokeStateCoordinator.ensureCurrentPresentationLoaded(
            state: &state,
            performDocumentMutation: { mutableState, contract in
                completeDocumentMutation(state: &mutableState, contract: contract)
            }
        )
    }

    func captureActiveStrokeBaseSnapshotIfNeeded(state: inout DocumentFeature.State) {
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
        state: inout DocumentFeature.State
    ) -> Effect<Action> {
        documentMutationFeedbackEffect(for: DocumentMutationFeedbackMapper().feedback(for: failure))
    }

    func prepareCanvasStrokeEditing(state: inout DocumentFeature.State) -> DocumentMutationResult {
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

    func canvasStrokeContext(in state: DocumentFeature.State) -> CanvasStrokeContext? {
        canvasStrokeContextResolver.resolve(
            in: state,
            resolvedBrushSettings: { state in
                DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
            },
            activeEditableLayer: { state in
                activeEditableCanvasLayer(in: state)
            }
        )
    }

    func resolveInitialStrokePreview(
        state: DocumentFeature.State,
        sample: StylusSample,
        context: CanvasStrokeContext
    ) -> GpuStrokeSessionOutcome {
        canvasStrokeInteractionService.beginPreview(
            sample: sample,
            baseSnapshot: state.canvas.strokeSession.baseSnapshot,
            context: DocumentStrokeContext(context),
            usesResponsivePreview: state.usesResponsivePreview(for: context.previewBrush)
        )
    }

    func resolveAppendedStrokePreview(
        state: DocumentFeature.State,
        samples: [StylusSample],
        context: CanvasStrokeContext
    ) -> GpuStrokeSessionOutcome {
        documentCanvasStrokeSessionCoordinator.resolveAppendedStrokePreview(
            state: state,
            samples: samples,
            context: context
        )
    }

    func applyStrokePreviewOutcome(
        _ outcome: GpuStrokeSessionOutcome,
        activeLayerIndex: Int,
        state: inout DocumentFeature.State
    ) -> Effect<Action> {
        switch outcome {
        case let .preview(mutation):
            documentCanvasStrokeStateCoordinator.applyPreviewMutation(
                mutation,
                state: &state,
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

    func applyLiveCompositeSurface(
        _ compositeSurface: DocumentCompositeSurface,
        state: inout DocumentFeature.State
    ) -> Effect<Action> {
        guard DocumentFeature.canvasPreviewStateCoordinator.applyLiveCompositeSurface(
            compositeSurface,
            to: &state
        ) else {
            return .none
        }
        return .send(.delegate(.presentationApplied))
    }

    func resolveStrokeCommit(
        state: inout DocumentFeature.State,
        samples: [StylusSample],
        context: CanvasStrokeContext,
        keepsSelectionCleared: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> StrokeCommitResolution {
        documentCanvasStrokeSessionCoordinator.resolveStrokeCommit(
            state: &state,
            samples: samples,
            context: context,
            keepsSelectionCleared: keepsSelectionCleared,
            refreshViaDirtyPresentation: refreshViaDirtyPresentation
        )
    }

    func completeResolvedStrokeCommit(
        _ resolution: StrokeCommitResolution,
        state: inout DocumentFeature.State
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
                .none
            }
        )
    }

    func activeEditableCanvasLayer(in state: DocumentFeature.State) -> LayerRowModel? {
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
              !activeLayer.isLocked
        else {
            return nil
        }
        return activeLayer
    }

    func completeCanvasStrokeMutation(
        state: inout DocumentFeature.State,
        contract: DocumentMutationContract = .dirty
    ) -> Effect<Action> {
        completeDocumentMutation(state: &state, contract: contract)
    }

    func handleBeginStroke(
        state: inout DocumentFeature.State,
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
                .none
            }
        )
    }

    func handleAppendStrokeSamples(
        state: inout DocumentFeature.State,
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
        state: inout DocumentFeature.State,
        samples: [StylusSample]
    ) -> Effect<Action> {
        guard !samples.isEmpty else { return .none }
        guard let context = canvasStrokeContext(in: state) else {
            return .none
        }
        switch prepareCanvasStrokeEditing(state: &state) {
        case .success:
            break
        case let .failure(failure):
            return applyCanvasStrokeFailure(failure, state: &state)
        }
        canvasStrokeStateCoordinator.captureBaseSnapshotIfNeeded(
            state: &state,
            ensureCurrentPresentationLoaded: { state in
                ensureCurrentCanvasPresentationLoaded(state: &state)
            }
        )
        let previewOutcome = documentCanvasStrokeSessionCoordinator.resolveShapeStrokePreview(
            state: state,
            samples: samples,
            context: context
        )
        return applyStrokePreviewOutcome(
            previewOutcome,
            activeLayerIndex: context.activeLayerIndex,
            state: &state
        )
    }

    func handleFinishStroke(
        state: inout DocumentFeature.State,
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

    func handleCancelStroke(state: inout DocumentFeature.State) -> Effect<Action> {
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
        state: inout DocumentFeature.State,
        samples: [StylusSample]
    ) -> Effect<Action> {
        guard !samples.isEmpty else { return .none }
        guard activeEditableCanvasLayer(in: state) != nil else {
            return .none
        }
        let activeLayerIndex = state.canvas.activeLayerIndex
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
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

    func handleEndBlurStroke(state: inout DocumentFeature.State) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: documentStrokeCommandService.endBlurStroke
        )
    }

    func handleFill(
        state: inout DocumentFeature.State,
        sample: StylusSample
    ) -> Effect<Action> {
        guard activeEditableCanvasLayer(in: state) != nil else {
            return .none
        }
        let activeLayerIndex = state.canvas.activeLayerIndex
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
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

private extension DocumentFeature.State {
    func usesResponsivePreview(for brush: BrushRuntimeSettings) -> Bool {
        true
    }
}
