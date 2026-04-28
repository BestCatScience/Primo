import CasePaths
import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoWorkspaceApplication

@Reducer
struct DocumentFeature {
    static let canvasPresentationStateCoordinator = CanvasPresentationStateCoordinator()
    static let canvasPreviewStateCoordinator = CanvasPreviewStateCoordinator()

    @Dependency(\.appLanguageClient) var appLanguageClient
    @Dependency(\.documentCanvasCommandService) var documentCanvasCommandService
    @Dependency(\.documentPersistenceGateway) var documentPersistenceGateway
    @Dependency(\.documentGpuOperationGateway) var documentGpuOperationGateway
    @Dependency(\.documentHistoryCommandService) var documentHistoryCommandService
    @Dependency(\.documentMutationGateway) var documentMutationGateway
    @Dependency(\.documentMutationWorkflowService) var documentMutationWorkflowService
    @Dependency(\.documentQueryGateway) var documentQueryGateway
    @Dependency(\.documentStrokeSessionUseCase) var documentStrokeSessionUseCase
    @Dependency(\.layerTransformProcessor) var layerTransformProcessor
    @Dependency(\.processEnvironmentClient) var processEnvironmentClient
    @Dependency(\.selectionWorkflowService) var selectionWorkflowService
    @Dependency(\.textLayerGateway) var textLayerGateway

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

        func nanoBananaLayerName(for layerSidebar: LayerSidebarFeature.State) -> String {
            layerSidebar.numberedLayerName(prefix: "Nano Banana")
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

    struct CanvasStrokeContext {
        let activeLayer: LayerRowModel
        let activeLayerIndex: Int
        let brush: BrushRuntimeSettings
        let previewBrush: BrushRuntimeSettings
    }

    @ObservableState
    struct State: Equatable {
        var brushPalette = BrushPaletteFeature.State()
        var layerSidebar = LayerSidebarFeature.State()
        var canvas = CanvasFeature.State()
        var brushPanel = StudioPanelLayoutState()
        var layerPanel = StudioPanelLayoutState()
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
        }

        case startupPresentationBootstrapRequested
        case deferredPresentationLoadRequested
        case deferredPresentationRefreshRequested
        case presentationRefreshRequested
        case paperStyleSyncRequested(CanvasPaperStyle)
        case bootstrapPresentationLoaded(PaintDocumentPresentation)
        case presentationLoaded(PaintDocumentPresentation)
        case newCanvasRequested(width: Int, height: Int)
        case newCanvasPreparationCompleted(CanvasDimensions)
        case undoRequested
        case redoRequested
        case resizeCanvasRequested(width: Int, height: Int)
        case resizeCanvasExtentRequested(width: Int, height: Int)
        case photoImportReceived(name: String?, data: Data)
        case editing(EditingAction)
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

            Reduce { state, action in
                switch action {
                case .startupPresentationBootstrapRequested:
                    let paperStyle = Self.canvasToolStateCoordinator.resolvedPaperStyle(for: state)
                    return .merge(
                        synchronizePaperStyleEffect(paperStyle),
                        startupPresentationBootstrapEffect()
                    )

                case .deferredPresentationLoadRequested:
                    return deferredPresentationLoadEffect()

                case .deferredPresentationRefreshRequested:
                    return deferredPresentationRefreshEffect()

                case .presentationRefreshRequested:
                    let paperStyle = Self.canvasToolStateCoordinator.resolvedPaperStyle(for: state)
                    return .merge(
                        synchronizePaperStyleEffect(paperStyle),
                        deferredPresentationRefreshEffect()
                    )

                case let .paperStyleSyncRequested(paperStyle):
                    return synchronizePaperStyleEffect(paperStyle)

                case let .bootstrapPresentationLoaded(presentation):
                    return applyPresentation(presentation, to: &state)

                case let .presentationLoaded(presentation):
                    guard !state.canvas.isStrokeActive else { return .none }
                    return applyPresentation(presentation, to: &state)

                case let .resizeCanvasRequested(width, height):
                    return handleResizeCanvasRequest(state: &state, width: width, height: height)

                case let .resizeCanvasExtentRequested(width, height):
                    return handleResizeCanvasExtentRequest(state: &state, width: width, height: height)

                case .undoRequested:
                    return handleUndoRequested(state: &state)

                case .redoRequested:
                    return handleRedoRequested(state: &state)

                case let .editing(.panelCollapseToggled(panel)):
                    Self.toolPanelStateCoordinator.toggleCollapse(for: panel, in: &state)
                    return .none

                case let .editing(.toolSelected(tool)):
                    state.selectTool(tool, showsBrushSettingsPopover: false)
                    return .none

                case let .editing(.toolLongPressed(tool)):
                    state.selectTool(
                        tool,
                        showsBrushSettingsPopover: tool == .brush || tool == .erase
                    )
                    return .none

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

                case let .editing(.featherSelectionRequested(radius)):
                    handleFeatherSelection(state: &state, radius: max(radius, 1))
                    return .none

                case let .editing(.colorRangeSelectionRequested(request)):
                    return handleColorRangeSelectionRequest(state: &state, request: request)

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
                    return handleAdjustmentApplyRequest(
                        state: &state,
                        request: .gradientMap(preset),
                        failureFeedback: .gradientMapApplyFailed
                    )

                case let .editing(.gradientMapApplied(settings)):
                    return handleAdjustmentApplyRequest(
                        state: &state,
                        request: .gradientMapSettings(settings),
                        failureFeedback: .gradientMapApplyFailed
                    )

                case let .editing(.hueSaturationBrightnessApplied(settings)):
                    return handleAdjustmentApplyRequest(
                        state: &state,
                        request: .hueSaturationBrightness(settings),
                        failureFeedback: .colorAdjustmentApplyFailed
                    )

                case let .editing(.brightnessContrastApplied(settings)):
                    return handleAdjustmentApplyRequest(
                        state: &state,
                        request: .brightnessContrast(settings),
                        failureFeedback: .colorAdjustmentApplyFailed
                    )

                case let .editing(.levelsApplied(settings)):
                    return handleAdjustmentApplyRequest(
                        state: &state,
                        request: .levels(settings),
                        failureFeedback: .colorAdjustmentApplyFailed
                    )

                case let .editing(.toneCurveApplied(settings)):
                    return handleAdjustmentApplyRequest(
                        state: &state,
                        request: .toneCurve(settings),
                        failureFeedback: .colorAdjustmentApplyFailed
                    )

                case let .editing(.colorBalanceApplied(settings)):
                    return handleAdjustmentApplyRequest(
                        state: &state,
                        request: .colorBalance(settings),
                        failureFeedback: .colorAdjustmentApplyFailed
                    )

                case let .editing(.thresholdApplied(settings)):
                    return handleAdjustmentApplyRequest(
                        state: &state,
                        request: .threshold(settings),
                        failureFeedback: .colorAdjustmentApplyFailed
                    )

                case let .editing(.posterizeApplied(settings)):
                    return handleAdjustmentApplyRequest(
                        state: &state,
                        request: .posterize(settings),
                        failureFeedback: .colorAdjustmentApplyFailed
                    )

                case .editing(.luminanceToAlphaRequested):
                    return handleAdjustmentApplyRequest(
                        state: &state,
                        request: .luminanceToAlpha,
                        failureFeedback: .colorAdjustmentApplyFailed
                    )

                case .editing(.activeLayerVisibilityToggled):
                    return handleActiveLayerVisibilityToggle(state: &state)

                case .editing(.selectPreviousLayer):
                    return handleSelectAdjacentLayer(state: &state, direction: -1)

                case .editing(.selectNextLayer):
                    return handleSelectAdjacentLayer(state: &state, direction: 1)

                case let .layerSidebar(.delegate(.setOpacity(index, opacity))):
                    return handleLayerOpacityChange(state: &state, index: index, opacity: opacity)

                case let .layerSidebar(.delegate(.toggleLayerLock(index))):
                    return handleLayerLockToggle(state: &state, index: index)

                case let .layerSidebar(.delegate(.toggleAlphaLock(index))):
                    return handleLayerAlphaLockToggle(state: &state, index: index)

                case let .layerSidebar(.delegate(.toggleClippingMask(index))):
                    return handleLayerClippingToggle(state: &state, index: index)

                case let .layerSidebar(.delegate(.selectLayer(index))):
                    return handleLayerSelection(state: &state, index: index)

                case let .layerSidebar(.delegate(.toggleVisibility(index))):
                    return handleLayerVisibilityToggle(state: &state, index: index)

                case let .layerSidebar(.delegate(.setFolderExpanded(folderID, isExpanded))):
                    return handleFolderExpandedChange(state: &state, folderID: folderID, isExpanded: isExpanded)

                case let .layerSidebar(.delegate(.toggleFolderVisibility(folderID))):
                    return handleFolderVisibilityToggle(state: &state, folderID: folderID)

                case let .layerSidebar(.delegate(.renameFolder(folderID, name))):
                    return handleFolderRename(state: &state, folderID: folderID, name: name)

                case let .layerSidebar(.delegate(.setBlendMode(index, blendMode))):
                    return handleLayerBlendModeChange(state: &state, index: index, blendMode: blendMode)

                case let .layerSidebar(.delegate(.renameLayer(index, name))):
                    return handleLayerRename(state: &state, index: index, name: name)

                case .layerSidebar(.delegate(.addLayer)):
                    return handleAddLayer(state: &state)

                case .layerSidebar(.delegate(.addFolder)):
                    return handleAddFolder(state: &state)

                case let .layerSidebar(.delegate(.deleteFolder(folderID))):
                    return handleFolderDeletion(state: &state, folderID: folderID)

                case let .layerSidebar(.delegate(.deleteLayer(index))):
                    return handleLayerDeletion(state: &state, index: index)

                case let .layerSidebar(.delegate(.duplicateLayer(index))):
                    return handleLayerDuplication(state: &state, index: index)

                case let .layerSidebar(.delegate(.moveLayer(index, destinationIndex))):
                    return handleLayerMove(state: &state, index: index, destinationIndex: destinationIndex)

                case let .layerSidebar(.delegate(.moveLayerToFolder(index, folderID))):
                    return handleLayerFolderAssignment(state: &state, index: index, folderID: folderID)

                case let .layerSidebar(.delegate(.removeLayerFromFolder(index))):
                    return handleLayerFolderAssignment(state: &state, index: index, folderID: -1)

                case let .layerSidebar(.delegate(.mergeDown(index))):
                    return handleLayerMergeDown(state: &state, index: index)

                case let .photoImportReceived(name, data):
                    return handlePhotoImport(state: &state, name: name, data: data)

                case let .brushPalette(.delegate(.applyText(draft))):
                    return handleApplyText(state: &state, draft: draft)

                case .editing(.clearActiveLayerButtonTapped),
                     .brushPalette(.delegate(.clearActiveLayer)):
                    return handleClearActiveLayer(state: &state)

                case .editing(.createLayerMaskFromSelectionRequested):
                    return handleCreateLayerMask(state: &state)

                case .editing(.clearLayerMaskRequested):
                    return handleClearLayerMask(state: &state)

                case .editing(.applyLayerMaskRequested):
                    return handleApplyLayerMask(state: &state)

                case .canvas(.delegate(.requestUndo)):
                    return .send(.undoRequested)

                case .canvas(.delegate(.requestRedo)):
                    return .send(.redoRequested)

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

                case .brushPalette:
                    state.refreshBrushPaletteState()
                    return .none

                case .delegate:
                    return .none
                default:
                    return .none
                }
            }
        }
    }
}
