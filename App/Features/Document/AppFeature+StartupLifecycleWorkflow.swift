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
                do {
                    try await Task.sleep(for: .milliseconds(600))
                } catch {
                    return
                }

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

    func startupLanguageLoadEffect() -> Effect<Action> {
        .run { [appLanguageClient] send in
            await send(.startupLanguageLoaded(appLanguageClient.load()))
        }
    }

    func persistLanguageEffect(_ language: AppLanguage) -> Effect<Action> {
        .run { [appLanguageClient] _ in
            appLanguageClient.persist(language)
        }
    }

    func handleTask(state: inout State) -> Effect<Action> {
        state.application.beginStartup(language: state.application.appLanguage)
        Self.startupLogger.debug("AppFeature.task started")
        return .merge(
            startupPresentationService.bootstrapPresentationEffect(),
            startupLanguageLoadEffect(),
            documentPaperStyleSyncClient.synchronizeEffect(resolvedPaperStyle(for: state)),
            .send(.homeProjectsLoadRequested),
            .send(.autosaveRecoveryLoadRequested)
        )
    }

    func handleStartupLanguageLoaded(
        state: inout State,
        language: AppLanguage
    ) {
        state.application.updateLanguage(language)
    }

    func handleLoadPresentationAfterLaunch() -> Effect<Action> {
        startupPresentationService.deferredPresentationLoadEffect()
    }

    func handleHomeProjectsLoadRequest(state: inout State) -> Effect<Action> {
        state.application.beginLoadingHomeProjects()
        return .run { [workspaceCatalogService] send in
            do {
                await send(.homeProjectsLoaded(try workspaceCatalogService.loadSavedProjects()))
            } catch {
                await send(
                    .homeProjectsLoadFailed(
                        .openFailed(Self.optionalErrorMessage(error))
                    )
                )
            }
        }
    }

    func handleHomeProjectsLoaded(
        state: inout State,
        projects: [SavedProjectSummary]
    ) {
        state.application.finishLoadingHomeProjects(projects)
    }

    func handleHomeProjectsLoadFailed(
        state: inout State,
        feedback: ApplicationFeedback
    ) {
        state.application.finishLoadingHomeProjects([])
        state.application.presentFeedback(feedback)
    }

    func handleHomeReturnRequest(state: inout State) -> Effect<Action> {
        if state.workspace.activeTab != nil {
            switch saveActiveDocumentRequest(
                state: &state,
                preferredDestinationURL: state.workspace.activeTab?.sourceProjectURL,
                trigger: .autoSave,
                purpose: .homeReturn
            ) {
            case let .success(request):
                return .send(.workspacePersistenceRequested(request))
            case let .failure(failure):
                state.application.presentFeedback(failure.feedback)
                return .none
            }
        }
        state.application.showHome()
        return .send(.homeProjectsLoadRequested)
    }

    func handleDeferredPresentationRefresh() -> Effect<Action> {
        startupPresentationService.deferredPresentationRefreshEffect()
    }

    func handleDocumentPaperStyleSyncRequested(
        paperStyle: CanvasPaperStyle
    ) -> Effect<Action> {
        documentPaperStyleSyncClient.synchronizeEffect(paperStyle)
    }

    func handleRefreshPresentationRequest(state: inout State) -> Effect<Action> {
        .merge(
            documentPaperStyleSyncClient.synchronizeEffect(
                resolvedPaperStyle(for: state)
            ),
            startupPresentationService.deferredPresentationRefreshEffect()
        )
    }

    func handleLanguageChanged(
        state: inout State,
        language: AppLanguage
    ) -> Effect<Action> {
        state.application.updateLanguage(language)
        return persistLanguageEffect(language)
    }
}
