import ComposableArchitecture
import PrimoWorkspaceApplication

struct ApplicationWorkspaceBridge: Reducer {
    typealias State = PrimoRootFeature.State
    typealias Action = PrimoRootFeature.Action

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .application(.delegate(.requestHomeProjectsLoad)):
            return .send(.workspace(.catalogRequested(.loadSavedProjects)))

        case .application(.delegate(.requestAutosaveRecoveryLoad)):
            return .send(.workspace(.catalogRequested(.loadAutosaveRecoveryItems)))

        case let .application(.delegate(.requestAutosaveRecoveryRestore(item))):
            return .send(.workspace(.autosaveRecoveryRestoreRequested(item)))

        case let .application(.delegate(.requestAutosaveRecoveryDiscard(id))):
            return .send(
                .workspace(
                    .catalogRequested(
                        .discardAutosaveEntry(
                            PrimoWorkspaceApplication.WorkspaceAutosaveEntryDiscardRequest(autosaveID: id)
                        )
                    )
                )
            )

        case .application(.delegate(.requestPresentationRefresh)):
            return .send(.document(.presentation(.presentationRefreshRequested)))

        case .application(.delegate(.requestLifecycleAutosave)):
            return .send(.workspace(.lifecycleAutosaveRequested))

        case .application(.delegate(.requestStartupPresentationBootstrap)):
            return .send(.document(.presentation(.startupPresentationBootstrapRequested)))

        case .application(.deferredPresentationRefresh):
            return .send(.document(.presentation(.deferredPresentationRefreshRequested)))

        case .application(.refreshPresentationRequested):
            return .send(.document(.presentation(.presentationRefreshRequested)))

        case .application(.loadPresentationAfterLaunch):
            return .send(.document(.presentation(.deferredPresentationLoadRequested)))

        case let .application(.documentPaperStyleSyncRequested(paperStyle)):
            return .send(.document(.presentation(.paperStyleSyncRequested(paperStyle))))

        case let .application(.bootstrapPresentationLoaded(presentation)):
            return .send(.document(.presentation(.bootstrapPresentationLoaded(presentation))))

        case let .application(.presentationLoaded(presentation)):
            return .send(.document(.presentation(.presentationLoaded(presentation))))

        default:
            return .none
        }
    }
}
