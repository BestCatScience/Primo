import ComposableArchitecture
import CoreGraphics
import PrimoCanvasPresentationDomain
import PrimoDocumentDomain
import PrimoDocumentPersistenceContracts
import PrimoDocumentStrokeApplication

struct CanvasStrokeWorkflow {
    let reducer: CanvasEditingWorkflowReducer

    func reduce(
        state: inout DocumentEditingState,
        action: CanvasEditingWorkflowReducer.Action
    ) -> Effect<CanvasEditingWorkflowReducer.Action>? {
        switch action {
        case let .canvas(.delegate(.beginStroke(sample))):
            return reducer.handleBeginStroke(state: &state, sample: sample)

        case let .canvas(.delegate(.appendSamples(samples))):
            return reducer.handleAppendStrokeSamples(state: &state, samples: samples)

        case let .canvas(.delegate(.previewShapeStroke(samples))):
            return reducer.handlePreviewShapeStroke(state: &state, samples: samples)

        case let .canvas(.delegate(.endStroke(samples))):
            return reducer.handleFinishStroke(
                state: &state,
                samples: samples,
                keepsSelectionCleared: false,
                refreshViaDirtyPresentation: true
            )

        case .canvas(.delegate(.cancelStroke)):
            return reducer.handleCancelStroke(state: &state)

        case let .canvas(.delegate(.commitStroke(samples))):
            return reducer.handleFinishStroke(
                state: &state,
                samples: samples,
                keepsSelectionCleared: true,
                refreshViaDirtyPresentation: false
            )

        case let .canvas(.delegate(.blurSamples(samples))):
            return reducer.handleBlurSamples(state: &state, samples: samples)

        case .canvas(.delegate(.endBlurStroke)):
            return reducer.handleEndBlurStroke(state: &state)

        case .canvas(.delegate(.cancelBlurStroke)):
            return reducer.handleCancelBlurStroke(state: &state)

        case let .canvas(.delegate(.fill(sample))):
            return reducer.handleFill(state: &state, sample: sample)

        default:
            return nil
        }
    }
}

struct CanvasSelectionWorkflow {
    let reducer: CanvasEditingWorkflowReducer
    let transformWorkflow: CanvasTransformWorkflow

    func reduce(
        state: inout DocumentEditingState,
        action: CanvasEditingWorkflowReducer.Action
    ) -> Effect<CanvasEditingWorkflowReducer.Action>? {
        switch action {
        case .brushPalette(.delegate(.clearSelection)):
            state.canvas.clearSelectionState()
            return .none

        case .brushPalette(.delegate(.invertSelection)):
            reducer.handleInvertSelection(state: &state)
            return .none

        case let .brushPalette(.delegate(.expandSelection(expansion))):
            reducer.handleAdjustSelection(state: &state, expansion: max(expansion, 1))
            return .none

        case let .brushPalette(.delegate(.contractSelection(contraction))):
            reducer.handleAdjustSelection(state: &state, expansion: -max(contraction, 1))
            return .none

        case let .editing(.featherSelectionRequested(radius)):
            reducer.handleFeatherSelection(state: &state, radius: max(radius, 1))
            return .none

        case let .editing(.colorRangeSelectionRequested(request)):
            return reducer.handleColorRangeSelectionRequest(state: &state, request: request)

        case let .canvas(.delegate(.lassoSelect(points))):
            return reducer.handleLassoSelection(state: &state, points: points)

        case let .canvas(.delegate(.autoSelect(sample))):
            return reducer.handleAutoSelection(state: &state, sample: sample)

        case .canvas(.delegate(.previewSelectionMove)),
             .canvas(.delegate(.applySelectionMove)),
             .canvas(.delegate(.cancelSelectionMove)):
            return transformWorkflow.reduce(state: &state, action: action)

        default:
            return nil
        }
    }
}

struct CanvasTransformWorkflow {
    let reducer: CanvasEditingWorkflowReducer

    func reduce(
        state: inout DocumentEditingState,
        action: CanvasEditingWorkflowReducer.Action
    ) -> Effect<CanvasEditingWorkflowReducer.Action>? {
        switch action {
        case let .canvas(.delegate(.previewSelectionMove(offset))):
            return reducer.handlePreviewSelectionMove(state: &state, offset: offset)

        case let .canvas(.delegate(.applySelectionMove(offset))):
            return reducer.handleApplySelectionMove(state: &state, offset: offset)

        case .canvas(.delegate(.cancelSelectionMove)):
            return reducer.handleCancelSelectionMove(state: &state)

        default:
            return nil
        }
    }
}

struct CanvasPaperSyncWorkflow {
    let paperStylePort: any PaperStylePort

    func synchronize(_ paperStyle: CanvasPaperStyle) -> Effect<CanvasEditingWorkflowReducer.Action> {
        .run { [paperStylePort] _ in
            paperStylePort.setPaperStyle(paperStyle)
        }
    }
}
