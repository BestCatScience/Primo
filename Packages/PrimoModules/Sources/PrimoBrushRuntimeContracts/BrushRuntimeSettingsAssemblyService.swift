import Foundation
import PrimoBrushDomain

public struct BrushColorComponents: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct BrushFillRuntimeDescriptor: Equatable, Sendable {
    public var thresholdMode: FillThresholdMode
    public var opacityTolerance: Double
    public var colorTolerance: Double
    public var expansion: Double

    public init(
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Double
    ) {
        self.thresholdMode = thresholdMode
        self.opacityTolerance = opacityTolerance
        self.colorTolerance = colorTolerance
        self.expansion = expansion
    }
}

public struct BrushRuntimeDescriptor: Sendable {
    public var tipKind: BrushTipKind
    public var radius: Double
    public var sizeSpeedSensitivity: Double
    public var taperIn: Double
    public var taperOut: Double
    public var opacity: Double
    public var hardness: Double
    public var roundness: Double
    public var roundnessPressureSensitivity: Double
    public var roundnessTiltSensitivity: Double
    public var angle: Double
    public var anglePressureSensitivity: Double
    public var angleTiltSensitivity: Double
    public var angleMode: BrushAngleMode
    public var spacing: Double
    public var spacingJitter: Double
    public var scatterEnabled: Bool
    public var scatterMode: BrushScatterMode
    public var scatterLateral: Double
    public var scatterLinear: Double
    public var count: Double
    public var countJitter: Double
    public var countSizeJitter: Double
    public var countOpacityJitter: Double
    public var angleJitter: Double
    public var roundnessJitter: Double
    public var textureMode: BrushTextureMode
    public var textureStrength: Double
    public var flow: Double
    public var flowPressureSensitivity: Double
    public var flowJitter: Double
    public var velocityInfluence: Double
    public var wetness: Double
    public var wetnessPressureSensitivity: Double
    public var opacityPressureSensitivity: Double
    public var colorMixStrength: Double
    public var smudgeRadius: Double
    public var paintLoad: Double
    public var smudgeEngineEnabled: Bool
    public var smudgeMode: BrushSmudgeMode
    public var smudgeLength: Double
    public var colorRate: Double
    public var loadPressureSensitivity: Double
    public var paintAmountPressureBypass: Double
    public var paintDensityPressureBypass: Double
    public var colorStretchPressureBypass: Double
    public var dualEnabled: Bool
    public var dualTipKind: BrushTipKind
    public var dualScale: Double
    public var dualSpacing: Double
    public var dualScatter: Double
    public var dualAngle: Double
    public var dualBlendMode: BrushDualBlendMode
    public var grainScale: Double
    public var grainContrast: Double
    public var paperScale: Double
    public var paperStrength: Double
    public var paperThreshold: Double
    public var flipX: Bool
    public var flipY: Bool
    public var customTip: BrushTipRaster?
    public var pressureSensitivity: Double
    public var stabilization: Double
    public var isEraser: Bool

    public init(
        tipKind: BrushTipKind,
        radius: Double,
        sizeSpeedSensitivity: Double,
        taperIn: Double,
        taperOut: Double,
        opacity: Double,
        hardness: Double,
        roundness: Double,
        roundnessPressureSensitivity: Double,
        roundnessTiltSensitivity: Double,
        angle: Double,
        anglePressureSensitivity: Double,
        angleTiltSensitivity: Double,
        angleMode: BrushAngleMode,
        spacing: Double,
        spacingJitter: Double,
        scatterEnabled: Bool,
        scatterMode: BrushScatterMode,
        scatterLateral: Double,
        scatterLinear: Double,
        count: Double,
        countJitter: Double,
        countSizeJitter: Double,
        countOpacityJitter: Double,
        angleJitter: Double,
        roundnessJitter: Double,
        textureMode: BrushTextureMode,
        textureStrength: Double,
        flow: Double,
        flowPressureSensitivity: Double,
        flowJitter: Double,
        velocityInfluence: Double,
        wetness: Double,
        wetnessPressureSensitivity: Double,
        opacityPressureSensitivity: Double,
        colorMixStrength: Double,
        smudgeRadius: Double = 0.0,
        paintLoad: Double,
        smudgeEngineEnabled: Bool = false,
        smudgeMode: BrushSmudgeMode = .smearing,
        smudgeLength: Double = 0.0,
        colorRate: Double = 1.0,
        loadPressureSensitivity: Double,
        paintAmountPressureBypass: Double = 1.0,
        paintDensityPressureBypass: Double = 1.0,
        colorStretchPressureBypass: Double = 1.0,
        dualEnabled: Bool,
        dualTipKind: BrushTipKind,
        dualScale: Double,
        dualSpacing: Double,
        dualScatter: Double,
        dualAngle: Double,
        dualBlendMode: BrushDualBlendMode,
        grainScale: Double,
        grainContrast: Double,
        paperScale: Double,
        paperStrength: Double,
        paperThreshold: Double,
        flipX: Bool,
        flipY: Bool,
        customTip: BrushTipRaster?,
        pressureSensitivity: Double,
        stabilization: Double,
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
        self.dualEnabled = dualEnabled
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
        self.isEraser = isEraser
    }
}

public struct BrushRuntimeSettingsAssemblyService: Sendable {
    public init() {}

    public func makeRuntimeSettings(
        brush: BrushRuntimeDescriptor,
        fill: BrushFillRuntimeDescriptor,
        color: BrushColorComponents
    ) -> BrushRuntimeSettings {
        BrushRuntimeSettings(
            tipKind: brush.tipKind,
            radius: brush.radius,
            sizeSpeedSensitivity: brush.sizeSpeedSensitivity,
            taperIn: brush.taperIn,
            taperOut: brush.taperOut,
            opacity: brush.opacity,
            hardness: brush.hardness,
            roundness: brush.roundness,
            roundnessPressureSensitivity: brush.roundnessPressureSensitivity,
            roundnessTiltSensitivity: brush.roundnessTiltSensitivity,
            angle: brush.angle,
            anglePressureSensitivity: brush.anglePressureSensitivity,
            angleTiltSensitivity: brush.angleTiltSensitivity,
            angleMode: brush.angleMode,
            stampSpacing: brush.spacing,
            spacingJitter: brush.spacingJitter,
            scatterEnabled: brush.scatterEnabled,
            scatterMode: brush.scatterMode,
            scatterLateral: brush.scatterLateral,
            scatterLinear: brush.scatterLinear,
            count: Int(brush.count.rounded()),
            countJitter: brush.countJitter,
            countSizeJitter: brush.countSizeJitter,
            countOpacityJitter: brush.countOpacityJitter,
            angleJitter: brush.angleJitter,
            roundnessJitter: brush.roundnessJitter,
            textureMode: brush.textureMode,
            textureStrength: brush.textureStrength,
            flow: brush.flow,
            flowPressureSensitivity: brush.flowPressureSensitivity,
            flowJitter: brush.flowJitter,
            velocityInfluence: brush.velocityInfluence,
            wetness: brush.wetness,
            wetnessPressureSensitivity: brush.wetnessPressureSensitivity,
            opacityPressureSensitivity: brush.opacityPressureSensitivity,
            colorMixStrength: brush.colorMixStrength,
            smudgeBlurEnabled: false,
            smudgeBleed: 0.0,
            smudgeRadius: brush.smudgeEngineEnabled ? brush.smudgeRadius : 0.0,
            paintLoad: brush.paintLoad,
            smudgeEngineEnabled: brush.smudgeEngineEnabled,
            smudgeMode: brush.smudgeMode,
            smudgeLength: brush.smudgeLength,
            colorRate: brush.colorRate,
            loadPressureSensitivity: 0.0,
            paintAmountPressureBypass: brush.paintAmountPressureBypass,
            paintDensityPressureBypass: brush.paintDensityPressureBypass,
            colorStretchPressureBypass: brush.colorStretchPressureBypass,
            dualBrushEnabled: brush.dualEnabled,
            dualTipKind: brush.dualTipKind,
            dualScale: brush.dualScale,
            dualSpacing: brush.dualSpacing,
            dualScatter: brush.dualScatter,
            dualAngle: brush.dualAngle,
            dualBlendMode: brush.dualBlendMode,
            grainScale: brush.grainScale,
            grainContrast: brush.grainContrast,
            paperScale: brush.paperScale,
            paperStrength: brush.paperStrength,
            paperThreshold: brush.paperThreshold,
            flipX: brush.flipX,
            flipY: brush.flipY,
            customTip: brush.customTip,
            pressureSensitivity: brush.pressureSensitivity,
            stabilization: brush.stabilization,
            fillThresholdMode: fill.thresholdMode,
            fillOpacityTolerance: fill.opacityTolerance,
            fillColorTolerance: fill.colorTolerance,
            fillExpansion: Int(fill.expansion.rounded()),
            red: uint8ColorComponent(color.red),
            green: uint8ColorComponent(color.green),
            blue: uint8ColorComponent(color.blue),
            isEraser: brush.isEraser
        )
    }

    private func uint8ColorComponent(_ value: Double) -> UInt8 {
        UInt8(min(max(value * 255.0, 0.0), 255.0))
    }
}
