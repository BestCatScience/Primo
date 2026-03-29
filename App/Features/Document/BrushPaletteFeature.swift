import ComposableArchitecture
import Foundation
import SwiftUI
import UIKit

@Reducer
struct BrushPaletteFeature {
    @ObservableState
    struct State: Equatable {
        var brushRadius: Double = 3.0
        var brushOpacity: Double = 0.9
        var brushHardness: Double = 0.82
        var brushPressureSensitivity: Double = 0.4
        var brushColor: Color = Color(red: 31.0 / 255.0, green: 31.0 / 255.0, blue: 34.0 / 255.0)
        var selectedBrush: BrushPreset? = .defaultPencil
        let presets: [BrushPreset] = BrushPreset.defaults

        var runtimeSettings: BrushRuntimeSettings {
            let resolved = UIColor(brushColor)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return BrushRuntimeSettings(
                radius: brushRadius,
                opacity: brushOpacity,
                hardness: brushHardness,
                pressureSensitivity: brushPressureSensitivity,
                red: UInt8(min(max(Double(red) * 255.0, 0), 255)),
                green: UInt8(min(max(Double(green) * 255.0, 0), 255)),
                blue: UInt8(min(max(Double(blue) * 255.0, 0), 255))
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
            case .binding(\.brushColor):
                state.selectedBrush = nil
                return .none
            case .binding:
                return .none
            case let .selectPreset(preset):
                state.selectedBrush = preset
                state.brushColor = preset.color
                return .none
            case .clearActiveLayerButtonTapped:
                return .send(.delegate(.clearActiveLayer))
            case .delegate:
                return .none
            }
        }
    }
}
