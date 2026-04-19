import Foundation
import SwiftUI
import CoreGraphics
import PrimoBrushDomain
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoLocalization
import UIKit
import simd

typealias SelectionToolMode = PrimoDocumentDomain.SelectionToolMode
typealias ShapeToolMode = PrimoDocumentDomain.ShapeToolMode
typealias LayerBlendMode = PrimoDocumentDomain.LayerBlendMode
typealias BrushTipKind = PrimoBrushDomain.BrushTipKind
typealias BrushAngleMode = PrimoBrushDomain.BrushAngleMode
typealias BrushTextureMode = PrimoBrushDomain.BrushTextureMode
typealias BrushDualBlendMode = PrimoBrushDomain.BrushDualBlendMode
typealias BrushScatterMode = PrimoBrushDomain.BrushScatterMode
typealias BrushColorMixingMode = PrimoBrushDomain.BrushColorMixingMode
typealias FillThresholdMode = PrimoDocumentContracts.FillThresholdMode
typealias HueSaturationBrightnessSettings = PrimoDocumentContracts.HueSaturationBrightnessSettings
typealias BrightnessContrastSettings = PrimoDocumentContracts.BrightnessContrastSettings
typealias LevelsAdjustmentSettings = PrimoDocumentContracts.LevelsAdjustmentSettings
typealias ToneCurveSettings = PrimoDocumentContracts.ToneCurveSettings
typealias ColorBalanceSettings = PrimoDocumentContracts.ColorBalanceSettings
typealias ThresholdSettings = PrimoDocumentContracts.ThresholdSettings
typealias PosterizeSettings = PrimoDocumentContracts.PosterizeSettings
typealias GradientMapPreset = PrimoDocumentContracts.GradientMapPreset
typealias GradientMapStopSettings = PrimoDocumentContracts.GradientMapStopSettings
typealias GradientMapSettings = PrimoDocumentContracts.GradientMapSettings
typealias LayerProcessingRequest = PrimoDocumentContracts.LayerProcessingRequest
typealias TimelapseFrame = PrimoDocumentContracts.TimelapseFrame
typealias TimelapseOperation = PrimoDocumentContracts.TimelapseOperation
typealias TimelapseCaptureSource = PrimoDocumentContracts.TimelapseCaptureSource
typealias TimelapseCapture = PrimoDocumentContracts.TimelapseCapture
typealias CanvasSelection = PrimoDocumentContracts.CanvasSelection

enum StudioToolKind: String, CaseIterable, Equatable, Sendable, Identifiable {
    case brush
    case erase
    case blur
    case fill
    case eyedropper
    case select
    case move
    case shape
    case text

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
        case .text:
            return language.localized("テキスト")
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
        case .text:
            return "textformat"
        }
    }
}

enum TextFontLibrary {
    private static let liveClient = TextFontLibraryClient.live(fileClient: .live)

    static func availableFonts() -> [TextFontOption] {
        liveClient.loadAvailableFonts()
    }

    static func importFonts(from urls: [URL]) throws -> [TextFontOption] {
        try liveClient.importFonts(urls)
    }
}

extension TextLayerData {
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
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

extension FillThresholdMode {
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

extension SelectionToolMode {
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

extension ShapeToolMode {
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

extension LayerBlendMode {
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

extension GradientMapPreset {
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

extension BrushTipKind {
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

extension BrushAngleMode {
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

extension BrushTextureMode {
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

extension BrushDualBlendMode {
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

extension BrushScatterMode {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .directional:
            return language.localized("方向散布")
        case .spray:
            return language.localized("スプレー")
        }
    }
}

extension BrushColorMixingMode {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .off:
            return language.localized("オフ")
        case .blend:
            return language.localized("ブレンド")
        case .runningColor:
            return language.localized("ランニングカラー")
        case .smear:
            return language.localized("スメア")
        }
    }

}

enum BrushTipShapePreset: String, CaseIterable, Equatable, Sendable, Identifiable {
    case round
    case block
    case diamond
    case ribbon
    case petal
    case rake
    case star
    case custom

    var id: String { rawValue }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .round:
            return language.localized("ラウンド")
        case .block:
            return language.localized("スクエア")
        case .diamond:
            return language.localized("ダイヤ")
        case .ribbon:
            return language.localized("リボン")
        case .petal:
            return language.localized("花びら")
        case .rake:
            return language.localized("レーキ")
        case .star:
            return language.localized("スター")
        case .custom:
            return language.localized("カスタム")
        }
    }

    func raster(currentCustomTip: BrushTipRaster?) -> BrushTipRaster? {
        switch self {
        case .round:
            return nil
        case .block:
            return BuiltInBrushTipFactory.block
        case .diamond:
            return BuiltInBrushTipFactory.diamond
        case .ribbon:
            return BuiltInBrushTipFactory.ribbon
        case .petal:
            return BuiltInBrushTipFactory.petal
        case .rake:
            return BuiltInBrushTipFactory.rake
        case .star:
            return BuiltInBrushTipFactory.star
        case .custom:
            return currentCustomTip
        }
    }

    static func matching(customTip: BrushTipRaster?) -> BrushTipShapePreset {
        guard let customTip else { return .round }
        for preset in BrushTipShapePreset.allCases where preset != .round && preset != .custom {
            if preset.raster(currentCustomTip: nil) == customTip {
                return preset
            }
        }
        return .custom
    }
}

struct BrushPreset: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let tipKind: BrushTipKind
    let color: Color
    let radius: Double
    let sizeSpeedSensitivity: Double
    let taperIn: Double
    let taperOut: Double
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
    let colorMixingMode: BrushColorMixingMode
    let wetness: Double
    let wetnessPressureSensitivity: Double
    let opacityPressureSensitivity: Double
    let colorMixStrength: Double
    let smudgeBlurEnabled: Bool
    let smudgeBleed: Double
    let smudgeRadius: Double
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
        lhs.taperIn == rhs.taperIn &&
        lhs.taperOut == rhs.taperOut &&
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
        lhs.colorMixingMode == rhs.colorMixingMode &&
        lhs.wetness == rhs.wetness &&
        lhs.wetnessPressureSensitivity == rhs.wetnessPressureSensitivity &&
        lhs.opacityPressureSensitivity == rhs.opacityPressureSensitivity &&
        lhs.colorMixStrength == rhs.colorMixStrength &&
        lhs.smudgeBlurEnabled == rhs.smudgeBlurEnabled &&
        lhs.smudgeBleed == rhs.smudgeBleed &&
        lhs.smudgeRadius == rhs.smudgeRadius &&
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
        taperIn: Double = 0.0,
        taperOut: Double = 0.0,
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
        colorMixingMode: BrushColorMixingMode = .off,
        wetness: Double = 0.0,
        wetnessPressureSensitivity: Double = 0.0,
        opacityPressureSensitivity: Double = 0.0,
        colorMixStrength: Double = 0.0,
        smudgeBlurEnabled: Bool = false,
        smudgeBleed: Double = 0.0,
        smudgeRadius: Double = 0.0,
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
        self.taperIn = taperIn
        self.taperOut = taperOut
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
        self.colorMixingMode = colorMixingMode
        self.wetness = wetness
        self.wetnessPressureSensitivity = wetnessPressureSensitivity
        self.opacityPressureSensitivity = opacityPressureSensitivity
        self.colorMixStrength = colorMixStrength
        self.smudgeBlurEnabled = smudgeBlurEnabled
        self.smudgeBleed = smudgeBleed
        self.smudgeRadius = smudgeRadius
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
            name: "Sketch Pencil",
            tipKind: .pencil,
            color: Color(red: 0.11, green: 0.11, blue: 0.12),
            radius: 2.7,
            opacity: 0.82,
            hardness: 0.76,
            roundness: 0.88,
            roundnessPressureSensitivity: 0.10,
            roundnessTiltSensitivity: 0.18,
            angle: 0.02,
            anglePressureSensitivity: 0.03,
            angleTiltSensitivity: 0.12,
            spacing: 0.11,
            scatterLateral: 0.02,
            scatterLinear: 0.01,
            angleJitter: 0.02,
            roundnessJitter: 0.03,
            textureMode: .eachTip,
            textureStrength: 0.84,
            flow: 0.84,
            flowPressureSensitivity: 0.18,
            flowJitter: 0.03,
            wetness: 0.05,
            wetnessPressureSensitivity: 0.12,
            opacityPressureSensitivity: 0.46,
            colorMixStrength: 0.06,
            paintLoad: 0.94,
            loadPressureSensitivity: 0.08,
            grainScale: 1.42,
            grainContrast: 1.88,
            paperScale: 0.14,
            paperStrength: 0.42,
            paperThreshold: 0.40,
            pressureSensitivity: 0.70,
            red: 30,
            green: 30,
            blue: 33
        ),
        studioPreset(
            name: "Shade Pencil",
            tipKind: .pencil,
            color: Color(red: 0.15, green: 0.15, blue: 0.16),
            radius: 5.2,
            opacity: 0.56,
            hardness: 0.54,
            roundness: 0.94,
            roundnessPressureSensitivity: 0.16,
            roundnessTiltSensitivity: 0.24,
            angle: -0.04,
            anglePressureSensitivity: 0.05,
            angleTiltSensitivity: 0.16,
            spacing: 0.14,
            scatterLateral: 0.03,
            scatterLinear: 0.01,
            angleJitter: 0.04,
            roundnessJitter: 0.06,
            textureMode: .eachTip,
            textureStrength: 0.92,
            flow: 0.66,
            flowPressureSensitivity: 0.22,
            flowJitter: 0.06,
            wetness: 0.08,
            wetnessPressureSensitivity: 0.14,
            opacityPressureSensitivity: 0.60,
            colorMixStrength: 0.10,
            paintLoad: 0.90,
            loadPressureSensitivity: 0.12,
            grainScale: 1.54,
            grainContrast: 2.02,
            paperScale: 0.16,
            paperStrength: 0.52,
            paperThreshold: 0.40,
            pressureSensitivity: 0.86,
            red: 40,
            green: 40,
            blue: 43
        ),
        studioPreset(
            name: "Technical Pen",
            tipKind: .ink,
            color: Color(red: 0.04, green: 0.05, blue: 0.07),
            radius: 1.7,
            sizeSpeedSensitivity: 0.0,
            opacity: 1.0,
            hardness: 0.96,
            roundness: 1.0,
            angleMode: .fixed,
            spacing: 0.05,
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
            radius: 3.2,
            sizeSpeedSensitivity: 0.0,
            opacity: 1.0,
            hardness: 0.86,
            roundness: 0.58,
            roundnessPressureSensitivity: 0.10,
            roundnessTiltSensitivity: 0.12,
            angleMode: .strokeDirection,
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
            name: "Texture Spray",
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
            name: "Flat Paint",
            tipKind: .oil,
            color: Color(red: 0.23, green: 0.27, blue: 0.34),
            radius: 7.2,
            sizeSpeedSensitivity: 0.0,
            opacity: 0.90,
            hardness: 0.74,
            roundness: 0.86,
            roundnessPressureSensitivity: 0.03,
            roundnessTiltSensitivity: 0.03,
            angle: 0.0,
            anglePressureSensitivity: 0.0,
            angleTiltSensitivity: 0.0,
            angleMode: .fixed,
            spacing: 0.05,
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
            textureStrength: 0.20,
            flow: 0.70,
            flowPressureSensitivity: 0.08,
            flowJitter: 0.0,
            colorMixingMode: .runningColor,
            wetness: 0.84,
            wetnessPressureSensitivity: 0.18,
            opacityPressureSensitivity: 0.12,
            colorMixStrength: 0.76,
            smudgeBlurEnabled: true,
            smudgeBleed: 0.90,
            smudgeRadius: 0.96,
            paintLoad: 0.14,
            loadPressureSensitivity: 0.18,
            dualBrushEnabled: false,
            dualTipKind: .oil,
            dualScale: 0.64,
            dualSpacing: 0.22,
            dualScatter: 0.10,
            dualAngle: 0.08,
            dualBlendMode: .darker,
            grainScale: 1.10,
            grainContrast: 1.30,
            paperScale: 0.10,
            paperStrength: 0.08,
            paperThreshold: 0.46,
            pressureSensitivity: 0.18,
            red: 59,
            green: 69,
            blue: 87,
            customTip: BuiltInBrushTipFactory.block
        ),
        studioPreset(
            name: "Dry Bristle",
            tipKind: .oil,
            color: Color(red: 0.16, green: 0.17, blue: 0.18),
            radius: 5.8,
            sizeSpeedSensitivity: 0.0,
            opacity: 0.78,
            hardness: 0.88,
            roundness: 0.76,
            roundnessPressureSensitivity: 0.03,
            roundnessTiltSensitivity: 0.04,
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
            textureStrength: 0.38,
            flow: 0.60,
            flowPressureSensitivity: 0.06,
            flowJitter: 0.0,
            colorMixingMode: .blend,
            wetness: 0.58,
            wetnessPressureSensitivity: 0.10,
            opacityPressureSensitivity: 0.10,
            colorMixStrength: 0.54,
            smudgeBleed: 0.68,
            smudgeRadius: 0.74,
            paintLoad: 0.24,
            loadPressureSensitivity: 0.14,
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
            name: "Rake Texture",
            tipKind: .oil,
            color: Color(red: 0.18, green: 0.20, blue: 0.23),
            radius: 8.4,
            sizeSpeedSensitivity: 0.0,
            opacity: 0.88,
            hardness: 0.72,
            roundness: 0.74,
            angleMode: .strokeDirection,
            spacing: 0.05,
            scatterLateral: 0.0,
            scatterLinear: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .strokeLocked,
            textureStrength: 0.14,
            flow: 0.64,
            flowPressureSensitivity: 0.12,
            colorMixingMode: .runningColor,
            wetness: 0.92,
            wetnessPressureSensitivity: 0.18,
            opacityPressureSensitivity: 0.10,
            colorMixStrength: 0.84,
            smudgeBlurEnabled: true,
            smudgeBleed: 1.00,
            smudgeRadius: 1.00,
            paintLoad: 0.08,
            loadPressureSensitivity: 0.18,
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
            name: "Smudge Pull",
            tipKind: .oil,
            color: Color(red: 0.24, green: 0.25, blue: 0.28),
            radius: 9.8,
            sizeSpeedSensitivity: 0.0,
            opacity: 0.72,
            hardness: 0.44,
            roundness: 0.88,
            angleMode: .strokeDirection,
            spacing: 0.04,
            scatterLateral: 0.01,
            scatterLinear: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .strokeLocked,
            textureStrength: 0.12,
            flow: 0.36,
            flowPressureSensitivity: 0.10,
            colorMixingMode: .smear,
            wetness: 1.00,
            wetnessPressureSensitivity: 0.22,
            opacityPressureSensitivity: 0.10,
            colorMixStrength: 0.92,
            smudgeBlurEnabled: true,
            smudgeBleed: 0.96,
            smudgeRadius: 1.00,
            paintLoad: 0.03,
            loadPressureSensitivity: 0.20,
            dualBrushEnabled: true,
            dualTipKind: .oil,
            dualScale: 0.72,
            dualSpacing: 0.18,
            dualScatter: 0.08,
            dualAngle: 0.10,
            dualBlendMode: .darker,
            grainScale: 1.12,
            grainContrast: 1.24,
            paperScale: 0.10,
            paperStrength: 0.08,
            paperThreshold: 0.46,
            pressureSensitivity: 0.12,
            red: 61,
            green: 63,
            blue: 71,
            customTip: BuiltInBrushTipFactory.block
        ),
        studioPreset(
            name: "Wet Mixer",
            tipKind: .airbrush,
            color: Color(red: 0.22, green: 0.23, blue: 0.26),
            radius: 12.0,
            sizeSpeedSensitivity: 0.0,
            opacity: 0.32,
            hardness: 0.16,
            roundness: 1.0,
            angleMode: .fixed,
            spacing: 0.18,
            spacingJitter: 0.03,
            scatterEnabled: true,
            scatterMode: .spray,
            scatterLateral: 0.08,
            scatterLinear: 0.04,
            count: 2,
            countJitter: 0.10,
            countSizeJitter: 0.08,
            countOpacityJitter: 0.10,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .moving,
            textureStrength: 0.10,
            flow: 0.58,
            flowPressureSensitivity: 0.12,
            flowJitter: 0.08,
            colorMixingMode: .runningColor,
            wetness: 0.94,
            wetnessPressureSensitivity: 0.20,
            opacityPressureSensitivity: 0.22,
            colorMixStrength: 0.88,
            smudgeBlurEnabled: true,
            smudgeBleed: 1.00,
            smudgeRadius: 1.00,
            paintLoad: 0.08,
            loadPressureSensitivity: 0.18,
            grainScale: 1.02,
            grainContrast: 1.08,
            paperScale: 0.06,
            paperStrength: 0.02,
            paperThreshold: 0.48,
            pressureSensitivity: 0.06,
            red: 56,
            green: 58,
            blue: 63
        )
    ]

    static let defaultPencil = defaults[0]

    private static func studioPreset(
        name: String,
        tipKind: BrushTipKind,
        color: Color,
        radius: Double,
        sizeSpeedSensitivity: Double = 0.0,
        taperIn: Double = 0.0,
        taperOut: Double = 0.0,
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
        colorMixingMode: BrushColorMixingMode = .off,
        wetness: Double = 0.0,
        wetnessPressureSensitivity: Double = 0.0,
        opacityPressureSensitivity: Double = 0.0,
        colorMixStrength: Double = 0.0,
        smudgeBlurEnabled: Bool = false,
        smudgeBleed: Double = 0.0,
        smudgeRadius: Double = 0.0,
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

typealias LayerRowModel = PrimoDocumentContracts.LayerRowModel
typealias LayerFolderModel = PrimoDocumentContracts.LayerFolderModel
typealias LayerSidebarRowModel = PrimoDocumentContracts.LayerSidebarRowModel

struct LayerCanvasBuffer: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
    var name: String
    var visible: Bool
    var opacity: Double
    var blendMode: LayerBlendMode = .normal
    var strokes: [PreviewStrokeTrack] = []
}

typealias StylusSample = PrimoDocumentContracts.StylusSample

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

typealias MetalLayerSnapshot = PrimoDocumentContracts.MetalLayerSnapshot

typealias MetalDocumentSnapshot = PrimoDocumentContracts.MetalDocumentSnapshot
typealias IncrementalLayerUpdate = PrimoDocumentContracts.IncrementalLayerUpdate
