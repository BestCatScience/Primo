import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts

extension BrushRuntimeSettings {
    func withCustomTip(
        from sourceURL: URL,
        brushTipLibraryClient: BrushTipLibraryClient = .live(fileClient: .live)
    ) throws -> BrushRuntimeSettings {
        var copy = self
        copy.customTip = try brushTipLibraryClient.loadRaster(sourceURL)
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
