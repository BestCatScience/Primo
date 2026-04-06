import SwiftUI
import UIKit

extension BrushPaletteView {
    var colorHexLabel: String {
        let resolved = UIColor(store.brush.color)
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
                if store.brush.sizeSpeedSensitivity > 0.001 { return .speed }
                if store.brush.pressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                switch newValue {
                case .off:
                    store.brush.pressureSensitivity = 0.0
                    store.brush.sizeSpeedSensitivity = 0.0
                case .pressure:
                    if store.brush.pressureSensitivity <= 0.001 { store.brush.pressureSensitivity = 0.6 }
                    store.brush.sizeSpeedSensitivity = 0.0
                case .speed:
                    store.brush.pressureSensitivity = 0.0
                    if store.brush.sizeSpeedSensitivity <= 0.001 { store.brush.sizeSpeedSensitivity = 0.25 }
                case .tilt, .random:
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
                case .speed: return store.brush.sizeSpeedSensitivity
                default: return 0.0
                }
            },
            set: { newValue in
                switch sizeControlBinding.wrappedValue {
                case .pressure: store.brush.pressureSensitivity = newValue
                case .speed: store.brush.sizeSpeedSensitivity = newValue
                default: break
                }
            }
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

    var velocityDensityControlBinding: Binding<Bool> {
        Binding(
            get: { store.brush.velocityInfluence > 0.001 },
            set: { enabled in
                store.brush.velocityInfluence = enabled ? 0.012 : 0.0
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
