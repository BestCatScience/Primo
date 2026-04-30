import CasePaths
import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoAIImageApplication
import PrimoAIImageDomain
import PrimoWorkspaceApplication

@Reducer
struct DocumentFeature {
    static let canvasPresentationStateCoordinator = CanvasPresentationStateCoordinator()
    static let canvasPreviewStateCoordinator = CanvasPreviewStateCoordinator()

    typealias DocumentCanvasMutation = DocumentCanvasMutationIntent<CanvasSelection>
    typealias DocumentPresentationRefresh = DocumentPresentationRefreshIntent
    typealias LayerMutationFinalization = DocumentLayerMutationFinalization
    typealias DocumentMutationContract = DocumentMutationWorkflowOutcome<CanvasSelection, ApplicationFeature.Feedback>
    typealias LayerWorkflowService = DocumentMutationWorkflowService

    struct DocumentNamingPolicy: Equatable {
        let language: AppLanguage

        func defaultLayerName(for layerSidebar: LayerSidebarFeature.State) -> String {
            layerSidebar.numberedLayerName(prefix: "Layer")
        }

        func folderName(forOrdinal ordinal: Int) -> String {
            StudioStrings.folderName(ordinal, language)
        }

        func duplicatedLayerName(for originalName: String) -> String {
            language == .japanese ? "\(originalName) のコピー" : "\(originalName) Copy"
        }

        func photoLayerName(
            proposedName: String?,
            layerSidebar: LayerSidebarFeature.State
        ) -> String {
            let fallbackName = layerSidebar.numberedLayerName(
                prefix: language == .japanese ? "写真" : "Photo"
            )
            let trimmedName = proposedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmedName.isEmpty ? fallbackName : trimmedName
        }

        func textLayerName(from draftText: String) -> String {
            let trimmedLine = draftText
                .components(separatedBy: CharacterSet.newlines)
                .first?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if let trimmedLine, !trimmedLine.isEmpty {
                return trimmedLine
            }
            return language == .japanese ? "テキスト" : "Text"
        }

        func importedCanvasLayerName(from proposedName: String?) -> String {
            let trimmedName = proposedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmedName.isEmpty {
                return trimmedName
            }
            return language == .japanese ? "画像 1" : "Image 1"
        }

        func aiImageLayerName(for layerSidebar: LayerSidebarFeature.State) -> String {
            layerSidebar.numberedLayerName(prefix: "AI Image")
        }
    }

    struct CanvasDimensions: Equatable, Sendable {
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

    struct FreshDocumentReplacementContract: Equatable, Sendable {
        let canvasSize: CGSize
        let tabTitle: String
        var successFeedback: ApplicationFeature.Feedback? = nil
        var mutationFailureFeedback: ApplicationFeature.Feedback? = nil
    }

    struct WorkspaceDocumentSnapshot: Equatable, Sendable {
        let activeTab: OpenDocumentTab?
        let paperStyle: CanvasPaperStyle
        let previewSurface: DocumentCompositeSurface?
        let canvasSize: CGSize
    }

    enum WorkspaceSnapshotPurpose: Equatable, Sendable {
        case pendingWorkspaceOperation
    }

    enum FreshDocumentMutationOperation: Equatable, Sendable {
        case newCanvas(CanvasDimensions)
        case importedCanvas(ImportExportFeature.ImportedCanvasPlan)
    }

    struct FreshDocumentMutationRequest: Equatable, Sendable {
        let contract: FreshDocumentReplacementContract
        let operation: FreshDocumentMutationOperation
        let preparedTab: WorkspaceFeature.PreparedWorkspaceTab
    }

    struct CanvasStrokeContext {
        let activeLayer: LayerRowModel
        let activeLayerIndex: Int
        let brush: BrushRuntimeSettings
        let previewBrush: BrushRuntimeSettings
    }

    struct AIImageGenerationStart: Equatable, Sendable {
        let descriptor: AIImageEditDescriptor
        let jobID: UUID
        let createdAt: Date
    }

    struct AIImageAppliedEdit: Equatable, Sendable {
        let preview: AIImagePreviewState
        let historyID: UUID
        let createdAt: Date
    }

    @ObservableState
    struct State: Equatable {
        var brushPalette = BrushPaletteFeature.State()
        var layerSidebar = LayerSidebarFeature.State()
        var canvas = CanvasFeature.State()
        var brushPanel = StudioPanelLayoutState()
        var layerPanel = StudioPanelLayoutState()
        var activeAIImageJobID: UUID?
    }

    enum EditingAction: Equatable {
        case featherSelectionRequested(Int)
        case colorRangeSelectionRequested(ColorRangeSelectionRequest)
        case toolSelected(StudioToolKind)
        case toolLongPressed(StudioToolKind)
        case clearActiveLayerButtonTapped
        case createLayerMaskFromSelectionRequested
        case clearLayerMaskRequested
        case applyLayerMaskRequested
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
        case activeLayerVisibilityToggled
        case selectPreviousLayer
        case selectNextLayer
        case panelCollapseToggled(StudioPanelKind)
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
            Scope(state: \.brushPalette, action: \.brushPalette) {
                BrushPaletteFeature()
            }

            Scope(state: \.layerSidebar, action: \.layerSidebar) {
                LayerSidebarFeature()
            }

            Scope(state: \.canvas, action: \.canvas) {
                CanvasFeature()
            }

            Scope(state: \.self, action: \.presentation) {
                PresentationRefreshReducer()
            }

            Scope(state: \.self, action: \.lifecycle) {
                DocumentLifecycleReducer()
            }

            Scope(state: \.self, action: \.canvasEditing) {
                CanvasEditingWorkflowReducer()
            }

            Scope(state: \.self, action: \.layerWorkflow) {
                LayerWorkflowReducer()
            }

            Scope(state: \.self, action: \.adjustment) {
                AdjustmentWorkflowReducer()
            }

            Scope(state: \.self, action: \.aiImageWorkflow) {
                AIImageWorkflowReducer()
            }

            Reduce { state, action in
                switch action {
                case let .brushPalette(brushPaletteAction):
                    state.refreshBrushPaletteState()
                    return .merge(
                        .send(.canvasEditing(.brushPalette(brushPaletteAction))),
                        .send(.layerWorkflow(.brushPalette(brushPaletteAction)))
                    )

                case let .layerSidebar(layerSidebarAction):
                    return .merge(
                        .send(.canvasEditing(.layerSidebar(layerSidebarAction))),
                        .send(.layerWorkflow(.layerSidebar(layerSidebarAction)))
                    )

                case let .canvas(canvasAction):
                    return .send(.canvasEditing(.canvas(canvasAction)))

                case let .presentation(.delegate(delegateAction)),
                     let .lifecycle(.delegate(delegateAction)),
                     let .canvasEditing(.delegate(delegateAction)),
                     let .layerWorkflow(.delegate(delegateAction)),
                     let .adjustment(.delegate(delegateAction)),
                     let .aiImageWorkflow(.delegate(delegateAction)):
                    return .send(.delegate(delegateAction))

                case let .canvasEditing(.lifecycle(lifecycleAction)):
                    return .send(.lifecycle(lifecycleAction))

                case .delegate:
                    return .none
                default:
                    return .none
                }
            }
        }
    }
}
