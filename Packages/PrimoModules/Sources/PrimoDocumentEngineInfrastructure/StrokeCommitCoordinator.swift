import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentApplication
import PrimoDocumentPresentationContracts

struct StrokeCommitCoordinator: Sendable {
    struct BlurSessionReservation: Sendable {
        fileprivate let previousState: (baseline: SwiftDocumentStoreSnapshot?, layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])?
    }

    private var currentStroke: (layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])?
    private var currentBlurStroke: (baseline: SwiftDocumentStoreSnapshot?, layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])?

    var blurStrokeState: (baseline: SwiftDocumentStoreSnapshot?, layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])? {
        currentBlurStroke
    }

    mutating func beginStroke(layerIndex: Int, sample: StylusSample, brush: BrushRuntimeSettings) {
        currentStroke = (layerIndex: layerIndex, brush: brush, samples: [sample])
    }

    mutating func appendStroke(sample: StylusSample) {
        currentStroke?.samples.append(sample)
    }

    mutating func currentStrokePlanInput() -> (layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])? {
        currentStroke
    }

    mutating func clearCurrentStroke() {
        currentStroke = nil
    }

    mutating func cancelStroke() {
        currentStroke = nil
    }

    mutating func beginOrAppendBlur(
        baseline: SwiftDocumentStoreSnapshot,
        layerIndex: Int,
        brush: BrushRuntimeSettings,
        samples: [StylusSample]
    ) -> BlurSessionReservation {
        let reservation = BlurSessionReservation(previousState: currentBlurStroke)
        currentBlurStroke = (
            baseline: currentBlurStroke?.baseline ?? baseline,
            layerIndex: layerIndex,
            brush: brush,
            samples: (currentBlurStroke?.samples ?? []) + samples
        )
        return reservation
    }

    mutating func rollbackBlurReservation(_ reservation: BlurSessionReservation) {
        currentBlurStroke = reservation.previousState
    }

    mutating func clearBlurStroke() {
        currentBlurStroke = nil
    }
}
