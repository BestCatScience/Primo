import ComposableArchitecture

struct DocumentEditingRouter: Reducer {
    typealias State = DocumentFeature.State
    typealias Action = DocumentFeature.Action

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .brushPalette(brushPaletteAction):
            state.editing.refreshBrushPaletteState()
            return .merge(
                .send(.canvasEditing(.brushPalette(brushPaletteAction))),
                .send(.layerWorkflow(.brushPalette(brushPaletteAction)))
            )

        case let .layerSidebar(layerSidebarAction):
            return .merge(
                .send(.canvasEditing(.layerSidebar(layerSidebarAction))),
                .send(.layerWorkflow(.layerSidebar(layerSidebarAction)))
            )

        case let .canvas(canvasAction):
            return .send(.canvasEditing(.canvas(canvasAction)))

        case let .presentation(.delegate(delegateAction)),
             let .lifecycle(.delegate(delegateAction)),
             let .canvasEditing(.delegate(delegateAction)),
             let .layerWorkflow(.delegate(delegateAction)),
             let .adjustment(.delegate(delegateAction)),
             let .aiImageWorkflow(.delegate(delegateAction)):
            return .send(.delegate(delegateAction))

        case let .canvasEditing(.lifecycle(lifecycleAction)):
            return .send(.lifecycle(lifecycleAction))

        case .delegate:
            return .none

        default:
            return .none
        }
    }
}
