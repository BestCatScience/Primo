import ComposableArchitecture
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentStrokeApplication

extension CanvasEditingWorkflowReducer {
    struct CanvasStrokeContextResolver {
        func previewBrush(for brush: BrushRuntimeSettings) -> BrushRuntimeSettings {
            brush
        }

        func resolve(
            in state: DocumentEditingState,
            resolvedBrushSettings: (DocumentEditingState) -> BrushRuntimeSettings,
            activeEditableLayer: (DocumentEditingState) -> LayerRowModel?
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
            state: inout DocumentEditingState,
            resetPreview: (inout DocumentEditingState, StrokePreviewLease) -> Void,
            completeMutation: (inout DocumentEditingState, DocumentMutationContract) -> Effect<Action>,
            applyFailureFeedback: (DocumentMutationFailure, inout DocumentEditingState) -> Effect<Action>,
            cancelEffects: () -> Effect<Action>
        ) -> Effect<Action> {
            let transferredPreviewLease: StrokePreviewLease
            if case let .committed(_, lease) = resolution {
                transferredPreviewLease = lease
            } else {
                transferredPreviewLease = .none
            }
            if case .failed = resolution {
                state.canvas.isAwaitingCommittedRender = false
            }
            resetPreview(&state, transferredPreviewLease)
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
            state: inout DocumentEditingState,
            sample: StylusSample,
            resolveContext: (DocumentEditingState) -> CanvasStrokeContext?,
            prepareEditing: (inout DocumentEditingState) -> DocumentMutationResult,
            applyFailureFeedback: (DocumentMutationFailure, inout DocumentEditingState) -> Effect<Action>,
            captureBaseSnapshot: (inout DocumentEditingState) -> Void,
            resolveInitialPreview: (DocumentEditingState, StylusSample, CanvasStrokeContext) -> GpuStrokeSessionOutcome,
            applyPreview: (GpuStrokeSessionOutcome, Int, inout DocumentEditingState) -> Effect<Action>,
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
            state: inout DocumentEditingState,
            samples: [StylusSample],
            resolveContext: (DocumentEditingState) -> CanvasStrokeContext?,
            resolvePreview: (DocumentEditingState, [StylusSample], CanvasStrokeContext) -> GpuStrokeSessionOutcome,
            applyPreview: (GpuStrokeSessionOutcome, Int, inout DocumentEditingState) -> Effect<Action>
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
            state: inout DocumentEditingState,
            samples: [StylusSample],
            keepsSelectionCleared: Bool,
            refreshViaDirtyPresentation: Bool,
            resolveContext: (DocumentEditingState) -> CanvasStrokeContext?,
            resetPreview: (inout DocumentEditingState, StrokePreviewLease) -> Void,
            resolveCommit: (inout DocumentEditingState, [StylusSample], CanvasStrokeContext, Bool, Bool) -> StrokeCommitResolution,
            completeCommit: (StrokeCommitResolution, inout DocumentEditingState) -> Effect<Action>
        ) -> Effect<Action> {
            guard let context = resolveContext(state) else {
                resetPreview(&state, .none)
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
            state: inout DocumentEditingState,
            cancelShapeStrokeIfNeeded: (inout DocumentEditingState) -> Void,
            resetPreview: (inout DocumentEditingState) -> Void,
            completeMutation: (inout DocumentEditingState, DocumentMutationContract) -> Effect<Action>
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
            layerVisibility: documentLayerCommandService,
            strokeCommit: documentStrokeCommandService
        )
    }

    var documentCanvasStrokeStateCoordinator: DocumentFeature.CanvasStrokeStateCoordinator {
        DocumentFeature.CanvasStrokeStateCoordinator(
            layerVisibility: documentLayerCommandService,
            strokeCommit: documentStrokeCommandService
        )
    }

    var documentCanvasStrokeSessionCoordinator: DocumentFeature.CanvasStrokeSessionCoordinator {
        return DocumentFeature.CanvasStrokeSessionCoordinator(
            layerVisibility: documentLayerCommandService,
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
        state: inout DocumentEditingState,
        preserving transferredPreviewLease: StrokePreviewLease = .none
    ) {
        _ = canvasStrokeInteractionService.cancel()
        documentCanvasStrokeStateCoordinator.resetPreviewState(
            state: &state,
            preserving: transferredPreviewLease
        ) { lease in
            canvasStrokeInteractionService.discardPreviewLease(lease)
        }
    }

    func clearCanvasSelectionWithoutRefresh(state: inout DocumentEditingState) {
        canvasStrokeStateCoordinator.clearSelectionWithoutRefresh(
            state: &state,
            performDocumentMutation: { mutableState, contract in
                completeDocumentMutation(state: &mutableState, contract: contract)
            }
        )
    }

    func ensureCurrentCanvasPresentationLoaded(state: inout DocumentEditingState) {
        canvasStrokeStateCoordinator.ensureCurrentPresentationLoaded(
            state: &state,
            performDocumentMutation: { mutableState, contract in
                completeDocumentMutation(state: &mutableState, contract: contract)
            }
        )
    }

    func captureActiveStrokeBaseSnapshotIfNeeded(state: inout DocumentEditingState) {
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
        state: inout DocumentEditingState
    ) -> Effect<Action> {
        documentMutationFeedbackEffect(for: DocumentMutationFeedbackMapper().feedback(for: failure))
    }

    func prepareCanvasStrokeEditing(state: inout DocumentEditingState) -> DocumentMutationResult {
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

    func canvasStrokeContext(in state: DocumentEditingState) -> CanvasStrokeContext? {
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
        state: DocumentEditingState,
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
        state: DocumentEditingState,
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
        state: inout DocumentEditingState
    ) -> Effect<Action> {
        switch outcome {
        case let .preview(mutation):
            documentCanvasStrokeStateCoordinator.applyPreviewMutation(
                mutation,
                state: &state,
                discardPreviewLease: { lease in
                    canvasStrokeInteractionService.discardPreviewLease(lease)
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
        state: inout DocumentEditingState
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
        state: inout DocumentEditingState,
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
        state: inout DocumentEditingState
    ) -> Effect<Action> {
        canvasStrokeEffectCoordinator.complete(
            resolution,
            state: &state,
            resetPreview: { state, transferredPreviewLease in
                resetStrokePreviewState(
                    state: &state,
                    preserving: transferredPreviewLease
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

    func activeEditableCanvasLayer(in state: DocumentEditingState) -> LayerRowModel? {
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
              !activeLayer.isLocked
        else {
            return nil
        }
        return activeLayer
    }

    func completeCanvasStrokeMutation(
        state: inout DocumentEditingState,
        contract: DocumentMutationContract = .dirty
    ) -> Effect<Action> {
        completeDocumentMutation(state: &state, contract: contract)
    }

    func handleBeginStroke(
        state: inout DocumentEditingState,
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
        state: inout DocumentEditingState,
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
        state: inout DocumentEditingState,
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
        resetStrokePreviewState(state: &state)
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
        state: inout DocumentEditingState,
        samples: [StylusSample],
        keepsSelectionCleared: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> Effect<Action> {
        if state.canvas.currentTool == .shape {
            resetStrokePreviewState(state: &state)
        }
        return canvasStrokeInteractionCoordinator.finish(
            state: &state,
            samples: samples,
            keepsSelectionCleared: keepsSelectionCleared,
            refreshViaDirtyPresentation: refreshViaDirtyPresentation,
            resolveContext: { state in
                canvasStrokeContext(in: state)
            },
            resetPreview: { state, transferredPreviewLease in
                resetStrokePreviewState(
                    state: &state,
                    preserving: transferredPreviewLease
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

    func handleCancelStroke(state: inout DocumentEditingState) -> Effect<Action> {
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
        state: inout DocumentEditingState,
        samples: [StylusSample]
    ) -> Effect<Action> {
        guard !samples.isEmpty else { return .none }
        guard activeEditableCanvasLayer(in: state) != nil else {
            return .none
        }
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
        let command: ValidatedBlurStrokeMutationCommand
        switch documentWorkflowCommandValidator.blurStrokeCommand(
            samples: samples,
            brush: brush,
            clearSelectionAfterBlur: false,
            in: state
        ) {
        case let .success(validatedCommand):
            command = validatedCommand
        case let .failure(failure):
            return applyCanvasStrokeFailure(failure, state: &state)
        }
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection),
            mutation: {
                switch documentLayerCommandService.revealLayerForEditing(command.layer) {
                case .success:
                    return documentStrokeCommandService.blurStroke(command)
                case let .failure(failure):
                    return .failure(failure)
                }
            }
        )
    }

    func handleEndBlurStroke(state: inout DocumentEditingState) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: documentStrokeCommandService.endBlurStroke
        )
    }

    func handleCancelBlurStroke(state: inout DocumentEditingState) -> Effect<Action> {
        documentStrokeCommandService.cancelBlurStroke()
        return .none
    }

    func handleFill(
        state: inout DocumentEditingState,
        sample: StylusSample
    ) -> Effect<Action> {
        guard activeEditableCanvasLayer(in: state) != nil else {
            return .none
        }
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
        let command: ValidatedFillMutationCommand
        switch documentWorkflowCommandValidator.fillCommand(
            sample: sample,
            brush: brush,
            in: state
        ) {
        case let .success(validatedCommand):
            command = validatedCommand
        case let .failure(failure):
            return applyCanvasStrokeFailure(failure, state: &state)
        }
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection),
            mutation: {
                switch documentLayerCommandService.ensureLayerVisible(command.layer) {
                case .success:
                    return documentStrokeCommandService.fill(command)
                case let .failure(failure):
                    return .failure(failure)
                }
            }
        )
    }
}

private extension DocumentStrokeContext {
    init(_ context: DocumentCanvasStrokeContext) {
        self.init(
            activeLayer: context.activeLayer,
            activeLayerIndex: context.activeLayerIndex,
            brush: context.brush,
            previewBrush: context.previewBrush
        )
    }
}

private extension DocumentEditingState {
    func usesResponsivePreview(for brush: BrushRuntimeSettings) -> Bool {
        GpuOnlyStrokePreviewPolicy().usesResponsivePreview(for: brush)
    }
}
