import Foundation

extension PaintDocumentSession {
    func beginStroke(sample: StylusSample, brush: BrushRuntimeSettings) {
        activeStrokeLayerIndex = Int(bridge.activeLayerIndex)
        activeStrokeBrush = brush
        activeStrokeSamples = [sample]
        if let activeStrokeLayerIndex {
            clearTextLayerData(index: activeStrokeLayerIndex)
        }
        bridge.beginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: sample))
    }

    func appendStroke(sample: StylusSample) {
        activeStrokeSamples.append(sample)
        bridge.appendStroke(point: makeStrokePoint(from: sample))
    }

    func endStroke() {
        let activeLayerIndex = Int(bridge.activeLayerIndex)
        let recordedEvent: TimelapseOperation? = if let layerIndex = activeStrokeLayerIndex,
                                                   let brush = activeStrokeBrush,
                                                   !activeStrokeSamples.isEmpty {
            TimelapseOperation.stroke(
                layerIndex: layerIndex,
                brush: brush,
                samples: activeStrokeSamples
            )
        } else {
            nil
        }
        bridge.endStroke()
        editingLifecycleService.resetStrokeState(
            activeLayerIndex: &activeStrokeLayerIndex,
            activeBrush: &activeStrokeBrush,
            activeSamples: &activeStrokeSamples
        )
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: recordedEvent.map { [$0] } ?? [],
                invalidating: .layer(activeLayerIndex)
            )
        )
    }

    func cancelStroke() {
        let activeLayerIndex = Int(bridge.activeLayerIndex)
        bridge.cancelStroke()
        editingLifecycleService.resetStrokeState(
            activeLayerIndex: &activeStrokeLayerIndex,
            activeBrush: &activeStrokeBrush,
            activeSamples: &activeStrokeSamples
        )
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                invalidating: .layer(activeLayerIndex),
                captureFrame: false
            )
        )
    }

    func fill(sample: StylusSample, brush: BrushRuntimeSettings) {
        let layerIndex = Int(bridge.activeLayerIndex)
        guard !isLayerLocked(index: layerIndex) else { return }
        clearTextLayerData(index: layerIndex)
        bridge.fill(
            at: sample.point,
            brush: makeBrushDescriptor(from: brush)
        )
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .fill(
                    layerIndex: layerIndex,
                    brush: brush,
                    sample: sample
                ),
                invalidating: .layer(Int(bridge.activeLayerIndex))
            )
        )
    }

    func blur(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, captureTimelapse: Bool) {
        guard !samples.isEmpty else { return }
        guard !isLayerLocked(index: layerIndex) else { return }
        clearTextLayerData(index: layerIndex)
        if activeBlurStrokeLayerIndex != layerIndex {
            activeBlurStrokeLayerIndex = layerIndex
            activeBlurStrokeBrush = brush
            activeBlurStrokeSamples = []
            blurStrokeHasCapturedHistory = false
        }
        activeBlurStrokeSamples.append(contentsOf: samples)
        applyBlurStroke(samples: samples, brush: brush, layerIndex: layerIndex, transient: blurStrokeHasCapturedHistory)
        blurStrokeHasCapturedHistory = true
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                invalidating: .layer(layerIndex),
                captureFrame: captureTimelapse
            )
        )
    }

    func endBlurStroke() {
        let recordedEvent: TimelapseOperation? = if let layerIndex = activeBlurStrokeLayerIndex,
                                                   let brush = activeBlurStrokeBrush,
                                                   !activeBlurStrokeSamples.isEmpty {
            TimelapseOperation.blurStroke(
                layerIndex: layerIndex,
                brush: brush,
                samples: activeBlurStrokeSamples
            )
        } else {
            nil
        }
        editingLifecycleService.resetBlurStrokeState(
            activeLayerIndex: &activeBlurStrokeLayerIndex,
            activeBrush: &activeBlurStrokeBrush,
            activeSamples: &activeBlurStrokeSamples,
            blurStrokeHasCapturedHistory: &blurStrokeHasCapturedHistory
        )
        applyLifecycleMutation(
            editingLifecycleService.mutation(recording: recordedEvent.map { [$0] } ?? [])
        )
    }

    @discardableResult
    func applySoftwareStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int) -> Bool {
        guard !isLayerLocked(index: layerIndex) else { return false }
        let basePixelData = bridge.pixelDataForLayer(at: layerIndex) as Data
        guard let rasterized = AppFeature.layerPixelDataByApplyingCommittedStroke(
            basePixelData: basePixelData,
            canvasWidth: Int(bridge.width),
            canvasHeight: Int(bridge.height),
            samples: samples,
            brush: brush,
            preserveAlphaLockedPixels: isLayerAlphaLocked(index: layerIndex)
        ) else {
            return false
        }
        replaceLayerPixels(index: layerIndex, data: rasterized)
        return true
    }

    func applyBlurStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, transient: Bool = false) {
        guard !samples.isEmpty else { return }
        guard !isLayerLocked(index: layerIndex) else { return }
        let canvasSize = PaintDocumentCanvasSize(width: Int(bridge.width), height: Int(bridge.height))
        let sourceData = bridge.pixelDataForLayer(at: layerIndex) as Data
        guard sourceData.count == canvasSize.rgbaByteCount else { return }

        let original = [UInt8](sourceData)
        guard let blurred = blurService.boxBlurredPixels(from: original, size: canvasSize, radius: brush.radius) else {
            return
        }

        let blended = blurService.blendBlurredPixels(
            original: original,
            blurred: blurred,
            size: canvasSize,
            samples: samples,
            brush: brush
        )
        let outputData = isLayerAlphaLocked(index: layerIndex)
            ? Self.pixelDataByPreservingExistingAlpha(source: Data(blended), existing: sourceData)
            : Data(blended)
        if transient {
            bridge.replaceLayerPixelsTransient(at: layerIndex, data: outputData)
        } else {
            bridge.replaceLayerPixels(at: layerIndex, data: outputData)
        }
    }
}
