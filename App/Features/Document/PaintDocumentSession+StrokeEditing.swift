import Foundation

extension PaintDocumentSession {
    func beginStroke(sample: StylusSample, brush: BrushRuntimeSettings) {
        let activeLayerIndex = queryBridge.activeLayerIndex()
        beginTrackedStroke(on: activeLayerIndex, brush: brush, sample: sample)
        clearTextLayerData(index: activeLayerIndex)
        strokeBridge.beginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: sample))
    }

    func appendStroke(sample: StylusSample) {
        appendTrackedStroke(sample)
        strokeBridge.appendStroke(point: makeStrokePoint(from: sample))
    }

    func endStroke() {
        let activeLayerIndex = queryBridge.activeLayerIndex()
        let recordedEvent = finishTrackedStroke()
        strokeBridge.endStroke()
        applyLayerLifecycleMutation(
            at: activeLayerIndex,
            recording: recordedEvent.map { [$0] } ?? []
        )
    }

    func cancelStroke() {
        let activeLayerIndex = queryBridge.activeLayerIndex()
        strokeBridge.cancelStroke()
        resetTrackedStroke()
        applyLayerLifecycleMutation(
            at: activeLayerIndex,
            captureFrame: false
        )
    }

    @discardableResult
    func fill(sample: StylusSample, brush: BrushRuntimeSettings) -> Bool {
        let layerIndex = queryBridge.activeLayerIndex()
        guard beginPixelLayerMutation(at: layerIndex) else { return false }
        strokeBridge.fill(
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
        return true
    }

    @discardableResult
    func blur(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, captureTimelapse: Bool) -> Bool {
        guard !samples.isEmpty else { return false }
        guard beginPixelLayerMutation(at: layerIndex) else { return false }
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
        return true
    }

    func endBlurStroke() {
        let recordedEvent = finishTrackedBlurStroke()
        applyRecordedLifecycleMutation(
            recording: recordedEvent.map { [$0] } ?? []
        )
    }

    @discardableResult
    func applySoftwareStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int) -> Bool {
        guard containsLayerIndex(layerIndex) else { return false }
        guard !isLayerLocked(index: layerIndex) else { return false }
        let basePixelData = pixelDataForLayer(index: layerIndex)
        guard let rasterized = AppFeature.layerPixelDataByApplyingCommittedStroke(
            basePixelData: basePixelData,
            canvasWidth: queryBridge.canvasWidth,
            canvasHeight: queryBridge.canvasHeight,
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
        guard containsLayerIndex(layerIndex) else { return }
        guard !isLayerLocked(index: layerIndex) else { return }
        let canvasSize = PaintDocumentCanvasSize(width: queryBridge.canvasWidth, height: queryBridge.canvasHeight)
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
        layerBridge.replaceLayerPixels(index: layerIndex, data: outputData, transient: transient)
    }
}
