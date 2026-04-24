import ComposableArchitecture
import Foundation
import PrimoDocumentContracts

extension AppFeature {
    func routeAdjustmentEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .editing(.gradientMapSelected(preset)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .gradientMap(preset),
                failureFeedback: .gradientMapApplyFailed
            )

        case let .editing(.gradientMapPreviewChanged(settings)):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .gradientMapSettings($0) }
            )
            return .none

        case let .editing(.gradientMapApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .gradientMapSettings(settings),
                failureFeedback: .gradientMapApplyFailed
            )

        case let .editing(.hueSaturationBrightnessPreviewChanged(settings)):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .hueSaturationBrightness($0) }
            )
            return .none

        case let .editing(.hueSaturationBrightnessApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .hueSaturationBrightness(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .editing(.brightnessContrastPreviewChanged(settings)):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .brightnessContrast($0) }
            )
            return .none

        case let .editing(.brightnessContrastApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .brightnessContrast(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .editing(.levelsPreviewChanged(settings)):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .levels($0) }
            )
            return .none

        case let .editing(.levelsApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .levels(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .editing(.toneCurvePreviewChanged(settings)):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .toneCurve($0) }
            )
            return .none

        case let .editing(.toneCurveApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .toneCurve(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .editing(.colorBalancePreviewChanged(settings)):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .colorBalance($0) }
            )
            return .none

        case let .editing(.colorBalanceApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .colorBalance(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .editing(.thresholdPreviewChanged(settings)):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .threshold($0) }
            )
            return .none

        case let .editing(.thresholdApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .threshold(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .editing(.posterizePreviewChanged(settings)):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .posterize($0) }
            )
            return .none

        case let .editing(.posterizeApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .posterize(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case .editing(.luminanceToAlphaRequested):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .luminanceToAlpha,
                failureFeedback: .colorAdjustmentApplyFailed
            )

        default:
            return nil
        }
    }
}
