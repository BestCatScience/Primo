import PrimoBrushDomain
import PrimoBrushRuntimeContracts
import Testing

struct BrushPresetValidationTests {
    @Test
    func brushPresetValueObjectsRejectInvalidRawValues() {
        #expect(BrushPresetName("  ") == nil)
        #expect(BrushPositiveFiniteDouble(0) == nil)
        #expect(BrushPositiveFiniteDouble(.infinity) == nil)
        #expect(BrushUnitInterval(-0.1) == nil)
        #expect(BrushUnitInterval(1.1) == nil)
        #expect(BrushUnitInterval(.nan) == nil)
        #expect(BrushPositiveCount(0) == nil)
    }

    @Test
    func brushPresetInitializerRejectsInvalidScalars() {
        #expect(makePreset(name: "") == nil)
        #expect(makePreset(radius: 0) == nil)
        #expect(makePreset(opacity: 1.1) == nil)
        #expect(makePreset(hardness: .nan) == nil)
        #expect(makePreset(count: 0) == nil)
    }

    @Test
    func builtInPresetsAreValidAndKeepDefaultPencilFirst() throws {
        let first = try #require(BrushPreset.defaults.first)

        #expect(!BrushPreset.defaults.isEmpty)
        #expect(first == BrushPreset.defaultPencil)
        #expect(first.name == "Sketch Pencil")
        #expect(BrushPreset.defaults.allSatisfy { BrushPresetName($0.name) != nil })
    }

    @Test
    func presetValuesCanFeedRuntimeDescriptorWithoutChangingRawValues() throws {
        let preset = try #require(makePreset())

        let descriptor = BrushRuntimeDescriptor(
            tipKind: preset.tipKind,
            radius: preset.radius,
            sizeSpeedSensitivity: preset.sizeSpeedSensitivity,
            taperIn: preset.taperIn,
            taperOut: preset.taperOut,
            opacity: preset.opacity,
            hardness: preset.hardness,
            roundness: preset.roundness,
            roundnessPressureSensitivity: preset.roundnessPressureSensitivity,
            roundnessTiltSensitivity: preset.roundnessTiltSensitivity,
            angle: preset.angle,
            anglePressureSensitivity: preset.anglePressureSensitivity,
            angleTiltSensitivity: preset.angleTiltSensitivity,
            angleMode: preset.angleMode,
            spacing: preset.spacing,
            spacingJitter: preset.spacingJitter,
            scatterEnabled: preset.scatterEnabled,
            scatterMode: preset.scatterMode,
            scatterLateral: preset.scatterLateral,
            scatterLinear: preset.scatterLinear,
            count: Double(preset.count),
            countJitter: preset.countJitter,
            countSizeJitter: preset.countSizeJitter,
            countOpacityJitter: preset.countOpacityJitter,
            angleJitter: preset.angleJitter,
            roundnessJitter: preset.roundnessJitter,
            textureMode: preset.textureMode,
            textureStrength: preset.textureStrength,
            flow: preset.flow,
            flowPressureSensitivity: preset.flowPressureSensitivity,
            flowJitter: preset.flowJitter,
            velocityInfluence: preset.velocityInfluence,
            wetness: preset.wetness,
            wetnessPressureSensitivity: preset.wetnessPressureSensitivity,
            opacityPressureSensitivity: preset.opacityPressureSensitivity,
            colorMixStrength: preset.colorMixStrength,
            smudgeRadius: preset.smudgeRadius,
            paintLoad: preset.paintLoad,
            smudgeEngineEnabled: preset.smudgeEngineEnabled,
            smudgeMode: preset.smudgeMode,
            smudgeLength: preset.smudgeLength,
            colorRate: preset.colorRate,
            loadPressureSensitivity: preset.loadPressureSensitivity,
            paintAmountPressureBypass: preset.paintAmountPressureBypass,
            paintDensityPressureBypass: preset.paintDensityPressureBypass,
            colorStretchPressureBypass: preset.colorStretchPressureBypass,
            dualEnabled: preset.dualBrushEnabled,
            dualTipKind: preset.dualTipKind,
            dualScale: preset.dualScale,
            dualSpacing: preset.dualSpacing,
            dualScatter: preset.dualScatter,
            dualAngle: preset.dualAngle,
            dualBlendMode: preset.dualBlendMode,
            grainScale: preset.grainScale,
            grainContrast: preset.grainContrast,
            paperScale: preset.paperScale,
            paperStrength: preset.paperStrength,
            paperThreshold: preset.paperThreshold,
            flipX: preset.flipX,
            flipY: preset.flipY,
            customTip: preset.customTip,
            pressureSensitivity: preset.pressureSensitivity,
            stabilization: 0.5
        )

        #expect(descriptor.radius == preset.radius)
        #expect(descriptor.opacity == preset.opacity)
        #expect(descriptor.hardness == preset.hardness)
        #expect(descriptor.spacing == preset.spacing)
        #expect(descriptor.wetness == preset.wetness)
    }

    private func makePreset(
        name: String = "Test Brush",
        radius: Double = 4,
        opacity: Double = 0.8,
        hardness: Double = 0.6,
        count: Int = 1
    ) -> BrushPreset? {
        BrushPreset(
            name: name,
            tipKind: .ink,
            radius: radius,
            opacity: opacity,
            hardness: hardness,
            roundness: 1,
            angle: 0,
            angleMode: .fixed,
            spacing: 0.1,
            spacingJitter: 0,
            scatterLateral: 0,
            scatterLinear: 0,
            count: count,
            countJitter: 0,
            angleJitter: 0,
            roundnessJitter: 0,
            textureMode: .off,
            textureStrength: 0,
            flow: 1,
            flipX: false,
            flipY: false,
            pressureSensitivity: 0,
            red: 0,
            green: 0,
            blue: 0
        )
    }
}
