import CasePaths
import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoWorkspaceApplication

@Reducer
struct ApplicationFeature {
    @Dependency(\.appLanguageClient) var appLanguageClient

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
        case aiImageEdit
        case aiImageSettingsPersist
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
        case aiImagePromptRequired
        case aiImageAPIKeyRequired
        case aiImageEndpointRequired
        case aiImagePrepareLayerFailed
        case aiImageSelectionRequired
        case aiImageApplyFailed
        case aiImageInvalidResponse
        case aiImageInvalidEndpoint
        case aiImageMissingImage
        case aiImageUnsupportedImage
        case aiImageEditFailed(String?)
        case aiImageGenerationCanceled
        case aiImageEditApplied
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
        var recovery = RecoveryState()
    }

    struct RecoveryState: Equatable {
        var items: [AutosaveRecoveryItem] = []
        var isPresented = false
    }

    @CasePathable
    enum Action: Equatable {
        enum Delegate: Equatable {
            case requestHomeProjectsLoad
            case requestAutosaveRecoveryLoad
            case requestAutosaveRecoveryRestore(AutosaveRecoveryItem)
            case requestAutosaveRecoveryDiscard(WorkspaceItemID)
            case requestPresentationRefresh
            case requestLifecycleAutosave
            case requestStartupPresentationBootstrap
        }

        case task
        case startupStarted(AppLanguage)
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
        case autosaveRecoveryRestoreFailed(String?)
        case autosaveRecoveryRestoreCompleted(WorkspaceItemID)
        case autosaveRecoveryDiscardRequested(WorkspaceItemID)
        case autosaveRecoveryDiscarded(WorkspaceItemID)
        case autosaveRecoveryDismissed
        case hydrationStarted
        case hydrationFailed(String?, showingHome: Bool? = nil)
        case hydrationFinished(showingHome: Bool? = nil)
        case workspaceProjectLoadCompleted(String?)
        case hydrationFeedbackPresented(Feedback, showingHome: Bool? = nil)
        case feedbackPresented(Feedback)
        case bannerPresented(String?)
        case showHomeRequested(HomeSidebarSection)
        case showWorkspaceRequested
        case homeSectionSelected(HomeSidebarSection)
        case deferredPresentationRefresh
        case refreshPresentationRequested
        case bannerDismissed
        case languageChanged(AppLanguage)
        case delegate(Delegate)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    startupLanguageLoadEffect(),
                    .send(.startupStarted(state.appLanguage)),
                    .send(.delegate(.requestStartupPresentationBootstrap)),
                    .send(.homeProjectsLoadRequested),
                    .send(.autosaveRecoveryLoadRequested)
                )

            case let .startupStarted(language):
                state.beginStartup(language: language)
                return .none

            case let .scenePhaseChanged(phase):
                guard phase == .background else { return .none }
                guard !state.showsHome else { return .none }
                return .send(.delegate(.requestLifecycleAutosave))

            case .homeProjectsLoadRequested:
                state.beginLoadingHomeProjects()
                return .send(.delegate(.requestHomeProjectsLoad))

            case let .homeProjectsLoaded(projects):
                state.finishLoadingHomeProjects(projects)
                return .none

            case let .homeProjectsLoadFailed(message):
                state.finishLoadingHomeProjects([])
                state.presentBanner(message)
                return .none

            case .autosaveRecoveryLoadRequested:
                return .send(.delegate(.requestAutosaveRecoveryLoad))

            case let .autosaveRecoveryLoaded(items):
                state.recovery.present(items: items)
                return .none

            case let .autosaveRecoveryLoadFailed(message):
                state.failHydration(message: message)
                return .none

            case let .autosaveRecoveryRestoreFailed(message):
                state.failHydration(message: message)
                return .none

            case let .autosaveRecoveryRestoreRequested(id):
                guard let item = state.recovery.item(id: id) else { return .none }
                return .send(.delegate(.requestAutosaveRecoveryRestore(item)))

            case let .autosaveRecoveryRestoreCompleted(id):
                state.recovery.completeRestore(of: id)
                return .none

            case let .autosaveRecoveryDiscardRequested(id):
                return .send(.delegate(.requestAutosaveRecoveryDiscard(id)))

            case let .autosaveRecoveryDiscarded(id):
                state.recovery.removeItem(id: id)
                return .none

            case .autosaveRecoveryDismissed:
                state.recovery.dismiss()
                return .none

            case .hydrationStarted:
                state.beginHydration()
                return .none

            case let .hydrationFailed(message, showingHome):
                state.failHydration(message: message, showingHome: showingHome)
                return .none

            case let .hydrationFinished(showingHome):
                state.finishHydration(showingHome: showingHome)
                return .none

            case let .workspaceProjectLoadCompleted(message):
                state.completeWorkspaceProjectLoad(message: message)
                return .none

            case let .hydrationFeedbackPresented(feedback, showingHome):
                state.failHydration(
                    message: feedback.message(for: state.appLanguage),
                    showingHome: showingHome
                )
                return .none

            case let .feedbackPresented(feedback):
                state.presentFeedback(feedback)
                return .none

            case let .bannerPresented(message):
                state.presentBanner(message)
                return .none

            case let .showHomeRequested(section):
                state.showHome(section: section)
                return .none

            case .showWorkspaceRequested:
                state.showWorkspace()
                return .none

            case let .startupLanguageLoaded(language):
                state.updateLanguage(language)
                return .none

            case let .homeSectionSelected(section):
                state.selectHomeSection(section)
                return .none

            case let .languageChanged(language):
                state.updateLanguage(language)
                return persistLanguageEffect(language)

            case .bannerDismissed:
                state.clearBanner()
                return .none

            case .delegate:
                return .none
            default:
                return .none
            }
        }
    }
}
