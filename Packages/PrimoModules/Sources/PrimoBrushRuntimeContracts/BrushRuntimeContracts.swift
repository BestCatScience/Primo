import Foundation
import PrimoBrushDomain

public enum FillThresholdMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case opacity
    case color

    public var id: String { rawValue }
}

public struct BrushRuntimeSettings: Equatable, Sendable {
    public var tipKind: BrushTipKind
    public var radius: Double
    public var sizeSpeedSensitivity: Double = 0.0
    public var taperIn: Double = 0.0
    public var taperOut: Double = 0.0
    public var opacity: Double
    public var hardness: Double
    public var roundness: Double
    public var roundnessPressureSensitivity: Double = 0.0
    public var roundnessTiltSensitivity: Double = 0.0
    public var angle: Double
    public var anglePressureSensitivity: Double = 0.0
    public var angleTiltSensitivity: Double = 0.0
    public var angleMode: BrushAngleMode
    public var stampSpacing: Double
    public var spacingJitter: Double
    public var scatterEnabled: Bool = false
    public var scatterMode: BrushScatterMode = .directional
    public var scatterLateral: Double
    public var scatterLinear: Double
    public var count: Int
    public var countJitter: Double
    public var countSizeJitter: Double = 0.0
    public var countOpacityJitter: Double = 0.0
    public var angleJitter: Double
    public var roundnessJitter: Double
    public var textureMode: BrushTextureMode
    public var textureStrength: Double
    public var flow: Double = 1.0
    public var flowPressureSensitivity: Double = 0.0
    public var flowJitter: Double = 0.0
    public var velocityInfluence: Double = 0.0
    public var colorMixingMode: BrushColorMixingMode = .off
    public var wetness: Double = 0.0
    public var wetnessPressureSensitivity: Double = 0.0
    public var opacityPressureSensitivity: Double = 0.0
    public var colorMixStrength: Double = 0.0
    public var smudgeBlurEnabled: Bool = false
    public var smudgeBleed: Double = 0.0
    public var smudgeRadius: Double = 0.0
    public var paintLoad: Double = 1.0
    public var smudgeEngineEnabled: Bool = false
    public var smudgeMode: BrushSmudgeMode = .smearing
    public var smudgeLength: Double = 0.0
    public var colorRate: Double = 1.0
    public var loadPressureSensitivity: Double = 0.0
    public var paintAmountPressureBypass: Double = 1.0
    public var paintDensityPressureBypass: Double = 1.0
    public var colorStretchPressureBypass: Double = 1.0
    public var dualBrushEnabled: Bool = false
    public var dualTipKind: BrushTipKind = .ink
    public var dualScale: Double = 0.72
    public var dualSpacing: Double = 0.26
    public var dualScatter: Double = 0.18
    public var dualAngle: Double = 0.0
    public var dualBlendMode: BrushDualBlendMode = .multiply
    public var grainScale: Double = 1.35
    public var grainContrast: Double = 1.7
    public var paperScale: Double = 0.12
    public var paperStrength: Double = 0.32
    public var paperThreshold: Double = 0.42
    public var flipX: Bool = false
    public var flipY: Bool = false
    public var customTip: BrushTipRaster? = nil
    public var pressureSensitivity: Double
    public var stabilization: Double = 0.5
    public var fillThresholdMode: FillThresholdMode = .opacity
    public var fillOpacityTolerance: Double = 0.0
    public var fillColorTolerance: Double = 0.12
    public var fillExpansion: Int = 0
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var isEraser: Bool = false

    public init(
        tipKind: BrushTipKind,
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
        stampSpacing: Double,
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
        flow: Double = 1.0,
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
        smudgeEngineEnabled: Bool,
        smudgeMode: BrushSmudgeMode,
        smudgeLength: Double,
        colorRate: Double,
        loadPressureSensitivity: Double = 0.0,
        paintAmountPressureBypass: Double = 1.0,
        paintDensityPressureBypass: Double = 1.0,
        colorStretchPressureBypass: Double = 1.0,
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
        flipX: Bool = false,
        flipY: Bool = false,
        customTip: BrushTipRaster? = nil,
        pressureSensitivity: Double,
        stabilization: Double = 0.5,
        fillThresholdMode: FillThresholdMode = .opacity,
        fillOpacityTolerance: Double = 0.0,
        fillColorTolerance: Double = 0.12,
        fillExpansion: Int = 0,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        isEraser: Bool = false
    ) {
        self.tipKind = tipKind
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
        self.stampSpacing = stampSpacing
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
        self.smudgeEngineEnabled = smudgeEngineEnabled
        self.smudgeMode = smudgeMode
        self.smudgeLength = smudgeLength
        self.colorRate = colorRate
        self.loadPressureSensitivity = loadPressureSensitivity
        self.paintAmountPressureBypass = paintAmountPressureBypass
        self.paintDensityPressureBypass = paintDensityPressureBypass
        self.colorStretchPressureBypass = colorStretchPressureBypass
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
        self.stabilization = stabilization
        self.fillThresholdMode = fillThresholdMode
        self.fillOpacityTolerance = fillOpacityTolerance
        self.fillColorTolerance = fillColorTolerance
        self.fillExpansion = fillExpansion
        self.red = red
        self.green = green
        self.blue = blue
        self.isEraser = isEraser
    }

    public init(
        tipKind: BrushTipKind,
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
        stampSpacing: Double,
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
        flow: Double = 1.0,
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
        paintAmountPressureBypass: Double = 1.0,
        paintDensityPressureBypass: Double = 1.0,
        colorStretchPressureBypass: Double = 1.0,
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
        flipX: Bool = false,
        flipY: Bool = false,
        customTip: BrushTipRaster? = nil,
        pressureSensitivity: Double,
        stabilization: Double = 0.5,
        fillThresholdMode: FillThresholdMode = .opacity,
        fillOpacityTolerance: Double = 0.0,
        fillColorTolerance: Double = 0.12,
        fillExpansion: Int = 0,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        isEraser: Bool = false
    ) {
        self.init(
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
            stampSpacing: stampSpacing,
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
            colorMixingMode: colorMixingMode,
            wetness: wetness,
            wetnessPressureSensitivity: wetnessPressureSensitivity,
            opacityPressureSensitivity: opacityPressureSensitivity,
            colorMixStrength: colorMixStrength,
            smudgeBlurEnabled: smudgeBlurEnabled,
            smudgeBleed: smudgeBleed,
            smudgeRadius: smudgeRadius,
            paintLoad: paintLoad,
            smudgeEngineEnabled: false,
            smudgeMode: .smearing,
            smudgeLength: 0.0,
            colorRate: 1.0,
            loadPressureSensitivity: loadPressureSensitivity,
            paintAmountPressureBypass: paintAmountPressureBypass,
            paintDensityPressureBypass: paintDensityPressureBypass,
            colorStretchPressureBypass: colorStretchPressureBypass,
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
            stabilization: stabilization,
            fillThresholdMode: fillThresholdMode,
            fillOpacityTolerance: fillOpacityTolerance,
            fillColorTolerance: fillColorTolerance,
            fillExpansion: fillExpansion,
            red: red,
            green: green,
            blue: blue,
            isEraser: isEraser
        )
    }
}
