import ComposableArchitecture
import Foundation

extension AppFeature {
    func routeCanvasEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .canvas(.delegate(.beginStroke(sample))):
            return handleBeginStroke(state: &state, sample: sample)

        case let .canvas(.delegate(.appendSamples(samples))):
            handleAppendStrokeSamples(state: &state, samples: samples)
            return .none

        case let .canvas(.delegate(.previewShapeStroke(samples))):
            return handlePreviewShapeStroke(state: &state, samples: samples)

        case .canvas(.delegate(.commitPreviewShapeStroke)):
            return handleCommitPreviewShapeStroke(state: &state)

        case let .canvas(.delegate(.endStroke(samples))):
            return handleFinishStroke(
                state: &state,
                samples: samples,
                keepsSelectionCleared: false,
                refreshViaDirtyPresentation: true
            )

        case .canvas(.delegate(.cancelStroke)):
            return handleCancelStroke(state: &state)

        case let .canvas(.delegate(.commitStroke(samples))):
            return handleFinishStroke(
                state: &state,
                samples: samples,
                keepsSelectionCleared: true,
                refreshViaDirtyPresentation: false
            )

        case let .canvas(.delegate(.blurSamples(samples))):
            handleBlurSamples(state: &state, samples: samples)
            return .none

        case .canvas(.delegate(.endBlurStroke)):
            handleEndBlurStroke(state: &state)
            return .none

        case let .canvas(.delegate(.fill(sample))):
            return handleFill(state: &state, sample: sample)

        case let .canvas(.delegate(.lassoSelect(points))):
            return handleLassoSelection(state: &state, points: points)

        case let .canvas(.delegate(.autoSelect(sample))):
            return handleAutoSelection(state: &state, sample: sample)

        case .canvas(.delegate(.requestUndo)):
            return .send(.undoRequested)

        case .canvas(.delegate(.requestRedo)):
            return .send(.redoRequested)

        case .canvas(.delegate(.toggleBrushAndEraser)):
            handleToggleBrushAndEraser(state: &state)
            return .none

        case let .canvas(.colorSampled(sampledColor)):
            handleColorSampled(state: &state, sampledColor: sampledColor)
            return .none

        case .canvas:
            return .none

        default:
            return nil
        }
    }
}
