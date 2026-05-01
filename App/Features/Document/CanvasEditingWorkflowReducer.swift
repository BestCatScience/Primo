import ComposableArchitecture
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts

struct CanvasEditingWorkflowReducer: Reducer {
    typealias State = DocumentEditingState
    typealias CanvasStrokeContext = DocumentCanvasStrokeContext
    typealias CanvasStrokeSessionCoordinator = DocumentFeature.CanvasStrokeSessionCoordinator
    typealias CanvasStrokeStateCoordinator = DocumentFeature.CanvasStrokeStateCoordinator
    typealias DocumentMutationContract = DocumentFeature.DocumentMutationContract
    typealias DocumentMutationFeedbackMapper = DocumentFeature.DocumentMutationFeedbackMapper
    typealias LayerMutationFinalization = DocumentFeature.LayerMutationFinalization
    typealias StrokeCommitResolution = DocumentFeature.StrokeCommitResolution

    @Dependency(\.canvasStrokeInteractionService) var canvasStrokeInteractionService
    @Dependency(\.canvasEditingWorkflowService) var canvasEditingWorkflowService
    @Dependency(\.documentGpuOperationGateway) var documentGpuOperationGateway
    @Dependency(\.documentLayerCommandService) var documentLayerCommandService
    @Dependency(\.documentPersistenceGateway) var documentPersistenceGateway
    @Dependency(\.documentQueryGateway) var documentQueryGateway
    @Dependency(\.documentStrokeCommandService) var documentStrokeCommandService
    @Dependency(\.documentStrokeSessionUseCase) var documentStrokeSessionUseCase
    @Dependency(\.selectionWorkflowService) var selectionWorkflowService

    enum EditingAction: Equatable {
        case featherSelectionRequested(Int)
        case colorRangeSelectionRequested(ColorRangeSelectionRequest)
        case toolSelected(StudioToolKind)
        case toolLongPressed(StudioToolKind)
        case panelCollapseToggled(StudioPanelKind)
    }

    enum Action: Equatable {
        case editing(EditingAction)
        case brushPalette(BrushPaletteFeature.Action)
        case layerSidebar(LayerSidebarFeature.Action)
        case canvas(CanvasFeature.Action)
        case lifecycle(DocumentLifecycleReducer.Action)
        case delegate(DocumentFeature.Action.Delegate)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .editing(editingAction):
            return reduceEditingAction(editingAction, state: &state)

        case .brushPalette(.delegate(.clearSelection)):
            state.canvas.clearSelectionState()
            return .none

        case .brushPalette(.delegate(.invertSelection)):
            handleInvertSelection(state: &state)
            return .none

        case .brushPalette(.delegate(.cancelTransform)):
            state.canvas.resetTransformPreview()
            return .none

        case .brushPalette(.delegate(.applyTransform)),
             .canvas(.delegate(.applyTransform)):
            return handleApplyTransform(state: &state)

        case let .brushPalette(.delegate(.expandSelection(expansion))):
            handleAdjustSelection(state: &state, expansion: max(expansion, 1))
            return .none

        case let .brushPalette(.delegate(.contractSelection(contraction))):
            handleAdjustSelection(state: &state, expansion: -max(contraction, 1))
            return .none

        case .canvas(.delegate(.requestUndo)):
            return .send(.lifecycle(.undoRequested))

        case .canvas(.delegate(.requestRedo)):
            return .send(.lifecycle(.redoRequested))

        case .canvas(.delegate(.beginStroke)),
             .canvas(.delegate(.appendSamples)),
             .canvas(.delegate(.previewShapeStroke)),
             .canvas(.delegate(.endStroke)),
             .canvas(.delegate(.cancelStroke)),
             .canvas(.delegate(.commitStroke)),
             .canvas(.delegate(.blurSamples)),
             .canvas(.delegate(.endBlurStroke)),
             .canvas(.delegate(.cancelBlurStroke)),
             .canvas(.delegate(.fill)):
            return routeDocumentEditorEditingAction(state: &state, action: action) ?? .none

        case .canvas(.delegate(.toggleBrushAndEraser)):
            state.toggleBrushAndEraser()
            return .none

        case let .canvas(.delegate(.placeText(point))):
            state.placeText(point)
            return .none

        case let .canvas(.colorSampled(sampledColor)):
            state.applyColorSampled(sampledColor)
            return .none

        case let .canvas(.delegate(.lassoSelect(points))):
            return handleLassoSelection(state: &state, points: points)

        case let .canvas(.delegate(.autoSelect(sample))):
            return handleAutoSelection(state: &state, sample: sample)

        case .brushPalette(.binding(\.paper.color)),
             .brushPalette(.binding(\.paper.isTransparent)):
            let paperStyle = state.syncBrushPalettePaperBinding()
            return synchronizePaperStyleEffect(paperStyle)

        case .layerSidebar(.binding(\.paperColor)),
             .layerSidebar(.binding(\.transparentPaper)):
            let paperStyle = state.syncLayerSidebarPaperBinding()
            return synchronizePaperStyleEffect(paperStyle)

        default:
            return .none
        }
    }

    private func reduceEditingAction(
        _ action: EditingAction,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case let .panelCollapseToggled(panel):
            DocumentFeature.toolPanelStateCoordinator.toggleCollapse(for: panel, in: &state)
            return .none
        case let .toolSelected(tool):
            state.selectTool(tool, showsBrushSettingsPopover: false)
            return .none
        case let .toolLongPressed(tool):
            state.selectTool(tool, showsBrushSettingsPopover: tool == .brush || tool == .erase)
            return .none
        case let .featherSelectionRequested(radius):
            handleFeatherSelection(state: &state, radius: max(radius, 1))
            return .none
        case let .colorRangeSelectionRequested(request):
            return handleColorRangeSelectionRequest(state: &state, request: request)
        }
    }
}
