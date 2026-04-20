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
        switch beginPixelLayerMutation(at: layerIndex) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            break
        }
        return documentGateway.strokes.applyCommittedStroke(
            samples: samples,
            brush: brush,
            layerIndex: layerIndex
        )
            ? .success(())
            : .failure(.bridgeMutationFailed("applyCommittedStroke"))
    }

    func applyBlurStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, transient: Bool = false) {
        guard !samples.isEmpty else { return }
        guard validate(.layer(index: layerIndex, requiresUnlocked: true)) == nil else { return }
        _ = documentGateway.strokes.applyBlurStroke(
            samples: samples,
            brush: brush,
            layerIndex: layerIndex,
            transient: transient
        )
    }
}
