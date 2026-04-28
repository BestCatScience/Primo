import CasePaths
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoWorkspaceApplication

extension PrimoRootFeature {
    @CasePathable
    enum Action: Equatable {
        case application(ApplicationFeature.Action)
        case workspace(WorkspaceFeature.Action)
        case document(DocumentFeature.Action)
        case importExport(ImportExportFeature.Action)
        case nanoBanana(NanoBananaFeature.Action)
    }
}

extension PrimoRootFeature.Action {
    static var task: Self { .application(.task) }
    static func scenePhaseChanged(_ phase: ApplicationFeature.ScenePhase) -> Self { .application(.scenePhaseChanged(phase)) }
    static func startupLanguageLoaded(_ language: AppLanguage) -> Self { .application(.startupLanguageLoaded(language)) }
    static func documentPaperStyleSyncRequested(_ paperStyle: CanvasPaperStyle) -> Self { .application(.documentPaperStyleSyncRequested(paperStyle)) }
    static func workspacePersistenceRequested(_ request: PrimoRootFeature.WorkspacePersistenceRequest) -> Self { .workspace(.persistenceRequested(request)) }
    static func workspacePersistenceSucceeded(_ result: PrimoRootFeature.WorkspacePersistenceResult) -> Self { .workspace(.persistenceSucceeded(result)) }
    static func workspacePersistenceFailed(_ failure: PrimoRootFeature.WorkspacePersistenceFailure) -> Self { .workspace(.persistenceFailed(failure)) }
    static func workspaceCatalogRequested(_ request: PrimoRootFeature.WorkspaceCatalogRequest) -> Self { .workspace(.catalogRequested(request)) }
    static func workspaceCatalogSucceeded(_ result: PrimoRootFeature.WorkspaceCatalogResult) -> Self { .workspace(.catalogSucceeded(result)) }
    static func workspaceCatalogFailed(_ failure: PrimoRootFeature.WorkspaceCatalogFailure) -> Self { .workspace(.catalogFailed(failure)) }
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
    static var exportSheetDismissed: Self { .importExport(.exportSheetDismissed) }
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
    static func newCanvasPreparationCompleted(_ dimensions: DocumentFeature.CanvasDimensions) -> Self { .document(.newCanvasPreparationCompleted(dimensions)) }
    static var undoRequested: Self { .document(.undoRequested) }
    static var redoRequested: Self { .document(.redoRequested) }
    static var saveHistoryRequested: Self { .importExport(.saveHistoryRequested) }
    static func saveHistoryLoaded(_ entries: [SaveHistoryEntry]) -> Self { .importExport(.saveHistoryLoaded(entries)) }
    static func saveHistoryLoadFailed(_ message: String?) -> Self { .importExport(.saveHistoryLoadFailed(message)) }
    static var saveHistoryDismissed: Self { .importExport(.saveHistoryDismissed) }
    static func saveHistoryRestoreRequested(_ url: DocumentProjectPath, _ openInNewTab: Bool) -> Self { .importExport(.saveHistoryRestoreRequested(url, openInNewTab)) }
    static func saveHistoryOpened(_ loaded: LoadedPaintProject, _ url: DocumentProjectPath, _ openInNewTab: Bool, _ issues: [WorkspaceProjectLoadIssue]) -> Self { .importExport(.saveHistoryOpened(loaded, url, openInNewTab, issues)) }
    static func saveHistoryRestoreFailed(_ message: String?) -> Self { .importExport(.saveHistoryRestoreFailed(message)) }
    static var saveDocumentRequested: Self { .importExport(.saveDocumentRequested) }
    static var saveDocumentCopyRequested: Self { .importExport(.saveDocumentCopyRequested) }
    static var exportDocumentRequested: Self { .importExport(.exportDocumentRequested) }
    static var exportTimelapseRequested: Self { .importExport(.exportTimelapseRequested) }
    static func photoImportReceived(name: String?, data: Data) -> Self { .importExport(.photoImportReceived(name: name, data: data)) }
    static func photoImportFailed(_ message: String?) -> Self { .importExport(.photoImportFailed(message)) }
    static func timelapseExportProgressUpdated(_ progress: TimelapseExportProgress) -> Self { .importExport(.timelapseExportProgressUpdated(progress)) }
    static func timelapseExportSucceeded(_ result: TimelapseExportResult) -> Self { .importExport(.timelapseExportSucceeded(result)) }
    static func timelapseExportFailed(_ message: String?) -> Self { .importExport(.timelapseExportFailed(message)) }
    static func resizeCanvasRequested(width: Int, height: Int) -> Self { .document(.resizeCanvasRequested(width: width, height: height)) }
    static func resizeCanvasExtentRequested(width: Int, height: Int) -> Self { .document(.resizeCanvasExtentRequested(width: width, height: height)) }
    static func newCanvasFromImageReceived(name: String?, data: Data) -> Self { .importExport(.newCanvasFromImageReceived(name: name, data: data)) }
    static func newCanvasFromImagePreparationCompleted(_ plan: ImportExportFeature.ImportedCanvasPlan) -> Self { .importExport(.newCanvasFromImagePreparationCompleted(plan)) }
    static func newCanvasFromImageFailed(_ message: String?) -> Self { .importExport(.newCanvasFromImageFailed(message)) }

    static func featherSelectionRequested(_ radius: Int) -> Self { .document(.editing(.featherSelectionRequested(radius))) }
    static func colorRangeSelectionRequested(_ request: ColorRangeSelectionRequest) -> Self { .document(.editing(.colorRangeSelectionRequested(request))) }
    static func toolSelected(_ tool: StudioToolKind) -> Self { .document(.editing(.toolSelected(tool))) }
    static func toolLongPressed(_ tool: StudioToolKind) -> Self { .document(.editing(.toolLongPressed(tool))) }
    static var clearActiveLayerButtonTapped: Self { .document(.editing(.clearActiveLayerButtonTapped)) }
    static var createLayerMaskFromSelectionRequested: Self { .document(.editing(.createLayerMaskFromSelectionRequested)) }
    static var clearLayerMaskRequested: Self { .document(.editing(.clearLayerMaskRequested)) }
    static var applyLayerMaskRequested: Self { .document(.editing(.applyLayerMaskRequested)) }
    static func gradientMapSelected(_ preset: GradientMapPreset) -> Self { .document(.editing(.gradientMapSelected(preset))) }
    static func gradientMapPreviewChanged(_ settings: GradientMapSettings?) -> Self { .document(.editing(.gradientMapPreviewChanged(settings))) }
    static func gradientMapApplied(_ settings: GradientMapSettings) -> Self { .document(.editing(.gradientMapApplied(settings))) }
    static func hueSaturationBrightnessPreviewChanged(_ settings: HueSaturationBrightnessSettings?) -> Self { .document(.editing(.hueSaturationBrightnessPreviewChanged(settings))) }
    static func hueSaturationBrightnessApplied(_ settings: HueSaturationBrightnessSettings) -> Self { .document(.editing(.hueSaturationBrightnessApplied(settings))) }
    static func brightnessContrastPreviewChanged(_ settings: BrightnessContrastSettings?) -> Self { .document(.editing(.brightnessContrastPreviewChanged(settings))) }
    static func brightnessContrastApplied(_ settings: BrightnessContrastSettings) -> Self { .document(.editing(.brightnessContrastApplied(settings))) }
    static func levelsPreviewChanged(_ settings: LevelsAdjustmentSettings?) -> Self { .document(.editing(.levelsPreviewChanged(settings))) }
    static func levelsApplied(_ settings: LevelsAdjustmentSettings) -> Self { .document(.editing(.levelsApplied(settings))) }
    static func toneCurvePreviewChanged(_ settings: ToneCurveSettings?) -> Self { .document(.editing(.toneCurvePreviewChanged(settings))) }
    static func toneCurveApplied(_ settings: ToneCurveSettings) -> Self { .document(.editing(.toneCurveApplied(settings))) }
    static func colorBalancePreviewChanged(_ settings: ColorBalanceSettings?) -> Self { .document(.editing(.colorBalancePreviewChanged(settings))) }
    static func colorBalanceApplied(_ settings: ColorBalanceSettings) -> Self { .document(.editing(.colorBalanceApplied(settings))) }
    static func thresholdPreviewChanged(_ settings: ThresholdSettings?) -> Self { .document(.editing(.thresholdPreviewChanged(settings))) }
    static func thresholdApplied(_ settings: ThresholdSettings) -> Self { .document(.editing(.thresholdApplied(settings))) }
    static func posterizePreviewChanged(_ settings: PosterizeSettings?) -> Self { .document(.editing(.posterizePreviewChanged(settings))) }
    static func posterizeApplied(_ settings: PosterizeSettings) -> Self { .document(.editing(.posterizeApplied(settings))) }
    static var luminanceToAlphaRequested: Self { .document(.editing(.luminanceToAlphaRequested)) }
    static var activeLayerVisibilityToggled: Self { .document(.editing(.activeLayerVisibilityToggled)) }
    static var selectPreviousLayer: Self { .document(.editing(.selectPreviousLayer)) }
    static var selectNextLayer: Self { .document(.editing(.selectNextLayer)) }
    static func panelCollapseToggled(_ panel: StudioPanelKind) -> Self { .document(.editing(.panelCollapseToggled(panel))) }
    static func brushPalette(_ action: BrushPaletteFeature.Action) -> Self { .document(.brushPalette(action)) }
    static func layerSidebar(_ action: LayerSidebarFeature.Action) -> Self { .document(.layerSidebar(action)) }
    static func canvas(_ action: CanvasFeature.Action) -> Self { .document(.canvas(action)) }
}
