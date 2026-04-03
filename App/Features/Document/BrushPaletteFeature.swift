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
        var brushRoundness: Double = BrushPreset.defaultPencil.roundness
        var brushAngle: Double = BrushPreset.defaultPencil.angle
        var brushAngleMode: BrushAngleMode = BrushPreset.defaultPencil.angleMode
        var brushSpacing: Double = BrushPreset.defaultPencil.spacing
        var brushScatterLateral: Double = BrushPreset.defaultPencil.scatterLateral
        var brushScatterLinear: Double = BrushPreset.defaultPencil.scatterLinear
        var brushTextureMode: BrushTextureMode = BrushPreset.defaultPencil.textureMode
        var brushTextureStrength: Double = BrushPreset.defaultPencil.textureStrength
        var brushPressureSensitivity: Double = BrushPreset.defaultPencil.pressureSensitivity
        var brushStabilization: Double = 0.0
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
        var paperColor: Color = Color(red: 0.93, green: 0.93, blue: 0.91)
        var transparentPaper = false
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
                roundness: brushRoundness,
                angle: brushAngle,
                angleMode: brushAngleMode,
                stampSpacing: brushSpacing,
                scatterLateral: brushScatterLateral,
                scatterLinear: brushScatterLinear,
                textureMode: brushTextureMode,
                textureStrength: brushTextureStrength,
                pressureSensitivity: brushPressureSensitivity,
                stabilization: brushStabilization,
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
                 .binding(\.brushRoundness),
                 .binding(\.brushAngle),
                 .binding(\.brushAngleMode),
                 .binding(\.brushSpacing),
                 .binding(\.brushScatterLateral),
                 .binding(\.brushScatterLinear),
                 .binding(\.brushTextureMode),
                 .binding(\.brushTextureStrength),
                 .binding(\.brushPressureSensitivity),
                 .binding(\.brushStabilization),
                 .binding(\.selectionToolMode),
                 .binding(\.selectionCombineMode),
                 .binding(\.selectionThresholdMode),
                 .binding(\.selectionOpacityTolerance),
                 .binding(\.selectionColorTolerance),
                 .binding(\.selectionExpansion),
                 .binding(\.fillThresholdMode),
                 .binding(\.fillOpacityTolerance),
                 .binding(\.fillColorTolerance),
                 .binding(\.fillExpansion),
                 .binding(\.paperColor),
                 .binding(\.transparentPaper):
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
                state.brushRoundness = preset.roundness
                state.brushAngle = preset.angle
                state.brushAngleMode = preset.angleMode
                state.brushSpacing = preset.spacing
                state.brushScatterLateral = preset.scatterLateral
                state.brushScatterLinear = preset.scatterLinear
                state.brushTextureMode = preset.textureMode
                state.brushTextureStrength = preset.textureStrength
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
