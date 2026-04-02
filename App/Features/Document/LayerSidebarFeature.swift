import ComposableArchitecture
import Foundation

@Reducer
struct LayerSidebarFeature {
    @ObservableState
    struct State: Equatable {
        var layers: [LayerRowModel] = []
        var layerBuffers: [LayerCanvasBuffer] = []
        var activeLayerIndex: Int = 0
    }

    enum Action: Equatable {
        case addLayerButtonTapped
        case layerTapped(Int)
        case visibilityButtonTapped(Int)
        case blendModeSelected(Int, LayerBlendMode)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case addLayer
        case selectLayer(Int)
        case toggleVisibility(Int)
        case setBlendMode(Int, LayerBlendMode)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .addLayerButtonTapped:
                return .send(.delegate(.addLayer))
            case let .layerTapped(index):
                state.activeLayerIndex = index
                return .send(.delegate(.selectLayer(index)))
            case let .visibilityButtonTapped(index):
                return .send(.delegate(.toggleVisibility(index)))
            case let .blendModeSelected(index, blendMode):
                return .send(.delegate(.setBlendMode(index, blendMode)))
            case .delegate:
                return .none
            }
        }
    }
}
