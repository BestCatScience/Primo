import CasePaths
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoWorkspaceApplication

extension AppFeature {
    enum AppScenePhase: Equatable {
        case active
        case inactive
        case background
    }

    enum ApplicationAction: Equatable {
        case task
        case scenePhaseChanged(AppScenePhase)
        case startupLanguageLoaded(AppLanguage)
        case documentPaperStyleSyncRequested(CanvasPaperStyle)
        case workspacePersistenceRequested(WorkspacePersistenceRequest)
        case workspacePersistenceSucceeded(WorkspacePersistenceResult)
        case workspacePersistenceFailed(WorkspacePersistenceFailure)
        case workspaceCatalogRequested(WorkspaceCatalogRequest)
        case workspaceCatalogSucceeded(WorkspaceCatalogResult)
        case workspaceCatalogFailed(WorkspaceCatalogFailure)
        case bootstrapPresentationLoaded(PaintDocumentPresentation)
        case presentationLoaded(PaintDocumentPresentation)
        case loadPresentationAfterLaunch
        case homeProjectsLoadRequested
        case homeProjectsLoaded([SavedProjectSummary])
        case homeProjectsLoadFailed(String?)
        case autosaveRecoveryLoadRequested
        case autosaveRecoveryLoaded([AutosaveRecoveryItem])
        case autosaveRecoveryLoadFailed(String?)
        case autosaveRecoveryRestoreRequested(WorkspaceItemID)
        case autosaveRecoveryOpened(LoadedPaintProject, AutosaveRecoveryItem, [WorkspaceProjectLoadIssue])
        case autosaveRecoveryRestoreFailed(String?)
        case autosaveRecoveryDiscardRequested(WorkspaceItemID)
        case autosaveRecoveryDismissed
        case homeSectionSelected(HomeSidebarSection)
        case deferredPresentationRefresh
        case refreshPresentationRequested
        case exportSheetDismissed
        case bannerDismissed
        case languageChanged(AppLanguage)
    }

    enum WorkspaceAction: Equatable {
        case tabSelected(OpenDocumentTab.ID)
        case tabSelectionLoaded(OpenDocumentTab.ID, LoadedPaintProject)
        case tabSelectionFailed(String?)
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
        case openImportedDocumentRequested(URL)
        case openImportedDocumentLoaded(LoadedPaintProject, String, [WorkspaceProjectLoadIssue])
        case openDocumentSelected(DocumentProjectPath)
        case openDocumentLoaded(LoadedPaintProject, DocumentProjectPath, [WorkspaceProjectLoadIssue])
        case openDocumentFailed(String?)
    }

    enum DocumentAction: Equatable {
        case newCanvasRequested(width: Int, height: Int)
        case newCanvasPreparationCompleted(CanvasDimensions)
        case undoRequested
        case redoRequested
        case saveHistoryRequested
        case saveHistoryLoaded([SaveHistoryEntry])
        case saveHistoryLoadFailed(String?)
        case saveHistoryDismissed
        case saveHistoryRestoreRequested(DocumentProjectPath, Bool)
        case saveHistoryOpened(LoadedPaintProject, DocumentProjectPath, Bool, [WorkspaceProjectLoadIssue])
        case saveHistoryRestoreFailed(String?)
        case saveDocumentRequested
        case saveDocumentCopyRequested
        case exportDocumentRequested
        case exportTimelapseRequested
        case photoImportReceived(name: String?, data: Data)
        case photoImportFailed(String?)
        case timelapseExportProgressUpdated(TimelapseExportProgress)
        case timelapseExportSucceeded(TimelapseExportResult)
        case timelapseExportFailed(String?)
        case resizeCanvasRequested(width: Int, height: Int)
        case resizeCanvasExtentRequested(width: Int, height: Int)
        case newCanvasFromImageReceived(name: String?, data: Data)
        case newCanvasFromImagePreparationCompleted(AppFeature.ImportedCanvasPlan)
        case newCanvasFromImageFailed(String?)
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
        case application(ApplicationAction)
        case workspace(WorkspaceAction)
        case document(DocumentAction)
        case editing(EditingAction)
        case nanoBanana(NanoBananaFeature.Action)
        case brushPalette(BrushPaletteFeature.Action)
        case layerSidebar(LayerSidebarFeature.Action)
        case canvas(CanvasFeature.Action)
    }
}

extension AppFeature.Action {
    static var task: Self { .application(.task) }
    static func scenePhaseChanged(_ phase: AppFeature.AppScenePhase) -> Self { .application(.scenePhaseChanged(phase)) }
    static func startupLanguageLoaded(_ language: AppLanguage) -> Self { .application(.startupLanguageLoaded(language)) }
    static func documentPaperStyleSyncRequested(_ paperStyle: CanvasPaperStyle) -> Self { .application(.documentPaperStyleSyncRequested(paperStyle)) }
    static func workspacePersistenceRequested(_ request: AppFeature.WorkspacePersistenceRequest) -> Self { .application(.workspacePersistenceRequested(request)) }
    static func workspacePersistenceSucceeded(_ result: AppFeature.WorkspacePersistenceResult) -> Self { .application(.workspacePersistenceSucceeded(result)) }
    static func workspacePersistenceFailed(_ failure: AppFeature.WorkspacePersistenceFailure) -> Self { .application(.workspacePersistenceFailed(failure)) }
    static func workspaceCatalogRequested(_ request: AppFeature.WorkspaceCatalogRequest) -> Self { .application(.workspaceCatalogRequested(request)) }
    static func workspaceCatalogSucceeded(_ result: AppFeature.WorkspaceCatalogResult) -> Self { .application(.workspaceCatalogSucceeded(result)) }
    static func workspaceCatalogFailed(_ failure: AppFeature.WorkspaceCatalogFailure) -> Self { .application(.workspaceCatalogFailed(failure)) }
    static func bootstrapPresentationLoaded(_ presentation: PaintDocumentPresentation) -> Self { .application(.bootstrapPresentationLoaded(presentation)) }
    static func presentationLoaded(_ presentation: PaintDocumentPresentation) -> Self { .application(.presentationLoaded(presentation)) }
    static var loadPresentationAfterLaunch: Self { .application(.loadPresentationAfterLaunch) }
    static var homeProjectsLoadRequested: Self { .application(.homeProjectsLoadRequested) }
    static func homeProjectsLoaded(_ projects: [SavedProjectSummary]) -> Self { .application(.homeProjectsLoaded(projects)) }
    static func homeProjectsLoadFailed(_ message: String?) -> Self { .application(.homeProjectsLoadFailed(message)) }
    static var autosaveRecoveryLoadRequested: Self { .application(.autosaveRecoveryLoadRequested) }
    static func autosaveRecoveryLoaded(_ items: [AutosaveRecoveryItem]) -> Self { .application(.autosaveRecoveryLoaded(items)) }
    static func autosaveRecoveryLoadFailed(_ message: String?) -> Self { .application(.autosaveRecoveryLoadFailed(message)) }
    static func autosaveRecoveryRestoreRequested(_ id: WorkspaceItemID) -> Self { .application(.autosaveRecoveryRestoreRequested(id)) }
    static func autosaveRecoveryOpened(_ loaded: LoadedPaintProject, _ item: AutosaveRecoveryItem, _ issues: [WorkspaceProjectLoadIssue]) -> Self { .application(.autosaveRecoveryOpened(loaded, item, issues)) }
    static func autosaveRecoveryRestoreFailed(_ message: String?) -> Self { .application(.autosaveRecoveryRestoreFailed(message)) }
    static func autosaveRecoveryDiscardRequested(_ id: WorkspaceItemID) -> Self { .application(.autosaveRecoveryDiscardRequested(id)) }
    static var autosaveRecoveryDismissed: Self { .application(.autosaveRecoveryDismissed) }
    static func homeSectionSelected(_ section: HomeSidebarSection) -> Self { .application(.homeSectionSelected(section)) }
    static var deferredPresentationRefresh: Self { .application(.deferredPresentationRefresh) }
    static var refreshPresentationRequested: Self { .application(.refreshPresentationRequested) }
    static var exportSheetDismissed: Self { .application(.exportSheetDismissed) }
    static var bannerDismissed: Self { .application(.bannerDismissed) }
    static func languageChanged(_ language: AppLanguage) -> Self { .application(.languageChanged(language)) }

    static func tabSelected(_ id: OpenDocumentTab.ID) -> Self { .workspace(.tabSelected(id)) }
    static func tabSelectionLoaded(_ id: OpenDocumentTab.ID, _ loaded: LoadedPaintProject) -> Self { .workspace(.tabSelectionLoaded(id, loaded)) }
    static func tabSelectionFailed(_ message: String?) -> Self { .workspace(.tabSelectionFailed(message)) }
    static func tabCloseRequested(_ id: OpenDocumentTab.ID) -> Self { .workspace(.tabCloseRequested(id)) }
    static func tabClosed(_ id: OpenDocumentTab.ID) -> Self { .workspace(.tabClosed(id)) }
    static func closeOtherTabsRequested(_ id: OpenDocumentTab.ID) -> Self { .workspace(.closeOtherTabsRequested(id)) }
    static func closeOtherTabs(_ id: OpenDocumentTab.ID) -> Self { .workspace(.closeOtherTabs(id)) }
    static func closeTabsToRightRequested(_ id: OpenDocumentTab.ID) -> Self { .workspace(.closeTabsToRightRequested(id)) }
    static func closeTabsToRight(_ id: OpenDocumentTab.ID) -> Self { .workspace(.closeTabsToRight(id)) }
    static var pendingCloseSaveConfirmed: Self { .workspace(.pendingCloseSaveConfirmed) }
    static var pendingCloseDiscardConfirmed: Self { .workspace(.pendingCloseDiscardConfirmed) }
    static var pendingCloseCancelled: Self { .workspace(.pendingCloseCancelled) }
    static func moveTabToSecondaryPane(_ id: OpenDocumentTab.ID) -> Self { .workspace(.moveTabToSecondaryPane(id)) }
    static func tabReordered(moving: OpenDocumentTab.ID, before: OpenDocumentTab.ID) -> Self { .workspace(.tabReordered(moving: moving, before: before)) }
    static func tabDropped(moving: OpenDocumentTab.ID, toPane: WorkspacePane, before: OpenDocumentTab.ID?) -> Self { .workspace(.tabDropped(moving: moving, toPane: toPane, before: before)) }
    static var splitActiveTabIntoSecondaryPane: Self { .workspace(.splitActiveTabIntoSecondaryPane) }
    static var mergeWorkspacePanes: Self { .workspace(.mergeWorkspacePanes) }
    static func workspacePaneActivated(_ pane: WorkspacePane) -> Self { .workspace(.workspacePaneActivated(pane)) }
    static func homeProjectSelected(_ url: DocumentProjectPath) -> Self { .workspace(.homeProjectSelected(url)) }
    static func moveSavedProject(_ url: DocumentProjectPath, _ path: RelativeProjectFolderPath?) -> Self { .workspace(.moveSavedProject(url, path)) }
    static var homeReturnRequested: Self { .workspace(.homeReturnRequested) }
    static func openImportedDocumentRequested(_ url: URL) -> Self { .workspace(.openImportedDocumentRequested(url)) }
    static func openImportedDocumentLoaded(_ loaded: LoadedPaintProject, _ title: String, _ issues: [WorkspaceProjectLoadIssue]) -> Self { .workspace(.openImportedDocumentLoaded(loaded, title, issues)) }
    static func openDocumentSelected(_ url: DocumentProjectPath) -> Self { .workspace(.openDocumentSelected(url)) }
    static func openDocumentLoaded(_ loaded: LoadedPaintProject, _ url: DocumentProjectPath, _ issues: [WorkspaceProjectLoadIssue]) -> Self { .workspace(.openDocumentLoaded(loaded, url, issues)) }
    static func openDocumentFailed(_ message: String?) -> Self { .workspace(.openDocumentFailed(message)) }

    static func newCanvasRequested(width: Int, height: Int) -> Self { .document(.newCanvasRequested(width: width, height: height)) }
    static func newCanvasPreparationCompleted(_ dimensions: AppFeature.CanvasDimensions) -> Self { .document(.newCanvasPreparationCompleted(dimensions)) }
    static var undoRequested: Self { .document(.undoRequested) }
    static var redoRequested: Self { .document(.redoRequested) }
    static var saveHistoryRequested: Self { .document(.saveHistoryRequested) }
    static func saveHistoryLoaded(_ entries: [SaveHistoryEntry]) -> Self { .document(.saveHistoryLoaded(entries)) }
    static func saveHistoryLoadFailed(_ message: String?) -> Self { .document(.saveHistoryLoadFailed(message)) }
    static var saveHistoryDismissed: Self { .document(.saveHistoryDismissed) }
    static func saveHistoryRestoreRequested(_ url: DocumentProjectPath, _ openInNewTab: Bool) -> Self { .document(.saveHistoryRestoreRequested(url, openInNewTab)) }
    static func saveHistoryOpened(_ loaded: LoadedPaintProject, _ url: DocumentProjectPath, _ openInNewTab: Bool, _ issues: [WorkspaceProjectLoadIssue]) -> Self { .document(.saveHistoryOpened(loaded, url, openInNewTab, issues)) }
    static func saveHistoryRestoreFailed(_ message: String?) -> Self { .document(.saveHistoryRestoreFailed(message)) }
    static var saveDocumentRequested: Self { .document(.saveDocumentRequested) }
    static var saveDocumentCopyRequested: Self { .document(.saveDocumentCopyRequested) }
    static var exportDocumentRequested: Self { .document(.exportDocumentRequested) }
    static var exportTimelapseRequested: Self { .document(.exportTimelapseRequested) }
    static func photoImportReceived(name: String?, data: Data) -> Self { .document(.photoImportReceived(name: name, data: data)) }
    static func photoImportFailed(_ message: String?) -> Self { .document(.photoImportFailed(message)) }
    static func timelapseExportProgressUpdated(_ progress: TimelapseExportProgress) -> Self { .document(.timelapseExportProgressUpdated(progress)) }
    static func timelapseExportSucceeded(_ result: TimelapseExportResult) -> Self { .document(.timelapseExportSucceeded(result)) }
    static func timelapseExportFailed(_ message: String?) -> Self { .document(.timelapseExportFailed(message)) }
    static func resizeCanvasRequested(width: Int, height: Int) -> Self { .document(.resizeCanvasRequested(width: width, height: height)) }
    static func resizeCanvasExtentRequested(width: Int, height: Int) -> Self { .document(.resizeCanvasExtentRequested(width: width, height: height)) }
    static func newCanvasFromImageReceived(name: String?, data: Data) -> Self { .document(.newCanvasFromImageReceived(name: name, data: data)) }
    static func newCanvasFromImagePreparationCompleted(_ plan: AppFeature.ImportedCanvasPlan) -> Self { .document(.newCanvasFromImagePreparationCompleted(plan)) }
    static func newCanvasFromImageFailed(_ message: String?) -> Self { .document(.newCanvasFromImageFailed(message)) }

    static func featherSelectionRequested(_ radius: Int) -> Self { .editing(.featherSelectionRequested(radius)) }
    static func colorRangeSelectionRequested(_ request: ColorRangeSelectionRequest) -> Self { .editing(.colorRangeSelectionRequested(request)) }
    static func toolSelected(_ tool: StudioToolKind) -> Self { .editing(.toolSelected(tool)) }
    static func toolLongPressed(_ tool: StudioToolKind) -> Self { .editing(.toolLongPressed(tool)) }
    static var clearActiveLayerButtonTapped: Self { .editing(.clearActiveLayerButtonTapped) }
    static var createLayerMaskFromSelectionRequested: Self { .editing(.createLayerMaskFromSelectionRequested) }
    static var clearLayerMaskRequested: Self { .editing(.clearLayerMaskRequested) }
    static var applyLayerMaskRequested: Self { .editing(.applyLayerMaskRequested) }
    static func gradientMapSelected(_ preset: GradientMapPreset) -> Self { .editing(.gradientMapSelected(preset)) }
    static func gradientMapPreviewChanged(_ settings: GradientMapSettings?) -> Self { .editing(.gradientMapPreviewChanged(settings)) }
    static func gradientMapApplied(_ settings: GradientMapSettings) -> Self { .editing(.gradientMapApplied(settings)) }
    static func hueSaturationBrightnessPreviewChanged(_ settings: HueSaturationBrightnessSettings?) -> Self { .editing(.hueSaturationBrightnessPreviewChanged(settings)) }
    static func hueSaturationBrightnessApplied(_ settings: HueSaturationBrightnessSettings) -> Self { .editing(.hueSaturationBrightnessApplied(settings)) }
    static func brightnessContrastPreviewChanged(_ settings: BrightnessContrastSettings?) -> Self { .editing(.brightnessContrastPreviewChanged(settings)) }
    static func brightnessContrastApplied(_ settings: BrightnessContrastSettings) -> Self { .editing(.brightnessContrastApplied(settings)) }
    static func levelsPreviewChanged(_ settings: LevelsAdjustmentSettings?) -> Self { .editing(.levelsPreviewChanged(settings)) }
    static func levelsApplied(_ settings: LevelsAdjustmentSettings) -> Self { .editing(.levelsApplied(settings)) }
    static func toneCurvePreviewChanged(_ settings: ToneCurveSettings?) -> Self { .editing(.toneCurvePreviewChanged(settings)) }
    static func toneCurveApplied(_ settings: ToneCurveSettings) -> Self { .editing(.toneCurveApplied(settings)) }
    static func colorBalancePreviewChanged(_ settings: ColorBalanceSettings?) -> Self { .editing(.colorBalancePreviewChanged(settings)) }
    static func colorBalanceApplied(_ settings: ColorBalanceSettings) -> Self { .editing(.colorBalanceApplied(settings)) }
    static func thresholdPreviewChanged(_ settings: ThresholdSettings?) -> Self { .editing(.thresholdPreviewChanged(settings)) }
    static func thresholdApplied(_ settings: ThresholdSettings) -> Self { .editing(.thresholdApplied(settings)) }
    static func posterizePreviewChanged(_ settings: PosterizeSettings?) -> Self { .editing(.posterizePreviewChanged(settings)) }
    static func posterizeApplied(_ settings: PosterizeSettings) -> Self { .editing(.posterizeApplied(settings)) }
    static var luminanceToAlphaRequested: Self { .editing(.luminanceToAlphaRequested) }
    static var activeLayerVisibilityToggled: Self { .editing(.activeLayerVisibilityToggled) }
    static var selectPreviousLayer: Self { .editing(.selectPreviousLayer) }
    static var selectNextLayer: Self { .editing(.selectNextLayer) }
    static func panelCollapseToggled(_ panel: StudioPanelKind) -> Self { .editing(.panelCollapseToggled(panel)) }
}
