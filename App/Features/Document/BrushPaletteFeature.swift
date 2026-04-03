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
        var brushSizeSpeedSensitivity: Double = BrushPreset.defaultPencil.sizeSpeedSensitivity
        var brushOpacity: Double = BrushPreset.defaultPencil.opacity
        var brushHardness: Double = BrushPreset.defaultPencil.hardness
        var brushRoundness: Double = BrushPreset.defaultPencil.roundness
        var brushRoundnessPressureSensitivity: Double = BrushPreset.defaultPencil.roundnessPressureSensitivity
        var brushRoundnessTiltSensitivity: Double = BrushPreset.defaultPencil.roundnessTiltSensitivity
        var brushAngle: Double = BrushPreset.defaultPencil.angle
        var brushAnglePressureSensitivity: Double = BrushPreset.defaultPencil.anglePressureSensitivity
        var brushAngleTiltSensitivity: Double = BrushPreset.defaultPencil.angleTiltSensitivity
        var brushAngleMode: BrushAngleMode = BrushPreset.defaultPencil.angleMode
        var brushSpacing: Double = BrushPreset.defaultPencil.spacing
        var brushSpacingJitter: Double = BrushPreset.defaultPencil.spacingJitter
        var brushScatterEnabled: Bool = BrushPreset.defaultPencil.scatterEnabled
        var brushScatterMode: BrushScatterMode = BrushPreset.defaultPencil.scatterMode
        var brushScatterLateral: Double = BrushPreset.defaultPencil.scatterLateral
        var brushScatterLinear: Double = BrushPreset.defaultPencil.scatterLinear
        var brushCount: Double = Double(BrushPreset.defaultPencil.count)
        var brushCountJitter: Double = BrushPreset.defaultPencil.countJitter
        var brushCountSizeJitter: Double = BrushPreset.defaultPencil.countSizeJitter
        var brushCountOpacityJitter: Double = BrushPreset.defaultPencil.countOpacityJitter
        var brushAngleJitter: Double = BrushPreset.defaultPencil.angleJitter
        var brushRoundnessJitter: Double = BrushPreset.defaultPencil.roundnessJitter
        var brushTextureMode: BrushTextureMode = BrushPreset.defaultPencil.textureMode
        var brushTextureStrength: Double = BrushPreset.defaultPencil.textureStrength
        var brushFlow: Double = BrushPreset.defaultPencil.flow
        var brushFlowPressureSensitivity: Double = BrushPreset.defaultPencil.flowPressureSensitivity
        var brushFlowJitter: Double = BrushPreset.defaultPencil.flowJitter
        var brushWetness: Double = BrushPreset.defaultPencil.wetness
        var brushWetnessPressureSensitivity: Double = BrushPreset.defaultPencil.wetnessPressureSensitivity
        var brushOpacityPressureSensitivity: Double = BrushPreset.defaultPencil.opacityPressureSensitivity
        var brushColorMixStrength: Double = BrushPreset.defaultPencil.colorMixStrength
        var brushPaintLoad: Double = BrushPreset.defaultPencil.paintLoad
        var brushLoadPressureSensitivity: Double = BrushPreset.defaultPencil.loadPressureSensitivity
        var brushDualEnabled: Bool = BrushPreset.defaultPencil.dualBrushEnabled
        var brushDualTipKind: BrushTipKind = BrushPreset.defaultPencil.dualTipKind
        var brushDualScale: Double = BrushPreset.defaultPencil.dualScale
        var brushDualSpacing: Double = BrushPreset.defaultPencil.dualSpacing
        var brushDualScatter: Double = BrushPreset.defaultPencil.dualScatter
        var brushDualAngle: Double = BrushPreset.defaultPencil.dualAngle
        var brushDualBlendMode: BrushDualBlendMode = BrushPreset.defaultPencil.dualBlendMode
        var brushGrainScale: Double = BrushPreset.defaultPencil.grainScale
        var brushGrainContrast: Double = BrushPreset.defaultPencil.grainContrast
        var brushPaperScale: Double = BrushPreset.defaultPencil.paperScale
        var brushPaperStrength: Double = BrushPreset.defaultPencil.paperStrength
        var brushPaperThreshold: Double = BrushPreset.defaultPencil.paperThreshold
        var brushFlipX: Bool = BrushPreset.defaultPencil.flipX
        var brushFlipY: Bool = BrushPreset.defaultPencil.flipY
        var brushCustomTip: BrushTipRaster? = BrushPreset.defaultPencil.customTip
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
        var presets: [BrushPreset] = BrushPreset.defaults
        var savedPresets: [BrushPreset] = BrushPresetStore.loadSavedPresets()

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
                sizeSpeedSensitivity: brushSizeSpeedSensitivity,
                opacity: brushOpacity,
                hardness: brushHardness,
                roundness: brushRoundness,
                roundnessPressureSensitivity: brushRoundnessPressureSensitivity,
                roundnessTiltSensitivity: brushRoundnessTiltSensitivity,
                angle: brushAngle,
                anglePressureSensitivity: brushAnglePressureSensitivity,
                angleTiltSensitivity: brushAngleTiltSensitivity,
                angleMode: brushAngleMode,
                stampSpacing: brushSpacing,
                spacingJitter: brushSpacingJitter,
                scatterEnabled: brushScatterEnabled,
                scatterMode: brushScatterMode,
                scatterLateral: brushScatterLateral,
                scatterLinear: brushScatterLinear,
                count: Int(brushCount.rounded()),
                countJitter: brushCountJitter,
                countSizeJitter: brushCountSizeJitter,
                countOpacityJitter: brushCountOpacityJitter,
                angleJitter: brushAngleJitter,
                roundnessJitter: brushRoundnessJitter,
                textureMode: brushTextureMode,
                textureStrength: brushTextureStrength,
                flow: brushFlow,
                flowPressureSensitivity: brushFlowPressureSensitivity,
                flowJitter: brushFlowJitter,
                wetness: brushWetness,
                wetnessPressureSensitivity: brushWetnessPressureSensitivity,
                opacityPressureSensitivity: brushOpacityPressureSensitivity,
                colorMixStrength: brushColorMixStrength,
                paintLoad: brushPaintLoad,
                loadPressureSensitivity: brushLoadPressureSensitivity,
                dualBrushEnabled: brushDualEnabled,
                dualTipKind: brushDualTipKind,
                dualScale: brushDualScale,
                dualSpacing: brushDualSpacing,
                dualScatter: brushDualScatter,
                dualAngle: brushDualAngle,
                dualBlendMode: brushDualBlendMode,
                grainScale: brushGrainScale,
                grainContrast: brushGrainContrast,
                paperScale: brushPaperScale,
                paperStrength: brushPaperStrength,
                paperThreshold: brushPaperThreshold,
                flipX: brushFlipX,
                flipY: brushFlipY,
                customTip: brushCustomTip,
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
        case importedPresets([BrushPreset])
        case saveCurrentBrushButtonTapped
        case deleteSavedPresetButtonTapped(String)
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
            case .binding(\.paperColor),
                 .binding(\.transparentPaper):
                return .none
            case .binding(\.brushColor),
                 .binding(\.brushTipKind),
                 .binding(\.brushRadius),
                 .binding(\.brushSizeSpeedSensitivity),
                 .binding(\.brushOpacity),
                 .binding(\.brushHardness),
                 .binding(\.brushRoundness),
                 .binding(\.brushRoundnessPressureSensitivity),
                 .binding(\.brushRoundnessTiltSensitivity),
                 .binding(\.brushAngle),
                 .binding(\.brushAnglePressureSensitivity),
                 .binding(\.brushAngleTiltSensitivity),
                 .binding(\.brushAngleMode),
                 .binding(\.brushSpacing),
                 .binding(\.brushSpacingJitter),
                 .binding(\.brushScatterEnabled),
                 .binding(\.brushScatterMode),
                 .binding(\.brushScatterLateral),
                 .binding(\.brushScatterLinear),
                 .binding(\.brushCount),
                 .binding(\.brushCountJitter),
                 .binding(\.brushCountSizeJitter),
                 .binding(\.brushCountOpacityJitter),
                 .binding(\.brushAngleJitter),
                 .binding(\.brushRoundnessJitter),
                 .binding(\.brushTextureMode),
                 .binding(\.brushTextureStrength),
                 .binding(\.brushFlow),
                 .binding(\.brushFlowPressureSensitivity),
                 .binding(\.brushFlowJitter),
                 .binding(\.brushWetness),
                 .binding(\.brushWetnessPressureSensitivity),
                 .binding(\.brushOpacityPressureSensitivity),
                 .binding(\.brushColorMixStrength),
                 .binding(\.brushPaintLoad),
                 .binding(\.brushLoadPressureSensitivity),
                 .binding(\.brushDualEnabled),
                 .binding(\.brushDualTipKind),
                 .binding(\.brushDualScale),
                 .binding(\.brushDualSpacing),
                 .binding(\.brushDualScatter),
                 .binding(\.brushDualAngle),
                 .binding(\.brushDualBlendMode),
                 .binding(\.brushGrainScale),
                 .binding(\.brushGrainContrast),
                 .binding(\.brushPaperScale),
                 .binding(\.brushPaperStrength),
                 .binding(\.brushPaperThreshold),
                 .binding(\.brushFlipX),
                 .binding(\.brushFlipY),
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
                 .binding(\.fillExpansion):
                state.selectedBrush = nil
                return .none
            case .binding:
                return .none
            case let .selectPreset(preset):
                state.applyPreset(preset)
                return .none
            case let .importedPresets(presets):
                let persistedPresets = state.persistImportedPresets(presets)
                let resolvedPresets = persistedPresets.isEmpty ? presets : persistedPresets
                state.presets.insert(contentsOf: resolvedPresets.reversed(), at: 0)
                if let first = resolvedPresets.first {
                    state.applyPreset(first)
                }
                return .none
            case .saveCurrentBrushButtonTapped:
                let savedNames = state.savedPresets.map(\.name)
                let isOverwritingSavedPreset = state.selectedBrush.map { selected in
                    state.savedPresets.contains(where: { $0.name == selected.name })
                } ?? false
                let baseName = state.selectedBrush?.name ?? (state.brushTipKind == .pencil ? "Custom Pencil" : "Custom Brush")
                let resolvedName = isOverwritingSavedPreset ? baseName : BrushPresetStore.uniqueName(basedOn: baseName, existingNames: savedNames)
                let preset = state.makeCurrentPreset(named: resolvedName)
                if let saved = try? BrushPresetStore.savePreset(preset, replacingExisting: isOverwritingSavedPreset) {
                    state.savedPresets = saved
                    if let matching = saved.first(where: { $0.name == resolvedName }) {
                        state.applyPreset(matching)
                    } else {
                        state.applyPreset(preset)
                    }
                }
                return .none
            case let .deleteSavedPresetButtonTapped(name):
                if let saved = try? BrushPresetStore.deletePreset(named: name) {
                    state.savedPresets = saved
                } else {
                    state.savedPresets.removeAll { $0.name == name }
                }
                state.presets.removeAll { $0.name == name }
                if state.selectedBrush?.name == name {
                    state.selectedBrush = nil
                }
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

private extension BrushPaletteFeature.State {
    mutating func applyPreset(_ preset: BrushPreset) {
        selectedBrush = preset
        brushTipKind = preset.tipKind
        brushRadius = preset.radius
        brushSizeSpeedSensitivity = preset.sizeSpeedSensitivity
        brushOpacity = preset.opacity
        brushHardness = preset.hardness
        brushRoundness = preset.roundness
        brushRoundnessPressureSensitivity = preset.roundnessPressureSensitivity
        brushRoundnessTiltSensitivity = preset.roundnessTiltSensitivity
        brushAngle = preset.angle
        brushAnglePressureSensitivity = preset.anglePressureSensitivity
        brushAngleTiltSensitivity = preset.angleTiltSensitivity
        brushAngleMode = preset.angleMode
        brushSpacing = preset.spacing
        brushSpacingJitter = preset.spacingJitter
        brushScatterEnabled = preset.scatterEnabled
        brushScatterMode = preset.scatterMode
        brushScatterLateral = preset.scatterLateral
        brushScatterLinear = preset.scatterLinear
        brushCount = Double(preset.count)
        brushCountJitter = preset.countJitter
        brushCountSizeJitter = preset.countSizeJitter
        brushCountOpacityJitter = preset.countOpacityJitter
        brushAngleJitter = preset.angleJitter
        brushRoundnessJitter = preset.roundnessJitter
        brushTextureMode = preset.textureMode
        brushTextureStrength = preset.textureStrength
        brushFlow = preset.flow
        brushFlowPressureSensitivity = preset.flowPressureSensitivity
        brushFlowJitter = preset.flowJitter
        brushWetness = preset.wetness
        brushWetnessPressureSensitivity = preset.wetnessPressureSensitivity
        brushOpacityPressureSensitivity = preset.opacityPressureSensitivity
        brushColorMixStrength = preset.colorMixStrength
        brushPaintLoad = preset.paintLoad
        brushLoadPressureSensitivity = preset.loadPressureSensitivity
        brushDualEnabled = preset.dualBrushEnabled
        brushDualTipKind = preset.dualTipKind
        brushDualScale = preset.dualScale
        brushDualSpacing = preset.dualSpacing
        brushDualScatter = preset.dualScatter
        brushDualAngle = preset.dualAngle
        brushDualBlendMode = preset.dualBlendMode
        brushGrainScale = preset.grainScale
        brushGrainContrast = preset.grainContrast
        brushPaperScale = preset.paperScale
        brushPaperStrength = preset.paperStrength
        brushPaperThreshold = preset.paperThreshold
        brushFlipX = preset.flipX
        brushFlipY = preset.flipY
        brushCustomTip = preset.customTip
        brushPressureSensitivity = preset.pressureSensitivity
    }

    func makeCurrentPreset(named name: String) -> BrushPreset {
        return BrushPreset(
            name: name,
            tipKind: brushTipKind,
            color: .white,
            radius: brushRadius,
            sizeSpeedSensitivity: brushSizeSpeedSensitivity,
            opacity: brushOpacity,
            hardness: brushHardness,
            roundness: brushRoundness,
            roundnessPressureSensitivity: brushRoundnessPressureSensitivity,
            roundnessTiltSensitivity: brushRoundnessTiltSensitivity,
            angle: brushAngle,
            anglePressureSensitivity: brushAnglePressureSensitivity,
            angleTiltSensitivity: brushAngleTiltSensitivity,
            angleMode: brushAngleMode,
            spacing: brushSpacing,
            spacingJitter: brushSpacingJitter,
            scatterEnabled: brushScatterEnabled,
            scatterMode: brushScatterMode,
            scatterLateral: brushScatterLateral,
            scatterLinear: brushScatterLinear,
            count: Int(brushCount.rounded()),
            countJitter: brushCountJitter,
            countSizeJitter: brushCountSizeJitter,
            countOpacityJitter: brushCountOpacityJitter,
            angleJitter: brushAngleJitter,
            roundnessJitter: brushRoundnessJitter,
            textureMode: brushTextureMode,
            textureStrength: brushTextureStrength,
            flow: brushFlow,
            flowPressureSensitivity: brushFlowPressureSensitivity,
            flowJitter: brushFlowJitter,
            wetness: brushWetness,
            wetnessPressureSensitivity: brushWetnessPressureSensitivity,
            opacityPressureSensitivity: brushOpacityPressureSensitivity,
            colorMixStrength: brushColorMixStrength,
            paintLoad: brushPaintLoad,
            loadPressureSensitivity: brushLoadPressureSensitivity,
            dualBrushEnabled: brushDualEnabled,
            dualTipKind: brushDualTipKind,
            dualScale: brushDualScale,
            dualSpacing: brushDualSpacing,
            dualScatter: brushDualScatter,
            dualAngle: brushDualAngle,
            dualBlendMode: brushDualBlendMode,
            grainScale: brushGrainScale,
            grainContrast: brushGrainContrast,
            paperScale: brushPaperScale,
            paperStrength: brushPaperStrength,
            paperThreshold: brushPaperThreshold,
            flipX: brushFlipX,
            flipY: brushFlipY,
            customTip: brushCustomTip,
            pressureSensitivity: brushPressureSensitivity,
            red: 255,
            green: 255,
            blue: 255
        )
    }

    mutating func persistImportedPresets(_ imported: [BrushPreset]) -> [BrushPreset] {
        guard !imported.isEmpty else { return [] }

        var resolvedImported: [BrushPreset] = []
        var workingSaved = savedPresets
        var usedNames = Set(savedPresets.map(\.name))
        usedNames.formUnion(presets.map(\.name))

        for preset in imported {
            let resolvedName = BrushPresetStore.uniqueName(
                basedOn: preset.name,
                existingNames: Array(usedNames)
            )
            let resolvedPreset = resolvedName == preset.name ? preset : BrushPreset(
                name: resolvedName,
                tipKind: preset.tipKind,
                color: preset.color,
                radius: preset.radius,
                sizeSpeedSensitivity: preset.sizeSpeedSensitivity,
                opacity: preset.opacity,
                hardness: preset.hardness,
                roundness: preset.roundness,
                roundnessPressureSensitivity: preset.roundnessPressureSensitivity,
                roundnessTiltSensitivity: preset.roundnessTiltSensitivity,
                angle: preset.angle,
                anglePressureSensitivity: preset.anglePressureSensitivity,
                angleTiltSensitivity: preset.angleTiltSensitivity,
                angleMode: preset.angleMode,
                spacing: preset.spacing,
                spacingJitter: preset.spacingJitter,
                scatterEnabled: preset.scatterEnabled,
                scatterMode: preset.scatterMode,
                scatterLateral: preset.scatterLateral,
                scatterLinear: preset.scatterLinear,
                count: preset.count,
                countJitter: preset.countJitter,
                countSizeJitter: preset.countSizeJitter,
                countOpacityJitter: preset.countOpacityJitter,
                angleJitter: preset.angleJitter,
                roundnessJitter: preset.roundnessJitter,
                textureMode: preset.textureMode,
                textureStrength: preset.textureStrength,
                flow: preset.flow,
                flowPressureSensitivity: preset.flowPressureSensitivity,
                flowJitter: preset.flowJitter,
                wetness: preset.wetness,
                wetnessPressureSensitivity: preset.wetnessPressureSensitivity,
                opacityPressureSensitivity: preset.opacityPressureSensitivity,
                colorMixStrength: preset.colorMixStrength,
                paintLoad: preset.paintLoad,
                loadPressureSensitivity: preset.loadPressureSensitivity,
                dualBrushEnabled: preset.dualBrushEnabled,
                dualTipKind: preset.dualTipKind,
                dualScale: preset.dualScale,
                dualSpacing: preset.dualSpacing,
                dualScatter: preset.dualScatter,
                dualAngle: preset.dualAngle,
                dualBlendMode: preset.dualBlendMode,
                grainScale: preset.grainScale,
                grainContrast: preset.grainContrast,
                paperScale: preset.paperScale,
                paperStrength: preset.paperStrength,
                paperThreshold: preset.paperThreshold,
                flipX: preset.flipX,
                flipY: preset.flipY,
                customTip: preset.customTip,
                pressureSensitivity: preset.pressureSensitivity,
                red: preset.red,
                green: preset.green,
                blue: preset.blue
            )
            usedNames.insert(resolvedName)
            resolvedImported.append(resolvedPreset)

            if let saved = try? BrushPresetStore.savePreset(resolvedPreset, replacingExisting: false) {
                workingSaved = saved
            }
        }

        savedPresets = workingSaved
        return resolvedImported
    }
}
