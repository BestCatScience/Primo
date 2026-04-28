import CasePaths
import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoWorkspaceApplication

@Reducer
struct ApplicationFeature {
    enum ScenePhase: Equatable {
        case active
        case inactive
        case background
    }

    enum CancelID {
        case deferredPresentationRefresh
        case startupPresentationLoad
        case workspaceProjectLoad
        case timelapseExport
        case nanoBananaEdit
    }

    enum Feedback: Equatable, Sendable {
        case saveFailed(String?)
        case openFailed(String?)
        case moveFailed(String?)
        case autosaveRestoreFailed(String?)
        case saveHistoryRestoreFailed(String?)
        case couldNotCreateCanvasFromImage(String?)
        case couldNotImportPhoto(String?)
        case photoImportedToNewLayer
        case textLayerApplyFailed
        case layerUnavailable
        case folderUnavailable
        case layerEditLocked
        case layerAlphaEditLocked
        case invalidLayerOpacity
        case emptyDocumentMutationInput
        case documentMutationBridgeFailed(String?)
        case documentMutationTransactionFailed(DocumentMutationFailure, DocumentMutationFailure)
        case unsupportedLayerType
        case createLayerMaskNeedsSelection
        case createLayerMaskFailed
        case applyLayerMaskFailed
        case gradientMapApplyFailed
        case colorAdjustmentApplyFailed
        case exportFailed
        case timelapseHistoryUnavailable
        case timelapseExportFailed(String?)
        case nanoBananaPromptRequired
        case nanoBananaAPIKeyRequired
        case nanoBananaEndpointRequired
        case nanoBananaPrepareLayerFailed
        case nanoBananaSelectionRequired
        case nanoBananaApplyFailed
        case nanoBananaInvalidResponse
        case nanoBananaInvalidEndpoint
        case nanoBananaMissingImage
        case nanoBananaUnsupportedImage
        case nanoBananaEditFailed(String?)
        case nanoBananaGenerationCanceled
        case nanoBananaEditApplied
        case couldNotCreateTab
        case canvasSizeUnsupported
        case imageResolutionUpdated
        case canvasSizeUpdated
        case imageSizeUnsupported
        case canvasCreatedFromImage
        case undoUnavailableWhileDrawing
        case redoUnavailableWhileDrawing
        case openedDocument(Int)
        case savedDocument(String)
        case restoredSaveHistory
        case restoredAutosave
    }

    @ObservableState
    struct State: Equatable {
        var isHydrating = true
        var showsHome = true
        var homeSection: HomeSidebarSection = .home
        var homeProjects: [SavedProjectSummary] = []
        var isLoadingHomeProjects = true
        var bannerMessage: String?
        var appLanguage: AppLanguage = .japanese
    }

    struct RecoveryState: Equatable {
        var items: [AutosaveRecoveryItem] = []
        var isPresented = false
    }

    @CasePathable
    enum Action: Equatable {
        case task
        case scenePhaseChanged(ScenePhase)
        case startupLanguageLoaded(AppLanguage)
        case documentPaperStyleSyncRequested(CanvasPaperStyle)
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
        case bannerDismissed
        case languageChanged(AppLanguage)
    }

    var body: some ReducerOf<Self> {
        Reduce { _, _ in .none }
    }
}
