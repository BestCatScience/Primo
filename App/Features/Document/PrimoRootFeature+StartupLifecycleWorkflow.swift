import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts
import PrimoDocumentDomain

extension DocumentFeatureRuntimeReducer {
    struct StartupPresentationService {
        let documentQueryGateway: DocumentQueryGateway
        let documentPersistenceGateway: DocumentPersistenceGateway
        let processEnvironmentClient: ProcessEnvironmentClient

        func bootstrapPresentationEffect() -> Effect<Action> {
            .run { [documentPersistenceGateway, documentQueryGateway] send in
                let startupClock = ContinuousClock()
                let bootstrapStart = startupClock.now

                AppDiagnostics.debug(
                    PrimoRootFeature.startupLogger,
                    "Loading lightweight presentation",
                    processEnvironmentClient: processEnvironmentClient
                )
                let lightweightPresentation = documentQueryGateway.lightweightPresentation()
                let bootstrapDuration = bootstrapStart.duration(to: startupClock.now)
                AppDiagnostics.debug(
                    PrimoRootFeature.startupLogger,
                    "Lightweight presentation loaded in \(String(describing: bootstrapDuration))",
                    processEnvironmentClient: processEnvironmentClient
                )
                await send(.application(.bootstrapPresentationLoaded(lightweightPresentation)))
                documentPersistenceGateway.prewarmDrawingResources()
                await send(.application(.loadPresentationAfterLaunch))
            }
        }

        func deferredPresentationLoadEffect() -> Effect<Action> {
            .run { [documentQueryGateway] send in
                let clock = ContinuousClock()
                do {
                    try await Task.sleep(for: .milliseconds(600))
                } catch {
                    return
                }

                let presentationStart = clock.now
                AppDiagnostics.debug(
                    PrimoRootFeature.startupLogger,
                    "Loading full presentation after initial launch",
                    processEnvironmentClient: processEnvironmentClient
                )
                let presentation = documentQueryGateway.presentation()
                let presentationDuration = presentationStart.duration(to: clock.now)
                AppDiagnostics.debug(
                    PrimoRootFeature.startupLogger,
                    "Full presentation loaded in \(String(describing: presentationDuration))",
                    processEnvironmentClient: processEnvironmentClient
                )
                await send(.application(.presentationLoaded(presentation)))
            }
            .cancellable(id: CancelID.startupPresentationLoad, cancelInFlight: true)
        }

        func deferredPresentationRefreshEffect() -> Effect<Action> {
            .run { [documentQueryGateway] send in
                await send(.application(.presentationLoaded(documentQueryGateway.presentation())))
            }
            .cancellable(id: CancelID.deferredPresentationRefresh, cancelInFlight: true)
        }
    }

    var startupPresentationService: StartupPresentationService {
        StartupPresentationService(
            documentQueryGateway: documentQueryGateway,
            documentPersistenceGateway: documentPersistenceGateway,
            processEnvironmentClient: processEnvironmentClient
        )
    }

    func startupLanguageLoadEffect() -> Effect<Action> {
        .run { [appLanguageClient] send in
            await send(.application(.startupLanguageLoaded(appLanguageClient.load())))
        }
    }

    func persistLanguageEffect(_ language: AppLanguage) -> Effect<Action> {
        .run { [appLanguageClient] _ in
            appLanguageClient.persist(language)
        }
    }

    func handleTask(state: inout State) -> Effect<Action> {
        state.application.beginStartup(language: state.application.appLanguage)
        AppDiagnostics.debug(
            Self.startupLogger,
            "PrimoRootFeature.task started",
            processEnvironmentClient: processEnvironmentClient
        )
        return .merge(
            startupPresentationService.bootstrapPresentationEffect(),
            startupLanguageLoadEffect(),
            documentPaperStyleSyncClient.synchronizeEffect(resolvedPaperStyle(for: state)),
            .send(.application(.homeProjectsLoadRequested)),
            .send(.application(.autosaveRecoveryLoadRequested))
        )
    }

    func handleScenePhaseChanged(
        state: inout State,
        phase: AppScenePhase
    ) -> Effect<Action> {
        guard phase == .background else { return .none }
        guard !state.application.showsHome else { return .none }
        guard state.workspace.activeTab?.isDirty == true else { return .none }
        guard let request = lifecycleAutosaveRequest(state: &state) else { return .none }
        return .send(.workspace(.persistenceRequested(request)))
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
        return .send(.workspace(.catalogRequested(.loadSavedProjects)))
    }

    func handleHomeProjectsLoaded(
        state: inout State,
        projects: [SavedProjectSummary]
    ) {
        state.application.finishLoadingHomeProjects(projects)
    }

    func handleHomeProjectsLoadFailed(
        state: inout State,
        message: String?
    ) {
        state.application.finishLoadingHomeProjects([])
        state.application.presentBanner(message)
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
                return .send(.workspace(.persistenceRequested(request)))
            case let .failure(failure):
                state.application.presentBanner(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                )
                return .none
            }
        }
        state.application.showHome()
        return .send(.application(.homeProjectsLoadRequested))
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
