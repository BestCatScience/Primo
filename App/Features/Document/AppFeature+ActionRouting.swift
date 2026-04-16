import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleAction(state: inout State, action: Action) -> Effect<Action> {
        if let effect = routeApplicationAction(state: &state, action: action) {
            return effect
        }
        if let effect = routeWorkspaceAction(state: &state, action: action) {
            return effect
        }
        if let effect = routeDocumentAction(state: &state, action: action) {
            return effect
        }
        if let effect = routeEditingAction(state: &state, action: action) {
            return effect
        }
        return .none
    }
}
