import Foundation

extension PaintDocumentSession {
    func beginStroke(sample: StylusSample, brush: BrushRuntimeSettings) {
        let activeLayerIndex = bridgeActiveLayerIndex()
        beginTrackedStroke(on: activeLayerIndex, brush: brush, sample: sample)
        clearTextLayerData(index: activeLayerIndex)
        bridgeBeginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: sample))
    }

    func appendStroke(sample: StylusSample) {
        appendTrackedStroke(sample)
        bridgeAppendStroke(point: makeStrokePoint(from: sample))
    }

    func endStroke() {
        let activeLayerIndex = bridgeActiveLayerIndex()
        let recordedEvent = finishTrackedStroke()
        bridgeEndStroke()
        applyLayerLifecycleMutation(
            at: activeLayerIndex,
            recording: recordedEvent.map { [$0] } ?? []
        )
    }

    func cancelStroke() {
        let activeLayerIndex = bridgeActiveLayerIndex()
        bridgeCancelStroke()
        resetTrackedStroke()
        applyLayerLifecycleMutation(
            at: activeLayerIndex,
            captureFrame: false
        )
    }

    func fill(sample: StylusSample, brush: BrushRuntimeSettings) {
        let layerIndex = bridgeActiveLayerIndex()
        guard beginPixelLayerMutation(at: layerIndex) else { return }
        bridgeFill(
            at: sample.point,
            brush: makeBrushDescriptor(from: brush)
        )
        applyLayerLifecycleMutation(
            at: layerIndex,
            recording: .fill(
                layerIndex: .unchecked(layerIndex),
                brush: brush,
                sample: sample
            )
        )
    }

    func blur(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, captureTimelapse: Bool) {
        guard !samples.isEmpty else { return }
        guard beginPixelLayerMutation(at: layerIndex) else { return }
        beginOrContinueTrackedBlurStroke(on: layerIndex, brush: brush)
        appendTrackedBlurSamples(samples)
        applyBlurStroke(
            samples: samples,
            brush: brush,
            layerIndex: layerIndex,
            transient: shouldApplyTrackedBlurTransiently
        )
        markTrackedBlurHistoryCaptured()
        applyLayerLifecycleMutation(
            at: layerIndex,
            captureFrame: captureTimelapse
        )
    }

    func endBlurStroke() {
        let recordedEvent = finishTrackedBlurStroke()
        applyRecordedLifecycleMutation(
            recording: recordedEvent.map { [$0] } ?? []
        )
    }

    @discardableResult
    func applySoftwareStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int) -> Bool {
        requireExistingLayerIndex(layerIndex)
        guard !isLayerLocked(index: layerIndex) else { return false }
        let basePixelData = pixelDataForLayer(index: layerIndex)
        guard let rasterized = AppFeature.layerPixelDataByApplyingCommittedStroke(
            basePixelData: basePixelData,
            canvasWidth: bridgeCanvasWidth,
            canvasHeight: bridgeCanvasHeight,
            samples: samples,
            brush: brush,
            preserveAlphaLockedPixels: isLayerAlphaLocked(index: layerIndex)
        ) else {
            return false
        }
        return replaceLayerPixels(index: layerIndex, data: rasterized)
    }

    func applyBlurStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, transient: Bool = false) {
        guard !samples.isEmpty else { return }
        requireExistingLayerIndex(layerIndex)
        guard !isLayerLocked(index: layerIndex) else { return }
        let canvasSize = PaintDocumentCanvasSize(width: bridgeCanvasWidth, height: bridgeCanvasHeight)
        let sourceData = pixelDataForLayer(index: layerIndex)
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
        bridgeReplaceLayerPixels(index: layerIndex, data: outputData, transient: transient)
    }
}
