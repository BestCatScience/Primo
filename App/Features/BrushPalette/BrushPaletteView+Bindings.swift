import SwiftUI
import UIKit

extension BrushPaletteView {
    var colorHexLabel: String {
        let resolved = UIColor(store.brushColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
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
                if store.brushSizeSpeedSensitivity > 0.001 { return .speed }
                if store.brushPressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                switch newValue {
                case .off:
                    store.brushPressureSensitivity = 0.0
                    store.brushSizeSpeedSensitivity = 0.0
                case .pressure:
                    if store.brushPressureSensitivity <= 0.001 { store.brushPressureSensitivity = 0.6 }
                    store.brushSizeSpeedSensitivity = 0.0
                case .speed:
                    store.brushPressureSensitivity = 0.0
                    if store.brushSizeSpeedSensitivity <= 0.001 { store.brushSizeSpeedSensitivity = 0.25 }
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
                case .pressure: return store.brushPressureSensitivity
                case .speed: return store.brushSizeSpeedSensitivity
                default: return 0.0
                }
            },
            set: { newValue in
                switch sizeControlBinding.wrappedValue {
                case .pressure: store.brushPressureSensitivity = newValue
                case .speed: store.brushSizeSpeedSensitivity = newValue
                default: break
                }
            }
        )
    }

    var roundnessControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: {
                if store.brushRoundnessJitter > 0.001 { return .random }
                if store.brushRoundnessTiltSensitivity > 0.001 { return .tilt }
                if store.brushRoundnessPressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                store.brushRoundnessPressureSensitivity = 0.0
                store.brushRoundnessTiltSensitivity = 0.0
                store.brushRoundnessJitter = 0.0
                switch newValue {
                case .pressure:
                    store.brushRoundnessPressureSensitivity = 0.24
                case .tilt:
                    store.brushRoundnessTiltSensitivity = 0.24
                case .random:
                    store.brushRoundnessJitter = 0.12
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
                case .pressure: return store.brushRoundnessPressureSensitivity
                case .tilt: return store.brushRoundnessTiltSensitivity
                case .random: return store.brushRoundnessJitter
                default: return 0.0
                }
            },
            set: { newValue in
                switch roundnessControlBinding.wrappedValue {
                case .pressure: store.brushRoundnessPressureSensitivity = newValue
                case .tilt: store.brushRoundnessTiltSensitivity = newValue
                case .random: store.brushRoundnessJitter = newValue
                default: break
                }
            }
        )
    }

    var angleControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: {
                if store.brushAngleJitter > 0.001 { return .random }
                if store.brushAngleTiltSensitivity > 0.001 { return .tilt }
                if store.brushAnglePressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                store.brushAnglePressureSensitivity = 0.0
                store.brushAngleTiltSensitivity = 0.0
                store.brushAngleJitter = 0.0
                switch newValue {
                case .pressure:
                    store.brushAnglePressureSensitivity = 0.16
                case .tilt:
                    store.brushAngleTiltSensitivity = 0.24
                case .random:
                    store.brushAngleJitter = 0.14
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
                case .pressure: return store.brushAnglePressureSensitivity
                case .tilt: return store.brushAngleTiltSensitivity
                case .random: return min(1.0, store.brushAngleJitter)
                default: return 0.0
                }
            },
            set: { newValue in
                switch angleControlBinding.wrappedValue {
                case .pressure: store.brushAnglePressureSensitivity = newValue
                case .tilt: store.brushAngleTiltSensitivity = newValue
                case .random: store.brushAngleJitter = newValue
                default: break
                }
            }
        )
    }

    var opacityControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: { store.brushOpacityPressureSensitivity > 0.001 ? .pressure : .off },
            set: { newValue in
                store.brushOpacityPressureSensitivity = newValue == .pressure ? max(store.brushOpacityPressureSensitivity, 0.4) : 0.0
            }
        )
    }

    var opacityAmountBinding: Binding<Double> {
        Binding(
            get: { 1.0 - store.brushOpacityPressureSensitivity },
            set: { store.brushOpacityPressureSensitivity = 1.0 - $0 }
        )
    }

    var flowControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: {
                if store.brushFlowJitter > 0.001 { return .random }
                if store.brushFlowPressureSensitivity > 0.001 { return .pressure }
                return .off
            },
            set: { newValue in
                store.brushFlowPressureSensitivity = 0.0
                store.brushFlowJitter = 0.0
                switch newValue {
                case .pressure:
                    store.brushFlowPressureSensitivity = 0.24
                case .random:
                    store.brushFlowJitter = 0.18
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
                case .pressure: return 1.0 - store.brushFlowPressureSensitivity
                case .random: return 1.0 - store.brushFlowJitter
                default: return 0.0
                }
            },
            set: { newValue in
                switch flowControlBinding.wrappedValue {
                case .pressure: store.brushFlowPressureSensitivity = 1.0 - newValue
                case .random: store.brushFlowJitter = 1.0 - newValue
                default: break
                }
            }
        )
    }

    var velocityDensityControlBinding: Binding<Bool> {
        Binding(
            get: { store.brushVelocityInfluence > 0.001 },
            set: { enabled in
                store.brushVelocityInfluence = enabled ? 0.012 : 0.0
            }
        )
    }

    var wetnessControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: { store.brushWetnessPressureSensitivity > 0.001 ? .pressure : .off },
            set: { newValue in
                store.brushWetnessPressureSensitivity = newValue == .pressure ? max(store.brushWetnessPressureSensitivity, 0.3) : 0.0
            }
        )
    }

    var wetnessAmountBinding: Binding<Double> {
        Binding(
            get: { 1.0 - store.brushWetnessPressureSensitivity },
            set: { store.brushWetnessPressureSensitivity = 1.0 - $0 }
        )
    }

    var loadControlBinding: Binding<PhotoshopDynamicControl> {
        Binding(
            get: { store.brushLoadPressureSensitivity > 0.001 ? .pressure : .off },
            set: { newValue in
                store.brushLoadPressureSensitivity = newValue == .pressure ? max(store.brushLoadPressureSensitivity, 0.24) : 0.0
            }
        )
    }

    var loadAmountBinding: Binding<Double> {
        Binding(
            get: { 1.0 - store.brushLoadPressureSensitivity },
            set: { store.brushLoadPressureSensitivity = 1.0 - $0 }
        )
    }
}
