import ComposableArchitecture
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication

struct CanvasEditingWorkflowReducer: Reducer {
    typealias State = DocumentEditingState
    typealias CanvasStrokeContext = DocumentCanvasStrokeContext
    typealias CanvasStrokeSessionCoordinator = DocumentFeature.CanvasStrokeSessionCoordinator
    typealias CanvasStrokeStateCoordinator = DocumentFeature.CanvasStrokeStateCoordinator
    typealias DocumentMutationContract = DocumentFeature.DocumentMutationContract
    typealias DocumentMutationFeedbackMapper = DocumentFeature.DocumentMutationFeedbackMapper
    typealias LayerMutationFinalization = DocumentFeature.LayerMutationFinalization
    typealias StrokeCommitResolution = DocumentFeature.StrokeCommitResolution

    @Dependency(\.strokePreviewPort) var strokePreviewPort
    @Dependency(\.strokeCommitPort) var strokeCommitPort
    @Dependency(\.layerVisibilityPort) var layerVisibilityPort
    @Dependency(\.layerContentPort) var layerContentPort
    @Dependency(\.selectionProcessingPort) var selectionProcessingPort
    @Dependency(\.canvasTransformPort) var canvasTransformPort
    @Dependency(\.canvasEditingPresentationPort) var canvasEditingPresentationPort
    @Dependency(\.paperStylePort) var paperStylePort

    var canvasStrokeInteractionService: any StrokePreviewPort {
        strokePreviewPort
    }

    var documentRenderingWorkflow: DocumentRenderingWorkflow {
        canvasEditingPresentationPort.renderingWorkflow
    }

    var documentLayerCommandService: any LayerVisibilityPort {
        layerVisibilityPort
    }

    var documentPresentationReader: DocumentPresentationReader {
        canvasEditingPresentationPort.presentationReader
    }

    var documentStrokeCommandService: any StrokeCommitPort {
        strokeCommitPort
    }

    var canvasEditingWorkflowService: any CanvasEditingExecuting {
        canvasTransformPort
    }

    var documentContentService: any LayerContentPort {
        layerContentPort
    }

    var layerTransformProcessor: any LayerTransformProcessing {
        canvasTransformPort
    }

    var selectionWorkflowService: any SelectionProcessingPort {
        selectionProcessingPort
    }

    var documentWorkflowCommandValidator: DocumentWorkflowCommandValidator {
        DocumentWorkflowCommandValidator()
    }

    var strokeWorkflow: CanvasStrokeWorkflow {
        CanvasStrokeWorkflow(reducer: self)
    }

    var transformWorkflow: CanvasTransformWorkflow {
        CanvasTransformWorkflow(reducer: self)
    }

    var selectionWorkflow: CanvasSelectionWorkflow {
        CanvasSelectionWorkflow(
            reducer: self,
            transformWorkflow: transformWorkflow
        )
    }

    var paperSyncWorkflow: CanvasPaperSyncWorkflow {
        CanvasPaperSyncWorkflow(paperStylePort: paperStylePort)
    }

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
        if let effect = strokeWorkflow.reduce(state: &state, action: action) {
            return effect
        }
        if let effect = selectionWorkflow.reduce(state: &state, action: action) {
            return effect
        }

        switch action {
        case let .editing(editingAction):
            return reduceEditingAction(editingAction, state: &state)

        case .canvas(.delegate(.requestUndo)):
            return .send(.lifecycle(.undoRequested))

        case .canvas(.delegate(.requestRedo)):
            return .send(.lifecycle(.redoRequested))

        case .canvas(.delegate(.toggleBrushAndEraser)):
            state.toggleBrushAndEraser()
            return .none

        case let .canvas(.delegate(.placeText(point))):
            state.placeText(point)
            return .none

        case let .canvas(.colorSampled(sampledColor)):
            state.applyColorSampled(sampledColor)
            return .none

        case .brushPalette(.binding(\.paper.color)),
             .brushPalette(.binding(\.paper.isTransparent)):
            let paperStyle = state.syncBrushPalettePaperBinding()
            return paperSyncWorkflow.synchronize(paperStyle)

        case .layerSidebar(.binding(\.paperColor)),
             .layerSidebar(.binding(\.transparentPaper)):
            let paperStyle = state.syncLayerSidebarPaperBinding()
            return paperSyncWorkflow.synchronize(paperStyle)

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
        case .featherSelectionRequested,
             .colorRangeSelectionRequested:
            return selectionWorkflow.reduce(state: &state, action: .editing(action)) ?? .none
        }
    }
}
