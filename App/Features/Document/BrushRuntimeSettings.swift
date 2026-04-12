import Foundation

struct BrushRuntimeSettings: Equatable, Sendable {
    var tipKind: BrushTipKind
    var radius: Double
    var sizeSpeedSensitivity: Double = 0.0
    var taperIn: Double = 0.0
    var taperOut: Double = 0.0
    var opacity: Double
    var hardness: Double
    var roundness: Double
    var roundnessPressureSensitivity: Double = 0.0
    var roundnessTiltSensitivity: Double = 0.0
    var angle: Double
    var anglePressureSensitivity: Double = 0.0
    var angleTiltSensitivity: Double = 0.0
    var angleMode: BrushAngleMode
    var stampSpacing: Double
    var spacingJitter: Double
    var scatterEnabled: Bool = false
    var scatterMode: BrushScatterMode = .directional
    var scatterLateral: Double
    var scatterLinear: Double
    var count: Int
    var countJitter: Double
    var countSizeJitter: Double = 0.0
    var countOpacityJitter: Double = 0.0
    var angleJitter: Double
    var roundnessJitter: Double
    var textureMode: BrushTextureMode
    var textureStrength: Double
    var flow: Double = 1.0
    var flowPressureSensitivity: Double = 0.0
    var flowJitter: Double = 0.0
    var velocityInfluence: Double = 0.0
    var wetness: Double = 0.0
    var wetnessPressureSensitivity: Double = 0.0
    var opacityPressureSensitivity: Double = 0.0
    var colorMixStrength: Double = 0.0
    var paintLoad: Double = 1.0
    var loadPressureSensitivity: Double = 0.0
    var dualBrushEnabled: Bool = false
    var dualTipKind: BrushTipKind = .ink
    var dualScale: Double = 0.72
    var dualSpacing: Double = 0.26
    var dualScatter: Double = 0.18
    var dualAngle: Double = 0.0
    var dualBlendMode: BrushDualBlendMode = .multiply
    var grainScale: Double = 1.35
    var grainContrast: Double = 1.7
    var paperScale: Double = 0.12
    var paperStrength: Double = 0.32
    var paperThreshold: Double = 0.42
    var flipX: Bool = false
    var flipY: Bool = false
    var customTip: BrushTipRaster? = nil
    var pressureSensitivity: Double
    var stabilization: Double = 0.0
    var fillThresholdMode: FillThresholdMode = .opacity
    var fillOpacityTolerance: Double = 0.0
    var fillColorTolerance: Double = 0.12
    var fillExpansion: Int = 0
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var isEraser: Bool = false

    func withCustomTip(from sourceURL: URL) throws -> BrushRuntimeSettings {
        var copy = self
        copy.customTip = try BrushTipLibrary.loadRaster(from: sourceURL)
        return copy
    }

    func withPhotoshopBrush(_ imported: ImportedPhotoshopBrush) -> BrushRuntimeSettings {
        BrushRuntimeSettings(
            tipKind: imported.preset.tipKind,
            radius: imported.preset.radius,
            sizeSpeedSensitivity: imported.preset.sizeSpeedSensitivity,
            taperIn: imported.preset.taperIn,
            taperOut: imported.preset.taperOut,
            opacity: imported.preset.opacity,
            hardness: imported.preset.hardness,
            roundness: imported.preset.roundness,
            roundnessPressureSensitivity: imported.preset.roundnessPressureSensitivity,
            roundnessTiltSensitivity: imported.preset.roundnessTiltSensitivity,
            angle: imported.preset.angle,
            anglePressureSensitivity: imported.preset.anglePressureSensitivity,
            angleTiltSensitivity: imported.preset.angleTiltSensitivity,
            angleMode: imported.preset.angleMode,
            stampSpacing: imported.preset.spacing,
            spacingJitter: imported.preset.spacingJitter,
            scatterEnabled: imported.preset.scatterEnabled,
            scatterMode: imported.preset.scatterMode,
            scatterLateral: imported.preset.scatterLateral,
            scatterLinear: imported.preset.scatterLinear,
            count: imported.preset.count,
            countJitter: imported.preset.countJitter,
            countSizeJitter: imported.preset.countSizeJitter,
            countOpacityJitter: imported.preset.countOpacityJitter,
            angleJitter: imported.preset.angleJitter,
            roundnessJitter: imported.preset.roundnessJitter,
            textureMode: imported.preset.textureMode,
            textureStrength: imported.preset.textureStrength,
            flow: imported.preset.flow,
            flowPressureSensitivity: imported.preset.flowPressureSensitivity,
            flowJitter: imported.preset.flowJitter,
            velocityInfluence: imported.preset.velocityInfluence,
            wetness: imported.preset.wetness,
            wetnessPressureSensitivity: imported.preset.wetnessPressureSensitivity,
            opacityPressureSensitivity: imported.preset.opacityPressureSensitivity,
            colorMixStrength: imported.preset.colorMixStrength,
            paintLoad: imported.preset.paintLoad,
            loadPressureSensitivity: imported.preset.loadPressureSensitivity,
            dualBrushEnabled: imported.preset.dualBrushEnabled,
            dualTipKind: imported.preset.dualTipKind,
            dualScale: imported.preset.dualScale,
            dualSpacing: imported.preset.dualSpacing,
            dualScatter: imported.preset.dualScatter,
            dualAngle: imported.preset.dualAngle,
            dualBlendMode: imported.preset.dualBlendMode,
            grainScale: imported.preset.grainScale,
            grainContrast: imported.preset.grainContrast,
            paperScale: imported.preset.paperScale,
            paperStrength: imported.preset.paperStrength,
            paperThreshold: imported.preset.paperThreshold,
            flipX: imported.preset.flipX,
            flipY: imported.preset.flipY,
            customTip: imported.tip,
            pressureSensitivity: imported.preset.pressureSensitivity,
            stabilization: stabilization,
            fillThresholdMode: fillThresholdMode,
            fillOpacityTolerance: fillOpacityTolerance,
            fillColorTolerance: fillColorTolerance,
            fillExpansion: fillExpansion,
            red: imported.preset.red,
            green: imported.preset.green,
            blue: imported.preset.blue,
            isEraser: isEraser
        )
    }
}
