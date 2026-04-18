import Testing

@testable import PrimoBrushDomain

struct BrushTypesTests {
    @Test
    func inferredColorMixingModePrefersRunningColorForSmudgeBrushes() {
        #expect(
            BrushColorMixingMode.inferred(
                wetness: 0,
                colorMixStrength: 0,
                smudgeBlurEnabled: true,
                smudgeBleed: 0,
                smudgeRadius: 0,
                paintLoad: 1
            ) == .runningColor
        )
    }

    @Test
    func inferredColorMixingModeDistinguishesBlendAndSmear() {
        #expect(
            BrushColorMixingMode.inferred(
                wetness: 0.3,
                colorMixStrength: 0,
                smudgeBlurEnabled: false,
                smudgeBleed: 0,
                smudgeRadius: 0,
                paintLoad: 0.1
            ) == .smear
        )
        #expect(
            BrushColorMixingMode.inferred(
                wetness: 0.3,
                colorMixStrength: 0,
                smudgeBlurEnabled: false,
                smudgeBleed: 0,
                smudgeRadius: 0,
                paintLoad: 0.8
            ) == .blend
        )
    }
}
