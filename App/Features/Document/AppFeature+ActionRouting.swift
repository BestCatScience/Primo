import ComposableArchitecture
import Foundation

struct AppFeatureApplicationReducer: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action

    let feature: AppFeature

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        guard case let .application(applicationAction) = action else {
            return .none
        }
        return feature.routeApplicationAction(state: &state, action: applicationAction)
    }
}

struct AppFeatureWorkspaceReducer: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action

    let feature: AppFeature

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        guard case let .workspace(workspaceAction) = action else {
            return .none
        }
        return feature.routeWorkspaceAction(state: &state, action: workspaceAction)
    }
}

struct AppFeatureDocumentReducer: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action

    let feature: AppFeature

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        feature.routeDocumentAction(state: &state, action: action) ?? .none
    }
}

struct AppFeatureEditingReducer: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action

    let feature: AppFeature

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        feature.routeEditingAction(state: &state, action: action) ?? .none
    }
}
