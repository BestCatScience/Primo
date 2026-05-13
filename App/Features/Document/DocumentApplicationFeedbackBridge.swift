import ComposableArchitecture

struct DocumentApplicationFeedbackBridge: Reducer {
    typealias State = PrimoRootFeature.State
    typealias Action = PrimoRootFeature.Action

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .importExport(.delegate(.exportFailed)):
            return .send(.application(.feedbackPresented(.exportFailed)))

        case .importExport(.delegate(.timelapseHistoryUnavailable)):
            return .send(.application(.feedbackPresented(.timelapseHistoryUnavailable)))

        case let .importExport(.delegate(.presentBanner(message))):
            return .send(.application(.bannerPresented(message)))

        case let .importExport(.delegate(.presentFeedback(feedback))):
            return .send(.application(.feedbackPresented(feedback)))

        case let .importExport(.saveHistoryRestoreFailed(message)):
            return .send(.application(.hydrationFailed(message)))

        case let .workspace(.delegate(.homeProjectsLoaded(projects))):
            return .send(.application(.homeProjectsLoaded(projects)))

        case let .workspace(.delegate(.presentFeedback(feedback))):
            return .send(.application(.feedbackPresented(feedback)))

        case let .workspace(.delegate(.presentBanner(message))):
            return .send(.application(.bannerPresented(message)))

        case .workspace(.delegate(.showHome)):
            return .send(.application(.showHomeRequested(.home)))

        case let .workspace(.delegate(.workspaceProjectLoadFailed(message, showingHome))):
            return .send(.application(.hydrationFailed(message, showingHome: showingHome)))

        case let .workspace(.delegate(.workspaceProjectLoadFailedFeedback(feedback, showingHome))):
            return .send(.application(.hydrationFeedbackPresented(feedback, showingHome: showingHome)))

        case let .workspace(.delegate(.workspaceProjectLoadCompleted(message))):
            return .send(.application(.workspaceProjectLoadCompleted(message)))

        case let .workspace(.delegate(.autosaveRecoveryLoaded(items))):
            return .send(.application(.autosaveRecoveryLoaded(items)))

        case let .workspace(.delegate(.autosaveRecoveryLoadFailed(feedback))):
            return .send(.application(.hydrationFeedbackPresented(feedback)))

        case let .workspace(.delegate(.autosaveRecoveryDiscarded(id))):
            return .send(.application(.autosaveRecoveryDiscarded(id)))

        case let .workspace(.delegate(.autosaveRecoveryRestoreCompleted(id))):
            return .send(.application(.autosaveRecoveryRestoreCompleted(id)))

        case .workspace(.delegate(.autosaveRecoveryDismissed)):
            return .send(.application(.autosaveRecoveryDismissed))

        case let .workspace(.delegate(.saveHistoryRestoreFailedFeedback(feedback))):
            return .send(.application(.hydrationFeedbackPresented(feedback)))

        case .workspace(.delegate(.requestHomeProjectsLoad)):
            return .send(.application(.homeProjectsLoadRequested))

        case let .aiImage(.delegate(.presentBanner(message))):
            return .send(.application(.bannerPresented(message)))

        case let .document(.delegate(.paperStyleSyncRequested(paperStyle))):
            return .send(.document(.presentation(.paperStyleSyncRequested(paperStyle))))

        case .document(.delegate(.presentationRefreshRequested)):
            return .send(.document(.presentation(.presentationRefreshRequested)))

        case let .document(.delegate(.documentMutationFeedback(feedback))):
            return .send(.application(.feedbackPresented(feedback)))

        case .document(.delegate(.presentationApplied)):
            return .send(.application(.hydrationFinished()))

        default:
            return .none
        }
    }
}
