import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentApplication
import PrimoDocumentPresentationContracts

struct StrokeCommitCoordinator: Sendable {
    struct StrokeSession: Sendable {
        let id: UUID
        var layerIndex: Int
        var brush: BrushRuntimeSettings
        var samples: [StylusSample]
    }

    struct BlurSession: Sendable {
        let id: UUID
        var baseline: SwiftDocumentStoreSnapshot?
        var layerIndex: Int
        var brush: BrushRuntimeSettings
        var samples: [StylusSample]
    }

    struct BlurSessionReservation: Sendable {
        fileprivate let sessionID: UUID
        fileprivate let previousState: BlurSession?
    }

    private var currentStroke: StrokeSession?
    private var currentBlurStroke: BlurSession?

    var blurStrokeState: BlurSession? {
        currentBlurStroke
    }

    mutating func beginStroke(layerIndex: Int, sample: StylusSample, brush: BrushRuntimeSettings) {
        currentStroke = StrokeSession(id: UUID(), layerIndex: layerIndex, brush: brush, samples: [sample])
    }

    mutating func appendStroke(sample: StylusSample) {
        currentStroke?.samples.append(sample)
    }

    mutating func currentStrokePlanInput() -> StrokeSession? {
        currentStroke
    }

    mutating func clearCurrentStroke(id: UUID? = nil) {
        if let id, currentStroke?.id != id { return }
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
        let previousState = currentBlurStroke
        let sessionID = previousState?.id ?? UUID()
        let reservation = BlurSessionReservation(sessionID: sessionID, previousState: previousState)
        currentBlurStroke = BlurSession(
            id: sessionID,
            baseline: previousState?.baseline ?? baseline,
            layerIndex: layerIndex,
            brush: brush,
            samples: (previousState?.samples ?? []) + samples
        )
        return reservation
    }

    mutating func rollbackBlurReservation(_ reservation: BlurSessionReservation) {
        guard currentBlurStroke?.id == reservation.sessionID else { return }
        currentBlurStroke = reservation.previousState
    }

    mutating func clearBlurStroke() {
        currentBlurStroke = nil
    }
}
