import ComposableArchitecture
import Foundation

extension AppFeature {
    func routeApplicationAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case .task:
            return handleTask(state: &state)

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

        case .autosaveRecoveryLoadRequested:
            return handleAutosaveRecoveryLoadRequest()

        case let .autosaveRecoveryLoaded(items):
            handleAutosaveRecoveryLoaded(state: &state, items: items)
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
            handleRefreshPresentationRequest(state: &state)
            return .none

        case let .languageChanged(language):
            handleLanguageChanged(state: &state, language: language)
            return .none

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
