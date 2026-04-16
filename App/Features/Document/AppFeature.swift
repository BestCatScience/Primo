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

    struct ApplicationState: Equatable {
        var isHydrating = true
        var showsHome = true
        var homeSection: HomeSidebarSection = .home
        var homeProjects: [SavedProjectSummary] = []
        var isLoadingHomeProjects = true
        var bannerMessage: String?
        var appLanguage: AppLanguage = .japanese
    }

    struct WorkspaceState: Equatable {
        var openTabs: [OpenDocumentTab] = []
        var activeTabID: OpenDocumentTab.ID?
        var primarySelectedTabID: OpenDocumentTab.ID?
        var secondarySelectedTabID: OpenDocumentTab.ID?
        var focusedWorkspacePane: WorkspacePane = .primary
        var workspaceLayout: WorkspaceLayoutMode = .single
        var pendingCloseConfirmation: PendingCloseConfirmationState?
    }

    struct RecoveryState: Equatable {
        var items: [AutosaveRecoveryItem] = []
        var isPresented = false
    }

    struct SaveHistoryState: Equatable {
        var entries: [SaveHistoryEntry] = []
        var isPresented = false
    }

    struct ExportState: Equatable {
        var shareSheet: ShareExport?
        var timelapsePreview: TimelapseExportPreview?
    }

    struct NanoBananaState: Equatable {
        var isGenerating = false
        var preview: NanoBananaPreviewState?
        var jobs: [NanoBananaJob] = []
        var history: [NanoBananaHistoryItem] = []
        var pendingRequest: NanoBananaGenerationRequest?
        var activeJobID: UUID?
        var pendingOutputMode: NanoBananaOutputMode = .replaceCurrentLayer
    }

    @ObservableState
    struct State: Equatable {
        var application = ApplicationState()
        var workspace = WorkspaceState()
        var recovery = RecoveryState()
        var saveHistory = SaveHistoryState()
        var export = ExportState()
        var nanoBanana = NanoBananaState()
        var brushPalette = BrushPaletteFeature.State()
        var layerSidebar = LayerSidebarFeature.State()
        var canvas = CanvasFeature.State()
        var brushPanel = StudioPanelLayoutState()
        var layerPanel = StudioPanelLayoutState()

        var isHydrating: Bool {
            get { application.isHydrating }
            set { application.isHydrating = newValue }
        }

        var showsHome: Bool {
            get { application.showsHome }
            set { application.showsHome = newValue }
        }

        var homeSection: HomeSidebarSection {
            get { application.homeSection }
            set { application.homeSection = newValue }
        }

        var homeProjects: [SavedProjectSummary] {
            get { application.homeProjects }
            set { application.homeProjects = newValue }
        }

        var isLoadingHomeProjects: Bool {
            get { application.isLoadingHomeProjects }
            set { application.isLoadingHomeProjects = newValue }
        }

        var bannerMessage: String? {
            get { application.bannerMessage }
            set { application.bannerMessage = newValue }
        }

        var appLanguage: AppLanguage {
            get { application.appLanguage }
            set { application.appLanguage = newValue }
        }

        var openTabs: [OpenDocumentTab] {
            get { workspace.openTabs }
            set { workspace.openTabs = newValue }
        }

        var activeTabID: OpenDocumentTab.ID? {
            get { workspace.activeTabID }
            set { workspace.activeTabID = newValue }
        }

        var primarySelectedTabID: OpenDocumentTab.ID? {
            get { workspace.primarySelectedTabID }
            set { workspace.primarySelectedTabID = newValue }
        }

        var secondarySelectedTabID: OpenDocumentTab.ID? {
            get { workspace.secondarySelectedTabID }
            set { workspace.secondarySelectedTabID = newValue }
        }

        var focusedWorkspacePane: WorkspacePane {
            get { workspace.focusedWorkspacePane }
            set { workspace.focusedWorkspacePane = newValue }
        }

        var workspaceLayout: WorkspaceLayoutMode {
            get { workspace.workspaceLayout }
            set { workspace.workspaceLayout = newValue }
        }

        var pendingCloseConfirmation: PendingCloseConfirmationState? {
            get { workspace.pendingCloseConfirmation }
            set { workspace.pendingCloseConfirmation = newValue }
        }

        var autosaveRecoveryItems: [AutosaveRecoveryItem] {
            get { recovery.items }
            set { recovery.items = newValue }
        }

        var isShowingAutosaveRecovery: Bool {
            get { recovery.isPresented }
            set { recovery.isPresented = newValue }
        }

        var saveHistoryEntries: [SaveHistoryEntry] {
            get { saveHistory.entries }
            set { saveHistory.entries = newValue }
        }

        var isShowingSaveHistory: Bool {
            get { saveHistory.isPresented }
            set { saveHistory.isPresented = newValue }
        }

        var exportSheet: ShareExport? {
            get { export.shareSheet }
            set { export.shareSheet = newValue }
        }

        var timelapseExportPreview: TimelapseExportPreview? {
            get { export.timelapsePreview }
            set { export.timelapsePreview = newValue }
        }

        var isNanoBananaGenerating: Bool {
            get { nanoBanana.isGenerating }
            set { nanoBanana.isGenerating = newValue }
        }

        var nanoBananaPreview: NanoBananaPreviewState? {
            get { nanoBanana.preview }
            set { nanoBanana.preview = newValue }
        }

        var nanoBananaJobs: [NanoBananaJob] {
            get { nanoBanana.jobs }
            set { nanoBanana.jobs = newValue }
        }

        var nanoBananaHistory: [NanoBananaHistoryItem] {
            get { nanoBanana.history }
            set { nanoBanana.history = newValue }
        }

        var pendingNanoBananaRequest: NanoBananaGenerationRequest? {
            get { nanoBanana.pendingRequest }
            set { nanoBanana.pendingRequest = newValue }
        }

        var activeNanoBananaJobID: UUID? {
            get { nanoBanana.activeJobID }
            set { nanoBanana.activeJobID = newValue }
        }

        var pendingNanoBananaOutputMode: NanoBananaOutputMode {
            get { nanoBanana.pendingOutputMode }
            set { nanoBanana.pendingOutputMode = newValue }
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

            AppFeatureApplicationReducer(feature: self)
            AppFeatureWorkspaceReducer(feature: self)
            AppFeatureDocumentReducer(feature: self)
            AppFeatureEditingReducer(feature: self)
        }
    }
}
