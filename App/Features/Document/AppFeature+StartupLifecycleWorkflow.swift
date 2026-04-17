import ComposableArchitecture
import Foundation

extension AppFeature {
    struct StartupPresentationService {
        let paintDocumentClient: PaintDocumentClient

        func bootstrapPresentationEffect() -> Effect<Action> {
            .run { [paintDocumentClient] send in
                let startupClock = ContinuousClock()
                let bootstrapStart = startupClock.now

                AppFeature.startupLogger.debug("Loading lightweight presentation")
                let lightweightPresentation = paintDocumentClient.lightweightPresentation()
                let bootstrapDuration = bootstrapStart.duration(to: startupClock.now)
                AppFeature.startupLogger.debug("Lightweight presentation loaded in \(String(describing: bootstrapDuration), privacy: .public)")
                await send(.bootstrapPresentationLoaded(lightweightPresentation))
                paintDocumentClient.prewarmDrawingResources()
                await send(.loadPresentationAfterLaunch)
            }
        }

        func deferredPresentationLoadEffect() -> Effect<Action> {
            .run { [paintDocumentClient] send in
                let clock = ContinuousClock()
                try? await Task.sleep(for: .milliseconds(600))

                let presentationStart = clock.now
                AppFeature.startupLogger.debug("Loading full presentation after initial launch")
                let presentation = paintDocumentClient.presentation()
                let presentationDuration = presentationStart.duration(to: clock.now)
                AppFeature.startupLogger.debug("Full presentation loaded in \(String(describing: presentationDuration), privacy: .public)")
                await send(.presentationLoaded(presentation))
            }
            .cancellable(id: CancelID.startupPresentationLoad, cancelInFlight: true)
        }

        func deferredPresentationRefreshEffect() -> Effect<Action> {
            .run { [paintDocumentClient] send in
                await send(.presentationLoaded(paintDocumentClient.presentation()))
            }
            .cancellable(id: CancelID.deferredPresentationRefresh, cancelInFlight: true)
        }
    }

    var startupPresentationService: StartupPresentationService {
        StartupPresentationService(paintDocumentClient: paintDocumentClient)
    }

    func handleTask(state: inout State) -> Effect<Action> {
        state.application.beginStartup(language: appLanguageClient.load())
        syncPaperStyleToDocument(state: &state)
        Self.startupLogger.debug("AppFeature.task started")
        return .merge(
            startupPresentationService.bootstrapPresentationEffect(),
            .send(.homeProjectsLoadRequested),
            .send(.autosaveRecoveryLoadRequested)
        )
    }

    func handleLoadPresentationAfterLaunch() -> Effect<Action> {
        startupPresentationService.deferredPresentationLoadEffect()
    }

    func handleHomeProjectsLoadRequest(state: inout State) -> Effect<Action> {
        state.application.beginLoadingHomeProjects()
        return .run { [workspaceCatalogService] send in
            let projects = (try? workspaceCatalogService.loadSavedProjects()) ?? []
            await send(.homeProjectsLoaded(projects))
        }
    }

    func handleHomeProjectsLoaded(
        state: inout State,
        projects: [SavedProjectSummary]
    ) {
        state.application.finishLoadingHomeProjects(projects)
    }

    func handleHomeReturnRequest(state: inout State) -> Effect<Action> {
        if state.workspace.activeTab != nil {
            switch persistActiveProjectToWorkspace(
                state: &state,
                preferredDestinationURL: state.workspace.activeTab?.sourceProjectURL
            ) {
            case .success:
                break
            case let .failure(failure):
                state.application.presentFeedback(failure.feedback)
                return .none
            }
            if let activeTab = state.workspace.activeTab {
                persistSaveHistorySnapshot(for: activeTab, trigger: .autoSave)
            }
        }
        state.application.showHome()
        return .send(.homeProjectsLoadRequested)
    }

    func handleDeferredPresentationRefresh() -> Effect<Action> {
        startupPresentationService.deferredPresentationRefreshEffect()
    }

    func handleRefreshPresentationRequest(state: inout State) {
        syncPaperStyleToDocument(state: &state)
        applyDirtyPresentation(state: &state)
    }

    func handleLanguageChanged(
        state: inout State,
        language: AppLanguage
    ) {
        state.application.updateLanguage(language)
        appLanguageClient.persist(language)
    }
}
