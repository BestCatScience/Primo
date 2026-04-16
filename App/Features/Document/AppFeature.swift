import AVFoundation
import ComposableArchitecture
import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import SwiftUI
import UIKit
import os

@Reducer
struct AppFeature {
    static let startupLogger = Logger(subsystem: "com.primo.app", category: "Startup")

    enum CancelID {
        case deferredPresentationRefresh
        case startupPresentationLoad
        case timelapseExport
        case nanoBananaEdit
    }

    @ObservableState
    struct State: Equatable {
        var isHydrating = true
        var showsHome = true
        var homeSection: HomeSidebarSection = .home
        var homeProjects: [SavedProjectSummary] = []
        var openTabs: [OpenDocumentTab] = []
        var activeTabID: OpenDocumentTab.ID?
        var primarySelectedTabID: OpenDocumentTab.ID?
        var secondarySelectedTabID: OpenDocumentTab.ID?
        var focusedWorkspacePane: WorkspacePane = .primary
        var workspaceLayout: WorkspaceLayoutMode = .single
        var isLoadingHomeProjects = true
        var brushPalette = BrushPaletteFeature.State()
        var layerSidebar = LayerSidebarFeature.State()
        var canvas = CanvasFeature.State()
        var brushPanel = StudioPanelLayoutState()
        var layerPanel = StudioPanelLayoutState()
        var exportSheet: ShareExport?
        var bannerMessage: String?
        var timelapseExportPreview: TimelapseExportPreview?
        var isNanoBananaGenerating = false
        var nanoBananaPreview: NanoBananaPreviewState?
        var nanoBananaJobs: [NanoBananaJob] = []
        var nanoBananaHistory: [NanoBananaHistoryItem] = []
        var pendingNanoBananaRequest: NanoBananaGenerationRequest?
        var activeNanoBananaJobID: UUID?
        var pendingNanoBananaOutputMode: NanoBananaOutputMode = .replaceCurrentLayer
        var appLanguage: AppLanguage = .japanese
        var pendingCloseConfirmation: PendingCloseConfirmationState?
        var autosaveRecoveryItems: [AutosaveRecoveryItem] = []
        var isShowingAutosaveRecovery = false
        var saveHistoryEntries: [SaveHistoryEntry] = []
        var isShowingSaveHistory = false

        var nanoBananaProgress: Double? {
            guard isNanoBananaGenerating else { return nil }
            return 0.6
        }

        var activeTabIndex: Int? {
            guard let activeTabID else { return nil }
            return openTabs.firstIndex(where: { $0.id == activeTabID })
        }

        var activeTab: OpenDocumentTab? {
            guard let activeTabIndex else { return nil }
            return openTabs[activeTabIndex]
        }

        func selectedTabID(for pane: WorkspacePane) -> OpenDocumentTab.ID? {
            AppFeature.stateCoordinator.selectedTabID(for: pane, in: self)
        }

        mutating func setSelectedTabID(_ tabID: OpenDocumentTab.ID?, for pane: WorkspacePane) {
            AppFeature.stateCoordinator.setSelectedTabID(tabID, for: pane, in: &self)
        }

        func tabs(in pane: WorkspacePane) -> [OpenDocumentTab] {
            AppFeature.stateCoordinator.tabs(in: pane, state: self)
        }

        func selectedTab(in pane: WorkspacePane) -> OpenDocumentTab? {
            AppFeature.stateCoordinator.selectedTab(in: pane, state: self)
        }

        func hasTabs(in pane: WorkspacePane) -> Bool {
            AppFeature.stateCoordinator.hasTabs(in: pane, state: self)
        }

        func tabID(forSourceProjectURL sourceProjectURL: DocumentProjectPath) -> OpenDocumentTab.ID? {
            AppFeature.stateCoordinator.tabID(forSourceProjectURL: sourceProjectURL, in: self)
        }

        mutating func applyPresentation(_ presentation: PaintDocumentPresentation) {
            AppFeature.uiStateCoordinator.applyPresentation(presentation, to: &self)
        }

        mutating func updateActiveTabMetadata(
            title: String? = nil,
            sourceProjectURL: DocumentProjectPath? = nil,
            previewImageData: Data? = nil
        ) {
            AppFeature.stateCoordinator.updateActiveTabMetadata(
                title: title,
                sourceProjectURL: sourceProjectURL,
                previewImageData: previewImageData,
                in: &self
            )
        }

        mutating func setActiveTabDirty(_ isDirty: Bool) {
            AppFeature.stateCoordinator.setActiveTabDirty(isDirty, in: &self)
        }

        mutating func reorderTabs(moving movingID: OpenDocumentTab.ID, before targetID: OpenDocumentTab.ID) {
            AppFeature.stateCoordinator.reorderTabs(moving: movingID, before: targetID, in: &self)
        }

        mutating func moveTab(_ movingID: OpenDocumentTab.ID, to pane: WorkspacePane, before targetID: OpenDocumentTab.ID?) {
            AppFeature.stateCoordinator.moveTab(movingID, to: pane, before: targetID, in: &self)
        }

        mutating func ensureWorkspaceSelectionIntegrity() {
            AppFeature.stateCoordinator.ensureWorkspaceSelectionIntegrity(state: &self)
        }

        mutating func applyLoadedProject(_ loaded: LoadedPaintProject) {
            AppFeature.uiStateCoordinator.applyLoadedProject(loaded, to: &self)
        }

        mutating func syncTextEditorWithActiveLayer() {
            AppFeature.uiStateCoordinator.syncTextEditorWithActiveLayer(state: &self)
        }

        mutating func applyLiveCompositePixelData(_ compositePixelData: Data) {
            AppFeature.uiStateCoordinator.applyLiveCompositePixelData(compositePixelData, to: &self)
        }

        mutating func applyLiveStrokePreview(
            baseSnapshot: MetalDocumentSnapshot,
            activeLayerIndex: Int,
            adjustedActiveLayerPixels: Data
        ) {
            AppFeature.uiStateCoordinator.applyLiveStrokePreview(
                baseSnapshot: baseSnapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerPixels: adjustedActiveLayerPixels,
                to: &self
            )
        }

        func resolvedBrushSettings() -> BrushRuntimeSettings {
            AppFeature.uiStateCoordinator.resolvedBrushSettings(for: self)
        }

        func previewStrokeStyle() -> PreviewStrokeStyle {
            AppFeature.uiStateCoordinator.previewStrokeStyle(for: self)
        }

        func resolvedPaperStyle() -> CanvasPaperStyle {
            AppFeature.uiStateCoordinator.resolvedPaperStyle(for: self)
        }

        func panelState(for panel: StudioPanelKind) -> StudioPanelLayoutState {
            AppFeature.stateCoordinator.panelState(for: panel, in: self)
        }

        mutating func setPanelState(_ panelState: StudioPanelLayoutState, for panel: StudioPanelKind) {
            AppFeature.stateCoordinator.setPanelState(panelState, for: panel, in: &self)
        }

        mutating func toggleCollapse(for panel: StudioPanelKind) {
            AppFeature.stateCoordinator.toggleCollapse(for: panel, in: &self)
        }

        mutating func syncToolSpecificBrushSize() {
            AppFeature.stateCoordinator.syncToolSpecificBrushSize(state: &self)
        }

        mutating func applyToolSpecificBrushSize(for tool: StudioToolKind) {
            AppFeature.stateCoordinator.applyToolSpecificBrushSize(for: tool, state: &self)
        }
    }

    enum Action: Equatable {
        case task
        case bootstrapPresentationLoaded(PaintDocumentPresentation)
        case presentationLoaded(PaintDocumentPresentation)
        case loadPresentationAfterLaunch
        case homeProjectsLoadRequested
        case homeProjectsLoaded([SavedProjectSummary])
        case autosaveRecoveryLoadRequested
        case autosaveRecoveryLoaded([AutosaveRecoveryItem])
        case autosaveRecoveryRestoreRequested(WorkspaceItemID)
        case autosaveRecoveryOpened(LoadedPaintProject, AutosaveRecoveryItem)
        case autosaveRecoveryDiscardRequested(WorkspaceItemID)
        case autosaveRecoveryDismissed
        case homeSectionSelected(HomeSidebarSection)
        case tabSelected(OpenDocumentTab.ID)
        case tabCloseRequested(OpenDocumentTab.ID)
        case tabClosed(OpenDocumentTab.ID)
        case closeOtherTabsRequested(OpenDocumentTab.ID)
        case closeOtherTabs(OpenDocumentTab.ID)
        case closeTabsToRightRequested(OpenDocumentTab.ID)
        case closeTabsToRight(OpenDocumentTab.ID)
        case pendingCloseSaveConfirmed
        case pendingCloseDiscardConfirmed
        case pendingCloseCancelled
        case moveTabToSecondaryPane(OpenDocumentTab.ID)
        case tabReordered(moving: OpenDocumentTab.ID, before: OpenDocumentTab.ID)
        case tabDropped(moving: OpenDocumentTab.ID, toPane: WorkspacePane, before: OpenDocumentTab.ID?)
        case splitActiveTabIntoSecondaryPane
        case mergeWorkspacePanes
        case workspacePaneActivated(WorkspacePane)
        case homeProjectSelected(DocumentProjectPath)
        case moveSavedProject(DocumentProjectPath, RelativeProjectFolderPath?)
        case homeReturnRequested
        case deferredPresentationRefresh
        case refreshPresentationRequested
        case newCanvasRequested(width: Int, height: Int)
        case undoRequested
        case redoRequested
        case saveHistoryRequested
        case saveHistoryLoaded([SaveHistoryEntry])
        case saveHistoryDismissed
        case saveHistoryRestoreRequested(DocumentProjectPath, Bool)
        case saveHistoryOpened(LoadedPaintProject, DocumentProjectPath, Bool)
        case featherSelectionRequested(Int)
        case colorRangeSelectionRequested(ColorRangeSelectionRequest)
        case saveDocumentRequested
        case saveDocumentCopyRequested
        case exportDocumentRequested
        case exportTimelapseRequested
        case nanoBananaEditRequested(NanoBananaGenerationRequest)
        case nanoBananaEditSucceeded(NanoBananaPreviewState)
        case nanoBananaEditFailed(String)
        case nanoBananaCancelRequested
        case nanoBananaPreviewAccepted
        case nanoBananaPreviewDiscarded
        case nanoBananaRegenerateRequested
        case nanoBananaRetryJob(UUID)
        case openDocumentSelected(DocumentProjectPath)
        case openDocumentLoaded(LoadedPaintProject, DocumentProjectPath)
        case openDocumentFailed(String)
        case photoImportReceived(name: String?, data: Data)
        case photoImportFailed(String)
        case timelapseExportProgressUpdated(Double, Data?)
        case timelapseExportSucceeded(URL)
        case timelapseExportFailed(String)
        case exportSheetDismissed
        case bannerDismissed
        case languageChanged(AppLanguage)
        case toolSelected(StudioToolKind)
        case toolLongPressed(StudioToolKind)
        case resizeCanvasRequested(width: Int, height: Int)
        case resizeCanvasExtentRequested(width: Int, height: Int)
        case newCanvasFromImageReceived(name: String?, data: Data)
        case newCanvasFromImageFailed(String)
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
        case brushPalette(BrushPaletteFeature.Action)
        case layerSidebar(LayerSidebarFeature.Action)
        case canvas(CanvasFeature.Action)
    }

    @Dependency(\.paintDocumentClient) var paintDocumentClient
    @Dependency(\.nanoBananaClient) var nanoBananaClient
    @Dependency(\.documentWorkspaceClient) var documentWorkspaceClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.dateClient) var dateClient
    @Dependency(\.uuidClient) var uuidClient
    @Dependency(\.appLanguageClient) var appLanguageClient

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

            Reduce { (state: inout State, action: Action) -> Effect<Action> in
                switch action {
            case .task:
                return handleTask(state: &state)

            case let .bootstrapPresentationLoaded(presentation):
                state.applyPresentation(presentation)
                state.isHydrating = false
                Self.startupLogger.debug("Bootstrap presentation applied; initial UI is ready")
                return .none

            case .loadPresentationAfterLaunch:
                return handleLoadPresentationAfterLaunch()

            case .homeProjectsLoadRequested:
                return handleHomeProjectsLoadRequest(state: &state)

            case let .homeProjectsLoaded(projects):
                handleHomeProjectsLoaded(state: &state, projects: projects)
                return .none

            case .autosaveRecoveryLoadRequested:
                return handleAutosaveRecoveryLoadRequest()

            case let .autosaveRecoveryLoaded(items):
                state.autosaveRecoveryItems = items
                state.isShowingAutosaveRecovery = !items.isEmpty
                return .none

            case let .autosaveRecoveryRestoreRequested(autosaveID):
                return handleAutosaveRecoveryRestoreRequest(state: &state, autosaveID: autosaveID)

            case let .autosaveRecoveryOpened(loaded, item):
                handleAutosaveRecoveryOpened(state: &state, loaded: loaded, item: item)
                return .none

            case let .autosaveRecoveryDiscardRequested(autosaveID):
                handleAutosaveRecoveryDiscardRequest(state: &state, autosaveID: autosaveID)
                return .none

            case .autosaveRecoveryDismissed:
                state.isShowingAutosaveRecovery = false
                return .none

            case let .homeSectionSelected(section):
                state.homeSection = section
                return .none

            case let .tabSelected(tabID):
                handleTabSelection(state: &state, tabID: tabID)
                return .none

            case let .tabCloseRequested(tabID):
                return requestCloseOperation(state: &state, operation: .tab(tabID))

            case let .closeOtherTabsRequested(tabID):
                return requestCloseOperation(state: &state, operation: .closeOtherTabs(tabID))

            case let .closeTabsToRightRequested(tabID):
                return requestCloseOperation(state: &state, operation: .closeTabsToRight(tabID))

            case .pendingCloseSaveConfirmed:
                guard let confirmation = state.pendingCloseConfirmation else { return .none }
                do {
                    try saveTabsForClose(confirmation.tabIDs, state: &state)
                    state.pendingCloseConfirmation = nil
                    return performCloseOperation(state: &state, operation: confirmation.operation)
                } catch {
                    state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Save failed") : error.localizedDescription
                    state.pendingCloseConfirmation = nil
                    return .none
                }

            case .pendingCloseDiscardConfirmed:
                guard let confirmation = state.pendingCloseConfirmation else { return .none }
                state.pendingCloseConfirmation = nil
                return performCloseOperation(state: &state, operation: confirmation.operation)

            case .pendingCloseCancelled:
                state.pendingCloseConfirmation = nil
                return .none

            case let .tabClosed(tabID):
                handleTabClosed(state: &state, tabID: tabID)
                return .none

            case let .closeOtherTabs(tabID):
                return handleCloseOtherTabs(state: &state, retaining: tabID)

            case let .closeTabsToRight(tabID):
                handleCloseTabsToRight(state: &state, tabID: tabID)
                return .none

            case let .moveTabToSecondaryPane(tabID):
                state.workspaceLayout = .split
                state.moveTab(tabID, to: .secondary, before: nil)
                state.ensureWorkspaceSelectionIntegrity()
                return .none

            case let .tabReordered(movingID, targetID):
                state.reorderTabs(moving: movingID, before: targetID)
                return .none

            case let .tabDropped(movingID, pane, targetID):
                state.moveTab(movingID, to: pane, before: targetID)
                return .none

            case .splitActiveTabIntoSecondaryPane:
                state.workspaceLayout = .split
                state.ensureWorkspaceSelectionIntegrity()
                return .none

            case .mergeWorkspacePanes:
                let secondaryTabs = state.tabs(in: .secondary).map(\.id)
                for tabID in secondaryTabs {
                    state.moveTab(tabID, to: .primary, before: nil)
                }
                state.workspaceLayout = .single
                state.secondarySelectedTabID = nil
                state.focusedWorkspacePane = .primary
                state.ensureWorkspaceSelectionIntegrity()
                return .none

            case let .workspacePaneActivated(pane):
                state.focusedWorkspacePane = pane
                guard let tabID = state.selectedTabID(for: pane) else { return .none }
                if state.activeTabID == tabID {
                    return .none
                }
                return .send(.tabSelected(tabID))

            case let .moveSavedProject(url, relativeFolderPath):
                return handleSavedProjectMove(
                    state: &state,
                    url: url,
                    relativeFolderPath: relativeFolderPath
                )

            case .homeReturnRequested:
                return handleHomeReturnRequest(state: &state)

            case let .presentationLoaded(presentation):
                guard !state.canvas.isStrokeActive else {
                    return .none
                }
                state.applyPresentation(presentation)
                Self.startupLogger.debug("Full presentation applied")
                return .none

            case .deferredPresentationRefresh:
                return handleDeferredPresentationRefresh()

            case .refreshPresentationRequested:
                handleRefreshPresentationRequest(state: &state)
                return .none

            case let .languageChanged(language):
                handleLanguageChanged(state: &state, language: language)
                return .none

            case let .newCanvasRequested(width, height):
                return handleNewCanvasRequest(state: &state, width: width, height: height)

            case let .resizeCanvasRequested(width, height):
                handleResizeCanvasRequest(state: &state, width: width, height: height)
                return .none

            case let .resizeCanvasExtentRequested(width, height):
                handleResizeCanvasExtentRequest(state: &state, width: width, height: height)
                return .none

            case let .newCanvasFromImageReceived(name, data):
                return handleNewCanvasFromImageReceived(state: &state, name: name, data: data)

            case let .newCanvasFromImageFailed(message):
                state.bannerMessage = message.isEmpty ? state.appLanguage.localized("Could not create canvas from image") : message
                return .none

            case .undoRequested:
                handleUndoRequested(state: &state)
                return .none

            case .redoRequested:
                handleRedoRequested(state: &state)
                return .none

            case .saveHistoryRequested:
                return handleSaveHistoryRequest(state: &state)

            case let .saveHistoryLoaded(entries):
                state.saveHistoryEntries = entries
                state.isShowingSaveHistory = true
                return .none

            case .saveHistoryDismissed:
                state.isShowingSaveHistory = false
                return .none

            case let .saveHistoryRestoreRequested(projectURL, openInNewTab):
                return handleSaveHistoryRestoreRequest(
                    state: &state,
                    projectURL: projectURL,
                    openInNewTab: openInNewTab
                )

            case let .saveHistoryOpened(loaded, projectURL, openInNewTab):
                handleSaveHistoryOpened(
                    state: &state,
                    loaded: loaded,
                    projectURL: projectURL,
                    openInNewTab: openInNewTab
                )
                return .none

            case let .gradientMapSelected(preset):
                _ = handleAdjustmentApplyRequest(
                    state: &state,
                    request: .gradientMap(preset),
                    failureMessage: state.appLanguage.localized("Could not apply gradient map")
                )
                return .none

            case let .gradientMapPreviewChanged(settings):
                let adjusted = settings.flatMap { settings in
                    state.canvas.renderSnapshot
                        .flatMap { $0.layers.first(where: { $0.index == state.canvas.activeLayerIndex }) }
                        .flatMap { Self.gradientMappedLayerPixels(source: $0.pixelData, settings: settings) }
                }
                handleAdjustmentPreview(
                    state: &state,
                    adjustedPixels: adjusted
                )
                return .none

            case let .gradientMapApplied(settings):
                let adjusted = state.canvas.renderSnapshot
                    .flatMap { snapshot in
                        snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex })
                            .flatMap { Self.gradientMappedLayerPixels(source: $0.pixelData, settings: settings) }
                    }
                _ = handleAdjustmentApplyUsingPixels(
                    state: &state,
                    adjustedPixels: adjusted,
                    failureMessage: state.appLanguage.localized("Could not apply gradient map")
                )
                return .none

            case let .hueSaturationBrightnessPreviewChanged(settings):
                let adjusted = settings.flatMap { settings in
                    state.canvas.renderSnapshot
                        .flatMap { $0.layers.first(where: { $0.index == state.canvas.activeLayerIndex }) }
                        .flatMap { Self.hueSaturationBrightnessAdjustedLayerPixels(source: $0.pixelData, settings: settings) }
                }
                handleAdjustmentPreview(state: &state, adjustedPixels: adjusted)
                return .none

            case let .hueSaturationBrightnessApplied(settings):
                _ = handleAdjustmentApplyRequest(
                    state: &state,
                    request: .hueSaturationBrightness(settings),
                    failureMessage: state.appLanguage.localized("Could not apply color adjustment")
                )
                return .none

            case let .brightnessContrastPreviewChanged(settings):
                let adjusted = settings.flatMap { settings in
                    state.canvas.renderSnapshot
                        .flatMap { $0.layers.first(where: { $0.index == state.canvas.activeLayerIndex }) }
                        .flatMap { Self.brightnessContrastAdjustedLayerPixels(source: $0.pixelData, settings: settings) }
                }
                handleAdjustmentPreview(state: &state, adjustedPixels: adjusted)
                return .none

            case let .brightnessContrastApplied(settings):
                _ = handleAdjustmentApplyRequest(
                    state: &state,
                    request: .brightnessContrast(settings),
                    failureMessage: state.appLanguage.localized("Could not apply color adjustment")
                )
                return .none

            case let .levelsPreviewChanged(settings):
                let adjusted = settings.flatMap { settings in
                    state.canvas.renderSnapshot
                        .flatMap { $0.layers.first(where: { $0.index == state.canvas.activeLayerIndex }) }
                        .flatMap { Self.levelsAdjustedLayerPixels(source: $0.pixelData, settings: settings) }
                }
                handleAdjustmentPreview(state: &state, adjustedPixels: adjusted)
                return .none

            case let .levelsApplied(settings):
                _ = handleAdjustmentApplyRequest(
                    state: &state,
                    request: .levels(settings),
                    failureMessage: state.appLanguage.localized("Could not apply color adjustment")
                )
                return .none

            case let .toneCurvePreviewChanged(settings):
                let adjusted = settings.flatMap { settings in
                    state.canvas.renderSnapshot
                        .flatMap { $0.layers.first(where: { $0.index == state.canvas.activeLayerIndex }) }
                        .flatMap { Self.toneCurveAdjustedLayerPixels(source: $0.pixelData, settings: settings) }
                }
                handleAdjustmentPreview(state: &state, adjustedPixels: adjusted)
                return .none

            case let .toneCurveApplied(settings):
                _ = handleAdjustmentApplyRequest(
                    state: &state,
                    request: .toneCurve(settings),
                    failureMessage: state.appLanguage.localized("Could not apply color adjustment")
                )
                return .none

            case let .colorBalancePreviewChanged(settings):
                let adjusted = settings.flatMap { settings in
                    state.canvas.renderSnapshot
                        .flatMap { $0.layers.first(where: { $0.index == state.canvas.activeLayerIndex }) }
                        .flatMap { Self.colorBalanceAdjustedLayerPixels(source: $0.pixelData, settings: settings) }
                }
                handleAdjustmentPreview(state: &state, adjustedPixels: adjusted)
                return .none

            case let .colorBalanceApplied(settings):
                _ = handleAdjustmentApplyRequest(
                    state: &state,
                    request: .colorBalance(settings),
                    failureMessage: state.appLanguage.localized("Could not apply color adjustment")
                )
                return .none

            case let .thresholdPreviewChanged(settings):
                let adjusted = settings.flatMap { settings in
                    state.canvas.renderSnapshot
                        .flatMap { $0.layers.first(where: { $0.index == state.canvas.activeLayerIndex }) }
                        .flatMap { Self.thresholdAdjustedLayerPixels(source: $0.pixelData, settings: settings) }
                }
                handleAdjustmentPreview(state: &state, adjustedPixels: adjusted)
                return .none

            case let .thresholdApplied(settings):
                _ = handleAdjustmentApplyRequest(
                    state: &state,
                    request: .threshold(settings),
                    failureMessage: state.appLanguage.localized("Could not apply color adjustment")
                )
                return .none

            case let .posterizePreviewChanged(settings):
                let adjusted = settings.flatMap { settings in
                    state.canvas.renderSnapshot
                        .flatMap { $0.layers.first(where: { $0.index == state.canvas.activeLayerIndex }) }
                        .flatMap { Self.posterizedLayerPixels(source: $0.pixelData, settings: settings) }
                }
                handleAdjustmentPreview(state: &state, adjustedPixels: adjusted)
                return .none

            case let .posterizeApplied(settings):
                _ = handleAdjustmentApplyRequest(
                    state: &state,
                    request: .posterize(settings),
                    failureMessage: state.appLanguage.localized("Could not apply color adjustment")
                )
                return .none

            case .luminanceToAlphaRequested:
                let adjusted = state.canvas.renderSnapshot
                    .flatMap { $0.layers.first(where: { $0.index == state.canvas.activeLayerIndex }) }
                    .flatMap { Self.luminanceToAlphaLayerPixels(source: $0.pixelData) }
                _ = handleAdjustmentApplyUsingPixels(
                    state: &state,
                    adjustedPixels: adjusted,
                    failureMessage: state.appLanguage.localized("Could not apply color adjustment")
                )
                return .none

            case .exportDocumentRequested:
                handleExportDocumentRequest(state: &state)
                return .none

            case .saveDocumentRequested:
                return handleSaveDocumentRequest(
                    state: &state,
                    preferredDestinationURL: state.activeTab?.sourceProjectURL
                )

            case .saveDocumentCopyRequested:
                return handleSaveDocumentRequest(
                    state: &state,
                    preferredDestinationURL: nil
                )

            case .exportTimelapseRequested:
                return handleTimelapseExportRequest(state: &state)

            case let .nanoBananaEditRequested(request):
                return handleNanoBananaEditRequest(state: &state, request: request)

            case let .nanoBananaEditSucceeded(preview):
                handleNanoBananaEditSucceeded(state: &state, preview: preview)
                return .none

            case let .nanoBananaEditFailed(message):
                handleNanoBananaEditFailed(state: &state, message: message)
                return .none

            case .nanoBananaCancelRequested:
                return handleNanoBananaCancelRequested(state: &state)

            case .nanoBananaPreviewAccepted:
                handleNanoBananaPreviewAccepted(state: &state)
                return .none

            case .nanoBananaPreviewDiscarded:
                state.nanoBananaPreview = nil
                state.activeNanoBananaJobID = nil
                return .none

            case .nanoBananaRegenerateRequested:
                guard let request = state.nanoBananaPreview?.request ?? state.pendingNanoBananaRequest else { return .none }
                state.nanoBananaPreview = nil
                return .send(.nanoBananaEditRequested(request))

            case let .nanoBananaRetryJob(jobID):
                guard let job = state.nanoBananaJobs.first(where: { $0.id == jobID }) else { return .none }
                return .send(.nanoBananaEditRequested(job.request))

            case let .timelapseExportProgressUpdated(progress, previewData):
                state.timelapseExportPreview = TimelapseExportPreview(progress: progress, previewImageData: previewData ?? state.timelapseExportPreview?.previewImageData)
                return .none

            case let .timelapseExportSucceeded(url):
                state.timelapseExportPreview = nil
                state.exportSheet = makeShareExport(url: url)
                return .none

            case let .timelapseExportFailed(message):
                state.timelapseExportPreview = nil
                state.bannerMessage = message
                return .none

            case .exportSheetDismissed:
                state.exportSheet = nil
                return .none

            case .bannerDismissed:
                state.bannerMessage = nil
                return .none

            case let .openDocumentSelected(url):
                return handleOpenDocumentSelection(
                    state: &state,
                    url: url,
                    removesStagedWorkspaceItem: true
                )

            case let .homeProjectSelected(url):
                return handleOpenDocumentSelection(
                    state: &state,
                    url: url,
                    removesStagedWorkspaceItem: false
                )

            case let .openDocumentLoaded(loaded, sourceURL):
                return handleOpenDocumentLoaded(
                    state: &state,
                    loaded: loaded,
                    sourceURL: sourceURL
                )

            case let .openDocumentFailed(message):
                state.isHydrating = false
                state.bannerMessage = message.isEmpty ? StudioStrings.openFailed(state.appLanguage) : message
                return .none

            case let .photoImportReceived(name, data):
                handlePhotoImport(state: &state, name: name, data: data)
                return .none

            case let .photoImportFailed(message):
                state.bannerMessage = message.isEmpty ? state.appLanguage.localized("Could not import photo") : message
                return .none

            case let .toolSelected(tool):
                handleToolSelection(
                    state: &state,
                    tool: tool,
                    showsBrushSettingsPopover: false
                )
                return .none

            case let .toolLongPressed(tool):
                handleToolSelection(
                    state: &state,
                    tool: tool,
                    showsBrushSettingsPopover: tool == .brush || tool == .erase
                )
                return .none

            case let .panelCollapseToggled(panel):
                state.toggleCollapse(for: panel)
                return .none

            case .brushPalette(.delegate(.clearSelection)):
                handleClearSelection(state: &state)
                return .none

            case .brushPalette(.delegate(.invertSelection)):
                handleInvertSelection(state: &state)
                return .none

            case let .brushPalette(.delegate(.expandSelection(expansion))):
                handleAdjustSelection(state: &state, expansion: max(expansion, 1))
                return .none

            case let .brushPalette(.delegate(.contractSelection(contraction))):
                handleAdjustSelection(state: &state, expansion: -max(contraction, 1))
                return .none

            case let .featherSelectionRequested(radius):
                handleFeatherSelection(state: &state, radius: max(radius, 1))
                return .none

            case let .colorRangeSelectionRequested(request):
                return handleColorRangeSelectionRequest(state: &state, request: request)

            case .brushPalette(.delegate(.cancelTransform)):
                state.canvas.resetTransformPreview()
                return .none

            case .brushPalette(.delegate(.applyTransform)):
                return applyTransform(state: &state)

            case let .brushPalette(.delegate(.applyText(draft))):
                handleApplyText(state: &state, draft: draft)
                return .none

            case .canvas(.delegate(.applyTransform)):
                return .none

            case let .canvas(.delegate(.placeText(point))):
                handlePlaceText(state: &state, point: point)
                return .none

            case .clearActiveLayerButtonTapped, .brushPalette(.delegate(.clearActiveLayer)):
                handleClearActiveLayer(state: &state)
                return .none

            case .createLayerMaskFromSelectionRequested:
                handleCreateLayerMask(state: &state)
                return .none

            case .clearLayerMaskRequested:
                handleClearLayerMask(state: &state)
                return .none

            case .applyLayerMaskRequested:
                handleApplyLayerMask(state: &state)
                return .none

            case .activeLayerVisibilityToggled:
                handleActiveLayerVisibilityToggle(state: &state)
                return .none

            case .selectPreviousLayer:
                handleSelectAdjacentLayer(state: &state, direction: -1)
                return .none

            case .selectNextLayer:
                handleSelectAdjacentLayer(state: &state, direction: 1)
                return .none

            case .brushPalette:
                handleBrushPaletteStateRefresh(state: &state)
                return .none

            case .layerSidebar(.binding(\.paperColor)):
                handlePaperColorBindingChanged(state: &state)
                return .none

            case .layerSidebar(.binding(\.transparentPaper)):
                handleTransparentPaperBindingChanged(state: &state)
                return .none

            case .layerSidebar(.delegate(.addLayer)):
                handleAddLayer(state: &state)
                return .none

            case .layerSidebar(.delegate(.addFolder)):
                handleAddFolder(state: &state)
                return .none

            case let .layerSidebar(.delegate(.deleteFolder(folderID))):
                handleFolderDeletion(state: &state, folderID: folderID)
                return .none

            case let .layerSidebar(.delegate(.deleteLayer(index))):
                handleLayerDeletion(state: &state, index: index)
                return .none

            case let .layerSidebar(.delegate(.duplicateLayer(index))):
                handleLayerDuplication(state: &state, index: index)
                return .none

            case let .layerSidebar(.delegate(.moveLayer(index, destinationIndex))):
                handleLayerMove(state: &state, index: index, destinationIndex: destinationIndex)
                return .none

            case let .layerSidebar(.delegate(.moveLayerToFolder(index, folderID))):
                handleLayerFolderAssignment(state: &state, index: index, folderID: folderID)
                return .none

            case let .layerSidebar(.delegate(.removeLayerFromFolder(index))):
                handleLayerFolderAssignment(state: &state, index: index, folderID: -1)
                return .none

            case let .layerSidebar(.delegate(.setOpacity(index, opacity))):
                handleLayerOpacityChange(state: &state, index: index, opacity: opacity)
                return .none

            case let .layerSidebar(.delegate(.toggleLayerLock(index))):
                handleLayerLockToggle(state: &state, index: index)
                return .none

            case let .layerSidebar(.delegate(.toggleAlphaLock(index))):
                handleLayerAlphaLockToggle(state: &state, index: index)
                return .none

            case let .layerSidebar(.delegate(.toggleClippingMask(index))):
                handleLayerClippingToggle(state: &state, index: index)
                return .none

            case let .layerSidebar(.delegate(.mergeDown(index))):
                handleLayerMergeDown(state: &state, index: index)
                return .none

            case let .layerSidebar(.delegate(.selectLayer(index))):
                handleLayerSelection(state: &state, index: index)
                return .none

            case let .layerSidebar(.delegate(.toggleVisibility(index))):
                handleLayerVisibilityToggle(state: &state, index: index)
                return .none

            case let .layerSidebar(.delegate(.setFolderExpanded(folderID, isExpanded))):
                handleFolderExpandedChange(state: &state, folderID: folderID, isExpanded: isExpanded)
                return .none

            case let .layerSidebar(.delegate(.toggleFolderVisibility(folderID))):
                handleFolderVisibilityToggle(state: &state, folderID: folderID)
                return .none

            case let .layerSidebar(.delegate(.renameFolder(folderID, name))):
                handleFolderRename(state: &state, folderID: folderID, name: name)
                return .none

            case let .layerSidebar(.delegate(.setBlendMode(index, blendMode))):
                handleLayerBlendModeChange(state: &state, index: index, blendMode: blendMode)
                return .none

            case let .layerSidebar(.delegate(.renameLayer(index, name))):
                handleLayerRename(state: &state, index: index, name: name)
                return .none

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

                case .layerSidebar, .canvas:
                    return .none
                }
            }
        }
    }
}
