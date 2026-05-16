import CasePaths
import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoBrushRuntimeContracts
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentRuntime
import PrimoWorkspaceApplication

struct DocumentCanvasDimensions: Equatable, Sendable {
    let width: Int
    let height: Int

    init?(width: Int, height: Int) {
        guard width > 0, height > 0 else { return nil }
        self.width = width
        self.height = height
    }

    func isWithin(_ supportedRange: ClosedRange<Int>) -> Bool {
        supportedRange.contains(width) && supportedRange.contains(height)
    }

    var size: CGSize {
        CGSize(width: width, height: height)
    }
}

struct DocumentFreshDocumentReplacementContract: Equatable, Sendable {
    let canvasSize: CGSize
    let tabTitle: String
    var successFeedback: ApplicationFeature.Feedback? = nil
    var mutationFailureFeedback: ApplicationFeature.Feedback? = nil
}

struct DocumentWorkspaceDocumentSnapshot: Equatable, Sendable {
    let activeTab: OpenDocumentTab?
    let paperStyle: CanvasPaperStyle
    let previewSurface: DocumentCompositeSurface?
    let canvasSize: CGSize
}

enum DocumentWorkspaceSnapshotPurpose: Equatable, Sendable {
    case pendingWorkspaceOperation
}

enum DocumentFreshDocumentMutationOperation: Equatable, Sendable {
    case newCanvas(DocumentCanvasDimensions)
    case importedCanvas(ImportExportFeature.ImportedCanvasPlan)
}

struct DocumentFreshDocumentMutationRequest: Equatable, Sendable {
    let contract: DocumentFreshDocumentReplacementContract
    let operation: DocumentFreshDocumentMutationOperation
    let preparedTab: WorkspaceFeature.PreparedWorkspaceTab
}

struct DocumentCanvasStrokeContext {
    let activeLayer: LayerRowModel
    let activeLayerIndex: Int
    let brush: BrushRuntimeSettings
    let previewBrush: BrushRuntimeSettings
}

@ObservableState
struct DocumentEditingState: Equatable {
    var brushPalette = BrushPaletteFeature.State()
    var layerSidebar = LayerSidebarFeature.State()
    var canvas = CanvasFeature.State()
    var brushPanel = StudioPanelLayoutState()
    var layerPanel = StudioPanelLayoutState()
}

@Reducer
struct DocumentFeature {
    static let canvasPresentationStateCoordinator = CanvasPresentationStateCoordinator()
    static let canvasPreviewStateCoordinator = CanvasPreviewStateCoordinator()

    typealias DocumentCanvasMutation = DocumentCanvasMutationIntent<CanvasSelection>
    typealias DocumentPresentationRefresh = DocumentPresentationRefreshIntent
    typealias LayerMutationFinalization = DocumentLayerMutationFinalization
    typealias DocumentMutationContract = DocumentMutationWorkflowOutcome<CanvasSelection, ApplicationFeature.Feedback>
    typealias LayerWorkflowService = any LayerMutationWorkflowSubmitting
    typealias CanvasDimensions = DocumentCanvasDimensions
    typealias FreshDocumentReplacementContract = DocumentFreshDocumentReplacementContract
    typealias WorkspaceDocumentSnapshot = DocumentWorkspaceDocumentSnapshot
    typealias WorkspaceSnapshotPurpose = DocumentWorkspaceSnapshotPurpose
    typealias FreshDocumentMutationOperation = DocumentFreshDocumentMutationOperation
    typealias FreshDocumentMutationRequest = DocumentFreshDocumentMutationRequest
    typealias CanvasStrokeContext = DocumentCanvasStrokeContext

    @ObservableState
    struct State: Equatable {
        var editing = DocumentEditingState()
        var activeAIImageJobID: UUID?
    }

    @CasePathable
    enum Action: Equatable {
        enum Delegate: Equatable {
            case presentationRefreshRequested
            case documentMutationFeedback(ApplicationFeature.Feedback)
            case paperStyleSyncRequested(CanvasPaperStyle)
            case presentationApplied
            case workspaceSnapshotPrepared(WorkspaceSnapshotPurpose, WorkspaceDocumentSnapshot)
            case loadedProjectApplied
            case loadedProjectApplySkipped
            case freshDocumentMutationSucceeded(WorkspaceFeature.PreparedWorkspaceTab, FreshDocumentReplacementContract, WorkspaceDocumentSnapshot)
            case freshDocumentMutationFailed(ApplicationFeature.Feedback?)
            case freshDocumentRequested(FreshDocumentReplacementContract, FreshDocumentMutationOperation)
            case aiImageGenerationStarted(AIImageGenerationStart)
            case aiImageGenerationFailed(ApplicationFeature.Feedback, AppLanguage)
            case aiImageEditApplied(AIImageAppliedEdit)
        }

        case presentation(PresentationRefreshReducer.Action)
        case lifecycle(DocumentLifecycleReducer.Action)
        case canvasEditing(CanvasEditingWorkflowReducer.Action)
        case layerWorkflow(LayerWorkflowReducer.Action)
        case adjustment(AdjustmentWorkflowReducer.Action)
        case aiImageWorkflow(AIImageWorkflowReducer.Action)
        case brushPalette(BrushPaletteFeature.Action)
        case layerSidebar(LayerSidebarFeature.Action)
        case canvas(CanvasFeature.Action)
        case delegate(Delegate)
    }

    var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.editing.brushPalette, action: \.brushPalette) {
                BrushPaletteFeature()
            }

            Scope(state: \.editing.layerSidebar, action: \.layerSidebar) {
                LayerSidebarFeature()
            }

            Scope(state: \.editing.canvas, action: \.canvas) {
                CanvasFeature()
            }

            Scope(state: \.editing, action: \.presentation) {
                PresentationRefreshReducer()
            }

            Scope(state: \.editing, action: \.lifecycle) {
                DocumentLifecycleReducer()
            }

            Scope(state: \.editing, action: \.canvasEditing) {
                CanvasEditingWorkflowReducer()
            }

            Scope(state: \.editing, action: \.layerWorkflow) {
                LayerWorkflowReducer()
            }

            Scope(state: \.editing, action: \.adjustment) {
                AdjustmentWorkflowReducer()
            }

            Scope(state: \.self, action: \.aiImageWorkflow) {
                AIImageWorkflowReducer()
            }

            DocumentEditingRouter()
        }
    }
}
