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
        case failed
    }

    struct CanvasStrokeWorkflowService {
        let paintDocumentClient: PaintDocumentClient

        func ensureLayerVisible(_ layerIndex: Int) -> Bool {
            paintDocumentClient.setLayerVisibility(layerIndex, true)
        }

        func cancelStroke() {
            paintDocumentClient.cancelStroke()
        }

        func beginStroke(
            _ sample: StylusSample,
            brush: BrushRuntimeSettings
        ) {
            paintDocumentClient.beginStroke(sample, brush)
        }

        func appendStroke(_ sample: StylusSample) {
            paintDocumentClient.appendStroke(sample)
        }

        func compositePixelData() -> Data {
            paintDocumentClient.compositePixelData()
        }

        func endStroke() {
            paintDocumentClient.endStroke()
        }

        func replaceLayerPixels(
            _ layerIndex: Int,
            pixelData: Data
        ) -> Bool {
            paintDocumentClient.replaceLayerPixels(layerIndex, pixelData)
        }

        func applySoftwareStroke(
            _ samples: [StylusSample],
            brush: BrushRuntimeSettings,
            layerIndex: Int
        ) -> Bool {
            paintDocumentClient.applySoftwareStroke(samples, brush, layerIndex)
        }

        func revealLayerForEditing(_ layerIndex: Int) -> Bool {
            paintDocumentClient.revealLayerForEditing(layerIndex)
        }

        func blurStroke(
            _ samples: [StylusSample],
            brush: BrushRuntimeSettings,
            layerIndex: Int,
            clearSelectionAfterBlur: Bool
        ) -> Bool {
            paintDocumentClient.blurStroke(samples, brush, layerIndex, clearSelectionAfterBlur)
        }

        func endBlurStroke() {
            paintDocumentClient.endBlurStroke()
        }

        func fill(
            _ sample: StylusSample,
            brush: BrushRuntimeSettings
        ) -> Bool {
            paintDocumentClient.fill(sample, brush)
        }
    }

    var canvasStrokeWorkflowService: CanvasStrokeWorkflowService {
        CanvasStrokeWorkflowService(paintDocumentClient: paintDocumentClient)
    }

    func resetStrokePreviewState(state: inout State) {
        state.canvas.resetStrokePreview()
    }

    func clearCanvasSelectionWithoutRefresh(state: inout State) {
        completeDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .none
            )
        )
    }

    func ensureCurrentCanvasPresentationLoaded(state: inout State) {
        guard state.canvas.renderSnapshot == nil else { return }
        completeDocumentMutation(
            state: &state,
            contract: .currentPresentation
        )
    }

    func captureActiveStrokeBaseSnapshotIfNeeded(state: inout State) {
        guard state.canvas.activeStrokeBaseSnapshot == nil else { return }
        ensureCurrentCanvasPresentationLoaded(state: &state)
        if let renderSnapshot = state.canvas.renderSnapshot {
            state.canvas.captureStrokeBaseSnapshot(renderSnapshot)
        }
    }

    func prepareCanvasStrokeEditing(state: inout State) -> Bool {
        guard canvasStrokeWorkflowService.ensureLayerVisible(state.canvas.activeLayerIndex) else {
            return false
        }
        clearCanvasSelectionWithoutRefresh(state: &state)
        canvasStrokeWorkflowService.cancelStroke()
        return true
    }

    func previewBrush(for brush: BrushRuntimeSettings) -> BrushRuntimeSettings {
        var previewBrush = brush
        previewBrush.taperIn = 0
        previewBrush.taperOut = 0
        return previewBrush
    }

    func canvasStrokeContext(in state: State) -> CanvasStrokeContext? {
        guard let activeLayer = activeEditableCanvasLayer(in: state) else {
            return nil
        }
        let brush = resolvedBrushSettings(for: state)
        return CanvasStrokeContext(
            activeLayer: activeLayer,
            activeLayerIndex: state.canvas.activeLayerIndex,
            brush: brush,
            previewBrush: previewBrush(for: brush)
        )
    }

    func resolveInitialStrokePreview(
        state: State,
        sample: StylusSample,
        context: CanvasStrokeContext
    ) -> StrokePreviewResolution? {
        guard let baseSnapshot = state.canvas.activeStrokeBaseSnapshot,
              let baseLayer = baseSnapshot.layers.first(where: { $0.index == context.activeLayerIndex }),
              let previewPlan = makeStrokePreviewPlan(
                snapshot: baseSnapshot,
                activeLayerIndex: context.activeLayerIndex,
                basePixelData: baseLayer.pixelData,
                samples: [sample],
                brush: context.previewBrush,
                preserveAlphaLockedPixels: context.activeLayer.isAlphaLocked
              )
        else {
            return nil
        }
        return StrokePreviewResolution(plan: previewPlan)
    }

    func resolveAppendedStrokePreview(
        state: State,
        samples: [StylusSample],
        context: CanvasStrokeContext
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
            guard let previewPlan = makeStrokePreviewPlan(
                snapshot: baseSnapshot,
                activeLayerIndex: context.activeLayerIndex,
                basePixelData: basePixelData,
                samples: previewSamples,
                brush: context.previewBrush,
                preserveAlphaLockedPixels: context.activeLayer.isAlphaLocked
            ) else {
                return nil
            }
            return StrokePreviewResolution(plan: previewPlan)
        }

        guard
            let snapshot = state.canvas.renderSnapshot,
            let baseLayer = snapshot.layers.first(where: { $0.index == context.activeLayerIndex }),
            let previewPlan = makeStrokePreviewPlan(
                snapshot: snapshot,
                activeLayerIndex: context.activeLayerIndex,
                basePixelData: baseLayer.pixelData,
                samples: samples,
                brush: context.previewBrush,
                preserveAlphaLockedPixels: context.activeLayer.isAlphaLocked
            )
        else {
            return nil
        }
        return StrokePreviewResolution(
            plan: previewPlan,
            baseSnapshotToCapture: snapshot
        )
    }

    func applyStrokePreviewResolution(
        _ resolution: StrokePreviewResolution,
        activeLayerIndex: Int,
        state: inout State
    ) {
        if let baseSnapshotToCapture = resolution.baseSnapshotToCapture {
            state.canvas.captureStrokeBaseSnapshot(baseSnapshotToCapture)
        }
        applyStrokePreviewPlan(
            resolution.plan,
            activeLayerIndex: activeLayerIndex,
            state: &state
        )
    }

    func resolveStrokeCommit(
        state: inout State,
        samples: [StylusSample],
        context: CanvasStrokeContext,
        keepsSelectionCleared: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> StrokeCommitResolution {
        let shouldApplyTaperOnCommit = context.brush.taperIn > 0.001 || context.brush.taperOut > 0.001
        if keepsSelectionCleared {
            guard canvasStrokeWorkflowService.ensureLayerVisible(context.activeLayerIndex) else {
                return .failed
            }
            clearCanvasSelectionWithoutRefresh(state: &state)
        }
        let didCommit: Bool
        if let previewPixels = state.canvas.activeStrokePreviewLayerPixelData, !shouldApplyTaperOnCommit {
            didCommit = canvasStrokeWorkflowService.replaceLayerPixels(
                context.activeLayerIndex,
                pixelData: previewPixels
            )
        } else {
            let committedInSession = canvasStrokeWorkflowService.applySoftwareStroke(
                samples,
                brush: context.brush,
                layerIndex: context.activeLayerIndex
            )
            didCommit = committedInSession || commitStrokeUsingFallbackPixels(
                state: &state,
                samples: samples,
                brush: context.brush,
                activeLayer: context.activeLayer,
                refreshViaDirtyPresentation: refreshViaDirtyPresentation
            )
        }
        guard didCommit else {
            return .failed
        }
        return .committed(
            DocumentMutationContract(
                canvasMutation: keepsSelectionCleared ? .clearSelection : .none,
                refresh: refreshViaDirtyPresentation ? .dirty : .current
            )
        )
    }

    func completeResolvedStrokeCommit(
        _ resolution: StrokeCommitResolution,
        state: inout State
    ) -> Effect<Action> {
        resetStrokePreviewState(state: &state)
        switch resolution {
        case let .committed(contract):
            return completeCanvasStrokeMutation(
                state: &state,
                contract: contract
            )
        case .failed:
            return cancelStartupPresentationEffects()
        }
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
            state.canvas.setPendingIncrementalUpdate(incrementalUpdate)
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
    ) -> Bool {
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
            return false
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
        completeDocumentMutation(state: &state, contract: contract)
        return cancelStartupPresentationEffects()
    }

    func handleBeginStroke(
        state: inout State,
        sample: StylusSample
    ) -> Effect<Action> {
        guard let context = canvasStrokeContext(in: state) else {
            return .none
        }
        guard prepareCanvasStrokeEditing(state: &state) else {
            return .none
        }
        captureActiveStrokeBaseSnapshotIfNeeded(state: &state)
        if let previewResolution = resolveInitialStrokePreview(
            state: state,
            sample: sample,
            context: context
        ) {
            applyStrokePreviewResolution(
                previewResolution,
                activeLayerIndex: context.activeLayerIndex,
                state: &state
            )
        }
        return cancelStartupPresentationEffects()
    }

    func handleAppendStrokeSamples(
        state: inout State,
        samples: [StylusSample]
    ) {
        guard let context = canvasStrokeContext(in: state) else {
            return
        }
        guard let previewResolution = resolveAppendedStrokePreview(
            state: state,
            samples: samples,
            context: context
        ) else { return }
        applyStrokePreviewResolution(
            previewResolution,
            activeLayerIndex: context.activeLayerIndex,
            state: &state
        )
    }

    func handlePreviewShapeStroke(
        state: inout State,
        samples: [StylusSample]
    ) -> Effect<Action> {
        guard let first = samples.first else { return .none }
        guard prepareCanvasStrokeEditing(state: &state) else {
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
        guard let context = canvasStrokeContext(in: state) else {
            resetStrokePreviewState(state: &state)
            return .none
        }
        let commitResolution = resolveStrokeCommit(
            state: &state,
            samples: samples,
            context: context,
            keepsSelectionCleared: keepsSelectionCleared,
            refreshViaDirtyPresentation: refreshViaDirtyPresentation
        )
        return completeResolvedStrokeCommit(
            commitResolution,
            state: &state
        )
    }

    func handleCancelStroke(state: inout State) -> Effect<Action> {
        if state.canvas.currentTool == .shape {
            canvasStrokeWorkflowService.cancelStroke()
        }
        resetStrokePreviewState(state: &state)
        return completeCanvasStrokeMutation(
            state: &state,
            contract: .currentPresentation
        )
    }

    func handleBlurSamples(
        state: inout State,
        samples: [StylusSample]
    ) {
        guard !samples.isEmpty else { return }
        guard activeEditableCanvasLayer(in: state) != nil else {
            return
        }
        guard canvasStrokeWorkflowService.revealLayerForEditing(state.canvas.activeLayerIndex) else {
            return
        }
        guard canvasStrokeWorkflowService.blurStroke(
            samples,
            brush: resolvedBrushSettings(for: state),
            layerIndex: state.canvas.activeLayerIndex,
            clearSelectionAfterBlur: false
        ) else {
            return
        }
        completeDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        )
    }

    func handleEndBlurStroke(state: inout State) {
        canvasStrokeWorkflowService.endBlurStroke()
        completeDocumentMutation(state: &state)
    }

    func handleFill(
        state: inout State,
        sample: StylusSample
    ) -> Effect<Action> {
        guard activeEditableCanvasLayer(in: state) != nil else {
            return .none
        }
        guard canvasStrokeWorkflowService.ensureLayerVisible(state.canvas.activeLayerIndex) else {
            return .none
        }
        guard canvasStrokeWorkflowService.fill(sample, brush: resolvedBrushSettings(for: state)) else {
            return .none
        }
        return completeCanvasStrokeMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        )
    }
}
