import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
struct LayerSidebarFeature {
    @ObservableState
    struct State: Equatable {
        var layers: [LayerRowModel] = []
        var layerBuffers: [LayerCanvasBuffer] = []
        var activeLayerIndex: Int = 0
        var paperColor: Color = Color(red: 0.93, green: 0.93, blue: 0.91)
        var transparentPaper = false
        var showsPaperEditor = false
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case addLayerButtonTapped
        case layerTapped(Int)
        case visibilityButtonTapped(Int)
        case blendModeSelected(Int, LayerBlendMode)
        case deleteLayerButtonTapped(Int)
        case moveLayerUpButtonTapped(Int)
        case moveLayerDownButtonTapped(Int)
        case paperRowTapped
        case paperEditorDismissed
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case addLayer
        case selectLayer(Int)
        case toggleVisibility(Int)
        case setBlendMode(Int, LayerBlendMode)
        case deleteLayer(Int)
        case moveLayer(Int, Int)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .addLayerButtonTapped:
                return .send(.delegate(.addLayer))
            case let .layerTapped(index):
                state.activeLayerIndex = index
                return .send(.delegate(.selectLayer(index)))
            case let .visibilityButtonTapped(index):
                return .send(.delegate(.toggleVisibility(index)))
            case let .blendModeSelected(index, blendMode):
                return .send(.delegate(.setBlendMode(index, blendMode)))
            case let .deleteLayerButtonTapped(index):
                return .send(.delegate(.deleteLayer(index)))
            case let .moveLayerUpButtonTapped(index):
                guard let position = state.layers.firstIndex(where: { $0.index == index }), position > 0 else {
                    return .none
                }
                return .send(.delegate(.moveLayer(index, state.layers[position - 1].index)))
            case let .moveLayerDownButtonTapped(index):
                guard
                    let position = state.layers.firstIndex(where: { $0.index == index }),
                    position < state.layers.count - 1
                else {
                    return .none
                }
                return .send(.delegate(.moveLayer(index, state.layers[position + 1].index)))
            case .paperRowTapped:
                state.showsPaperEditor = true
                return .none
            case .paperEditorDismissed:
                state.showsPaperEditor = false
                return .none
            case .delegate:
                return .none
            }
        }
    }
}
