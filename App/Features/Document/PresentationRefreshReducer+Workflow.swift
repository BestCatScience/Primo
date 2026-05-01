import ComposableArchitecture
import Foundation
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts

extension PresentationRefreshReducer {
    func workspaceDocumentSnapshot(state: State) -> WorkspaceDocumentSnapshot {
        DocumentFeature.workspaceSnapshotCoordinator.snapshot(
            state: state,
            documentExportGateway: documentExportGateway,
            documentRenderingWorkflow: documentRenderingWorkflow
        )
    }

    func startupPresentationBootstrapEffect() -> Effect<Action> {
        .run { [documentPersistenceGateway, documentPresentationReader, processEnvironmentClient] send in
            let startupClock = ContinuousClock()
            let bootstrapStart = startupClock.now

            AppDiagnostics.debug(
                PrimoRootFeature.startupLogger,
                "Loading lightweight presentation",
                processEnvironmentClient: processEnvironmentClient
            )
            let lightweightPresentation = documentPresentationReader.lightweightPresentation()
            let bootstrapDuration = bootstrapStart.duration(to: startupClock.now)
            AppDiagnostics.debug(
                PrimoRootFeature.startupLogger,
                "Lightweight presentation loaded in \(String(describing: bootstrapDuration))",
                processEnvironmentClient: processEnvironmentClient
            )
            await send(.bootstrapPresentationLoaded(lightweightPresentation))
            documentPersistenceGateway.prewarmDrawingResources()
            await send(.deferredPresentationLoadRequested)
        }
    }

    func deferredPresentationLoadEffect() -> Effect<Action> {
        .run { [documentPresentationReader, processEnvironmentClient] send in
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
            let presentation = documentPresentationReader.presentation()
            let presentationDuration = presentationStart.duration(to: clock.now)
            AppDiagnostics.debug(
                PrimoRootFeature.startupLogger,
                "Full presentation loaded in \(String(describing: presentationDuration))",
                processEnvironmentClient: processEnvironmentClient
            )
            await send(.presentationLoaded(presentation))
        }
        .cancellable(id: ApplicationFeature.CancelID.startupPresentationLoad, cancelInFlight: true)
    }

    func deferredPresentationRefreshEffect() -> Effect<Action> {
        .run { [documentPresentationReader] send in
            await send(.presentationLoaded(documentPresentationReader.presentation()))
        }
        .cancellable(id: ApplicationFeature.CancelID.deferredPresentationRefresh, cancelInFlight: true)
    }

    func synchronizePaperStyleEffect(_ paperStyle: CanvasPaperStyle) -> Effect<Action> {
        .run { [documentPersistenceGateway] _ in
            documentPersistenceGateway.setPaperStyle(paperStyle)
        }
    }

    func applyPresentation(
        _ presentation: PaintDocumentPresentation,
        to state: inout State
    ) -> Effect<Action> {
        guard DocumentFeature.canvasPresentationStateCoordinator.applyPresentation(presentation, to: &state) else {
            return .none
        }
        return .send(.delegate(.presentationApplied))
    }
}
