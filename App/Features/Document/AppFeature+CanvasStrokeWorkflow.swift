import ComposableArchitecture
import Foundation

extension AppFeature {
    struct CanvasStrokeWorkflowService {
        let paintDocumentClient: PaintDocumentClient

        func ensureLayerVisible(_ layerIndex: Int) {
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
        ) {
            paintDocumentClient.replaceLayerPixels(layerIndex, pixelData)
        }

        func applySoftwareStroke(
            _ samples: [StylusSample],
            brush: BrushRuntimeSettings,
            layerIndex: Int
        ) -> Bool {
            paintDocumentClient.applySoftwareStroke(samples, brush, layerIndex)
        }

        func revealLayerForEditing(_ layerIndex: Int) {
            paintDocumentClient.revealLayerForEditing(layerIndex)
        }

        func blurStroke(
            _ samples: [StylusSample],
            brush: BrushRuntimeSettings,
            layerIndex: Int,
            clearSelectionAfterBlur: Bool
        ) {
            paintDocumentClient.blurStroke(samples, brush, layerIndex, clearSelectionAfterBlur)
        }

        func endBlurStroke() {
            paintDocumentClient.endBlurStroke()
        }

        func fill(
            _ sample: StylusSample,
            brush: BrushRuntimeSettings
        ) {
            paintDocumentClient.fill(sample, brush)
        }
    }

    var canvasStrokeWorkflowService: CanvasStrokeWorkflowService {
        CanvasStrokeWorkflowService(paintDocumentClient: paintDocumentClient)
    }

    func resetStrokePreviewState(state: inout State) {
        state.canvas.resetStrokePreview()
    }

    func handleBeginStroke(
        state: inout State,
        sample: StylusSample
    ) -> Effect<Action> {
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
            return .none
        }
        canvasStrokeWorkflowService.ensureLayerVisible(state.canvas.activeLayerIndex)
        state.canvas.clearSelection()
        canvasStrokeWorkflowService.cancelStroke()
        if state.canvas.activeStrokeBaseSnapshot == nil {
            if state.canvas.renderSnapshot == nil {
                applyCurrentDocumentPresentation(state: &state)
            }
            if let renderSnapshot = state.canvas.renderSnapshot {
                state.canvas.captureStrokeBaseSnapshot(renderSnapshot)
            }
        }
        let brush = resolvedBrushSettings(for: state)
        var previewBrush = brush
        previewBrush.taperIn = 0
        previewBrush.taperOut = 0
        if
            let baseSnapshot = state.canvas.activeStrokeBaseSnapshot,
            let baseLayer = baseSnapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
            let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                basePixelData: baseLayer.pixelData,
                canvasWidth: baseSnapshot.width,
                canvasHeight: baseSnapshot.height,
                samples: [sample],
                brush: previewBrush,
                preserveAlphaLockedPixels: activeLayer.isAlphaLocked
            )
        {
            state.canvas.setStrokePreviewLayerPixelData(adjustedPixels)
            if
                Self.shouldUseIncrementalPreviewUpdate(for: previewBrush),
                let dirtyRect = Self.strokePreviewDirtyRect(
                    samples: [sample],
                    brush: previewBrush,
                    canvasWidth: baseSnapshot.width,
                    canvasHeight: baseSnapshot.height
                ),
                let incrementalUpdate = Self.compositedPreviewIncrementalUpdate(
                    snapshot: baseSnapshot,
                    activeLayerIndex: state.canvas.activeLayerIndex,
                    adjustedActiveLayerPixels: adjustedPixels,
                    dirtyRect: dirtyRect
                )
            {
                state.canvas.setPendingIncrementalUpdate(incrementalUpdate)
            } else {
                applyLiveStrokePreview(
                    baseSnapshot: baseSnapshot,
                    activeLayerIndex: state.canvas.activeLayerIndex,
                    adjustedActiveLayerPixels: adjustedPixels,
                    state: &state
                )
            }
        }
        return .concatenate(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleAppendStrokeSamples(
        state: inout State,
        samples: [StylusSample]
    ) {
        guard !samples.isEmpty else { return }
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
            return
        }
        let brush = resolvedBrushSettings(for: state)
        var previewBrush = brush
        previewBrush.taperIn = 0
        previewBrush.taperOut = 0
        if
            let baseSnapshot = state.canvas.activeStrokeBaseSnapshot,
            let baseLayer = baseSnapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex })
        {
            let fullSamples = state.canvas.activeStroke?.points.map(\.stylusSample) ?? samples
            let anchorIndex = max(fullSamples.count - samples.count - 1, 0)
            let anchor = fullSamples.indices.contains(anchorIndex) ? fullSamples[anchorIndex] : nil
            let previewSamples = anchor.map { [$0] + samples } ?? samples
            let basePixelData = state.canvas.activeStrokePreviewLayerPixelData ?? baseLayer.pixelData
            guard let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                basePixelData: basePixelData,
                canvasWidth: baseSnapshot.width,
                canvasHeight: baseSnapshot.height,
                samples: previewSamples,
                brush: previewBrush,
                preserveAlphaLockedPixels: activeLayer.isAlphaLocked
            ) else {
                return
            }
            state.canvas.setStrokePreviewLayerPixelData(adjustedPixels)
            if
                Self.shouldUseIncrementalPreviewUpdate(for: previewBrush),
                let dirtyRect = Self.strokePreviewDirtyRect(
                    samples: previewSamples,
                    brush: previewBrush,
                    canvasWidth: baseSnapshot.width,
                    canvasHeight: baseSnapshot.height
                ),
                let incrementalUpdate = Self.compositedPreviewIncrementalUpdate(
                    snapshot: baseSnapshot,
                    activeLayerIndex: state.canvas.activeLayerIndex,
                    adjustedActiveLayerPixels: adjustedPixels,
                    dirtyRect: dirtyRect
                )
            {
                state.canvas.setPendingIncrementalUpdate(incrementalUpdate)
            } else {
                applyLiveStrokePreview(
                    baseSnapshot: baseSnapshot,
                    activeLayerIndex: state.canvas.activeLayerIndex,
                    adjustedActiveLayerPixels: adjustedPixels,
                    state: &state
                )
            }
            return
        }

        guard
            let snapshot = state.canvas.renderSnapshot,
            let baseLayer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
            let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                basePixelData: baseLayer.pixelData,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                samples: samples,
                brush: previewBrush,
                preserveAlphaLockedPixels: activeLayer.isAlphaLocked
            )
        else { return }

        state.canvas.captureStrokeBaseSnapshot(snapshot)
        state.canvas.setStrokePreviewLayerPixelData(adjustedPixels)
        if
            Self.shouldUseIncrementalPreviewUpdate(for: previewBrush),
            let dirtyRect = Self.strokePreviewDirtyRect(
                samples: samples,
                brush: previewBrush,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height
            ),
            let incrementalUpdate = Self.compositedPreviewIncrementalUpdate(
                snapshot: snapshot,
                activeLayerIndex: state.canvas.activeLayerIndex,
                adjustedActiveLayerPixels: adjustedPixels,
                dirtyRect: dirtyRect
            )
        {
            state.canvas.setPendingIncrementalUpdate(incrementalUpdate)
        } else {
            applyLiveStrokePreview(
                baseSnapshot: snapshot,
                activeLayerIndex: state.canvas.activeLayerIndex,
                adjustedActiveLayerPixels: adjustedPixels,
                state: &state
            )
        }
    }

    func handlePreviewShapeStroke(
        state: inout State,
        samples: [StylusSample]
    ) -> Effect<Action> {
        guard let first = samples.first else { return .none }
        canvasStrokeWorkflowService.ensureLayerVisible(state.canvas.activeLayerIndex)
        state.canvas.clearSelection()
        canvasStrokeWorkflowService.cancelStroke()
        canvasStrokeWorkflowService.beginStroke(first, brush: resolvedBrushSettings(for: state))
        for sample in samples.dropFirst() {
            canvasStrokeWorkflowService.appendStroke(sample)
        }
        applyLiveCompositePixelData(canvasStrokeWorkflowService.compositePixelData(), state: &state)
        return .concatenate(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleCommitPreviewShapeStroke(state: inout State) -> Effect<Action> {
        canvasStrokeWorkflowService.endStroke()
        applyDirtyPresentation(state: &state)
        return .concatenate(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleFinishStroke(
        state: inout State,
        samples: [StylusSample],
        keepsSelectionCleared: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> Effect<Action> {
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
            resetStrokePreviewState(state: &state)
            return .none
        }
        let brush = resolvedBrushSettings(for: state)
        let shouldApplyTaperOnCommit = brush.taperIn > 0.001 || brush.taperOut > 0.001
        if keepsSelectionCleared {
            canvasStrokeWorkflowService.ensureLayerVisible(state.canvas.activeLayerIndex)
            state.canvas.clearSelection()
        }
        if let previewPixels = state.canvas.activeStrokePreviewLayerPixelData, !shouldApplyTaperOnCommit {
            canvasStrokeWorkflowService.replaceLayerPixels(
                state.canvas.activeLayerIndex,
                pixelData: previewPixels
            )
        } else {
            let didCommit = canvasStrokeWorkflowService.applySoftwareStroke(
                samples,
                brush: brush,
                layerIndex: state.canvas.activeLayerIndex
            )
            if !didCommit {
                if !refreshViaDirtyPresentation && state.canvas.renderSnapshot == nil {
                    applyCurrentDocumentPresentation(state: &state)
                }
                let fallbackSnapshot = refreshViaDirtyPresentation
                    ? state.canvas.activeStrokeBaseSnapshot
                    : (state.canvas.activeStrokeBaseSnapshot ?? state.canvas.renderSnapshot)
                if let snapshot = fallbackSnapshot,
                   let baseLayer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                   let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                        basePixelData: baseLayer.pixelData,
                        canvasWidth: snapshot.width,
                        canvasHeight: snapshot.height,
                        samples: samples,
                        brush: brush,
                        preserveAlphaLockedPixels: activeLayer.isAlphaLocked
                   ) {
                    canvasStrokeWorkflowService.replaceLayerPixels(
                        state.canvas.activeLayerIndex,
                        pixelData: adjustedPixels
                    )
                }
            }
        }
        resetStrokePreviewState(state: &state)
        if refreshViaDirtyPresentation {
            applyDirtyPresentation(state: &state)
        } else {
            applyCurrentDocumentPresentation(state: &state)
        }
        return .concatenate(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleCancelStroke(state: inout State) -> Effect<Action> {
        if state.canvas.currentTool == .shape {
            canvasStrokeWorkflowService.cancelStroke()
        }
        resetStrokePreviewState(state: &state)
        applyCurrentDocumentPresentation(state: &state)
        return .concatenate(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleBlurSamples(
        state: inout State,
        samples: [StylusSample]
    ) {
        guard !samples.isEmpty else { return }
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
            return
        }
        canvasStrokeWorkflowService.revealLayerForEditing(state.canvas.activeLayerIndex)
        canvasStrokeWorkflowService.blurStroke(
            samples,
            brush: resolvedBrushSettings(for: state),
            layerIndex: state.canvas.activeLayerIndex,
            clearSelectionAfterBlur: false
        )
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
    }

    func handleEndBlurStroke(state: inout State) {
        canvasStrokeWorkflowService.endBlurStroke()
        applyDirtyPresentation(state: &state)
    }

    func handleFill(
        state: inout State,
        sample: StylusSample
    ) -> Effect<Action> {
        guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
            return .none
        }
        canvasStrokeWorkflowService.ensureLayerVisible(state.canvas.activeLayerIndex)
        canvasStrokeWorkflowService.fill(sample, brush: resolvedBrushSettings(for: state))
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
        return .concatenate(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }
}
