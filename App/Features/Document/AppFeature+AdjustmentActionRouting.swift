import ComposableArchitecture
import Foundation

extension AppFeature {
    func routeAdjustmentEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .gradientMapSelected(preset):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .gradientMap(preset),
                failureFeedback: .gradientMapApplyFailed
            )
            return .none

        case let .gradientMapPreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.gradientMappedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .gradientMapApplied(settings):
            let adjusted = adjustedActiveLayerPixels(in: state) {
                Self.gradientMappedLayerPixels(source: $0, settings: settings)
            }
            _ = handleAdjustmentApplyUsingPixels(
                state: &state,
                adjustedPixels: adjusted,
                failureFeedback: .gradientMapApplyFailed
            )
            return .none

        case let .hueSaturationBrightnessPreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.hueSaturationBrightnessAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .hueSaturationBrightnessApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .hueSaturationBrightness(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )
            return .none

        case let .brightnessContrastPreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.brightnessContrastAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .brightnessContrastApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .brightnessContrast(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )
            return .none

        case let .levelsPreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.levelsAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .levelsApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .levels(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )
            return .none

        case let .toneCurvePreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.toneCurveAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .toneCurveApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .toneCurve(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )
            return .none

        case let .colorBalancePreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.colorBalanceAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .colorBalanceApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .colorBalance(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )
            return .none

        case let .thresholdPreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.thresholdAdjustedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .thresholdApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .threshold(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )
            return .none

        case let .posterizePreviewChanged(settings):
            previewAdjustedActiveLayer(state: &state) { source in
                settings.flatMap { Self.posterizedLayerPixels(source: source, settings: $0) }
            }
            return .none

        case let .posterizeApplied(settings):
            _ = handleAdjustmentApplyRequest(
                state: &state,
                request: .posterize(settings),
                failureFeedback: .colorAdjustmentApplyFailed
            )
            return .none

        case .luminanceToAlphaRequested:
            let adjusted = adjustedActiveLayerPixels(in: state) {
                Self.luminanceToAlphaLayerPixels(source: $0)
            }
            _ = handleAdjustmentApplyUsingPixels(
                state: &state,
                adjustedPixels: adjusted,
                failureFeedback: .colorAdjustmentApplyFailed
            )
            return .none

        default:
            return nil
        }
    }
}
