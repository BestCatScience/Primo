import ComposableArchitecture
import Foundation

extension AppIntegrationFeature {
    func routeDocumentEditorEditingAction(
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
        return nil
    }

    func routeCanvasInteractionAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        routeCanvasEditingAction(state: &state, action: action)
    }

    func routeEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        if let effect = routeDocumentEditorEditingAction(state: &state, action: action) {
            return effect
        }
        return routeCanvasInteractionAction(state: &state, action: action)
    }
}
