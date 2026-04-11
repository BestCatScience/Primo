import ComposableArchitecture
import Foundation
import SwiftUI
import UIKit

@Reducer
struct BrushPaletteFeature {
    @ObservableState
    struct State: Equatable {
        struct BrushSettings: Equatable {
            var tipKind: BrushTipKind = BrushPreset.defaultPencil.tipKind
            var radius: Double = BrushPreset.defaultPencil.radius
            var sizeSpeedSensitivity: Double = BrushPreset.defaultPencil.sizeSpeedSensitivity
            var opacity: Double = BrushPreset.defaultPencil.opacity
            var hardness: Double = BrushPreset.defaultPencil.hardness
            var roundness: Double = BrushPreset.defaultPencil.roundness
            var roundnessPressureSensitivity: Double = BrushPreset.defaultPencil.roundnessPressureSensitivity
            var roundnessTiltSensitivity: Double = BrushPreset.defaultPencil.roundnessTiltSensitivity
            var angle: Double = BrushPreset.defaultPencil.angle
            var anglePressureSensitivity: Double = BrushPreset.defaultPencil.anglePressureSensitivity
            var angleTiltSensitivity: Double = BrushPreset.defaultPencil.angleTiltSensitivity
            var angleMode: BrushAngleMode = BrushPreset.defaultPencil.angleMode
            var spacing: Double = BrushPreset.defaultPencil.spacing
            var spacingJitter: Double = BrushPreset.defaultPencil.spacingJitter
            var scatterEnabled: Bool = BrushPreset.defaultPencil.scatterEnabled
            var scatterMode: BrushScatterMode = BrushPreset.defaultPencil.scatterMode
            var scatterLateral: Double = BrushPreset.defaultPencil.scatterLateral
            var scatterLinear: Double = BrushPreset.defaultPencil.scatterLinear
            var count: Double = Double(BrushPreset.defaultPencil.count)
            var countJitter: Double = BrushPreset.defaultPencil.countJitter
            var countSizeJitter: Double = BrushPreset.defaultPencil.countSizeJitter
            var countOpacityJitter: Double = BrushPreset.defaultPencil.countOpacityJitter
            var angleJitter: Double = BrushPreset.defaultPencil.angleJitter
            var roundnessJitter: Double = BrushPreset.defaultPencil.roundnessJitter
            var textureMode: BrushTextureMode = BrushPreset.defaultPencil.textureMode
            var textureStrength: Double = BrushPreset.defaultPencil.textureStrength
            var flow: Double = BrushPreset.defaultPencil.flow
            var flowPressureSensitivity: Double = BrushPreset.defaultPencil.flowPressureSensitivity
            var flowJitter: Double = BrushPreset.defaultPencil.flowJitter
            var velocityInfluence: Double = BrushPreset.defaultPencil.velocityInfluence
            var wetness: Double = BrushPreset.defaultPencil.wetness
            var wetnessPressureSensitivity: Double = BrushPreset.defaultPencil.wetnessPressureSensitivity
            var opacityPressureSensitivity: Double = BrushPreset.defaultPencil.opacityPressureSensitivity
            var colorMixStrength: Double = BrushPreset.defaultPencil.colorMixStrength
            var paintLoad: Double = BrushPreset.defaultPencil.paintLoad
            var loadPressureSensitivity: Double = BrushPreset.defaultPencil.loadPressureSensitivity
            var dualEnabled: Bool = BrushPreset.defaultPencil.dualBrushEnabled
            var dualTipKind: BrushTipKind = BrushPreset.defaultPencil.dualTipKind
            var dualScale: Double = BrushPreset.defaultPencil.dualScale
            var dualSpacing: Double = BrushPreset.defaultPencil.dualSpacing
            var dualScatter: Double = BrushPreset.defaultPencil.dualScatter
            var dualAngle: Double = BrushPreset.defaultPencil.dualAngle
            var dualBlendMode: BrushDualBlendMode = BrushPreset.defaultPencil.dualBlendMode
            var grainScale: Double = BrushPreset.defaultPencil.grainScale
            var grainContrast: Double = BrushPreset.defaultPencil.grainContrast
            var paperScale: Double = BrushPreset.defaultPencil.paperScale
            var paperStrength: Double = BrushPreset.defaultPencil.paperStrength
            var paperThreshold: Double = BrushPreset.defaultPencil.paperThreshold
            var flipX: Bool = BrushPreset.defaultPencil.flipX
            var flipY: Bool = BrushPreset.defaultPencil.flipY
            var customTip: BrushTipRaster? = BrushPreset.defaultPencil.customTip
            var pressureSensitivity: Double = BrushPreset.defaultPencil.pressureSensitivity
            var stabilization: Double = 0.0
            var color: Color = BrushPreset.defaultPencil.color
            var secondaryColor: Color = Color(red: 0.92, green: 0.94, blue: 0.98)
            var selectedColorSlot: BrushColorSlot = .primary

            var activeColor: Color {
                switch selectedColorSlot {
                case .primary:
                    return color
                case .secondary:
                    return secondaryColor
                case .transparent:
                    return .clear
                }
            }

            var activeOpaqueColor: Color {
                switch selectedColorSlot {
                case .primary, .transparent:
                    return color
                case .secondary:
                    return secondaryColor
                }
            }

            var usesTransparentColor: Bool {
                selectedColorSlot == .transparent
            }

            mutating func setSelectedSlotColor(_ newColor: Color) {
                switch selectedColorSlot {
                case .primary:
                    color = newColor
                case .secondary:
                    secondaryColor = newColor
                case .transparent:
                    break
                }
            }

            func runtimeSettings(fill: FillSettings) -> BrushRuntimeSettings {
                let resolved = UIColor(activeOpaqueColor)
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                resolved.getRed(&red, green: &green, blue: &blue, alpha: nil)
                return BrushRuntimeSettings(
                    tipKind: tipKind,
                    radius: radius,
                    sizeSpeedSensitivity: sizeSpeedSensitivity,
                    opacity: opacity,
                    hardness: hardness,
                    roundness: roundness,
                    roundnessPressureSensitivity: roundnessPressureSensitivity,
                    roundnessTiltSensitivity: roundnessTiltSensitivity,
                    angle: angle,
                    anglePressureSensitivity: anglePressureSensitivity,
                    angleTiltSensitivity: angleTiltSensitivity,
                    angleMode: angleMode,
                    stampSpacing: spacing,
                    spacingJitter: spacingJitter,
                    scatterEnabled: scatterEnabled,
                    scatterMode: scatterMode,
                    scatterLateral: scatterLateral,
                    scatterLinear: scatterLinear,
                    count: Int(count.rounded()),
                    countJitter: countJitter,
                    countSizeJitter: countSizeJitter,
                    countOpacityJitter: countOpacityJitter,
                    angleJitter: angleJitter,
                    roundnessJitter: roundnessJitter,
                    textureMode: textureMode,
                    textureStrength: textureStrength,
                    flow: flow,
                    flowPressureSensitivity: flowPressureSensitivity,
                    flowJitter: flowJitter,
                    velocityInfluence: velocityInfluence,
                    wetness: wetness,
                    wetnessPressureSensitivity: wetnessPressureSensitivity,
                    opacityPressureSensitivity: opacityPressureSensitivity,
                    colorMixStrength: colorMixStrength,
                    paintLoad: paintLoad,
                    loadPressureSensitivity: loadPressureSensitivity,
                    dualBrushEnabled: dualEnabled,
                    dualTipKind: dualTipKind,
                    dualScale: dualScale,
                    dualSpacing: dualSpacing,
                    dualScatter: dualScatter,
                    dualAngle: dualAngle,
                    dualBlendMode: dualBlendMode,
                    grainScale: grainScale,
                    grainContrast: grainContrast,
                    paperScale: paperScale,
                    paperStrength: paperStrength,
                    paperThreshold: paperThreshold,
                    flipX: flipX,
                    flipY: flipY,
                    customTip: customTip,
                    pressureSensitivity: pressureSensitivity,
                    stabilization: stabilization,
                    fillThresholdMode: fill.thresholdMode,
                    fillOpacityTolerance: fill.opacityTolerance,
                    fillColorTolerance: fill.colorTolerance,
                    fillExpansion: Int(fill.expansion.rounded()),
                    red: UInt8(min(max(Double(red) * 255.0, 0), 255)),
                    green: UInt8(min(max(Double(green) * 255.0, 0), 255)),
                    blue: UInt8(min(max(Double(blue) * 255.0, 0), 255))
                )
            }

            mutating func applyPreset(_ preset: BrushPreset) {
                let preservedRadius = radius
                tipKind = preset.tipKind
                radius = preservedRadius
                sizeSpeedSensitivity = preset.sizeSpeedSensitivity
                opacity = preset.opacity
                hardness = preset.hardness
                roundness = preset.roundness
                roundnessPressureSensitivity = preset.roundnessPressureSensitivity
                roundnessTiltSensitivity = preset.roundnessTiltSensitivity
                angle = preset.angle
                anglePressureSensitivity = preset.anglePressureSensitivity
                angleTiltSensitivity = preset.angleTiltSensitivity
                angleMode = preset.angleMode
                spacing = preset.spacing
                spacingJitter = preset.spacingJitter
                scatterEnabled = preset.scatterEnabled
                scatterMode = preset.scatterMode
                scatterLateral = preset.scatterLateral
                scatterLinear = preset.scatterLinear
                count = Double(preset.count)
                countJitter = preset.countJitter
                countSizeJitter = preset.countSizeJitter
                countOpacityJitter = preset.countOpacityJitter
                angleJitter = preset.angleJitter
                roundnessJitter = preset.roundnessJitter
                textureMode = preset.textureMode
                textureStrength = preset.textureStrength
                flow = preset.flow
                flowPressureSensitivity = preset.flowPressureSensitivity
                flowJitter = preset.flowJitter
                velocityInfluence = preset.velocityInfluence
                wetness = preset.wetness
                wetnessPressureSensitivity = preset.wetnessPressureSensitivity
                opacityPressureSensitivity = preset.opacityPressureSensitivity
                colorMixStrength = preset.colorMixStrength
                paintLoad = preset.paintLoad
                loadPressureSensitivity = preset.loadPressureSensitivity
                dualEnabled = preset.dualBrushEnabled
                dualTipKind = preset.dualTipKind
                dualScale = preset.dualScale
                dualSpacing = preset.dualSpacing
                dualScatter = preset.dualScatter
                dualAngle = preset.dualAngle
                dualBlendMode = preset.dualBlendMode
                grainScale = preset.grainScale
                grainContrast = preset.grainContrast
                paperScale = preset.paperScale
                paperStrength = preset.paperStrength
                paperThreshold = preset.paperThreshold
                flipX = preset.flipX
                flipY = preset.flipY
                customTip = preset.customTip
                pressureSensitivity = preset.pressureSensitivity
            }

            func makePreset(named name: String) -> BrushPreset {
                let storedRadius = BrushPreset.defaults.first(where: { $0.tipKind == tipKind })?.radius ?? radius

                return BrushPreset(
                    name: name,
                    tipKind: tipKind,
                    color: .white,
                    radius: storedRadius,
                    sizeSpeedSensitivity: sizeSpeedSensitivity,
                    opacity: opacity,
                    hardness: hardness,
                    roundness: roundness,
                    roundnessPressureSensitivity: roundnessPressureSensitivity,
                    roundnessTiltSensitivity: roundnessTiltSensitivity,
                    angle: angle,
                    anglePressureSensitivity: anglePressureSensitivity,
                    angleTiltSensitivity: angleTiltSensitivity,
                    angleMode: angleMode,
                    spacing: spacing,
                    spacingJitter: spacingJitter,
                    scatterEnabled: scatterEnabled,
                    scatterMode: scatterMode,
                    scatterLateral: scatterLateral,
                    scatterLinear: scatterLinear,
                    count: Int(count.rounded()),
                    countJitter: countJitter,
                    countSizeJitter: countSizeJitter,
                    countOpacityJitter: countOpacityJitter,
                    angleJitter: angleJitter,
                    roundnessJitter: roundnessJitter,
                    textureMode: textureMode,
                    textureStrength: textureStrength,
                    flow: flow,
                    flowPressureSensitivity: flowPressureSensitivity,
                    flowJitter: flowJitter,
                    velocityInfluence: velocityInfluence,
                    wetness: wetness,
                    wetnessPressureSensitivity: wetnessPressureSensitivity,
                    opacityPressureSensitivity: opacityPressureSensitivity,
                    colorMixStrength: colorMixStrength,
                    paintLoad: paintLoad,
                    loadPressureSensitivity: loadPressureSensitivity,
                    dualBrushEnabled: dualEnabled,
                    dualTipKind: dualTipKind,
                    dualScale: dualScale,
                    dualSpacing: dualSpacing,
                    dualScatter: dualScatter,
                    dualAngle: dualAngle,
                    dualBlendMode: dualBlendMode,
                    grainScale: grainScale,
                    grainContrast: grainContrast,
                    paperScale: paperScale,
                    paperStrength: paperStrength,
                    paperThreshold: paperThreshold,
                    flipX: flipX,
                    flipY: flipY,
                    customTip: customTip,
                    pressureSensitivity: pressureSensitivity,
                    red: 255,
                    green: 255,
                    blue: 255
                )
            }
        }

        struct SelectionSettings: Equatable {
            var toolMode: SelectionToolMode = .lasso
            var combineMode: SelectionCombineMode = .replace
            var thresholdMode: FillThresholdMode = .color
            var opacityTolerance: Double = 0.08
            var colorTolerance: Double = 0.12
            var expansion: Double = 0
        }

        struct FillSettings: Equatable {
            var thresholdMode: FillThresholdMode = .opacity
            var opacityTolerance: Double = 0.08
            var colorTolerance: Double = 0.12
            var expansion: Double = 0
        }

        struct ShapeSettings: Equatable {
            var mode: ShapeToolMode = .line
        }

        struct SamplingSettings: Equatable {
            var eyedropperSource: EyedropperSamplingSource = .activeLayer
        }

        struct PaperSettings: Equatable {
            var color: Color = .white
            var isTransparent = false
        }

        struct LibraryState: Equatable {
            var selectedBrush: BrushPreset? = .defaultPencil
            var presets: [BrushPreset] = BrushPreset.defaults
            var savedPresets: [BrushPreset] = BrushPresetStore.loadSavedPresets()
        }

        struct UIState: Equatable {
            var showsBrushSettingsPopover = false
        }

        var brush = BrushSettings()
        var selection = SelectionSettings()
        var fill = FillSettings()
        var shape = ShapeSettings()
        var sampling = SamplingSettings()
        var paper = PaperSettings()
        var library = LibraryState()
        var ui = UIState()

        var runtimeSettings: BrushRuntimeSettings {
            brush.runtimeSettings(fill: fill)
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case selectPreset(BrushPreset)
        case importedPresets([BrushPreset])
        case saveCurrentBrushButtonTapped
        case resetCurrentBrushSettingsButtonTapped
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
        case invertSelection
        case expandSelection(Int)
        case contractSelection(Int)
        case applyTransform
        case cancelTransform
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.paper.color),
                 .binding(\.paper.isTransparent):
                return .none

            case .binding(\.brush.color),
                 .binding(\.brush.secondaryColor),
                 .binding(\.brush.selectedColorSlot),
                 .binding(\.brush.tipKind),
                 .binding(\.brush.radius),
                 .binding(\.brush.sizeSpeedSensitivity),
                 .binding(\.brush.opacity),
                 .binding(\.brush.hardness),
                 .binding(\.brush.roundness),
                 .binding(\.brush.roundnessPressureSensitivity),
                 .binding(\.brush.roundnessTiltSensitivity),
                 .binding(\.brush.angle),
                 .binding(\.brush.anglePressureSensitivity),
                 .binding(\.brush.angleTiltSensitivity),
                 .binding(\.brush.angleMode),
                 .binding(\.brush.spacing),
                 .binding(\.brush.spacingJitter),
                 .binding(\.brush.scatterEnabled),
                 .binding(\.brush.scatterMode),
                 .binding(\.brush.scatterLateral),
                 .binding(\.brush.scatterLinear),
                 .binding(\.brush.count),
                 .binding(\.brush.countJitter),
                 .binding(\.brush.countSizeJitter),
                 .binding(\.brush.countOpacityJitter),
                 .binding(\.brush.angleJitter),
                 .binding(\.brush.roundnessJitter),
                 .binding(\.brush.textureMode),
                 .binding(\.brush.textureStrength),
                 .binding(\.brush.flow),
                 .binding(\.brush.flowPressureSensitivity),
                 .binding(\.brush.flowJitter),
                 .binding(\.brush.velocityInfluence),
                 .binding(\.brush.wetness),
                 .binding(\.brush.wetnessPressureSensitivity),
                 .binding(\.brush.opacityPressureSensitivity),
                 .binding(\.brush.colorMixStrength),
                 .binding(\.brush.paintLoad),
                 .binding(\.brush.loadPressureSensitivity),
                 .binding(\.brush.dualEnabled),
                 .binding(\.brush.dualTipKind),
                 .binding(\.brush.dualScale),
                 .binding(\.brush.dualSpacing),
                 .binding(\.brush.dualScatter),
                 .binding(\.brush.dualAngle),
                 .binding(\.brush.dualBlendMode),
                 .binding(\.brush.grainScale),
                 .binding(\.brush.grainContrast),
                 .binding(\.brush.paperScale),
                 .binding(\.brush.paperStrength),
                 .binding(\.brush.paperThreshold),
                 .binding(\.brush.flipX),
                 .binding(\.brush.flipY),
                 .binding(\.brush.pressureSensitivity),
                 .binding(\.brush.stabilization),
                 .binding(\.selection.toolMode),
                 .binding(\.selection.combineMode),
                 .binding(\.selection.thresholdMode),
                 .binding(\.selection.opacityTolerance),
                 .binding(\.selection.colorTolerance),
                 .binding(\.selection.expansion),
                 .binding(\.fill.thresholdMode),
                 .binding(\.fill.opacityTolerance),
                 .binding(\.fill.colorTolerance),
                 .binding(\.fill.expansion),
                 .binding(\.shape.mode),
                 .binding(\.sampling.eyedropperSource):
                state.library.selectedBrush = nil
                return .none

            case .binding:
                return .none

            case let .selectPreset(preset):
                state.applyPreset(preset)
                return .none

            case let .importedPresets(presets):
                let persistedPresets = state.persistImportedPresets(presets)
                let resolvedPresets = persistedPresets.isEmpty ? presets : persistedPresets
                state.library.presets.insert(contentsOf: resolvedPresets.reversed(), at: 0)
                if let first = resolvedPresets.first {
                    state.applyPreset(first)
                }
                return .none

            case .saveCurrentBrushButtonTapped:
                let savedNames = state.library.savedPresets.map(\.name)
                let isOverwritingSavedPreset = state.library.selectedBrush.map { selected in
                    state.library.savedPresets.contains(where: { $0.name == selected.name })
                } ?? false
                let baseName = state.library.selectedBrush?.name ?? (state.brush.tipKind == .pencil ? "Custom Pencil" : "Custom Brush")
                let resolvedName = isOverwritingSavedPreset ? baseName : BrushPresetStore.uniqueName(basedOn: baseName, existingNames: savedNames)
                let preset = state.brush.makePreset(named: resolvedName)
                if let saved = try? BrushPresetStore.savePreset(preset, replacingExisting: isOverwritingSavedPreset) {
                    state.library.savedPresets = saved
                    if let matching = saved.first(where: { $0.name == resolvedName }) {
                        state.applyPreset(matching)
                    } else {
                        state.applyPreset(preset)
                    }
                }
                return .none

            case .resetCurrentBrushSettingsButtonTapped:
                state.applyPreset(state.library.selectedBrush ?? .defaultPencil)
                return .none

            case let .deleteSavedPresetButtonTapped(name):
                if let saved = try? BrushPresetStore.deletePreset(named: name) {
                    state.library.savedPresets = saved
                } else {
                    state.library.savedPresets.removeAll { $0.name == name }
                }
                state.library.presets.removeAll { $0.name == name }
                if state.library.selectedBrush?.name == name {
                    state.library.selectedBrush = nil
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
        library.selectedBrush = preset
        brush.applyPreset(preset)
    }

    mutating func persistImportedPresets(_ imported: [BrushPreset]) -> [BrushPreset] {
        guard !imported.isEmpty else { return [] }

        var resolvedImported: [BrushPreset] = []
        var workingSaved = library.savedPresets
        var usedNames = Set(library.savedPresets.map(\.name))
        usedNames.formUnion(library.presets.map(\.name))

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
                velocityInfluence: preset.velocityInfluence,
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

        library.savedPresets = workingSaved
        return resolvedImported
    }
}
