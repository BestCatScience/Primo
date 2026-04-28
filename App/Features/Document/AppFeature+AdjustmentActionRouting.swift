import ComposableArchitecture
import Foundation
import PrimoDocumentContracts

extension AppIntegrationFeature {
    func routeAdjustmentEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .document(.editing(.gradientMapSelected(preset))):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .gradientMap(preset),
                failureFeedback: .gradientMapApplyFailed
            )

        case let .document(.editing(.gradientMapPreviewChanged(settings))):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .gradientMapSettings($0) }
            )
            return .none

        case let .document(.editing(.gradientMapApplied(settings))):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .gradientMapSettings(settings),
                failureFeedback: .gradientMapApplyFailed
            )

        case let .document(.editing(.hueSaturationBrightnessPreviewChanged(settings))):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .hueSaturationBrightness($0) }
            )
            return .none

        case let .document(.editing(.hueSaturationBrightnessApplied(settings))):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .hueSaturationBrightness(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .document(.editing(.brightnessContrastPreviewChanged(settings))):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .brightnessContrast($0) }
            )
            return .none

        case let .document(.editing(.brightnessContrastApplied(settings))):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .brightnessContrast(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .document(.editing(.levelsPreviewChanged(settings))):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .levels($0) }
            )
            return .none

        case let .document(.editing(.levelsApplied(settings))):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .levels(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .document(.editing(.toneCurvePreviewChanged(settings))):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .toneCurve($0) }
            )
            return .none

        case let .document(.editing(.toneCurveApplied(settings))):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .toneCurve(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .document(.editing(.colorBalancePreviewChanged(settings))):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .colorBalance($0) }
            )
            return .none

        case let .document(.editing(.colorBalanceApplied(settings))):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .colorBalance(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .document(.editing(.thresholdPreviewChanged(settings))):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .threshold($0) }
            )
            return .none

        case let .document(.editing(.thresholdApplied(settings))):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .threshold(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .document(.editing(.posterizePreviewChanged(settings))):
            previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .posterize($0) }
            )
            return .none

        case let .document(.editing(.posterizeApplied(settings))):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .posterize(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case .document(.editing(.luminanceToAlphaRequested)):
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
