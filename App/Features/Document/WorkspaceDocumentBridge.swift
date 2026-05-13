import ComposableArchitecture

struct WorkspaceDocumentBridge: Reducer {
    typealias State = PrimoRootFeature.State
    typealias Action = PrimoRootFeature.Action

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .workspace(.delegate(.requestDocumentSnapshot)):
            return .send(.document(.presentation(.workspaceSnapshotRequested(.pendingWorkspaceOperation))))

        case let .workspace(.delegate(.applyLoadedProject(loaded))):
            return .send(.document(.presentation(.applyLoadedProjectRequested(loaded))))

        case let .workspace(.delegate(.requestFreshDocumentMutation(request))):
            return .send(.document(.lifecycle(.freshDocumentMutationRequested(request))))

        case let .document(.delegate(.workspaceSnapshotPrepared(_, snapshot))):
            return .send(.workspace(.documentSnapshotPrepared(snapshot)))

        case .document(.delegate(.loadedProjectApplied)):
            return .send(.workspace(.loadedProjectApplied))

        case .document(.delegate(.loadedProjectApplySkipped)):
            return .send(.workspace(.loadedProjectApplySkipped))

        case let .document(.delegate(.freshDocumentRequested(contract, operation))):
            return .send(.workspace(.freshDocumentRequested(contract, operation)))

        case let .document(.delegate(.freshDocumentMutationSucceeded(preparedTab, contract, snapshot))):
            return .send(.workspace(.freshDocumentMutationSucceeded(preparedTab, contract, snapshot)))

        case let .document(.delegate(.freshDocumentMutationFailed(feedback))):
            return .send(.workspace(.freshDocumentMutationFailed(feedback)))

        default:
            return .none
        }
    }
}
