import PrimoBrushDomain
import PrimoBrushInfrastructure
import PrimoDocumentContracts
import Testing

struct BrushRuntimeSettingsAssemblyServiceTests {
    @Test
    func makeRuntimeSettingsRoundsCountsAndConvertsColorChannels() {
        let service = BrushRuntimeSettingsAssemblyService()
        let settings = service.makeRuntimeSettings(
            brush: BrushRuntimeDescriptor(
                tipKind: .airbrush,
                radius: 12.0,
                sizeSpeedSensitivity: 0.2,
                taperIn: 0.1,
                taperOut: 0.3,
                opacity: 0.8,
                hardness: 0.4,
                roundness: 0.9,
                roundnessPressureSensitivity: 0.2,
                roundnessTiltSensitivity: 0.3,
                angle: 0.4,
                anglePressureSensitivity: 0.5,
                angleTiltSensitivity: 0.6,
                angleMode: .fixed,
                spacing: 0.2,
                spacingJitter: 0.1,
                scatterEnabled: true,
                scatterMode: .spray,
                scatterLateral: 0.7,
                scatterLinear: 0.8,
                count: 2.6,
                countJitter: 0.9,
                countSizeJitter: 0.15,
                countOpacityJitter: 0.18,
                angleJitter: 0.11,
                roundnessJitter: 0.12,
                textureMode: .moving,
                textureStrength: 0.55,
                flow: 0.66,
                flowPressureSensitivity: 0.44,
                flowJitter: 0.22,
                velocityInfluence: 0.33,
                wetness: 0.25,
                wetnessPressureSensitivity: 0.14,
                opacityPressureSensitivity: 0.77,
                colorMixStrength: 0.41,
                smudgeRadius: 0.52,
                paintLoad: 0.91,
                smudgeEngineEnabled: true,
                smudgeMode: .dulling,
                smudgeLength: 0.67,
                colorRate: 0.23,
                loadPressureSensitivity: 0.27,
                dualEnabled: true,
                dualTipKind: .oil,
                dualScale: 0.63,
                dualSpacing: 0.28,
                dualScatter: 0.31,
                dualAngle: 0.12,
                dualBlendMode: .darker,
                grainScale: 1.4,
                grainContrast: 1.7,
                paperScale: 0.14,
                paperStrength: 0.35,
                paperThreshold: 0.48,
                flipX: true,
                flipY: false,
                customTip: nil,
                pressureSensitivity: 0.73,
                stabilization: 0.19
            ),
            fill: BrushFillRuntimeDescriptor(
                thresholdMode: .color,
                opacityTolerance: 0.08,
                colorTolerance: 0.12,
                expansion: 2.8
            ),
            color: BrushColorComponents(red: 0.5, green: 0.25, blue: 1.0)
        )

        #expect(settings.count == 3)
        #expect(settings.fillExpansion == 3)
        #expect(settings.red == 127)
        #expect(settings.green == 63)
        #expect(settings.blue == 255)
        #expect(settings.scatterMode == BrushScatterMode.spray)
        #expect(settings.dualBrushEnabled)
        #expect(settings.smudgeEngineEnabled)
        #expect(settings.smudgeMode == .dulling)
        #expect(settings.smudgeLength == 0.67)
        #expect(settings.colorRate == 0.23)
        #expect(settings.smudgeRadius == 0.52)
    }

    @Test
    func makeRuntimeSettingsClampsOutOfRangeColorsAndPreservesEraserFlag() {
        let service = BrushRuntimeSettingsAssemblyService()
        let settings = service.makeRuntimeSettings(
            brush: BrushRuntimeDescriptor(
                tipKind: .ink,
                radius: 4.0,
                sizeSpeedSensitivity: 0.0,
                taperIn: 0.0,
                taperOut: 0.0,
                opacity: 1.0,
                hardness: 1.0,
                roundness: 1.0,
                roundnessPressureSensitivity: 0.0,
                roundnessTiltSensitivity: 0.0,
                angle: 0.0,
                anglePressureSensitivity: 0.0,
                angleTiltSensitivity: 0.0,
                angleMode: .strokeDirection,
                spacing: 0.1,
                spacingJitter: 0.0,
                scatterEnabled: false,
                scatterMode: .directional,
                scatterLateral: 0.0,
                scatterLinear: 0.0,
                count: 1.0,
                countJitter: 0.0,
                countSizeJitter: 0.0,
                countOpacityJitter: 0.0,
                angleJitter: 0.0,
                roundnessJitter: 0.0,
                textureMode: .off,
                textureStrength: 0.0,
                flow: 1.0,
                flowPressureSensitivity: 0.0,
                flowJitter: 0.0,
                velocityInfluence: 0.0,
                wetness: 0.0,
                wetnessPressureSensitivity: 0.0,
                opacityPressureSensitivity: 0.0,
                colorMixStrength: 0.0,
                smudgeRadius: 0.0,
                paintLoad: 1.0,
                loadPressureSensitivity: 0.0,
                dualEnabled: false,
                dualTipKind: .ink,
                dualScale: 0.72,
                dualSpacing: 0.26,
                dualScatter: 0.18,
                dualAngle: 0.0,
                dualBlendMode: .multiply,
                grainScale: 1.35,
                grainContrast: 1.7,
                paperScale: 0.12,
                paperStrength: 0.32,
                paperThreshold: 0.42,
                flipX: false,
                flipY: false,
                customTip: nil,
                pressureSensitivity: 0.0,
                stabilization: 0.0,
                isEraser: true
            ),
            fill: BrushFillRuntimeDescriptor(
                thresholdMode: .opacity,
                opacityTolerance: 0.0,
                colorTolerance: 0.12,
                expansion: 0.0
            ),
            color: BrushColorComponents(red: -1.0, green: 2.0, blue: 0.0)
        )

        #expect(settings.red == 0)
        #expect(settings.green == 255)
        #expect(settings.blue == 0)
        #expect(settings.isEraser)
    }
}
