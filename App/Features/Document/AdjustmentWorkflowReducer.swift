import ComposableArchitecture
import PrimoDocumentMutationContracts

struct AdjustmentWorkflowReducer: Reducer {
    typealias State = DocumentEditingState
    typealias DocumentMutationContract = DocumentFeature.DocumentMutationContract
    typealias LayerMutationFinalization = DocumentFeature.LayerMutationFinalization

    @Dependency(\.documentGpuOperationGateway) var documentGpuOperationGateway
    @Dependency(\.documentMutationGateway) var documentMutationGateway
    @Dependency(\.documentQueryGateway) var documentQueryGateway

    enum EditingAction: Equatable {
        case gradientMapSelected(GradientMapPreset)
        case gradientMapPreviewChanged(GradientMapSettings?)
        case gradientMapApplied(GradientMapSettings)
        case hueSaturationBrightnessPreviewChanged(HueSaturationBrightnessSettings?)
        case hueSaturationBrightnessApplied(HueSaturationBrightnessSettings)
        case brightnessContrastPreviewChanged(BrightnessContrastSettings?)
        case brightnessContrastApplied(BrightnessContrastSettings)
        case levelsPreviewChanged(LevelsAdjustmentSettings?)
        case levelsApplied(LevelsAdjustmentSettings)
        case toneCurvePreviewChanged(ToneCurveSettings?)
        case toneCurveApplied(ToneCurveSettings)
        case colorBalancePreviewChanged(ColorBalanceSettings?)
        case colorBalanceApplied(ColorBalanceSettings)
        case thresholdPreviewChanged(ThresholdSettings?)
        case thresholdApplied(ThresholdSettings)
        case posterizePreviewChanged(PosterizeSettings?)
        case posterizeApplied(PosterizeSettings)
        case luminanceToAlphaRequested
    }

    enum Action: Equatable {
        case editing(EditingAction)
        case delegate(DocumentFeature.Action.Delegate)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .editing(.gradientMapPreviewChanged(settings)):
            Self.previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .gradientMapSettings($0) },
                gpuOperations: documentGpuOperationGateway
            )
            return .none
        case let .editing(.hueSaturationBrightnessPreviewChanged(settings)):
            Self.previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .hueSaturationBrightness($0) },
                gpuOperations: documentGpuOperationGateway
            )
            return .none
        case let .editing(.brightnessContrastPreviewChanged(settings)):
            Self.previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .brightnessContrast($0) },
                gpuOperations: documentGpuOperationGateway
            )
            return .none
        case let .editing(.levelsPreviewChanged(settings)):
            Self.previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .levels($0) },
                gpuOperations: documentGpuOperationGateway
            )
            return .none
        case let .editing(.toneCurvePreviewChanged(settings)):
            Self.previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .toneCurve($0) },
                gpuOperations: documentGpuOperationGateway
            )
            return .none
        case let .editing(.colorBalancePreviewChanged(settings)):
            Self.previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .colorBalance($0) },
                gpuOperations: documentGpuOperationGateway
            )
            return .none
        case let .editing(.thresholdPreviewChanged(settings)):
            Self.previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .threshold($0) },
                gpuOperations: documentGpuOperationGateway
            )
            return .none
        case let .editing(.posterizePreviewChanged(settings)):
            Self.previewAdjustedActiveLayer(
                state: &state,
                request: settings.map { .posterize($0) },
                gpuOperations: documentGpuOperationGateway
            )
            return .none
        case let .editing(.gradientMapSelected(preset)):
            return handleAdjustmentApplyRequest(state: &state, request: .gradientMap(preset), failureFeedback: .gradientMapApplyFailed)
        case let .editing(.gradientMapApplied(settings)):
            return handleAdjustmentApplyRequest(state: &state, request: .gradientMapSettings(settings), failureFeedback: .gradientMapApplyFailed)
        case let .editing(.hueSaturationBrightnessApplied(settings)):
            return handleAdjustmentApplyRequest(state: &state, request: .hueSaturationBrightness(settings), failureFeedback: .colorAdjustmentApplyFailed)
        case let .editing(.brightnessContrastApplied(settings)):
            return handleAdjustmentApplyRequest(state: &state, request: .brightnessContrast(settings), failureFeedback: .colorAdjustmentApplyFailed)
        case let .editing(.levelsApplied(settings)):
            return handleAdjustmentApplyRequest(state: &state, request: .levels(settings), failureFeedback: .colorAdjustmentApplyFailed)
        case let .editing(.toneCurveApplied(settings)):
            return handleAdjustmentApplyRequest(state: &state, request: .toneCurve(settings), failureFeedback: .colorAdjustmentApplyFailed)
        case let .editing(.colorBalanceApplied(settings)):
            return handleAdjustmentApplyRequest(state: &state, request: .colorBalance(settings), failureFeedback: .colorAdjustmentApplyFailed)
        case let .editing(.thresholdApplied(settings)):
            return handleAdjustmentApplyRequest(state: &state, request: .threshold(settings), failureFeedback: .colorAdjustmentApplyFailed)
        case let .editing(.posterizeApplied(settings)):
            return handleAdjustmentApplyRequest(state: &state, request: .posterize(settings), failureFeedback: .colorAdjustmentApplyFailed)
        case .editing(.luminanceToAlphaRequested):
            return handleAdjustmentApplyRequest(state: &state, request: .luminanceToAlpha, failureFeedback: .colorAdjustmentApplyFailed)
        default:
            return .none
        }
    }
}
