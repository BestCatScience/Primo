import ComposableArchitecture
import Foundation

struct AppFeatureApplicationReducer: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action

    let feature: AppFeature

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        feature.routeApplicationAction(state: &state, action: action) ?? .none
    }
}

struct AppFeatureWorkspaceReducer: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action

    let feature: AppFeature

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        feature.routeWorkspaceAction(state: &state, action: action) ?? .none
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
