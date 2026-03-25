import ComposableArchitecture
import Foundation

@Reducer
struct BrushPaletteFeature {
    @ObservableState
    struct State: Equatable {
        var brushRadius: Double = 3.0
        var brushOpacity: Double = 0.9
        var brushHardness: Double = 0.82
        var selectedBrush: BrushPreset = .defaultPencil
        let presets: [BrushPreset] = BrushPreset.defaults

        var runtimeSettings: BrushRuntimeSettings {
            BrushRuntimeSettings(
                radius: brushRadius,
                opacity: brushOpacity,
                hardness: brushHardness,
                red: selectedBrush.red,
                green: selectedBrush.green,
                blue: selectedBrush.blue
            )
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case selectPreset(BrushPreset)
        case clearActiveLayerButtonTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case clearActiveLayer
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case let .selectPreset(preset):
                state.selectedBrush = preset
                return .none
            case .clearActiveLayerButtonTapped:
                return .send(.delegate(.clearActiveLayer))
            case .delegate:
                return .none
            }
        }
    }
}
