import Foundation
import PrimoDocumentApplication

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

    func fill(sample: StylusSample, brush: BrushRuntimeSettings) -> DocumentMutationResult {
        let layerIndex = documentGateway.queries.activeLayerIndex()
        switch beginPixelLayerMutation(at: layerIndex) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            break
        }
        documentGateway.strokes.fill(sample: sample, brush: brush)
        applyLayerLifecycleMutation(
            at: layerIndex,
            recording: .fill(
                layerIndex: .unchecked(layerIndex),
                brush: brush,
                sample: sample
            )
        )
        return .success(())
    }

    func blur(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, captureTimelapse: Bool) -> DocumentMutationResult {
        guard !samples.isEmpty else { return .failure(.emptyInput) }
        switch beginPixelLayerMutation(at: layerIndex) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            break
        }
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
        return .success(())
    }

    func endBlurStroke() {
        let recordedEvent = finishTrackedBlurStroke()
        applyRecordedLifecycleMutation(
            recording: recordedEvent.map { [$0] } ?? []
        )
    }

    func applySoftwareStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int) -> DocumentMutationResult {
        guard !samples.isEmpty else {
            return .failure(.emptyInput)
        }
        if let failure = validate(.layer(index: layerIndex, requiresUnlocked: true)) {
            return .failure(failure)
        }
        let basePixelData = pixelDataForLayer(index: layerIndex)
        guard let rasterized = DocumentStrokeRasterizer.layerPixelDataByApplyingCommittedStroke(
            basePixelData: basePixelData,
            canvasWidth: documentGateway.queries.canvasWidth,
            canvasHeight: documentGateway.queries.canvasHeight,
            samples: samples,
            brush: brush,
            preserveAlphaLockedPixels: isLayerAlphaLocked(index: layerIndex)
        ) else {
            return .failure(.bridgeMutationFailed("applySoftwareStroke"))
        }
        return replaceLayerPixels(index: layerIndex, data: rasterized)
    }

    func applyBlurStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, transient: Bool = false) {
        guard !samples.isEmpty else { return }
        guard validate(.layer(index: layerIndex, requiresUnlocked: true)) == nil else { return }
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
