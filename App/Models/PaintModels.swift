import Foundation
import SwiftUI
import CoreGraphics
import simd

enum StudioToolKind: String, CaseIterable, Equatable, Sendable, Identifiable {
    case brush
    case erase
    case fill
    case eyedropper
    case select
    case move
    case shape

    var id: String { rawValue }

    var title: String {
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .brush:
            return language.localized("Brush")
        case .erase:
            return language.localized("Erase")
        case .fill:
            return language.localized("Fill")
        case .eyedropper:
            return language.localized("Eyedropper")
        case .select:
            return language.localized("Select")
        case .move:
            return language.localized("Move")
        case .shape:
            return language.localized("Shape")
        }
    }

    var systemImage: String {
        switch self {
        case .brush:
            return "paintbrush.pointed"
        case .erase:
            return "eraser"
        case .fill:
            return "paintbrush.fill"
        case .eyedropper:
            return "eyedropper"
        case .select:
            return "lasso"
        case .move:
            return "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left"
        case .shape:
            return "square.on.circle"
        }
    }
}

enum EyedropperSamplingSource: String, CaseIterable, Equatable, Sendable, Identifiable {
    case activeLayer
    case canvas

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .activeLayer:
            return language.localized("Active Layer")
        case .canvas:
            return language.localized("Canvas")
        }
    }
}

enum FillThresholdMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case opacity
    case color

    var id: String { rawValue }

    var title: String {
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .opacity:
            return language.localized("Opacity")
        case .color:
            return language.localized("Color")
        }
    }
}

enum SelectionToolMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case lasso
    case auto

    var id: String { rawValue }

    var title: String {
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .lasso:
            return language.localized("Lasso")
        case .auto:
            return language.localized("Auto")
        }
    }
}

enum SelectionCombineMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case replace
    case add
    case subtract

    var id: String { rawValue }

    var title: String {
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .replace:
            return language.localized("Replace")
        case .add:
            return language.localized("Add")
        case .subtract:
            return language.localized("Subtract")
        }
    }
}

enum LayerBlendMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case normal
    case darken
    case multiply
    case colorBurn
    case linearBurn
    case subtract
    case lighten
    case screen
    case colorDodge
    case glowDodge
    case overlay
    case softLight
    case hardLight
    case difference
    case vividLight
    case linearLight
    case pinLight
    case hardMix
    case exclusion
    case darkerColor
    case lighterColor
    case divide
    case hue
    case saturation
    case color
    case add
    case addGlow
    case luminosity

    var id: String { rawValue }

    var title: String {
        localizedTitle(.japanese)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .normal:
            return language.localized("Normal")
        case .darken:
            return language.localized("Darken")
        case .multiply:
            return language.localized("Multiply")
        case .colorBurn:
            return language.localized("Color Burn")
        case .linearBurn:
            return language.localized("Linear Burn")
        case .subtract:
            return language.localized("Subtract")
        case .lighten:
            return language.localized("Lighten")
        case .screen:
            return language.localized("Screen")
        case .colorDodge:
            return language.localized("Color Dodge")
        case .glowDodge:
            return language.localized("Glow Dodge")
        case .overlay:
            return language.localized("Overlay")
        case .softLight:
            return language.localized("Soft Light")
        case .hardLight:
            return language.localized("Hard Light")
        case .difference:
            return language.localized("Difference")
        case .vividLight:
            return language.localized("Vivid Light")
        case .linearLight:
            return language.localized("Linear Light")
        case .pinLight:
            return language.localized("Pin Light")
        case .hardMix:
            return language.localized("Hard Mix")
        case .exclusion:
            return language.localized("Exclusion")
        case .darkerColor:
            return language.localized("Darker Color")
        case .lighterColor:
            return language.localized("Lighter Color")
        case .divide:
            return language.localized("Divide")
        case .hue:
            return language.localized("Hue")
        case .saturation:
            return language.localized("Saturation")
        case .color:
            return language.localized("Color")
        case .add:
            return language.localized("Add")
        case .addGlow:
            return language.localized("Add Glow")
        case .luminosity:
            return language.localized("Luminosity")
        }
    }
}

enum BrushTipKind: String, CaseIterable, Equatable, Sendable, Identifiable {
    case pencil
    case ink
    case oil
    case airbrush

    var id: String { rawValue }

    var title: String {
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .pencil:
            return language.localized("Pencil")
        case .ink:
            return language.localized("Ink")
        case .oil:
            return language.localized("Oil")
        case .airbrush:
            return language.localized("Airbrush")
        }
    }

    var systemImage: String {
        switch self {
        case .pencil:
            return "pencil.tip"
        case .ink:
            return "paintbrush.pointed"
        case .oil:
            return "paintbrush"
        case .airbrush:
            return "aqi.low"
        }
    }
}

enum BrushAngleMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case fixed
    case strokeDirection
    case stylusTilt

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .fixed:
            return language.localized("Fixed")
        case .strokeDirection:
            return language.localized("Direction")
        case .stylusTilt:
            return language.localized("Tilt")
        }
    }
}

enum BrushTextureMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case off
    case strokeLocked
    case eachTip
    case moving

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .off:
            return language.localized("Off")
        case .strokeLocked:
            return language.localized("Stroke")
        case .eachTip:
            return language.localized("Each Tip")
        case .moving:
            return language.localized("Moving")
        }
    }
}

enum BrushDualBlendMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case multiply
    case darker
    case subtract

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .multiply:
            return language.localized("Multiply")
        case .darker:
            return language.localized("Darker")
        case .subtract:
            return language.localized("Subtract")
        }
    }
}

enum BrushScatterMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case directional
    case spray

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .directional:
            return language.localized("Directional")
        case .spray:
            return language.localized("Spray")
        }
    }
}

struct CanvasPaperStyle: Equatable, Sendable {
    var red: Float
    var green: Float
    var blue: Float
    var alpha: Float
    var isTransparent: Bool

    static let `default` = CanvasPaperStyle(
        red: 0.93,
        green: 0.93,
        blue: 0.91,
        alpha: 1.0,
        isTransparent: false
    )
}

struct BrushPreset: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let tipKind: BrushTipKind
    let color: Color
    let radius: Double
    let sizeSpeedSensitivity: Double
    let opacity: Double
    let hardness: Double
    let roundness: Double
    let roundnessPressureSensitivity: Double
    let roundnessTiltSensitivity: Double
    let angle: Double
    let anglePressureSensitivity: Double
    let angleTiltSensitivity: Double
    let angleMode: BrushAngleMode
    let spacing: Double
    let spacingJitter: Double
    let scatterEnabled: Bool
    let scatterMode: BrushScatterMode
    let scatterLateral: Double
    let scatterLinear: Double
    let count: Int
    let countJitter: Double
    let countSizeJitter: Double
    let countOpacityJitter: Double
    let angleJitter: Double
    let roundnessJitter: Double
    let textureMode: BrushTextureMode
    let textureStrength: Double
    let flow: Double
    let flowPressureSensitivity: Double
    let flowJitter: Double
    let velocityInfluence: Double
    let wetness: Double
    let wetnessPressureSensitivity: Double
    let opacityPressureSensitivity: Double
    let colorMixStrength: Double
    let paintLoad: Double
    let loadPressureSensitivity: Double
    let dualBrushEnabled: Bool
    let dualTipKind: BrushTipKind
    let dualScale: Double
    let dualSpacing: Double
    let dualScatter: Double
    let dualAngle: Double
    let dualBlendMode: BrushDualBlendMode
    let grainScale: Double
    let grainContrast: Double
    let paperScale: Double
    let paperStrength: Double
    let paperThreshold: Double
    let flipX: Bool
    let flipY: Bool
    let customTip: BrushTipRaster?
    let pressureSensitivity: Double
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    static func == (lhs: BrushPreset, rhs: BrushPreset) -> Bool {
        lhs.name == rhs.name &&
        lhs.tipKind == rhs.tipKind &&
        lhs.radius == rhs.radius &&
        lhs.sizeSpeedSensitivity == rhs.sizeSpeedSensitivity &&
        lhs.opacity == rhs.opacity &&
        lhs.hardness == rhs.hardness &&
        lhs.roundness == rhs.roundness &&
        lhs.roundnessPressureSensitivity == rhs.roundnessPressureSensitivity &&
        lhs.roundnessTiltSensitivity == rhs.roundnessTiltSensitivity &&
        lhs.angle == rhs.angle &&
        lhs.anglePressureSensitivity == rhs.anglePressureSensitivity &&
        lhs.angleTiltSensitivity == rhs.angleTiltSensitivity &&
        lhs.angleMode == rhs.angleMode &&
        lhs.spacing == rhs.spacing &&
        lhs.spacingJitter == rhs.spacingJitter &&
        lhs.scatterEnabled == rhs.scatterEnabled &&
        lhs.scatterMode == rhs.scatterMode &&
        lhs.scatterLateral == rhs.scatterLateral &&
        lhs.scatterLinear == rhs.scatterLinear &&
        lhs.count == rhs.count &&
        lhs.countJitter == rhs.countJitter &&
        lhs.countSizeJitter == rhs.countSizeJitter &&
        lhs.countOpacityJitter == rhs.countOpacityJitter &&
        lhs.angleJitter == rhs.angleJitter &&
        lhs.roundnessJitter == rhs.roundnessJitter &&
        lhs.textureMode == rhs.textureMode &&
        lhs.textureStrength == rhs.textureStrength &&
        lhs.flow == rhs.flow &&
        lhs.flowPressureSensitivity == rhs.flowPressureSensitivity &&
        lhs.flowJitter == rhs.flowJitter &&
        lhs.velocityInfluence == rhs.velocityInfluence &&
        lhs.wetness == rhs.wetness &&
        lhs.wetnessPressureSensitivity == rhs.wetnessPressureSensitivity &&
        lhs.opacityPressureSensitivity == rhs.opacityPressureSensitivity &&
        lhs.colorMixStrength == rhs.colorMixStrength &&
        lhs.paintLoad == rhs.paintLoad &&
        lhs.loadPressureSensitivity == rhs.loadPressureSensitivity &&
        lhs.dualBrushEnabled == rhs.dualBrushEnabled &&
        lhs.dualTipKind == rhs.dualTipKind &&
        lhs.dualScale == rhs.dualScale &&
        lhs.dualSpacing == rhs.dualSpacing &&
        lhs.dualScatter == rhs.dualScatter &&
        lhs.dualAngle == rhs.dualAngle &&
        lhs.dualBlendMode == rhs.dualBlendMode &&
        lhs.grainScale == rhs.grainScale &&
        lhs.grainContrast == rhs.grainContrast &&
        lhs.paperScale == rhs.paperScale &&
        lhs.paperStrength == rhs.paperStrength &&
        lhs.paperThreshold == rhs.paperThreshold &&
        lhs.flipX == rhs.flipX &&
        lhs.flipY == rhs.flipY &&
        lhs.customTip == rhs.customTip &&
        lhs.pressureSensitivity == rhs.pressureSensitivity &&
        lhs.red == rhs.red &&
        lhs.green == rhs.green &&
        lhs.blue == rhs.blue
    }

    init(
        name: String,
        tipKind: BrushTipKind,
        color: Color,
        radius: Double,
        sizeSpeedSensitivity: Double = 0.0,
        opacity: Double,
        hardness: Double,
        roundness: Double,
        roundnessPressureSensitivity: Double = 0.0,
        roundnessTiltSensitivity: Double = 0.0,
        angle: Double,
        anglePressureSensitivity: Double = 0.0,
        angleTiltSensitivity: Double = 0.0,
        angleMode: BrushAngleMode,
        spacing: Double,
        spacingJitter: Double,
        scatterEnabled: Bool = false,
        scatterMode: BrushScatterMode = .directional,
        scatterLateral: Double,
        scatterLinear: Double,
        count: Int,
        countJitter: Double,
        countSizeJitter: Double = 0.0,
        countOpacityJitter: Double = 0.0,
        angleJitter: Double,
        roundnessJitter: Double,
        textureMode: BrushTextureMode,
        textureStrength: Double,
        flow: Double,
        flowPressureSensitivity: Double = 0.0,
        flowJitter: Double = 0.0,
        velocityInfluence: Double = 0.0,
        wetness: Double = 0.0,
        wetnessPressureSensitivity: Double = 0.0,
        opacityPressureSensitivity: Double = 0.0,
        colorMixStrength: Double = 0.0,
        paintLoad: Double = 1.0,
        loadPressureSensitivity: Double = 0.0,
        dualBrushEnabled: Bool = false,
        dualTipKind: BrushTipKind = .ink,
        dualScale: Double = 0.72,
        dualSpacing: Double = 0.26,
        dualScatter: Double = 0.18,
        dualAngle: Double = 0.0,
        dualBlendMode: BrushDualBlendMode = .multiply,
        grainScale: Double = 1.35,
        grainContrast: Double = 1.7,
        paperScale: Double = 0.12,
        paperStrength: Double = 0.32,
        paperThreshold: Double = 0.42,
        flipX: Bool,
        flipY: Bool,
        customTip: BrushTipRaster? = nil,
        pressureSensitivity: Double,
        red: UInt8,
        green: UInt8,
        blue: UInt8
    ) {
        self.name = name
        self.tipKind = tipKind
        self.color = color
        self.radius = radius
        self.sizeSpeedSensitivity = sizeSpeedSensitivity
        self.opacity = opacity
        self.hardness = hardness
        self.roundness = roundness
        self.roundnessPressureSensitivity = roundnessPressureSensitivity
        self.roundnessTiltSensitivity = roundnessTiltSensitivity
        self.angle = angle
        self.anglePressureSensitivity = anglePressureSensitivity
        self.angleTiltSensitivity = angleTiltSensitivity
        self.angleMode = angleMode
        self.spacing = spacing
        self.spacingJitter = spacingJitter
        self.scatterEnabled = scatterEnabled
        self.scatterMode = scatterMode
        self.scatterLateral = scatterLateral
        self.scatterLinear = scatterLinear
        self.count = count
        self.countJitter = countJitter
        self.countSizeJitter = countSizeJitter
        self.countOpacityJitter = countOpacityJitter
        self.angleJitter = angleJitter
        self.roundnessJitter = roundnessJitter
        self.textureMode = textureMode
        self.textureStrength = textureStrength
        self.flow = flow
        self.flowPressureSensitivity = flowPressureSensitivity
        self.flowJitter = flowJitter
        self.velocityInfluence = velocityInfluence
        self.wetness = wetness
        self.wetnessPressureSensitivity = wetnessPressureSensitivity
        self.opacityPressureSensitivity = opacityPressureSensitivity
        self.colorMixStrength = colorMixStrength
        self.paintLoad = paintLoad
        self.loadPressureSensitivity = loadPressureSensitivity
        self.dualBrushEnabled = dualBrushEnabled
        self.dualTipKind = dualTipKind
        self.dualScale = dualScale
        self.dualSpacing = dualSpacing
        self.dualScatter = dualScatter
        self.dualAngle = dualAngle
        self.dualBlendMode = dualBlendMode
        self.grainScale = grainScale
        self.grainContrast = grainContrast
        self.paperScale = paperScale
        self.paperStrength = paperStrength
        self.paperThreshold = paperThreshold
        self.flipX = flipX
        self.flipY = flipY
        self.customTip = customTip
        self.pressureSensitivity = pressureSensitivity
        self.red = red
        self.green = green
        self.blue = blue
    }

    static let defaults: [BrushPreset] = [
        BrushPreset(
            name: "6B Pencil",
            tipKind: .pencil,
            color: Color(red: 0.12, green: 0.12, blue: 0.13),
            radius: 3.2,
            sizeSpeedSensitivity: 0.0,
            opacity: 0.92,
            hardness: 0.80,
            roundness: 0.86,
            roundnessPressureSensitivity: 0.12,
            roundnessTiltSensitivity: 0.22,
            angle: 0.10,
            anglePressureSensitivity: 0.04,
            angleTiltSensitivity: 0.18,
            angleMode: .strokeDirection,
            spacing: 0.12,
            spacingJitter: 0.0,
            scatterEnabled: false,
            scatterMode: .directional,
            scatterLateral: 0.03,
            scatterLinear: 0.01,
            count: 1,
            countJitter: 0.0,
            countSizeJitter: 0.0,
            countOpacityJitter: 0.0,
            angleJitter: 0.02,
            roundnessJitter: 0.03,
            textureMode: .eachTip,
            textureStrength: 0.88,
            flow: 0.84,
            flowPressureSensitivity: 0.20,
            flowJitter: 0.04,
            wetness: 0.10,
            wetnessPressureSensitivity: 0.18,
            opacityPressureSensitivity: 0.42,
            colorMixStrength: 0.08,
            paintLoad: 0.92,
            loadPressureSensitivity: 0.10,
            dualBrushEnabled: false,
            dualTipKind: .pencil,
            dualScale: 0.68,
            dualSpacing: 0.18,
            dualScatter: 0.06,
            dualAngle: 0.10,
            dualBlendMode: .multiply,
            grainScale: 1.45,
            grainContrast: 1.92,
            paperScale: 0.16,
            paperStrength: 0.48,
            paperThreshold: 0.40,
            flipX: false,
            flipY: false,
            pressureSensitivity: 0.62,
            red: 31, green: 31, blue: 34
        ),
        BrushPreset(
            name: "Fine Liner",
            tipKind: .ink,
            color: Color(red: 0.07, green: 0.08, blue: 0.10),
            radius: 1.5,
            sizeSpeedSensitivity: 0.04,
            opacity: 0.98,
            hardness: 0.96,
            roundness: 0.34,
            roundnessPressureSensitivity: 0.0,
            roundnessTiltSensitivity: 0.08,
            angle: 0.0,
            anglePressureSensitivity: 0.02,
            angleTiltSensitivity: 0.22,
            angleMode: .strokeDirection,
            spacing: 0.10,
            spacingJitter: 0.0,
            scatterEnabled: false,
            scatterMode: .directional,
            scatterLateral: 0.01,
            scatterLinear: 0.0,
            count: 1,
            countJitter: 0.0,
            countSizeJitter: 0.0,
            countOpacityJitter: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .strokeLocked,
            textureStrength: 0.10,
            flow: 1.0,
            flowPressureSensitivity: 0.08,
            flowJitter: 0.0,
            wetness: 0.0,
            wetnessPressureSensitivity: 0.0,
            opacityPressureSensitivity: 0.18,
            colorMixStrength: 0.0,
            paintLoad: 1.0,
            loadPressureSensitivity: 0.0,
            dualBrushEnabled: false,
            dualTipKind: .ink,
            dualScale: 0.72,
            dualSpacing: 0.20,
            dualScatter: 0.04,
            dualAngle: 0.0,
            dualBlendMode: .multiply,
            grainScale: 1.08,
            grainContrast: 1.45,
            paperScale: 0.08,
            paperStrength: 0.10,
            paperThreshold: 0.44,
            flipX: false,
            flipY: false,
            pressureSensitivity: 0.32,
            red: 18, green: 21, blue: 26
        ),
        BrushPreset(
            name: "Indigo Ink",
            tipKind: .ink,
            color: Color(red: 0.20, green: 0.24, blue: 0.42),
            radius: 2.8,
            sizeSpeedSensitivity: 0.06,
            opacity: 0.88,
            hardness: 0.72,
            roundness: 0.30,
            roundnessPressureSensitivity: 0.04,
            roundnessTiltSensitivity: 0.16,
            angle: 0.18,
            anglePressureSensitivity: 0.04,
            angleTiltSensitivity: 0.26,
            angleMode: .strokeDirection,
            spacing: 0.14,
            spacingJitter: 0.02,
            scatterEnabled: false,
            scatterMode: .directional,
            scatterLateral: 0.03,
            scatterLinear: 0.01,
            count: 1,
            countJitter: 0.0,
            countSizeJitter: 0.0,
            countOpacityJitter: 0.0,
            angleJitter: 0.03,
            roundnessJitter: 0.02,
            textureMode: .eachTip,
            textureStrength: 0.26,
            flow: 0.92,
            flowPressureSensitivity: 0.12,
            flowJitter: 0.02,
            wetness: 0.04,
            wetnessPressureSensitivity: 0.08,
            opacityPressureSensitivity: 0.26,
            colorMixStrength: 0.04,
            paintLoad: 0.98,
            loadPressureSensitivity: 0.04,
            dualBrushEnabled: false,
            dualTipKind: .ink,
            dualScale: 0.76,
            dualSpacing: 0.24,
            dualScatter: 0.08,
            dualAngle: 0.04,
            dualBlendMode: .multiply,
            grainScale: 1.12,
            grainContrast: 1.54,
            paperScale: 0.10,
            paperStrength: 0.16,
            paperThreshold: 0.42,
            flipX: false,
            flipY: false,
            pressureSensitivity: 0.44,
            red: 51, green: 61, blue: 107
        ),
        BrushPreset(
            name: "Soft Airbrush",
            tipKind: .airbrush,
            color: Color(red: 0.10, green: 0.10, blue: 0.11),
            radius: 8.5,
            sizeSpeedSensitivity: 0.14,
            opacity: 0.16,
            hardness: 0.10,
            roundness: 1.0,
            roundnessPressureSensitivity: 0.0,
            roundnessTiltSensitivity: 0.0,
            angle: 0.0,
            anglePressureSensitivity: 0.0,
            angleTiltSensitivity: 0.0,
            angleMode: .fixed,
            spacing: 0.34,
            spacingJitter: 0.08,
            scatterEnabled: true,
            scatterMode: .spray,
            scatterLateral: 0.20,
            scatterLinear: 0.06,
            count: 2,
            countJitter: 0.25,
            countSizeJitter: 0.32,
            countOpacityJitter: 0.28,
            angleJitter: 1.0,
            roundnessJitter: 0.0,
            textureMode: .moving,
            textureStrength: 0.22,
            flow: 0.62,
            flowPressureSensitivity: 0.36,
            flowJitter: 0.24,
            wetness: 0.34,
            wetnessPressureSensitivity: 0.46,
            opacityPressureSensitivity: 0.62,
            colorMixStrength: 0.22,
            paintLoad: 0.72,
            loadPressureSensitivity: 0.28,
            dualBrushEnabled: true,
            dualTipKind: .airbrush,
            dualScale: 0.54,
            dualSpacing: 0.42,
            dualScatter: 0.34,
            dualAngle: 0.0,
            dualBlendMode: .multiply,
            grainScale: 1.36,
            grainContrast: 1.52,
            paperScale: 0.09,
            paperStrength: 0.22,
            paperThreshold: 0.46,
            flipX: false,
            flipY: false,
            pressureSensitivity: 0.18,
            red: 25, green: 25, blue: 29
        ),
        BrushPreset(
            name: "Wash Airbrush",
            tipKind: .airbrush,
            color: Color(red: 0.16, green: 0.19, blue: 0.26),
            radius: 11.0,
            sizeSpeedSensitivity: 0.18,
            opacity: 0.10,
            hardness: 0.06,
            roundness: 1.0,
            roundnessPressureSensitivity: 0.0,
            roundnessTiltSensitivity: 0.0,
            angle: 0.0,
            anglePressureSensitivity: 0.0,
            angleTiltSensitivity: 0.0,
            angleMode: .fixed,
            spacing: 0.42,
            spacingJitter: 0.12,
            scatterEnabled: true,
            scatterMode: .spray,
            scatterLateral: 0.28,
            scatterLinear: 0.10,
            count: 2,
            countJitter: 0.35,
            countSizeJitter: 0.42,
            countOpacityJitter: 0.36,
            angleJitter: 1.2,
            roundnessJitter: 0.0,
            textureMode: .moving,
            textureStrength: 0.34,
            flow: 0.54,
            flowPressureSensitivity: 0.42,
            flowJitter: 0.32,
            wetness: 0.52,
            wetnessPressureSensitivity: 0.58,
            opacityPressureSensitivity: 0.70,
            colorMixStrength: 0.36,
            paintLoad: 0.56,
            loadPressureSensitivity: 0.34,
            dualBrushEnabled: true,
            dualTipKind: .airbrush,
            dualScale: 0.58,
            dualSpacing: 0.48,
            dualScatter: 0.40,
            dualAngle: 0.0,
            dualBlendMode: .multiply,
            grainScale: 1.42,
            grainContrast: 1.64,
            paperScale: 0.12,
            paperStrength: 0.30,
            paperThreshold: 0.44,
            flipX: false,
            flipY: false,
            pressureSensitivity: 0.10,
            red: 41, green: 49, blue: 66
        ),
        BrushPreset(
            name: "Burnt Sienna",
            tipKind: .oil,
            color: Color(red: 0.63, green: 0.31, blue: 0.20),
            radius: 3.8,
            sizeSpeedSensitivity: 0.10,
            opacity: 0.84,
            hardness: 0.66,
            roundness: 0.42,
            roundnessPressureSensitivity: 0.10,
            roundnessTiltSensitivity: 0.20,
            angle: 0.22,
            anglePressureSensitivity: 0.06,
            angleTiltSensitivity: 0.20,
            angleMode: .strokeDirection,
            spacing: 0.24,
            spacingJitter: 0.04,
            scatterEnabled: true,
            scatterMode: .directional,
            scatterLateral: 0.08,
            scatterLinear: 0.03,
            count: 2,
            countJitter: 0.15,
            countSizeJitter: 0.18,
            countOpacityJitter: 0.14,
            angleJitter: 0.08,
            roundnessJitter: 0.05,
            textureMode: .eachTip,
            textureStrength: 0.78,
            flow: 0.88,
            flowPressureSensitivity: 0.14,
            flowJitter: 0.10,
            wetness: 0.36,
            wetnessPressureSensitivity: 0.30,
            opacityPressureSensitivity: 0.34,
            colorMixStrength: 0.30,
            paintLoad: 0.74,
            loadPressureSensitivity: 0.24,
            dualBrushEnabled: true,
            dualTipKind: .oil,
            dualScale: 0.66,
            dualSpacing: 0.24,
            dualScatter: 0.12,
            dualAngle: 0.12,
            dualBlendMode: .darker,
            grainScale: 1.28,
            grainContrast: 1.82,
            paperScale: 0.14,
            paperStrength: 0.28,
            paperThreshold: 0.40,
            flipX: false,
            flipY: false,
            pressureSensitivity: 0.40,
            red: 160, green: 79, blue: 51
        ),
        BrushPreset(
            name: "Flat Oil",
            tipKind: .oil,
            color: Color(red: 0.18, green: 0.26, blue: 0.61),
            radius: 6.0,
            sizeSpeedSensitivity: 0.12,
            opacity: 0.80,
            hardness: 0.72,
            roundness: 0.36,
            roundnessPressureSensitivity: 0.08,
            roundnessTiltSensitivity: 0.18,
            angle: -0.14,
            anglePressureSensitivity: 0.06,
            angleTiltSensitivity: 0.18,
            angleMode: .strokeDirection,
            spacing: 0.22,
            spacingJitter: 0.03,
            scatterEnabled: true,
            scatterMode: .directional,
            scatterLateral: 0.06,
            scatterLinear: 0.03,
            count: 2,
            countJitter: 0.12,
            countSizeJitter: 0.16,
            countOpacityJitter: 0.12,
            angleJitter: 0.06,
            roundnessJitter: 0.04,
            textureMode: .eachTip,
            textureStrength: 0.82,
            flow: 0.86,
            flowPressureSensitivity: 0.12,
            flowJitter: 0.08,
            wetness: 0.28,
            wetnessPressureSensitivity: 0.22,
            opacityPressureSensitivity: 0.30,
            colorMixStrength: 0.24,
            paintLoad: 0.78,
            loadPressureSensitivity: 0.20,
            dualBrushEnabled: true,
            dualTipKind: .oil,
            dualScale: 0.62,
            dualSpacing: 0.22,
            dualScatter: 0.10,
            dualAngle: -0.08,
            dualBlendMode: .darker,
            grainScale: 1.24,
            grainContrast: 1.88,
            paperScale: 0.13,
            paperStrength: 0.26,
            paperThreshold: 0.40,
            flipX: false,
            flipY: false,
            pressureSensitivity: 0.36,
            red: 46, green: 66, blue: 156
        ),
        BrushPreset(
            name: "HB Sketch",
            tipKind: .pencil,
            color: Color(red: 0.25, green: 0.25, blue: 0.27),
            radius: 2.2,
            sizeSpeedSensitivity: 0.10,
            opacity: 0.70,
            hardness: 0.68,
            roundness: 0.88,
            roundnessPressureSensitivity: 0.10,
            roundnessTiltSensitivity: 0.20,
            angle: -0.08,
            anglePressureSensitivity: 0.04,
            angleTiltSensitivity: 0.16,
            angleMode: .strokeDirection,
            spacing: 0.13,
            spacingJitter: 0.01,
            scatterEnabled: false,
            scatterMode: .directional,
            scatterLateral: 0.03,
            scatterLinear: 0.01,
            count: 1,
            countJitter: 0.0,
            countSizeJitter: 0.0,
            countOpacityJitter: 0.0,
            angleJitter: 0.03,
            roundnessJitter: 0.04,
            textureMode: .eachTip,
            textureStrength: 0.82,
            flow: 0.78,
            flowPressureSensitivity: 0.18,
            flowJitter: 0.06,
            wetness: 0.14,
            wetnessPressureSensitivity: 0.16,
            opacityPressureSensitivity: 0.48,
            colorMixStrength: 0.10,
            paintLoad: 0.88,
            loadPressureSensitivity: 0.12,
            dualBrushEnabled: false,
            dualTipKind: .pencil,
            dualScale: 0.70,
            dualSpacing: 0.18,
            dualScatter: 0.06,
            dualAngle: -0.06,
            dualBlendMode: .multiply,
            grainScale: 1.48,
            grainContrast: 1.94,
            paperScale: 0.15,
            paperStrength: 0.44,
            paperThreshold: 0.40,
            flipX: false,
            flipY: false,
            pressureSensitivity: 0.82,
            red: 64, green: 64, blue: 69
        )
    ]

    static let defaultPencil = defaults[0]
}

struct LayerRowModel: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
    let name: String
    let visible: Bool
    let opacity: Double
    let blendMode: LayerBlendMode

    static func == (lhs: LayerRowModel, rhs: LayerRowModel) -> Bool {
        lhs.index == rhs.index &&
        lhs.name == rhs.name &&
        lhs.visible == rhs.visible &&
        lhs.opacity == rhs.opacity &&
        lhs.blendMode == rhs.blendMode
    }
}

struct LayerCanvasBuffer: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
    var name: String
    var visible: Bool
    var opacity: Double
    var blendMode: LayerBlendMode = .normal
    var strokes: [PreviewStrokeTrack] = []
}

struct StylusSample: Equatable {
    let point: CGPoint
    let pressure: CGFloat
    let altitude: CGFloat
    let azimuth: CGFloat
    let timestamp: TimeInterval

    static func == (lhs: StylusSample, rhs: StylusSample) -> Bool {
        lhs.point == rhs.point &&
        lhs.pressure == rhs.pressure &&
        lhs.altitude == rhs.altitude &&
        lhs.azimuth == rhs.azimuth &&
        lhs.timestamp == rhs.timestamp
    }
}

struct StrokePoint: Equatable {
    var position: SIMD2<Float>
    var pressure: Float
    var altitude: Float
    var azimuth: Float
    var timestamp: Double
    var isPredicted: Bool

    var cgPoint: CGPoint {
        CGPoint(x: CGFloat(position.x), y: CGFloat(position.y))
    }

    var stylusSample: StylusSample {
        StylusSample(
            point: cgPoint,
            pressure: CGFloat(pressure),
            altitude: CGFloat(altitude),
            azimuth: CGFloat(azimuth),
            timestamp: timestamp
        )
    }

    var previewPoint: PreviewStrokePoint {
        PreviewStrokePoint(
            point: cgPoint,
            pressure: CGFloat(pressure)
        )
    }
}

struct Stroke: Equatable {
    var points: [StrokePoint] = []
    var predictedPoints: [StrokePoint] = []
    var color: SIMD4<Float> = SIMD4(0, 0, 0, 1)
    var brushSize: Float = 4.0

    var confirmedPreviewPoints: [PreviewStrokePoint] {
        points.map(\.previewPoint)
    }

    var predictedPreviewPoints: [PreviewStrokePoint] {
        predictedPoints.map(\.previewPoint)
    }
}

struct PreviewStrokePoint: Identifiable, Equatable {
    let id = UUID()
    let point: CGPoint
    let pressure: CGFloat

    static func == (lhs: PreviewStrokePoint, rhs: PreviewStrokePoint) -> Bool {
        lhs.id == rhs.id &&
        lhs.point == rhs.point &&
        lhs.pressure == rhs.pressure
    }
}

struct PreviewStrokeStyle: Equatable {
    let tipKind: BrushTipKind
    let isEraser: Bool
    let radius: CGFloat
    let opacity: CGFloat
    let hardness: CGFloat
    let pressureSensitivity: CGFloat
    let stabilization: CGFloat
    let color: CGColor
}

struct PreviewStrokeTrack: Identifiable, Equatable {
    let id = UUID()
    let layerIndex: Int
    let points: [PreviewStrokePoint]
    let style: PreviewStrokeStyle

    static func == (lhs: PreviewStrokeTrack, rhs: PreviewStrokeTrack) -> Bool {
        lhs.id == rhs.id &&
        lhs.layerIndex == rhs.layerIndex &&
        lhs.points == rhs.points &&
        lhs.style == rhs.style
    }
}

struct SampledColor: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}

struct MetalLayerSnapshot: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
    let opacity: Float
    let visible: Bool
    let blendMode: LayerBlendMode
    let thumbnailData: Data?
    let pixelData: Data

    static func == (lhs: MetalLayerSnapshot, rhs: MetalLayerSnapshot) -> Bool {
        lhs.index == rhs.index &&
        lhs.opacity == rhs.opacity &&
        lhs.visible == rhs.visible &&
        lhs.blendMode == rhs.blendMode &&
        lhs.thumbnailData?.count == rhs.thumbnailData?.count &&
        lhs.pixelData.count == rhs.pixelData.count
    }
}

struct TimelapseFrame: Equatable, Sendable {
    let imageURL: URL
    let size: CGSize
}

struct TimelapseCapture: Equatable, Sendable {
    let canvasSize: CGSize
    let frames: [TimelapseFrame]
    let framesPerSecond: Int
}

struct MetalDocumentSnapshot: Equatable {
    let width: Int
    let height: Int
    let revision: Int
    let compositePixelData: Data
    let layers: [MetalLayerSnapshot]

    static func == (lhs: MetalDocumentSnapshot, rhs: MetalDocumentSnapshot) -> Bool {
        lhs.width == rhs.width &&
        lhs.height == rhs.height &&
        lhs.revision == rhs.revision &&
        lhs.compositePixelData.count == rhs.compositePixelData.count &&
        lhs.layers.count == rhs.layers.count
    }
}

struct IncrementalLayerUpdate: Equatable, Identifiable {
    let id = UUID()
    let layerIndex: Int
    let originX: Int
    let originY: Int
    let width: Int
    let height: Int
    let pixelData: Data

    var isEmpty: Bool { width <= 0 || height <= 0 || pixelData.isEmpty }

    static func == (lhs: IncrementalLayerUpdate, rhs: IncrementalLayerUpdate) -> Bool {
        lhs.id == rhs.id
    }
}

struct CanvasSelection: Equatable {
    let bounds: CGRect
    let maskWidth: Int
    let maskHeight: Int
    let maskData: Data
    let mode: SelectionToolMode

    var isEmpty: Bool {
        maskWidth <= 0 || maskHeight <= 0 || maskData.isEmpty || bounds.isNull || bounds.isEmpty
    }
}
