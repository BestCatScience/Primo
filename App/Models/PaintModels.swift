import Foundation
import SwiftUI
import CoreGraphics
import simd

enum StudioToolKind: String, CaseIterable, Equatable, Sendable, Identifiable {
    case brush
    case erase
    case blur
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
            return language.localized("ブラシ")
        case .erase:
            return language.localized("消しゴム")
        case .blur:
            return language.localized("ぼかし")
        case .fill:
            return language.localized("塗りつぶし")
        case .eyedropper:
            return language.localized("スポイト設定")
        case .select:
            return language.localized("選択")
        case .move:
            return language.localized("移動")
        case .shape:
            return language.localized("形状")
        }
    }

    var systemImage: String {
        switch self {
        case .brush:
            return "paintbrush.pointed"
        case .erase:
            return "eraser"
        case .blur:
            return "drop"
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

enum BrushColorSlot: String, CaseIterable, Equatable, Sendable, Identifiable {
    case primary
    case secondary
    case transparent

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .primary:
            return language.localized("主色")
        case .secondary:
            return language.localized("補助色")
        case .transparent:
            return language.localized("透明色")
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
            return language.localized("アクティブレイヤー")
        case .canvas:
            return language.localized("キャンバス")
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
            return language.localized("不透明")
        case .color:
            return language.localized("色")
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
            return language.localized("投げ縄")
        case .auto:
            return language.localized("自動")
        }
    }
}

enum ShapeToolMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case line
    case rectangle
    case ellipse
    case triangle
    case pentagon
    case hexagon

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .line:
            return language.localized("直線")
        case .rectangle:
            return language.localized("四角")
        case .ellipse:
            return language.localized("丸")
        case .triangle:
            return language.localized("三角形")
        case .pentagon:
            return language.localized("五角形")
        case .hexagon:
            return language.localized("六角形")
        }
    }

    var systemImage: String {
        switch self {
        case .line:
            return "line.diagonal"
        case .rectangle:
            return "square"
        case .ellipse:
            return "circle"
        case .triangle:
            return "triangle"
        case .pentagon:
            return "pentagon"
        case .hexagon:
            return "hexagon"
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
            return language.localized("置換")
        case .add:
            return language.localized("加算")
        case .subtract:
            return language.localized("削る")
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
            return language.localized("通常")
        case .darken:
            return language.localized("比較(暗)")
        case .multiply:
            return language.localized("乗算")
        case .colorBurn:
            return language.localized("焼き込みカラー")
        case .linearBurn:
            return language.localized("焼き込み(リニア)")
        case .subtract:
            return language.localized("削る")
        case .lighten:
            return language.localized("比較(明)")
        case .screen:
            return language.localized("スクリーン")
        case .colorDodge:
            return language.localized("覆い焼きカラー")
        case .glowDodge:
            return language.localized("覆い焼き(発光)")
        case .overlay:
            return language.localized("オーバーレイ")
        case .softLight:
            return language.localized("ソフトライト")
        case .hardLight:
            return language.localized("ハードライト")
        case .difference:
            return language.localized("差の絶対値")
        case .vividLight:
            return language.localized("ビビッドライト")
        case .linearLight:
            return language.localized("リニアライト")
        case .pinLight:
            return language.localized("ピンライト")
        case .hardMix:
            return language.localized("ハードミックス")
        case .exclusion:
            return language.localized("除外")
        case .darkerColor:
            return language.localized("カラー比較(暗)")
        case .lighterColor:
            return language.localized("カラー比較(明)")
        case .divide:
            return language.localized("除算")
        case .hue:
            return language.localized("色相")
        case .saturation:
            return language.localized("彩度")
        case .color:
            return language.localized("色")
        case .add:
            return language.localized("加算")
        case .addGlow:
            return language.localized("加算(発光)")
        case .luminosity:
            return language.localized("輝度")
        }
    }
}

enum GradientMapPreset: String, CaseIterable, Equatable, Sendable, Identifiable {
    case graphite
    case sepia
    case ocean
    case sunset
    case toxic

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .graphite:
            return language.localized("グラファイト")
        case .sepia:
            return language.localized("セピア")
        case .ocean:
            return language.localized("オーシャン")
        case .sunset:
            return language.localized("サンセット")
        case .toxic:
            return language.localized("トキシック")
        }
    }
}

struct HueSaturationBrightnessSettings: Equatable, Sendable {
    var hueDegrees: Double = 0
    var saturation: Double = 1
    var brightness: Double = 0
}

struct BrightnessContrastSettings: Equatable, Sendable {
    var brightness: Double = 0
    var contrast: Double = 1
}

struct LevelsAdjustmentSettings: Equatable, Sendable {
    var inputBlack: Double = 0
    var inputWhite: Double = 1
    var gamma: Double = 1
    var outputBlack: Double = 0
    var outputWhite: Double = 1
}

struct ToneCurveSettings: Equatable, Sendable {
    var shadows: Double = 0
    var midtones: Double = 0
    var highlights: Double = 0
}

struct ColorBalanceSettings: Equatable, Sendable {
    var redCyan: Double = 0
    var greenMagenta: Double = 0
    var blueYellow: Double = 0
}

struct ThresholdSettings: Equatable, Sendable {
    var threshold: Double = 0.5
}

struct PosterizeSettings: Equatable, Sendable {
    var levels: Double = 6
}

struct GradientMapStopSettings: Equatable, Sendable, Identifiable {
    let id: UUID
    var position: Double
    var red: UInt8
    var green: UInt8
    var blue: UInt8

    init(
        id: UUID = UUID(),
        position: Double,
        red: UInt8,
        green: UInt8,
        blue: UInt8
    ) {
        self.id = id
        self.position = position
        self.red = red
        self.green = green
        self.blue = blue
    }
}

struct GradientMapSettings: Equatable, Sendable {
    var stops: [GradientMapStopSettings] = [
        GradientMapStopSettings(position: 0.0, red: 17, green: 21, blue: 27),
        GradientMapStopSettings(position: 0.5, red: 84, green: 93, blue: 108),
        GradientMapStopSettings(position: 1.0, red: 243, green: 244, blue: 246)
    ]
}

enum LayerProcessingRequest: Equatable, Sendable {
    case gradientMap(GradientMapPreset)
    case hueSaturationBrightness(HueSaturationBrightnessSettings)
    case brightnessContrast(BrightnessContrastSettings)
    case levels(LevelsAdjustmentSettings)
    case toneCurve(ToneCurveSettings)
    case colorBalance(ColorBalanceSettings)
    case threshold(ThresholdSettings)
    case posterize(PosterizeSettings)
    case transform(translation: CGSize, scale: CGFloat, selection: CanvasSelection?)
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
            return language.localized("鉛筆")
        case .ink:
            return language.localized("インク")
        case .oil:
            return language.localized("油彩")
        case .airbrush:
            return language.localized("エアブラシ")
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
            return language.localized("固定")
        case .strokeDirection:
            return language.localized("線方向")
        case .stylusTilt:
            return language.localized("傾き")
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
            return language.localized("オフ")
        case .strokeLocked:
            return language.localized("ストローク固定")
        case .eachTip:
            return language.localized("先端ごと")
        case .moving:
            return language.localized("移動")
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
            return language.localized("乗算")
        case .darker:
            return language.localized("暗い方")
        case .subtract:
            return language.localized("削る")
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
            return language.localized("方向散布")
        case .spray:
            return language.localized("スプレー")
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
        red: 1.0,
        green: 1.0,
        blue: 1.0,
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
        angleJitter: Double = 0.0,
        roundnessJitter: Double = 0.0,
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
        studioPreset(
            name: "Soft Pencil",
            tipKind: .pencil,
            color: Color(red: 0.14, green: 0.14, blue: 0.15),
            radius: 2.6,
            opacity: 0.70,
            hardness: 0.68,
            roundness: 0.90,
            roundnessPressureSensitivity: 0.10,
            roundnessTiltSensitivity: 0.20,
            angle: -0.06,
            anglePressureSensitivity: 0.03,
            angleTiltSensitivity: 0.14,
            spacing: 0.12,
            scatterLateral: 0.02,
            scatterLinear: 0.01,
            angleJitter: 0.03,
            roundnessJitter: 0.04,
            textureMode: .eachTip,
            textureStrength: 0.78,
            flow: 0.76,
            flowPressureSensitivity: 0.16,
            flowJitter: 0.04,
            wetness: 0.06,
            wetnessPressureSensitivity: 0.12,
            opacityPressureSensitivity: 0.52,
            colorMixStrength: 0.08,
            paintLoad: 0.92,
            loadPressureSensitivity: 0.10,
            grainScale: 1.46,
            grainContrast: 1.94,
            paperScale: 0.15,
            paperStrength: 0.46,
            paperThreshold: 0.40,
            pressureSensitivity: 0.82,
            red: 36,
            green: 36,
            blue: 39
        ),
        studioPreset(
            name: "Sketch Pencil",
            tipKind: .pencil,
            color: Color(red: 0.11, green: 0.11, blue: 0.12),
            radius: 3.0,
            opacity: 0.90,
            hardness: 0.82,
            roundness: 0.86,
            roundnessPressureSensitivity: 0.10,
            roundnessTiltSensitivity: 0.16,
            angle: 0.04,
            anglePressureSensitivity: 0.04,
            angleTiltSensitivity: 0.14,
            spacing: 0.11,
            scatterLateral: 0.02,
            scatterLinear: 0.01,
            angleJitter: 0.02,
            roundnessJitter: 0.02,
            textureMode: .eachTip,
            textureStrength: 0.86,
            flow: 0.88,
            flowPressureSensitivity: 0.18,
            flowJitter: 0.03,
            wetness: 0.08,
            wetnessPressureSensitivity: 0.12,
            opacityPressureSensitivity: 0.40,
            colorMixStrength: 0.04,
            paintLoad: 0.96,
            loadPressureSensitivity: 0.08,
            grainScale: 1.42,
            grainContrast: 1.88,
            paperScale: 0.14,
            paperStrength: 0.40,
            paperThreshold: 0.40,
            pressureSensitivity: 0.62,
            red: 28,
            green: 28,
            blue: 31
        ),
        studioPreset(
            name: "Round Pen",
            tipKind: .ink,
            color: Color(red: 0.04, green: 0.05, blue: 0.07),
            radius: 1.9,
            sizeSpeedSensitivity: 0.0,
            opacity: 1.0,
            hardness: 0.94,
            roundness: 1.0,
            angleMode: .fixed,
            spacing: 0.06,
            scatterLateral: 0.0,
            scatterLinear: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .off,
            textureStrength: 0.0,
            flow: 0.98,
            flowPressureSensitivity: 0.0,
            opacityPressureSensitivity: 0.0,
            grainScale: 1.0,
            grainContrast: 1.0,
            paperScale: 0.05,
            paperStrength: 0.0,
            paperThreshold: 0.5,
            pressureSensitivity: 0.0,
            red: 10,
            green: 13,
            blue: 18
        ),
        studioPreset(
            name: "Brush Pen",
            tipKind: .ink,
            color: Color(red: 0.06, green: 0.07, blue: 0.09),
            radius: 2.6,
            sizeSpeedSensitivity: 0.0,
            opacity: 1.0,
            hardness: 0.88,
            roundness: 0.62,
            roundnessPressureSensitivity: 0.08,
            roundnessTiltSensitivity: 0.10,
            angleMode: .fixed,
            spacing: 0.07,
            spacingJitter: 0.01,
            scatterLateral: 0.01,
            scatterLinear: 0.01,
            angleJitter: 0.0,
            roundnessJitter: 0.01,
            textureMode: .strokeLocked,
            textureStrength: 0.03,
            flow: 0.97,
            flowPressureSensitivity: 0.0,
            flowJitter: 0.0,
            wetness: 0.0,
            wetnessPressureSensitivity: 0.0,
            opacityPressureSensitivity: 0.0,
            colorMixStrength: 0.0,
            paintLoad: 1.0,
            loadPressureSensitivity: 0.0,
            grainScale: 1.02,
            grainContrast: 1.18,
            paperScale: 0.06,
            paperStrength: 0.02,
            paperThreshold: 0.48,
            pressureSensitivity: 0.18,
            red: 15,
            green: 18,
            blue: 24
        ),
        studioPreset(
            name: "Block Marker",
            tipKind: .ink,
            color: Color(red: 0.06, green: 0.07, blue: 0.09),
            radius: 7.6,
            sizeSpeedSensitivity: 0.0,
            opacity: 1.0,
            hardness: 0.93,
            roundness: 0.82,
            angle: 0.0,
            angleMode: .fixed,
            spacing: 0.11,
            scatterLateral: 0.0,
            scatterLinear: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .off,
            textureStrength: 0.0,
            flow: 0.98,
            opacityPressureSensitivity: 0.0,
            paperScale: 0.05,
            paperStrength: 0.0,
            pressureSensitivity: 0.04,
            red: 16,
            green: 18,
            blue: 24,
            customTip: BuiltInBrushTipFactory.block
        ),
        studioPreset(
            name: "Chisel Marker",
            tipKind: .ink,
            color: Color(red: 0.07, green: 0.08, blue: 0.10),
            radius: 7.0,
            sizeSpeedSensitivity: 0.0,
            opacity: 1.0,
            hardness: 0.91,
            roundness: 0.56,
            roundnessPressureSensitivity: 0.08,
            angle: .pi / 8,
            angleTiltSensitivity: 0.10,
            angleMode: .strokeDirection,
            spacing: 0.10,
            scatterLateral: 0.01,
            scatterLinear: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .off,
            textureStrength: 0.0,
            flow: 0.98,
            opacityPressureSensitivity: 0.0,
            paperScale: 0.05,
            paperStrength: 0.0,
            pressureSensitivity: 0.12,
            red: 18,
            green: 20,
            blue: 27,
            customTip: BuiltInBrushTipFactory.ribbon
        ),
        studioPreset(
            name: "Diamond Nib",
            tipKind: .ink,
            color: Color(red: 0.08, green: 0.09, blue: 0.11),
            radius: 6.4,
            sizeSpeedSensitivity: 0.0,
            opacity: 1.0,
            hardness: 0.92,
            roundness: 0.68,
            angle: .pi / 4,
            angleMode: .fixed,
            spacing: 0.12,
            scatterLateral: 0.0,
            scatterLinear: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .off,
            textureStrength: 0.0,
            flow: 0.98,
            opacityPressureSensitivity: 0.0,
            paperScale: 0.05,
            paperStrength: 0.0,
            pressureSensitivity: 0.06,
            red: 20,
            green: 23,
            blue: 29,
            customTip: BuiltInBrushTipFactory.diamond
        ),
        studioPreset(
            name: "Soft Airbrush",
            tipKind: .airbrush,
            color: Color(red: 0.10, green: 0.10, blue: 0.11),
            radius: 8.0,
            sizeSpeedSensitivity: 0.0,
            opacity: 0.16,
            hardness: 0.08,
            roundness: 1.0,
            angleMode: .fixed,
            spacing: 0.22,
            spacingJitter: 0.02,
            scatterEnabled: false,
            scatterLateral: 0.02,
            scatterLinear: 0.01,
            count: 1,
            countJitter: 0.0,
            countSizeJitter: 0.0,
            countOpacityJitter: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .moving,
            textureStrength: 0.10,
            flow: 0.70,
            flowPressureSensitivity: 0.28,
            flowJitter: 0.08,
            wetness: 0.12,
            wetnessPressureSensitivity: 0.18,
            opacityPressureSensitivity: 0.50,
            colorMixStrength: 0.08,
            paintLoad: 0.86,
            loadPressureSensitivity: 0.18,
            dualBrushEnabled: false,
            grainScale: 1.24,
            grainContrast: 1.34,
            paperScale: 0.08,
            paperStrength: 0.12,
            paperThreshold: 0.46,
            pressureSensitivity: 0.16,
            red: 26,
            green: 26,
            blue: 29
        ),
        studioPreset(
            name: "Scatter Airbrush",
            tipKind: .airbrush,
            color: Color(red: 0.14, green: 0.15, blue: 0.18),
            radius: 11.5,
            sizeSpeedSensitivity: 0.0,
            opacity: 0.10,
            hardness: 0.06,
            roundness: 1.0,
            angleMode: .fixed,
            spacing: 0.40,
            spacingJitter: 0.10,
            scatterEnabled: true,
            scatterMode: .spray,
            scatterLateral: 0.26,
            scatterLinear: 0.10,
            count: 2,
            countJitter: 0.30,
            countSizeJitter: 0.40,
            countOpacityJitter: 0.32,
            angleJitter: 1.2,
            roundnessJitter: 0.0,
            textureMode: .moving,
            textureStrength: 0.28,
            flow: 0.56,
            flowPressureSensitivity: 0.40,
            flowJitter: 0.28,
            wetness: 0.44,
            wetnessPressureSensitivity: 0.50,
            opacityPressureSensitivity: 0.68,
            colorMixStrength: 0.28,
            paintLoad: 0.60,
            loadPressureSensitivity: 0.30,
            dualBrushEnabled: true,
            dualTipKind: .airbrush,
            dualScale: 0.58,
            dualSpacing: 0.46,
            dualScatter: 0.38,
            dualBlendMode: .multiply,
            grainScale: 1.40,
            grainContrast: 1.58,
            paperScale: 0.11,
            paperStrength: 0.24,
            paperThreshold: 0.44,
            pressureSensitivity: 0.10,
            red: 35,
            green: 38,
            blue: 46
        ),
        studioPreset(
            name: "Petal Spray",
            tipKind: .airbrush,
            color: Color(red: 0.18, green: 0.19, blue: 0.22),
            radius: 10.0,
            sizeSpeedSensitivity: 0.0,
            opacity: 0.22,
            hardness: 0.22,
            roundness: 1.0,
            angleMode: .strokeDirection,
            spacing: 0.28,
            spacingJitter: 0.08,
            scatterEnabled: true,
            scatterMode: .spray,
            scatterLateral: 0.16,
            scatterLinear: 0.08,
            count: 2,
            countJitter: 0.18,
            countSizeJitter: 0.26,
            countOpacityJitter: 0.18,
            angleJitter: 0.5,
            roundnessJitter: 0.0,
            textureMode: .moving,
            textureStrength: 0.10,
            flow: 0.66,
            flowPressureSensitivity: 0.20,
            flowJitter: 0.12,
            wetness: 0.08,
            wetnessPressureSensitivity: 0.10,
            opacityPressureSensitivity: 0.44,
            colorMixStrength: 0.10,
            paintLoad: 0.88,
            loadPressureSensitivity: 0.12,
            grainScale: 1.10,
            grainContrast: 1.16,
            paperScale: 0.06,
            paperStrength: 0.04,
            paperThreshold: 0.46,
            pressureSensitivity: 0.10,
            red: 38,
            green: 40,
            blue: 46,
            customTip: BuiltInBrushTipFactory.petal
        ),
        studioPreset(
            name: "Paint Brush",
            tipKind: .oil,
            color: Color(red: 0.23, green: 0.27, blue: 0.34),
            radius: 4.8,
            sizeSpeedSensitivity: 0.0,
            opacity: 0.90,
            hardness: 0.78,
            roundness: 0.84,
            roundnessPressureSensitivity: 0.02,
            roundnessTiltSensitivity: 0.03,
            angle: 0.0,
            anglePressureSensitivity: 0.0,
            angleTiltSensitivity: 0.0,
            angleMode: .fixed,
            spacing: 0.08,
            spacingJitter: 0.0,
            scatterEnabled: false,
            scatterMode: .directional,
            scatterLateral: 0.0,
            scatterLinear: 0.0,
            count: 1,
            countJitter: 0.0,
            countSizeJitter: 0.0,
            countOpacityJitter: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .strokeLocked,
            textureStrength: 0.22,
            flow: 0.96,
            flowPressureSensitivity: 0.04,
            flowJitter: 0.0,
            wetness: 0.12,
            wetnessPressureSensitivity: 0.06,
            opacityPressureSensitivity: 0.10,
            colorMixStrength: 0.06,
            paintLoad: 0.92,
            loadPressureSensitivity: 0.04,
            dualBrushEnabled: false,
            dualTipKind: .oil,
            dualScale: 0.64,
            dualSpacing: 0.22,
            dualScatter: 0.10,
            dualAngle: 0.08,
            dualBlendMode: .darker,
            grainScale: 1.10,
            grainContrast: 1.30,
            paperScale: 0.12,
            paperStrength: 0.10,
            paperThreshold: 0.46,
            pressureSensitivity: 0.18,
            red: 59,
            green: 69,
            blue: 87
        ),
        studioPreset(
            name: "Dry Brush",
            tipKind: .oil,
            color: Color(red: 0.16, green: 0.17, blue: 0.18),
            radius: 5.8,
            sizeSpeedSensitivity: 0.0,
            opacity: 0.82,
            hardness: 0.86,
            roundness: 0.76,
            roundnessPressureSensitivity: 0.03,
            roundnessTiltSensitivity: 0.04,
            angle: 0.0,
            anglePressureSensitivity: 0.0,
            angleTiltSensitivity: 0.0,
            angleMode: .fixed,
            spacing: 0.10,
            spacingJitter: 0.0,
            scatterEnabled: false,
            scatterMode: .directional,
            scatterLateral: 0.0,
            scatterLinear: 0.0,
            count: 1,
            countJitter: 0.0,
            countSizeJitter: 0.0,
            countOpacityJitter: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .strokeLocked,
            textureStrength: 0.34,
            flow: 0.90,
            flowPressureSensitivity: 0.05,
            flowJitter: 0.0,
            wetness: 0.10,
            wetnessPressureSensitivity: 0.04,
            opacityPressureSensitivity: 0.10,
            colorMixStrength: 0.08,
            paintLoad: 0.92,
            loadPressureSensitivity: 0.04,
            dualBrushEnabled: false,
            dualTipKind: .oil,
            dualScale: 0.60,
            dualSpacing: 0.24,
            dualScatter: 0.12,
            dualAngle: -0.08,
            dualBlendMode: .darker,
            grainScale: 1.16,
            grainContrast: 1.42,
            paperScale: 0.13,
            paperStrength: 0.14,
            paperThreshold: 0.46,
            pressureSensitivity: 0.20,
            red: 41,
            green: 43,
            blue: 46
        ),
        studioPreset(
            name: "Rake Brush",
            tipKind: .oil,
            color: Color(red: 0.18, green: 0.20, blue: 0.23),
            radius: 8.4,
            sizeSpeedSensitivity: 0.0,
            opacity: 0.90,
            hardness: 0.80,
            roundness: 0.74,
            angleMode: .strokeDirection,
            spacing: 0.09,
            scatterLateral: 0.0,
            scatterLinear: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .strokeLocked,
            textureStrength: 0.16,
            flow: 0.94,
            flowPressureSensitivity: 0.08,
            wetness: 0.12,
            wetnessPressureSensitivity: 0.08,
            opacityPressureSensitivity: 0.10,
            colorMixStrength: 0.10,
            paintLoad: 0.92,
            loadPressureSensitivity: 0.06,
            grainScale: 1.08,
            grainContrast: 1.24,
            paperScale: 0.08,
            paperStrength: 0.06,
            paperThreshold: 0.46,
            pressureSensitivity: 0.16,
            red: 46,
            green: 50,
            blue: 58,
            customTip: BuiltInBrushTipFactory.rake
        ),
        studioPreset(
            name: "Star Stamp",
            tipKind: .ink,
            color: Color(red: 0.08, green: 0.09, blue: 0.11),
            radius: 8.0,
            sizeSpeedSensitivity: 0.0,
            opacity: 1.0,
            hardness: 0.92,
            roundness: 1.0,
            angleMode: .fixed,
            spacing: 0.38,
            spacingJitter: 0.04,
            scatterEnabled: true,
            scatterMode: .spray,
            scatterLateral: 0.06,
            scatterLinear: 0.02,
            count: 1,
            countJitter: 0.0,
            countSizeJitter: 0.10,
            countOpacityJitter: 0.06,
            angleJitter: 0.9,
            roundnessJitter: 0.0,
            textureMode: .off,
            textureStrength: 0.0,
            flow: 1.0,
            opacityPressureSensitivity: 0.0,
            paperScale: 0.05,
            paperStrength: 0.0,
            pressureSensitivity: 0.0,
            red: 20,
            green: 22,
            blue: 28,
            customTip: BuiltInBrushTipFactory.star
        )
    ]

    static let defaultPencil = defaults[0]

    private static func studioPreset(
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
        angle: Double = 0.0,
        anglePressureSensitivity: Double = 0.0,
        angleTiltSensitivity: Double = 0.0,
        angleMode: BrushAngleMode = .strokeDirection,
        spacing: Double,
        spacingJitter: Double = 0.0,
        scatterEnabled: Bool = false,
        scatterMode: BrushScatterMode = .directional,
        scatterLateral: Double,
        scatterLinear: Double,
        count: Int = 1,
        countJitter: Double = 0.0,
        countSizeJitter: Double = 0.0,
        countOpacityJitter: Double = 0.0,
        angleJitter: Double,
        roundnessJitter: Double,
        textureMode: BrushTextureMode,
        textureStrength: Double,
        flow: Double,
        flowPressureSensitivity: Double = 0.0,
        flowJitter: Double = 0.0,
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
        pressureSensitivity: Double,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        customTip: BrushTipRaster? = nil
    ) -> BrushPreset {
        BrushPreset(
            name: name,
            tipKind: tipKind,
            color: color,
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
            wetness: wetness,
            wetnessPressureSensitivity: wetnessPressureSensitivity,
            opacityPressureSensitivity: opacityPressureSensitivity,
            colorMixStrength: colorMixStrength,
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
            flipX: false,
            flipY: false,
            customTip: customTip,
            pressureSensitivity: pressureSensitivity,
            red: red,
            green: green,
            blue: blue
        )
    }
}

private enum BuiltInBrushTipFactory {
    static let block = roundedSquare(size: 96, inset: 12, cornerRadius: 16)
    static let diamond = diamond(size: 96, inset: 12)
    static let ribbon = ribbon(size: 96, inset: 14, angle: .pi / 6)
    static let petal = petal(size: 96, inset: 8)
    static let rake = rake(size: 96, inset: 10, toothCount: 4)
    static let star = star(size: 96, points: 5, innerRadiusRatio: 0.44, outerInset: 10)

    private static func roundedSquare(size: Int, inset: CGFloat, cornerRadius: CGFloat) -> BrushTipRaster {
        raster(size: size) { context, rect in
            let square = rect.insetBy(dx: inset, dy: inset)
            let path = CGPath(
                roundedRect: square,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )
            context.addPath(path)
            context.fillPath()
        }
    }

    private static func diamond(size: Int, inset: CGFloat) -> BrushTipRaster {
        raster(size: size) { context, rect in
            let box = rect.insetBy(dx: inset, dy: inset)
            let center = CGPoint(x: box.midX, y: box.midY)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: center.x, y: box.minY))
            path.addLine(to: CGPoint(x: box.maxX, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: box.maxY))
            path.addLine(to: CGPoint(x: box.minX, y: center.y))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }
    }

    private static func ribbon(size: Int, inset: CGFloat, angle: CGFloat) -> BrushTipRaster {
        raster(size: size) { context, rect in
            let box = rect.insetBy(dx: inset, dy: inset * 1.6)
            context.saveGState()
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: angle)
            let ribbonRect = CGRect(
                x: -box.width * 0.5,
                y: -box.height * 0.22,
                width: box.width,
                height: box.height * 0.44
            )
            let path = CGPath(
                roundedRect: ribbonRect,
                cornerWidth: ribbonRect.height * 0.45,
                cornerHeight: ribbonRect.height * 0.45,
                transform: nil
            )
            context.addPath(path)
            context.fillPath()
            context.restoreGState()
        }
    }

    private static func petal(size: Int, inset: CGFloat) -> BrushTipRaster {
        raster(size: size) { context, rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let petalWidth = rect.width * 0.24
            let petalHeight = rect.height * 0.50
            let distance = rect.width * 0.12

            for index in 0..<4 {
                context.saveGState()
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: CGFloat(index) * (.pi / 2))
                let petalRect = CGRect(
                    x: -petalWidth * 0.5,
                    y: -(petalHeight - distance),
                    width: petalWidth,
                    height: petalHeight
                ).insetBy(dx: inset * 0.05, dy: inset * 0.02)
                context.fillEllipse(in: petalRect)
                context.restoreGState()
            }

            context.fillEllipse(
                in: CGRect(
                    x: center.x - rect.width * 0.10,
                    y: center.y - rect.height * 0.10,
                    width: rect.width * 0.20,
                    height: rect.height * 0.20
                )
            )
        }
    }

    private static func rake(size: Int, inset: CGFloat, toothCount: Int) -> BrushTipRaster {
        raster(size: size) { context, rect in
            let box = rect.insetBy(dx: inset, dy: inset)
            let gap = box.width * 0.06
            let toothWidth = (box.width - gap * CGFloat(toothCount - 1)) / CGFloat(toothCount)
            let topOffsets: [CGFloat] = [0.12, 0.0, 0.08, 0.18]

            for index in 0..<toothCount {
                let topOffset = box.height * topOffsets[min(index, topOffsets.count - 1)]
                let toothRect = CGRect(
                    x: box.minX + CGFloat(index) * (toothWidth + gap),
                    y: box.minY + topOffset,
                    width: toothWidth,
                    height: box.height - topOffset
                )
                let path = CGPath(
                    roundedRect: toothRect,
                    cornerWidth: toothWidth * 0.34,
                    cornerHeight: toothWidth * 0.34,
                    transform: nil
                )
                context.addPath(path)
                context.fillPath()
            }
        }
    }

    private static func star(size: Int, points: Int, innerRadiusRatio: CGFloat, outerInset: CGFloat) -> BrushTipRaster {
        raster(size: size) { context, rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerRadius = (min(rect.width, rect.height) * 0.5) - outerInset
            let innerRadius = outerRadius * innerRadiusRatio
            let path = CGMutablePath()

            for index in 0..<(points * 2) {
                let angle = (CGFloat(index) * .pi / CGFloat(points)) - (.pi / 2)
                let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }
    }

    private static func raster(size: Int, draw: (CGContext, CGRect) -> Void) -> BrushTipRaster {
        var pixels = [UInt8](repeating: 0, count: size * size)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                return
            }

            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.setFillColor(gray: 1.0, alpha: 1.0)
            draw(context, CGRect(x: 0, y: 0, width: size, height: size))
        }

        return BrushTipRaster(width: size, height: size, alphaData: Data(pixels))
    }
}

struct LayerRowModel: Identifiable, Equatable, Sendable {
    var id: Int { index }
    let index: Int
    let name: String
    let visible: Bool
    let opacity: Double
    let blendMode: LayerBlendMode
    let folderID: Int?
    let hasMask: Bool

    static func == (lhs: LayerRowModel, rhs: LayerRowModel) -> Bool {
        lhs.index == rhs.index &&
        lhs.name == rhs.name &&
        lhs.visible == rhs.visible &&
        lhs.opacity == rhs.opacity &&
        lhs.blendMode == rhs.blendMode &&
        lhs.folderID == rhs.folderID &&
        lhs.hasMask == rhs.hasMask
    }
}

struct LayerFolderModel: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let visible: Bool
    let isExpanded: Bool
    let anchorLayerIndex: Int?
    let childLayerIndices: [Int]
}

enum LayerSidebarRowModel: Identifiable, Equatable, Sendable {
    case folder(LayerFolderModel)
    case layer(LayerRowModel, depth: Int)

    var id: String {
        switch self {
        case let .folder(folder):
            return "folder-\(folder.id)"
        case let .layer(layer, _):
            return "layer-\(layer.index)"
        }
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

struct StylusSample: Equatable, Sendable {
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
    let flow: CGFloat
    let hardness: CGFloat
    let roundness: CGFloat
    let angle: CGFloat
    let followsStrokeAngle: Bool
    let pressureSensitivity: CGFloat
    let stabilization: CGFloat
    let customTip: BrushTipRaster?
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

enum TimelapseCaptureSource: Equatable, Sendable {
    case frames([TimelapseFrame])
    case operations([TimelapseOperation])
}

struct TimelapseCapture: Equatable, Sendable {
    let canvasSize: CGSize
    let paperStyle: CanvasPaperStyle
    let previewImageData: Data?
    let source: TimelapseCaptureSource
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

struct CanvasSelection: Equatable, Sendable {
    let bounds: CGRect
    let maskWidth: Int
    let maskHeight: Int
    let maskData: Data
    let mode: SelectionToolMode

    var isEmpty: Bool {
        maskWidth <= 0 || maskHeight <= 0 || maskData.isEmpty || bounds.isNull || bounds.isEmpty
    }
}
