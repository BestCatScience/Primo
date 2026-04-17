import Foundation

extension PaintDocumentSession {
    func beginStroke(sample: StylusSample, brush: BrushRuntimeSettings) {
        let activeLayerIndex = documentGateway.queries.activeLayerIndex()
        beginTrackedStroke(on: activeLayerIndex, brush: brush, sample: sample)
        clearTextLayerData(index: activeLayerIndex)
        documentGateway.strokes.begin(sample: sample, brush: brush)
    }

    func appendStroke(sample: StylusSample) {
        appendTrackedStroke(sample)
        documentGateway.strokes.append(sample: sample)
    }

    func endStroke() {
        let activeLayerIndex = documentGateway.queries.activeLayerIndex()
        let recordedEvent = finishTrackedStroke()
        documentGateway.strokes.end()
        applyLayerLifecycleMutation(
            at: activeLayerIndex,
            recording: recordedEvent.map { [$0] } ?? []
        )
    }

    func cancelStroke() {
        let activeLayerIndex = documentGateway.queries.activeLayerIndex()
        documentGateway.strokes.cancel()
        resetTrackedStroke()
        applyLayerLifecycleMutation(
            at: activeLayerIndex,
            captureFrame: false
        )
    }

    @discardableResult
    func fill(sample: StylusSample, brush: BrushRuntimeSettings) -> Bool {
        let layerIndex = documentGateway.queries.activeLayerIndex()
        guard beginPixelLayerMutation(at: layerIndex) else { return false }
        documentGateway.strokes.fill(sample: sample, brush: brush)
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
            canvasWidth: documentGateway.queries.canvasWidth,
            canvasHeight: documentGateway.queries.canvasHeight,
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
        let canvasSize = PaintDocumentCanvasSize(
            width: documentGateway.queries.canvasWidth,
            height: documentGateway.queries.canvasHeight
        )
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
        documentGateway.layers.replaceLayerPixels(index: layerIndex, data: outputData, transient: transient)
    }
}
