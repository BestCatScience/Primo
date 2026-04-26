import CoreGraphics
import Foundation
import PrimoBrushDomain
import PrimoBrushFileFormats
import PrimoDocumentContracts

public struct StoredStylusSample: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let pressure: Double
    let altitude: Double
    let azimuth: Double
    let timestamp: Double

    public init(_ sample: StylusSample) {
        x = Double(sample.point.x)
        y = Double(sample.point.y)
        pressure = Double(sample.pressure)
        altitude = Double(sample.altitude)
        azimuth = Double(sample.azimuth)
        timestamp = sample.timestamp
    }

    public var stylusSample: StylusSample {
        StylusSample(
            point: CGPoint(x: CGFloat(x), y: CGFloat(y)),
            pressure: CGFloat(pressure),
            altitude: CGFloat(altitude),
            azimuth: CGFloat(azimuth),
            timestamp: timestamp
        )
    }
}

public struct StoredBrushTipRaster: Codable, Equatable, Sendable {
    let width: Int
    let height: Int
    let alphaData: Data

    public init(_ raster: BrushTipRaster) {
        width = raster.width
        height = raster.height
        alphaData = raster.alphaData
    }

    public var raster: BrushTipRaster {
        BrushTipRaster(width: width, height: height, alphaData: alphaData)
    }
}

public struct StoredBrushRuntimeSettings: Codable, Equatable, Sendable {
    let tipKind: String
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
    let angleMode: String
    let stampSpacing: Double
    let spacingJitter: Double
    let scatterEnabled: Bool
    let scatterMode: String
    let scatterLateral: Double
    let scatterLinear: Double
    let count: Int
    let countJitter: Double
    let countSizeJitter: Double
    let countOpacityJitter: Double
    let angleJitter: Double
    let roundnessJitter: Double
    let textureMode: String
    let textureStrength: Double
    let flow: Double
    let flowPressureSensitivity: Double
    let flowJitter: Double
    let velocityInfluence: Double
    let colorMixingMode: String?
    let wetness: Double
    let wetnessPressureSensitivity: Double
    let opacityPressureSensitivity: Double
    let colorMixStrength: Double
    let smudgeBlurEnabled: Bool
    let smudgeBleed: Double
    let smudgeRadius: Double
    let paintLoad: Double
    let smudgeEngineEnabled: Bool
    let smudgeMode: String
    let smudgeLength: Double
    let colorRate: Double
    let loadPressureSensitivity: Double
    let paintAmountPressureBypass: Double?
    let paintDensityPressureBypass: Double?
    let colorStretchPressureBypass: Double?
    let dualBrushEnabled: Bool
    let dualTipKind: String
    let dualScale: Double
    let dualSpacing: Double
    let dualScatter: Double
    let dualAngle: Double
    let dualBlendMode: String
    let grainScale: Double
    let grainContrast: Double
    let paperScale: Double
    let paperStrength: Double
    let paperThreshold: Double
    let flipX: Bool
    let flipY: Bool
    let customTip: StoredBrushTipRaster?
    let pressureSensitivity: Double
    let stabilization: Double
    let fillThresholdMode: String
    let fillOpacityTolerance: Double
    let fillColorTolerance: Double
    let fillExpansion: Int
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let isEraser: Bool

    public init(_ brush: BrushRuntimeSettings) {
        tipKind = brush.tipKind.rawValue
        radius = brush.radius
        sizeSpeedSensitivity = brush.sizeSpeedSensitivity
        taperIn = brush.taperIn
        taperOut = brush.taperOut
        opacity = brush.opacity
        hardness = brush.hardness
        roundness = brush.roundness
        roundnessPressureSensitivity = brush.roundnessPressureSensitivity
        roundnessTiltSensitivity = brush.roundnessTiltSensitivity
        angle = brush.angle
        anglePressureSensitivity = brush.anglePressureSensitivity
        angleTiltSensitivity = brush.angleTiltSensitivity
        angleMode = brush.angleMode.rawValue
        stampSpacing = brush.stampSpacing
        spacingJitter = brush.spacingJitter
        scatterEnabled = brush.scatterEnabled
        scatterMode = brush.scatterMode.rawValue
        scatterLateral = brush.scatterLateral
        scatterLinear = brush.scatterLinear
        count = brush.count
        countJitter = brush.countJitter
        countSizeJitter = brush.countSizeJitter
        countOpacityJitter = brush.countOpacityJitter
        angleJitter = brush.angleJitter
        roundnessJitter = brush.roundnessJitter
        textureMode = brush.textureMode.rawValue
        textureStrength = brush.textureStrength
        flow = brush.flow
        flowPressureSensitivity = brush.flowPressureSensitivity
        flowJitter = brush.flowJitter
        velocityInfluence = brush.velocityInfluence
        colorMixingMode = brush.colorMixingMode.rawValue
        wetness = brush.wetness
        wetnessPressureSensitivity = brush.wetnessPressureSensitivity
        opacityPressureSensitivity = brush.opacityPressureSensitivity
        colorMixStrength = brush.colorMixStrength
        smudgeBlurEnabled = brush.smudgeBlurEnabled
        smudgeBleed = brush.smudgeBleed
        smudgeRadius = brush.smudgeRadius
        paintLoad = brush.paintLoad
        smudgeEngineEnabled = brush.smudgeEngineEnabled
        smudgeMode = brush.smudgeMode.rawValue
        smudgeLength = brush.smudgeLength
        colorRate = brush.colorRate
        loadPressureSensitivity = brush.loadPressureSensitivity
        paintAmountPressureBypass = brush.paintAmountPressureBypass
        paintDensityPressureBypass = brush.paintDensityPressureBypass
        colorStretchPressureBypass = brush.colorStretchPressureBypass
        dualBrushEnabled = brush.dualBrushEnabled
        dualTipKind = brush.dualTipKind.rawValue
        dualScale = brush.dualScale
        dualSpacing = brush.dualSpacing
        dualScatter = brush.dualScatter
        dualAngle = brush.dualAngle
        dualBlendMode = brush.dualBlendMode.rawValue
        grainScale = brush.grainScale
        grainContrast = brush.grainContrast
        paperScale = brush.paperScale
        paperStrength = brush.paperStrength
        paperThreshold = brush.paperThreshold
        flipX = brush.flipX
        flipY = brush.flipY
        customTip = brush.customTip.map(StoredBrushTipRaster.init)
        pressureSensitivity = brush.pressureSensitivity
        stabilization = brush.stabilization
        fillThresholdMode = brush.fillThresholdMode.rawValue
        fillOpacityTolerance = brush.fillOpacityTolerance
        fillColorTolerance = brush.fillColorTolerance
        fillExpansion = brush.fillExpansion
        red = brush.red
        green = brush.green
        blue = brush.blue
        isEraser = brush.isEraser
    }

    public var runtimeSettings: BrushRuntimeSettings? {
        guard let tipKind = BrushTipKind(rawValue: tipKind),
              let angleMode = BrushAngleMode(rawValue: angleMode),
              let scatterMode = BrushScatterMode(rawValue: scatterMode),
              let textureMode = BrushTextureMode(rawValue: textureMode),
              let dualTipKind = BrushTipKind(rawValue: dualTipKind),
              let dualBlendMode = BrushDualBlendMode(rawValue: dualBlendMode),
              let fillThresholdMode = FillThresholdMode(rawValue: fillThresholdMode)
        else {
            return nil
        }
        let resolvedSmudgeMode = BrushSmudgeMode(rawValue: smudgeMode) ?? .smearing
        let resolvedColorMixingMode = BrushColorMixingMode(rawValue: colorMixingMode ?? "") ?? BrushColorMixingMode.inferred(
            wetness: wetness,
            colorMixStrength: colorMixStrength,
            smudgeBlurEnabled: smudgeBlurEnabled,
            smudgeBleed: smudgeBleed,
            smudgeRadius: smudgeRadius,
            paintLoad: paintLoad
        )

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
            colorMixingMode: resolvedColorMixingMode,
            wetness: wetness,
            wetnessPressureSensitivity: wetnessPressureSensitivity,
            opacityPressureSensitivity: opacityPressureSensitivity,
            colorMixStrength: colorMixStrength,
            smudgeBlurEnabled: smudgeBlurEnabled,
            smudgeBleed: smudgeBleed,
            smudgeRadius: smudgeRadius,
            paintLoad: paintLoad,
            smudgeEngineEnabled: smudgeEngineEnabled,
            smudgeMode: resolvedSmudgeMode,
            smudgeLength: smudgeLength,
            colorRate: colorRate,
            loadPressureSensitivity: loadPressureSensitivity,
            paintAmountPressureBypass: paintAmountPressureBypass ?? 1.0,
            paintDensityPressureBypass: paintDensityPressureBypass ?? 1.0,
            colorStretchPressureBypass: colorStretchPressureBypass ?? 1.0,
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
            customTip: customTip?.raster,
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
