import ComposableArchitecture
import Foundation

extension DocumentFeatureRuntimeReducer {
    func routeCanvasEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .document(.canvas(.delegate(.beginStroke(sample)))):
            return handleBeginStroke(state: &state, sample: sample)

        case let .document(.canvas(.delegate(.appendSamples(samples)))):
            handleAppendStrokeSamples(state: &state, samples: samples)
            return .none

        case let .document(.canvas(.delegate(.previewShapeStroke(samples)))):
            return handlePreviewShapeStroke(state: &state, samples: samples)

        case .document(.canvas(.delegate(.commitPreviewShapeStroke))):
            return handleCommitPreviewShapeStroke(state: &state)

        case let .document(.canvas(.delegate(.endStroke(samples)))):
            return handleFinishStroke(
                state: &state,
                samples: samples,
                keepsSelectionCleared: false,
                refreshViaDirtyPresentation: true
            )

        case .document(.canvas(.delegate(.cancelStroke))):
            return handleCancelStroke(state: &state)

        case let .document(.canvas(.delegate(.commitStroke(samples)))):
            return handleFinishStroke(
                state: &state,
                samples: samples,
                keepsSelectionCleared: true,
                refreshViaDirtyPresentation: false
            )

        case let .document(.canvas(.delegate(.blurSamples(samples)))):
            return handleBlurSamples(state: &state, samples: samples)

        case .document(.canvas(.delegate(.endBlurStroke))):
            return handleEndBlurStroke(state: &state)

        case let .document(.canvas(.delegate(.fill(sample)))):
            return handleFill(state: &state, sample: sample)

        case let .document(.canvas(.delegate(.lassoSelect(points)))):
            return handleLassoSelection(state: &state, points: points)

        case let .document(.canvas(.delegate(.autoSelect(sample)))):
            return handleAutoSelection(state: &state, sample: sample)

        case .document(.canvas(.delegate(.requestUndo))):
            return .send(.document(.undoRequested))

        case .document(.canvas(.delegate(.requestRedo))):
            return .send(.document(.redoRequested))

        case .document(.canvas(.delegate(.toggleBrushAndEraser))):
            handleToggleBrushAndEraser(state: &state)
            return .none

        case let .document(.canvas(.colorSampled(sampledColor))):
            handleColorSampled(state: &state, sampledColor: sampledColor)
            return .none

        case .document(.canvas):
            return .none

        default:
            return nil
        }
    }
}
