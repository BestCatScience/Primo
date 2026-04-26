import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension AppFeature {
    func handleBootstrapPresentationLoaded(
        state: inout State,
        presentation: PaintDocumentPresentation
    ) {
        applyPresentation(presentation, state: &state)
        state.application.finishHydration()
        AppDiagnostics.debug(
            Self.startupLogger,
            "Bootstrap presentation applied; initial UI is ready",
            processEnvironmentClient: processEnvironmentClient
        )
    }

    func handleAutosaveRecoveryLoaded(
        state: inout State,
        items: [AutosaveRecoveryItem]
    ) {
        state.recovery.present(items: items)
    }

    func handleAutosaveRecoveryDismissed(state: inout State) {
        state.recovery.dismiss()
    }

    func handleHomeSectionSelected(
        state: inout State,
        section: HomeSidebarSection
    ) {
        state.application.selectHomeSection(section)
    }

    func handlePresentationLoaded(
        state: inout State,
        presentation: PaintDocumentPresentation
    ) {
        guard !state.canvas.isStrokeActive else { return }
        applyPresentation(presentation, state: &state)
        AppDiagnostics.debug(
            Self.startupLogger,
            "Full presentation applied",
            processEnvironmentClient: processEnvironmentClient
        )
    }

    func handleBannerDismissed(state: inout State) {
        state.application.clearBanner()
    }

    func routeApplicationAction(
        state: inout State,
        action: ApplicationAction
    ) -> Effect<Action> {
        switch action {
        case .task:
            return handleTask(state: &state)

        case let .scenePhaseChanged(phase):
            return handleScenePhaseChanged(state: &state, phase: phase)

        case let .startupLanguageLoaded(language):
            handleStartupLanguageLoaded(state: &state, language: language)
            return .none

        case let .documentPaperStyleSyncRequested(paperStyle):
            return handleDocumentPaperStyleSyncRequested(paperStyle: paperStyle)

        case let .workspacePersistenceRequested(request):
            return handleWorkspacePersistenceRequested(request: request)

        case let .workspacePersistenceSucceeded(result):
            return handleWorkspacePersistenceSucceeded(state: &state, result: result)

        case let .workspacePersistenceFailed(failure):
            return handleWorkspacePersistenceFailed(state: &state, failure: failure)

        case let .workspaceCatalogRequested(request):
            return handleWorkspaceCatalogRequested(request: request)

        case let .workspaceCatalogSucceeded(result):
            return handleWorkspaceCatalogSucceeded(state: &state, result: result)

        case let .workspaceCatalogFailed(failure):
            handleWorkspaceCatalogFailed(state: &state, failure: failure)
            return .none

        case let .bootstrapPresentationLoaded(presentation):
            handleBootstrapPresentationLoaded(state: &state, presentation: presentation)
            return .none

        case .loadPresentationAfterLaunch:
            return handleLoadPresentationAfterLaunch()

        case .homeProjectsLoadRequested:
            return handleHomeProjectsLoadRequest(state: &state)

        case let .homeProjectsLoaded(projects):
            handleHomeProjectsLoaded(state: &state, projects: projects)
            return .none

        case let .homeProjectsLoadFailed(message):
            handleHomeProjectsLoadFailed(state: &state, message: message)
            return .none

        case .autosaveRecoveryLoadRequested:
            return handleAutosaveRecoveryLoadRequest()

        case let .autosaveRecoveryLoaded(items):
            handleAutosaveRecoveryLoaded(state: &state, items: items)
            return .none

        case let .autosaveRecoveryLoadFailed(message):
            handleAutosaveRecoveryRestoreFailed(state: &state, message: message)
            return .none

        case let .autosaveRecoveryRestoreRequested(autosaveID):
            return handleAutosaveRecoveryRestoreRequest(state: &state, autosaveID: autosaveID)

        case let .autosaveRecoveryOpened(loaded, item, issues):
            return handleAutosaveRecoveryOpened(state: &state, loaded: loaded, item: item, issues: issues)

        case let .autosaveRecoveryRestoreFailed(message):
            handleAutosaveRecoveryRestoreFailed(state: &state, message: message)
            return .none

        case let .autosaveRecoveryDiscardRequested(autosaveID):
            return handleAutosaveRecoveryDiscardRequest(state: &state, autosaveID: autosaveID)

        case .autosaveRecoveryDismissed:
            handleAutosaveRecoveryDismissed(state: &state)
            return .none

        case let .homeSectionSelected(section):
            handleHomeSectionSelected(state: &state, section: section)
            return .none

        case let .presentationLoaded(presentation):
            handlePresentationLoaded(state: &state, presentation: presentation)
            return .none

        case .deferredPresentationRefresh:
            return handleDeferredPresentationRefresh()

        case .refreshPresentationRequested:
            return handleRefreshPresentationRequest(state: &state)

        case let .languageChanged(language):
            return handleLanguageChanged(state: &state, language: language)

        case .exportSheetDismissed:
            handleExportSheetDismissed(state: &state)
            return .none

        case .bannerDismissed:
            handleBannerDismissed(state: &state)
            return .none
        }
    }
}
