import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleTask(state: inout State) -> Effect<Action> {
        state.application.beginStartup(language: appLanguageClient.load())
        paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
        Self.startupLogger.debug("AppFeature.task started")
        return .merge(
            .run { [paintDocumentClient] send in
                let startupClock = ContinuousClock()
                let bootstrapStart = startupClock.now

                Self.startupLogger.debug("Loading lightweight presentation")
                let lightweightPresentation = paintDocumentClient.lightweightPresentation()
                let bootstrapDuration = bootstrapStart.duration(to: startupClock.now)
                Self.startupLogger.debug("Lightweight presentation loaded in \(String(describing: bootstrapDuration), privacy: .public)")
                await send(.bootstrapPresentationLoaded(lightweightPresentation))
                paintDocumentClient.prewarmDrawingResources()
                await send(.loadPresentationAfterLaunch)
            },
            .send(.homeProjectsLoadRequested),
            .send(.autosaveRecoveryLoadRequested)
        )
    }

    func handleLoadPresentationAfterLaunch() -> Effect<Action> {
        .run { [paintDocumentClient] send in
            let clock = ContinuousClock()
            try? await Task.sleep(for: .milliseconds(600))

            let presentationStart = clock.now
            Self.startupLogger.debug("Loading full presentation after initial launch")
            let presentation = paintDocumentClient.presentation()
            let presentationDuration = presentationStart.duration(to: clock.now)
            Self.startupLogger.debug("Full presentation loaded in \(String(describing: presentationDuration), privacy: .public)")
            await send(.presentationLoaded(presentation))
        }
        .cancellable(id: CancelID.startupPresentationLoad, cancelInFlight: true)
    }

    func handleHomeProjectsLoadRequest(state: inout State) -> Effect<Action> {
        state.application.beginLoadingHomeProjects()
        return .run { [documentWorkspaceClient] send in
            let projects = (try? documentWorkspaceClient.loadSavedProjects()) ?? []
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
        if state.activeTab != nil {
            guard persistActiveProjectToWorkspace(
                state: &state,
                preferredDestinationURL: state.activeTab?.sourceProjectURL
            ) != nil else {
                return .none
            }
            if let activeTab = state.activeTab {
                persistSaveHistorySnapshot(for: activeTab, trigger: .autoSave)
            }
        }
        state.application.showHome()
        return .send(.homeProjectsLoadRequested)
    }

    func handleDeferredPresentationRefresh() -> Effect<Action> {
        .run { [paintDocumentClient] send in
            await send(.presentationLoaded(paintDocumentClient.presentation()))
        }
        .cancellable(id: CancelID.deferredPresentationRefresh, cancelInFlight: true)
    }

    func handleRefreshPresentationRequest(state: inout State) {
        paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
        applyDirtyPresentation(state: &state)
    }

    func handleLanguageChanged(
        state: inout State,
        language: AppLanguage
    ) {
        state.appLanguage = language
        appLanguageClient.persist(language)
    }
}
