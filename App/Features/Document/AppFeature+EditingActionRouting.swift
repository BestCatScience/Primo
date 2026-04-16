import ComposableArchitecture
import Foundation

extension AppFeature {
    func routeEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        if let effect = routeAdjustmentEditingAction(state: &state, action: action) {
            return effect
        }
        if let effect = routeSelectionEditingAction(state: &state, action: action) {
            return effect
        }
        if let effect = routeLayerEditingAction(state: &state, action: action) {
            return effect
        }
        if let effect = routeCanvasEditingAction(state: &state, action: action) {
            return effect
        }
        return nil
    }
}
