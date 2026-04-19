import ComposableArchitecture
import Foundation

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
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.gradientMappedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .editing(.gradientMapApplied(settings)):
            let adjusted = adjustedActiveLayerPixels(in: state) {
                Self.gradientMappedLayerPixels(source: $0, settings: settings)
            }
            return handleAdjustmentApplyUsingPixels(
                state: &state,
                adjustedPixels: adjusted,
                failureFeedback: .gradientMapApplyFailed
            )

        case let .editing(.hueSaturationBrightnessPreviewChanged(settings)):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.hueSaturationBrightnessAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .editing(.hueSaturationBrightnessApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .hueSaturationBrightness(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .editing(.brightnessContrastPreviewChanged(settings)):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.brightnessContrastAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .editing(.brightnessContrastApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .brightnessContrast(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .editing(.levelsPreviewChanged(settings)):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.levelsAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .editing(.levelsApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .levels(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .editing(.toneCurvePreviewChanged(settings)):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.toneCurveAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .editing(.toneCurveApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .toneCurve(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .editing(.colorBalancePreviewChanged(settings)):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.colorBalanceAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .editing(.colorBalanceApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .colorBalance(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .editing(.thresholdPreviewChanged(settings)):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.thresholdAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .editing(.thresholdApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .threshold(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case let .editing(.posterizePreviewChanged(settings)):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.posterizedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .editing(.posterizeApplied(settings)):
            return handleAdjustmentApplyRequest(
                state: &state,
                request: .posterize(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )

        case .editing(.luminanceToAlphaRequested):
            let adjusted = adjustedActiveLayerPixels(in: state) {
                Self.luminanceToAlphaLayerPixels(source: $0)
            }
            return handleAdjustmentApplyUsingPixels(
                state: &state,
                adjustedPixels: adjusted,
                failureFeedback: .colorAdjustmentApplyFailed
            )

        default:
            return nil
        }
    }
}
