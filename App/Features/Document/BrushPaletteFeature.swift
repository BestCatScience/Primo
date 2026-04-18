import ComposableArchitecture
import Foundation
import SwiftUI
import UIKit

@Reducer
struct BrushPaletteFeature {
    static let maximumBrushRadius: Double = 256

    fileprivate struct LibraryBootstrap {
        let savedPresets: [BrushPreset]
        let availableFonts: [TextFontOption]
    }

    @ObservableState
    struct State: Equatable {
        struct BrushSettings: Equatable {
            var tipKind: BrushTipKind = BrushPreset.defaultPencil.tipKind
            var radius: Double = BrushPreset.defaultPencil.radius
            var brushToolRadius: Double = BrushPreset.defaultPencil.radius
            var eraserToolRadius: Double = 16.0
            var sizeSpeedSensitivity: Double = BrushPreset.defaultPencil.sizeSpeedSensitivity
            var taperIn: Double = BrushPreset.defaultPencil.taperIn
            var taperOut: Double = BrushPreset.defaultPencil.taperOut
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
            var colorMixingMode: BrushColorMixingMode = BrushPreset.defaultPencil.colorMixingMode
            var wetness: Double = BrushPreset.defaultPencil.wetness
            var wetnessPressureSensitivity: Double = BrushPreset.defaultPencil.wetnessPressureSensitivity
            var opacityPressureSensitivity: Double = BrushPreset.defaultPencil.opacityPressureSensitivity
            var colorMixStrength: Double = BrushPreset.defaultPencil.colorMixStrength
            var smudgeBlurEnabled: Bool = BrushPreset.defaultPencil.smudgeBlurEnabled
            var smudgeBleed: Double = BrushPreset.defaultPencil.smudgeBleed
            var smudgeRadius: Double = BrushPreset.defaultPencil.smudgeRadius
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
                    taperIn: taperIn,
                    taperOut: taperOut,
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
                    colorMixingMode: colorMixingMode,
                    wetness: wetness,
                    wetnessPressureSensitivity: wetnessPressureSensitivity,
                    opacityPressureSensitivity: opacityPressureSensitivity,
                    colorMixStrength: colorMixStrength,
                    smudgeBlurEnabled: smudgeBlurEnabled,
                    smudgeBleed: smudgeBleed,
                    smudgeRadius: smudgeRadius,
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
                taperIn = preset.taperIn
                taperOut = preset.taperOut
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
                colorMixingMode = preset.colorMixingMode
                wetness = preset.wetness
                wetnessPressureSensitivity = preset.wetnessPressureSensitivity
                opacityPressureSensitivity = preset.opacityPressureSensitivity
                colorMixStrength = preset.colorMixStrength
                smudgeBlurEnabled = preset.smudgeBlurEnabled
                smudgeBleed = preset.smudgeBleed
                smudgeRadius = preset.smudgeRadius
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

            func storedRadius(for tool: StudioToolKind) -> Double {
                switch tool {
                case .erase:
                    return eraserToolRadius
                default:
                    return brushToolRadius
                }
            }

            mutating func storeCurrentRadius(for tool: StudioToolKind) {
                switch tool {
                case .erase:
                    eraserToolRadius = radius
                default:
                    brushToolRadius = radius
                }
            }

            mutating func applyStoredRadius(for tool: StudioToolKind) {
                radius = storedRadius(for: tool)
            }

            func makePreset(named name: String) -> BrushPreset {
                let storedRadius = BrushPreset.defaults.first(where: { $0.tipKind == tipKind })?.radius ?? radius

                return BrushPreset(
                    name: name,
                    tipKind: tipKind,
                    color: .white,
                    radius: storedRadius,
                    sizeSpeedSensitivity: sizeSpeedSensitivity,
                    taperIn: taperIn,
                    taperOut: taperOut,
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
                    smudgeBlurEnabled: smudgeBlurEnabled,
                    smudgeBleed: smudgeBleed,
                    smudgeRadius: smudgeRadius,
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

        struct TextSettings: Equatable {
            var content = "Text"
            var fontSize: Double = 64
            var position: CGPoint?
            var scale: Double = 1.0
            var rotationDegrees: Double = 0
            var targetLayerIndex: Int?
            var availableFonts: [TextFontOption]
            var selectedFontPostScriptName: String?
            var selectedFontDisplayName: String?

            init() {
                availableFonts = []
                selectedFontPostScriptName = nil
                selectedFontDisplayName = nil
            }
        }

        struct LibraryState: Equatable {
            var selectedBrush: BrushPreset? = .defaultPencil
            var presets: [BrushPreset] = BrushPreset.defaults
            var savedPresets: [BrushPreset] = []
        }

        struct UIState: Equatable {
            var showsBrushSettingsPopover = false
            var hasLoadedLibrary = false
            var brushLibraryErrorMessage: String?
            var textFontImportErrorMessage: String?
        }

        var brush = BrushSettings()
        var selection = SelectionSettings()
        var fill = FillSettings()
        var shape = ShapeSettings()
        var sampling = SamplingSettings()
        var paper = PaperSettings()
        var text = TextSettings()
        var library = LibraryState()
        var ui = UIState()

        var runtimeSettings: BrushRuntimeSettings {
            brush.runtimeSettings(fill: fill)
        }
    }

    enum Action: BindableAction, Equatable {
        case task
        case binding(BindingAction<State>)
        case selectPreset(BrushPreset)
        case bootstrapLoaded(savedPresets: [BrushPreset], availableFonts: [TextFontOption])
        case importedPresets([BrushPreset])
        case importedTextFonts([TextFontOption])
        case importBrushesRequested([URL])
        case importTextFontsRequested([URL])
        case importCustomTipRequested(URL)
        case customTipImported(BrushTipRaster)
        case brushLibraryErrorOccurred(String)
        case textFontImportErrorOccurred(String)
        case dismissBrushLibraryError
        case dismissTextFontImportError
        case saveCurrentBrushButtonTapped
        case resetCurrentBrushSettingsButtonTapped
        case deleteSavedPresetButtonTapped(String)
        case renameSavedPresetButtonTapped(oldName: String, newName: String)
        case setTextPlacement(CGPoint)
        case configureTextForActiveLayer(TextLayerDraft?)
        case applyTextButtonTapped
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
        case applyText(TextLayerDraft)
    }

    @Dependency(\.brushPresetLibraryClient) var brushPresetLibraryClient
    @Dependency(\.brushImportClient) var brushImportClient
    @Dependency(\.textFontLibraryClient) var textFontLibraryClient
    @Dependency(\.appLanguageClient) var appLanguageClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .task:
                guard !state.ui.hasLoadedLibrary else { return .none }
                state.ui.hasLoadedLibrary = true
                return .run { [brushPresetLibraryClient, textFontLibraryClient] send in
                    await send(
                        .bootstrapLoaded(
                            savedPresets: brushPresetLibraryClient.loadSavedPresets(),
                            availableFonts: textFontLibraryClient.loadAvailableFonts()
                        )
                    )
                }

            case let .bootstrapLoaded(savedPresets, availableFonts):
                state.applyLibraryBootstrap(
                    LibraryBootstrap(
                        savedPresets: savedPresets,
                        availableFonts: availableFonts
                    )
                )
                return .none

            case .binding(\.paper.color),
                 .binding(\.paper.isTransparent):
                return .none

            case .binding(\.brush.radius):
                state.brush.radius = min(max(state.brush.radius, 1), Self.maximumBrushRadius)
                return .none

            case .binding(\.brush.color),
                 .binding(\.brush.secondaryColor),
                 .binding(\.brush.selectedColorSlot),
                 .binding(\.brush.tipKind),
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

            case .binding(\.text.content),
                 .binding(\.text.fontSize),
                 .binding(\.text.selectedFontPostScriptName),
                 .binding(\.text.selectedFontDisplayName):
                return .none

            case .binding:
                return .none

            case let .selectPreset(preset):
                state.applyPreset(preset)
                return .none

            case let .importedPresets(presets):
                state.library.presets.insert(contentsOf: presets.reversed(), at: 0)
                if let first = presets.first {
                    state.applyPreset(first)
                }
                return .none

            case let .importedTextFonts(fonts):
                if let selected = fonts.first {
                    state.text.selectedFontPostScriptName = selected.postScriptName
                    state.text.selectedFontDisplayName = selected.displayName
                }
                return .none

            case let .importBrushesRequested(urls):
                let existingNames = state.library.savedPresets.map(\.name) + state.library.presets.map(\.name)
                let resolvedLanguage = appLanguageClient.load()
                return .run { [brushImportClient, brushPresetLibraryClient] send in
                    let importedResult = brushImportClient.importBrushPresets(
                        BrushPresetImportRequest(urls: urls, language: resolvedLanguage)
                    )

                    var usedNames = Set(existingNames)
                    var workingSaved = brushPresetLibraryClient.loadSavedPresets()
                    var resolvedImported: [BrushPreset] = []
                    var failureMessages = importedResult.failureMessages

                    for preset in importedResult.presets {
                        let resolvedName = brushPresetLibraryClient.uniqueName(
                            preset.name,
                            Array(usedNames)
                        )
                        let resolvedPreset = resolvedName == preset.name
                            ? preset
                            : preset.renamed(to: resolvedName)
                        usedNames.insert(resolvedName)
                        resolvedImported.append(resolvedPreset)
                        do {
                            workingSaved = try brushPresetLibraryClient.savePreset(
                                resolvedPreset,
                                false
                            )
                        } catch {
                            failureMessages.append(
                                "\(resolvedPreset.name): \(error.localizedDescription)"
                            )
                        }
                    }

                    await send(.bootstrapLoaded(savedPresets: workingSaved, availableFonts: []))
                    if !resolvedImported.isEmpty {
                        await send(.importedPresets(resolvedImported))
                    }
                    if !failureMessages.isEmpty {
                        await send(.brushLibraryErrorOccurred(failureMessages.joined(separator: "\n")))
                    }
                }

            case let .importTextFontsRequested(urls):
                let savedPresets = state.library.savedPresets
                return .run { [brushImportClient, textFontLibraryClient] send in
                    let importResult = brushImportClient.importTextFonts(
                        TextFontImportRequest(urls: urls)
                    )
                    await send(
                        .bootstrapLoaded(
                            savedPresets: savedPresets,
                            availableFonts: textFontLibraryClient.loadAvailableFonts()
                        )
                    )
                    if !importResult.fonts.isEmpty {
                        await send(.importedTextFonts(importResult.fonts))
                    }
                    if !importResult.failureMessages.isEmpty {
                        await send(
                            .textFontImportErrorOccurred(
                                importResult.failureMessages.joined(separator: "\n")
                            )
                        )
                    }
                }

            case let .importCustomTipRequested(url):
                return .run { [brushImportClient] send in
                    switch brushImportClient.loadCustomTip(url) {
                    case let .success(customTip):
                        await send(.customTipImported(customTip))
                    case let .failure(error):
                        await send(
                            .brushLibraryErrorOccurred(
                                error.localizedDescription
                            )
                        )
                    }
                }

            case let .customTipImported(customTip):
                state.brush.customTip = customTip
                return .none

            case let .brushLibraryErrorOccurred(message):
                state.ui.brushLibraryErrorMessage = message
                return .none

            case let .textFontImportErrorOccurred(message):
                state.ui.textFontImportErrorMessage = message
                return .none

            case .dismissBrushLibraryError:
                state.ui.brushLibraryErrorMessage = nil
                return .none

            case .dismissTextFontImportError:
                state.ui.textFontImportErrorMessage = nil
                return .none

            case let .setTextPlacement(position):
                state.text.position = position
                return .none

            case let .configureTextForActiveLayer(draft):
                if let draft {
                    state.text.content = draft.text
                    state.text.fontSize = draft.fontSize
                    state.text.position = draft.position
                    state.text.scale = draft.scale
                    state.text.rotationDegrees = draft.rotationDegrees
                    state.text.targetLayerIndex = draft.targetLayerIndex
                    state.text.selectedFontPostScriptName = draft.fontPostScriptName
                    state.text.selectedFontDisplayName = draft.fontDisplayName
                } else {
                    state.text.targetLayerIndex = nil
                    state.text.scale = 1.0
                    state.text.rotationDegrees = 0
                    if state.text.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        state.text.content = "Text"
                    }
                }
                return .none

            case .applyTextButtonTapped:
                let trimmed = state.text.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                guard let position = state.text.position else { return .none }
                let draft = TextLayerDraft(
                    targetLayerIndex: state.text.targetLayerIndex,
                    text: trimmed,
                    position: position,
                    fontPostScriptName: state.text.selectedFontPostScriptName,
                    fontDisplayName: state.text.selectedFontDisplayName,
                    fontSize: state.text.fontSize,
                    scale: state.text.scale,
                    rotationDegrees: state.text.rotationDegrees
                )
                return .send(.delegate(.applyText(draft)))

            case .saveCurrentBrushButtonTapped:
                let savedNames = state.library.savedPresets.map(\.name)
                let isOverwritingSavedPreset = state.library.selectedBrush.map { selected in
                    state.library.savedPresets.contains(where: { $0.name == selected.name })
                } ?? false
                let baseName = state.library.selectedBrush?.name ?? (state.brush.tipKind == .pencil ? "Custom Pencil" : "Custom Brush")
                let resolvedName = isOverwritingSavedPreset
                    ? baseName
                    : brushPresetLibraryClient.uniqueName(baseName, savedNames)
                let preset = state.brush.makePreset(named: resolvedName)
                return .run { [brushPresetLibraryClient] send in
                    do {
                        let saved = try brushPresetLibraryClient.savePreset(
                            preset,
                            isOverwritingSavedPreset
                        )
                        await send(.bootstrapLoaded(savedPresets: saved, availableFonts: []))
                        if let matching = saved.first(where: { $0.name == resolvedName }) {
                            await send(.selectPreset(matching))
                        } else {
                            await send(.selectPreset(preset))
                        }
                    } catch {
                        await send(.brushLibraryErrorOccurred(error.localizedDescription))
                    }
                }

            case .resetCurrentBrushSettingsButtonTapped:
                state.applyPreset(state.library.selectedBrush ?? .defaultPencil)
                return .none

            case let .deleteSavedPresetButtonTapped(name):
                return .run { [brushPresetLibraryClient] send in
                    do {
                        let saved = try brushPresetLibraryClient.deletePreset(name)
                        await send(.bootstrapLoaded(savedPresets: saved, availableFonts: []))
                    } catch {
                        await send(.brushLibraryErrorOccurred(error.localizedDescription))
                    }
                }

            case let .renameSavedPresetButtonTapped(oldName, newName):
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                let selectedBrushName = state.library.selectedBrush?.name
                let selectedCustomTip = state.brush.customTip
                return .run { [brushPresetLibraryClient] send in
                    do {
                        let saved = try brushPresetLibraryClient.renamePreset(oldName, trimmed)
                        await send(.bootstrapLoaded(savedPresets: saved, availableFonts: []))
                        if selectedBrushName == oldName,
                           let renamed = saved.first(where: { $0.name == trimmed })
                            ?? saved.first(where: { $0.customTip == selectedCustomTip }) {
                            await send(.selectPreset(renamed))
                        }
                    } catch {
                        await send(.brushLibraryErrorOccurred(error.localizedDescription))
                    }
                }

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

extension BrushPaletteFeature.State {
    fileprivate mutating func applyLibraryBootstrap(_ bootstrap: BrushPaletteFeature.LibraryBootstrap) {
        library.savedPresets = bootstrap.savedPresets
        if !bootstrap.availableFonts.isEmpty {
            text.availableFonts = bootstrap.availableFonts
            if text.selectedFontPostScriptName == nil, let first = bootstrap.availableFonts.first {
                text.selectedFontPostScriptName = first.postScriptName
                text.selectedFontDisplayName = first.displayName
            }
        }
    }

    mutating func syncPaper(
        color: Color,
        isTransparent: Bool
    ) {
        paper.color = color
        paper.isTransparent = isTransparent
    }

    mutating func applyLoadedPaperStyle(_ paperStyle: CanvasPaperStyle) {
        syncPaper(
            color: Color(
                red: Double(paperStyle.red),
                green: Double(paperStyle.green),
                blue: Double(paperStyle.blue),
                opacity: Double(paperStyle.alpha)
            ),
            isTransparent: paperStyle.isTransparent
        )
    }

    mutating func ensureTextPlacement(in canvasSize: CGSize) {
        guard text.position == nil else { return }
        text.position = CGPoint(
            x: canvasSize.width * 0.12,
            y: canvasSize.height * 0.12
        )
    }

    mutating func setTextPlacement(_ point: CGPoint) {
        text.position = point
    }

    mutating func syncTextEditor(with activeLayer: LayerRowModel?) {
        guard let activeLayer else {
            text.targetLayerIndex = nil
            text.scale = 1.0
            text.rotationDegrees = 0
            return
        }
        guard let textLayer = activeLayer.textLayer else {
            text.targetLayerIndex = nil
            text.scale = 1.0
            text.rotationDegrees = 0
            return
        }
        text.content = textLayer.text
        text.fontSize = textLayer.fontSize
        text.position = textLayer.position
        text.scale = textLayer.scale
        text.rotationDegrees = textLayer.rotationDegrees
        text.targetLayerIndex = activeLayer.index
        text.selectedFontPostScriptName = textLayer.fontPostScriptName
        text.selectedFontDisplayName = textLayer.fontDisplayName
    }

    mutating func setTextTargetLayer(_ index: Int?) {
        text.targetLayerIndex = index
    }

    mutating func presentBrushSettingsPopover() {
        ui.showsBrushSettingsPopover = true
    }

    mutating func clearSelectedPreset() {
        library.selectedBrush = nil
    }

    mutating func applySampledColor(_ color: Color) {
        if brush.selectedColorSlot == .transparent {
            brush.selectedColorSlot = .primary
        }
        brush.setSelectedSlotColor(color)
        clearSelectedPreset()
    }
}

private extension BrushPaletteFeature.State {
    mutating func applyPreset(_ preset: BrushPreset) {
        library.selectedBrush = preset
        brush.applyPreset(preset)
    }
}

private extension BrushPreset {
    func renamed(to newName: String) -> BrushPreset {
        BrushPreset(
            name: newName,
            tipKind: tipKind,
            color: color,
            radius: radius,
            sizeSpeedSensitivity: sizeSpeedSensitivity,
            taperIn: taperIn,
            taperOut: taperOut,
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
            count: count,
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
            smudgeBlurEnabled: smudgeBlurEnabled,
            smudgeBleed: smudgeBleed,
            smudgeRadius: smudgeRadius,
            paintLoad: paintLoad,
            loadPressureSensitivity: loadPressureSensitivity,
            dualBrushEnabled: dualBrushEnabled,
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
            red: red,
            green: green,
            blue: blue
        )
    }
}
