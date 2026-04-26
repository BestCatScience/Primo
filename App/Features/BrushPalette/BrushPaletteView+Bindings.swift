import SwiftUI
import UIKit

extension BrushPaletteView {
    var isTransparentBrushColorSelected: Bool {
        store.brush.usesTransparentColor
    }

    var activeBrushColor: Color {
        store.brush.activeColor
    }

    var activeBrushAccentColor: Color {
        isTransparentBrushColorSelected ? Color.white.opacity(0.78) : store.brush.activeOpaqueColor
    }

    var editableBrushColorBinding: Binding<Color> {
        Binding(
            get: { store.brush.activeOpaqueColor },
            set: { newColor in
                let keyPath: WritableKeyPath<BrushPaletteFeature.State, Color> =
                    store.brush.selectedColorSlot == .secondary ? \.brush.secondaryColor : \.brush.color
                store.send(.binding(.set(keyPath, newColor)))
            }
        )
    }

    var primaryBrushColorBinding: Binding<Color> {
        Binding(
            get: { store.brush.color },
            set: { store.send(.binding(.set(\.brush.color, $0))) }
        )
    }

    var secondaryBrushColorBinding: Binding<Color> {
        Binding(
            get: { store.brush.secondaryColor },
            set: { store.send(.binding(.set(\.brush.secondaryColor, $0))) }
        )
    }

    var selectedBrushColorSlotBinding: Binding<BrushColorSlot> {
        Binding(
            get: { store.brush.selectedColorSlot },
            set: { store.send(.binding(.set(\.brush.selectedColorSlot, $0))) }
        )
    }

    var paletteSwatchesBinding: Binding<[PaletteSwatch]> {
        Binding(
            get: { store.ui.paletteSwatches },
            set: { store.send(.binding(.set(\.ui.paletteSwatches, $0))) }
        )
    }

    var brushColorPalettePanel: some View {
        BrushColorPalettePanel(
            primaryColor: primaryBrushColorBinding,
            secondaryColor: secondaryBrushColorBinding,
            selectedSlot: selectedBrushColorSlotBinding,
            paletteSwatches: paletteSwatchesBinding,
            paletteColumns: paletteColumns,
            panelHairlineFill: panelHairlineFill,
            isTransparentSelected: isTransparentBrushColorSelected,
            transparentTitle: language.localized("透明色で描画")
        ) { swatchColor in
            store.send(
                .binding(
                    .set(
                        store.brush.selectedColorSlot == .secondary ? \.brush.secondaryColor : \.brush.color,
                        swatchColor
                    )
                )
            )
        }
    }

    var colorHexLabel: String {
        guard !isTransparentBrushColorSelected else {
            return language.localized("透明")
        }
        let resolved = UIColor(activeBrushColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return String(
            format: "#%02X%02X%02X",
            Int((red * 255.0).rounded()),
            Int((green * 255.0).rounded()),
            Int((blue * 255.0).rounded())
        )
    }

    var sizeControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: {
                if store.brush.pressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                switch newValue {
                case .off:
                    store.brush.pressureSensitivity = 0.0
                case .pressure:
                    if store.brush.pressureSensitivity <= 0.001 { store.brush.pressureSensitivity = 0.6 }
                case .speed, .tilt, .random:
                    break
                }
            }
        )
    }

    var sizeAmountBinding: Binding<Double> {
        Binding(
            get: {
                switch sizeControlBinding.wrappedValue {
                case .pressure: return store.brush.pressureSensitivity
                default: return 0.0
                }
            },
            set: { newValue in
                switch sizeControlBinding.wrappedValue {
                case .pressure: store.brush.pressureSensitivity = newValue
                default: break
                }
            }
        )
    }

    private func speedSliderValue(from sensitivity: Double) -> Double {
        min(max(100.0 + (sensitivity * 100.0), 0.0), 200.0)
    }

    private func speedSensitivity(from sliderValue: Double) -> Double {
        min(max((sliderValue - 100.0) / 100.0, -1.0), 1.0)
    }

    var speedSizeAmountBinding: Binding<Double> {
        Binding(
            get: { speedSliderValue(from: store.brush.sizeSpeedSensitivity) },
            set: { store.brush.sizeSpeedSensitivity = speedSensitivity(from: $0) }
        )
    }

    var speedOpacityAmountBinding: Binding<Double> {
        Binding(
            get: { speedSliderValue(from: store.brush.velocityInfluence) },
            set: { store.brush.velocityInfluence = speedSensitivity(from: $0) }
        )
    }

    private func taperSliderValue(from amount: Double) -> Double {
        min(max((1.0 - amount) * 100.0, 0.0), 100.0)
    }

    private func taperAmount(from sliderValue: Double) -> Double {
        min(max(1.0 - (sliderValue / 100.0), 0.0), 1.0)
    }

    var taperInAmountBinding: Binding<Double> {
        Binding(
            get: { taperSliderValue(from: store.brush.taperIn) },
            set: { store.brush.taperIn = taperAmount(from: $0) }
        )
    }

    var taperOutAmountBinding: Binding<Double> {
        Binding(
            get: { taperSliderValue(from: store.brush.taperOut) },
            set: { store.brush.taperOut = taperAmount(from: $0) }
        )
    }

    var roundnessControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: {
                if store.brush.roundnessJitter > 0.001 { return .random }
                if store.brush.roundnessTiltSensitivity > 0.001 { return .tilt }
                if store.brush.roundnessPressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                store.brush.roundnessPressureSensitivity = 0.0
                store.brush.roundnessTiltSensitivity = 0.0
                store.brush.roundnessJitter = 0.0
                switch newValue {
                case .pressure:
                    store.brush.roundnessPressureSensitivity = 0.24
                case .tilt:
                    store.brush.roundnessTiltSensitivity = 0.24
                case .random:
                    store.brush.roundnessJitter = 0.12
                case .off, .speed:
                    break
                }
            }
        )
    }

    var roundnessAmountBinding: Binding<Double> {
        Binding(
            get: {
                switch roundnessControlBinding.wrappedValue {
                case .pressure: return store.brush.roundnessPressureSensitivity
                case .tilt: return store.brush.roundnessTiltSensitivity
                case .random: return store.brush.roundnessJitter
                default: return 0.0
                }
            },
            set: { newValue in
                switch roundnessControlBinding.wrappedValue {
                case .pressure: store.brush.roundnessPressureSensitivity = newValue
                case .tilt: store.brush.roundnessTiltSensitivity = newValue
                case .random: store.brush.roundnessJitter = newValue
                default: break
                }
            }
        )
    }

    var angleControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: {
                if store.brush.angleJitter > 0.001 { return .random }
                if store.brush.angleTiltSensitivity > 0.001 { return .tilt }
                if store.brush.anglePressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                store.brush.anglePressureSensitivity = 0.0
                store.brush.angleTiltSensitivity = 0.0
                store.brush.angleJitter = 0.0
                switch newValue {
                case .pressure:
                    store.brush.anglePressureSensitivity = 0.16
                case .tilt:
                    store.brush.angleTiltSensitivity = 0.24
                case .random:
                    store.brush.angleJitter = 0.14
                case .off, .speed:
                    break
                }
            }
        )
    }

    var angleAmountBinding: Binding<Double> {
        Binding(
            get: {
                switch angleControlBinding.wrappedValue {
                case .pressure: return store.brush.anglePressureSensitivity
                case .tilt: return store.brush.angleTiltSensitivity
                case .random: return min(1.0, store.brush.angleJitter)
                default: return 0.0
                }
            },
            set: { newValue in
                switch angleControlBinding.wrappedValue {
                case .pressure: store.brush.anglePressureSensitivity = newValue
                case .tilt: store.brush.angleTiltSensitivity = newValue
                case .random: store.brush.angleJitter = newValue
                default: break
                }
            }
        )
    }

    var opacityControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: { store.brush.opacityPressureSensitivity > 0.001 ? .pressure : .off },
            set: { newValue in
                store.brush.opacityPressureSensitivity = newValue == .pressure ? max(store.brush.opacityPressureSensitivity, 0.4) : 0.0
            }
        )
    }

    var opacityAmountBinding: Binding<Double> {
        Binding(
            get: { 1.0 - store.brush.opacityPressureSensitivity },
            set: { store.brush.opacityPressureSensitivity = 1.0 - $0 }
        )
    }

    var flowControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: {
                if store.brush.flowJitter > 0.001 { return .random }
                if store.brush.flowPressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                store.brush.flowPressureSensitivity = 0.0
                store.brush.flowJitter = 0.0
                switch newValue {
                case .pressure:
                    store.brush.flowPressureSensitivity = 0.24
                case .random:
                    store.brush.flowJitter = 0.18
                case .off, .tilt, .speed:
                    break
                }
            }
        )
    }

    var flowAmountBinding: Binding<Double> {
        Binding(
            get: {
                switch flowControlBinding.wrappedValue {
                case .pressure: return 1.0 - store.brush.flowPressureSensitivity
                case .random: return 1.0 - store.brush.flowJitter
                default: return 0.0
                }
            },
            set: { newValue in
                switch flowControlBinding.wrappedValue {
                case .pressure: store.brush.flowPressureSensitivity = 1.0 - newValue
                case .random: store.brush.flowJitter = 1.0 - newValue
                default: break
                }
            }
        )
    }

    var wetnessControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: { store.brush.wetnessPressureSensitivity > 0.001 ? .pressure : .off },
            set: { newValue in
                store.brush.wetnessPressureSensitivity = newValue == .pressure ? max(store.brush.wetnessPressureSensitivity, 0.3) : 0.0
            }
        )
    }

    var wetnessAmountBinding: Binding<Double> {
        Binding(
            get: { 1.0 - store.brush.wetnessPressureSensitivity },
            set: { store.brush.wetnessPressureSensitivity = 1.0 - $0 }
        )
    }

    var loadControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: { store.brush.loadPressureSensitivity > 0.001 ? .pressure : .off },
            set: { newValue in
                store.brush.loadPressureSensitivity = newValue == .pressure ? max(store.brush.loadPressureSensitivity, 0.24) : 0.0
            }
        )
    }

    var loadAmountBinding: Binding<Double> {
        Binding(
            get: { 1.0 - store.brush.loadPressureSensitivity },
            set: { store.brush.loadPressureSensitivity = 1.0 - $0 }
        )
    }
}
