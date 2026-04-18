import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleBootstrapPresentationLoaded(
        state: inout State,
        presentation: PaintDocumentPresentation
    ) {
        applyPresentation(presentation, state: &state)
        state.application.finishHydration()
        Self.startupLogger.debug("Bootstrap presentation applied; initial UI is ready")
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
        Self.startupLogger.debug("Full presentation applied")
    }

    func handleBannerDismissed(state: inout State) {
        state.application.clearBanner()
    }

    func routeApplicationAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case .task:
            return handleTask(state: &state)

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

        case let .homeProjectsLoadFailed(feedback):
            handleHomeProjectsLoadFailed(state: &state, feedback: feedback)
            return .none

        case .autosaveRecoveryLoadRequested:
            return handleAutosaveRecoveryLoadRequest()

        case let .autosaveRecoveryLoaded(items):
            handleAutosaveRecoveryLoaded(state: &state, items: items)
            return .none

        case let .autosaveRecoveryLoadFailed(feedback):
            handleAutosaveRecoveryRestoreFailed(state: &state, feedback: feedback)
            return .none

        case let .autosaveRecoveryRestoreRequested(autosaveID):
            return handleAutosaveRecoveryRestoreRequest(state: &state, autosaveID: autosaveID)

        case let .autosaveRecoveryOpened(loaded, item):
            return handleAutosaveRecoveryOpened(state: &state, loaded: loaded, item: item)

        case let .autosaveRecoveryRestoreFailed(feedback):
            handleAutosaveRecoveryRestoreFailed(state: &state, feedback: feedback)
            return .none

        case let .autosaveRecoveryDiscardRequested(autosaveID):
            handleAutosaveRecoveryDiscardRequest(state: &state, autosaveID: autosaveID)
            return .none

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

        default:
            return nil
        }
    }
}
