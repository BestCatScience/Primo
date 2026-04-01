import ComposableArchitecture
import Foundation
import SwiftUI
import UIKit

@Reducer
struct BrushPaletteFeature {
    @ObservableState
    struct State: Equatable {
        var brushTipKind: BrushTipKind = BrushPreset.defaultPencil.tipKind
        var brushRadius: Double = BrushPreset.defaultPencil.radius
        var brushOpacity: Double = BrushPreset.defaultPencil.opacity
        var brushHardness: Double = BrushPreset.defaultPencil.hardness
        var brushPressureSensitivity: Double = BrushPreset.defaultPencil.pressureSensitivity
        var selectionToolMode: SelectionToolMode = .lasso
        var selectionCombineMode: SelectionCombineMode = .replace
        var selectionThresholdMode: FillThresholdMode = .color
        var selectionOpacityTolerance: Double = 0.08
        var selectionColorTolerance: Double = 0.12
        var selectionExpansion: Double = 0
        var fillThresholdMode: FillThresholdMode = .opacity
        var fillOpacityTolerance: Double = 0.08
        var fillColorTolerance: Double = 0.12
        var fillExpansion: Double = 0
        var brushColor: Color = BrushPreset.defaultPencil.color
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
                tipKind: brushTipKind,
                radius: brushRadius,
                opacity: brushOpacity,
                hardness: brushHardness,
                pressureSensitivity: brushPressureSensitivity,
                fillThresholdMode: fillThresholdMode,
                fillOpacityTolerance: fillOpacityTolerance,
                fillColorTolerance: fillColorTolerance,
                fillExpansion: Int(fillExpansion.rounded()),
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
        case clearSelectionButtonTapped
        case applyTransformButtonTapped
        case cancelTransformButtonTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case clearActiveLayer
        case clearSelection
        case applyTransform
        case cancelTransform
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.brushColor),
                 .binding(\.brushTipKind),
                 .binding(\.brushRadius),
                 .binding(\.brushOpacity),
                 .binding(\.brushHardness),
                 .binding(\.brushPressureSensitivity),
                 .binding(\.selectionToolMode),
                 .binding(\.selectionCombineMode),
                 .binding(\.selectionThresholdMode),
                 .binding(\.selectionOpacityTolerance),
                 .binding(\.selectionColorTolerance),
                 .binding(\.selectionExpansion),
                 .binding(\.fillThresholdMode),
                 .binding(\.fillOpacityTolerance),
                 .binding(\.fillColorTolerance),
                 .binding(\.fillExpansion):
                state.selectedBrush = nil
                return .none
            case .binding:
                return .none
            case let .selectPreset(preset):
                state.selectedBrush = preset
                state.brushColor = preset.color
                state.brushTipKind = preset.tipKind
                state.brushRadius = preset.radius
                state.brushOpacity = preset.opacity
                state.brushHardness = preset.hardness
                state.brushPressureSensitivity = preset.pressureSensitivity
                return .none
            case .clearActiveLayerButtonTapped:
                return .send(.delegate(.clearActiveLayer))
            case .clearSelectionButtonTapped:
                return .send(.delegate(.clearSelection))
            case .applyTransformButtonTapped:
                return .send(.delegate(.applyTransform))
            case .cancelTransformButtonTapped:
                return .send(.delegate(.cancelTransform))
            case .delegate:
                return .none
            }
        }
    }
}
