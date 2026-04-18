import CoreGraphics
import Foundation

enum BrushStrokeKernel {
    static func taperScale(
        progress: CGFloat,
        taperIn: CGFloat,
        taperOut: CGFloat
    ) -> CGFloat {
        func easedRamp(_ progress: CGFloat, length: CGFloat) -> CGFloat {
            guard length > 0.001 else { return 1.0 }
            let t = max(0.0, min(1.0, progress / length))
            let eased = t * t * (3.0 - (2.0 * t))
            return 0.08 + (0.92 * eased)
        }

        let entry = easedRamp(progress, length: taperIn)
        let exit = easedRamp(1.0 - progress, length: taperOut)
        return min(entry, exit)
    }

    static func taperScale(
        progress: Double,
        taperIn: Double,
        taperOut: Double
    ) -> Double {
        Double(
            taperScale(
                progress: CGFloat(progress),
                taperIn: CGFloat(taperIn),
                taperOut: CGFloat(taperOut)
            )
        )
    }

    static func resolvedRadius(
        for sample: StylusSample,
        progress: CGFloat,
        brush: BrushRuntimeSettings
    ) -> CGFloat {
        let clampedPressure = max(0.08, min(sample.pressure, 1.0))
        let pressureFactor = max(
            0.1,
            1.0 + ((clampedPressure - 1.0) * CGFloat(brush.pressureSensitivity))
        )
        let taperScale = taperScale(
            progress: progress,
            taperIn: CGFloat(brush.taperIn),
            taperOut: CGFloat(brush.taperOut)
        )
        return max(CGFloat(brush.radius) * pressureFactor * taperScale, 1.5)
    }

    static func previewStampAlpha(
        pressure: Double,
        opacityJitter: Double,
        style: BrushPreviewStyle
    ) -> Double {
        let base = min(max(style.opacity, 0.04), 1.0)
        let flow = min(max(style.flow, 0.0), 1.0)
        let hardnessBias = 0.55 + (style.hardness * 0.45)
        let opacityPressure = max(
            0.2,
            1.0 - style.opacityPressureSensitivity + (style.opacityPressureSensitivity * pressure)
        )
        let flowPressure = max(
            0.2,
            1.0 - style.flowPressureSensitivity + (style.flowPressureSensitivity * pressure)
        )
        let customTipBoost = style.customTip == nil ? 1.0 : 0.92
        return min(
            max(
                base * flow * hardnessBias * 0.55 * opacityPressure * flowPressure * opacityJitter * customTipBoost,
                0.0
            ),
            1.0
        )
    }

    static func rasterizedSourceAlpha(
        sample: StylusSample,
        brush: BrushRuntimeSettings,
        progress: CGFloat,
        radius: CGFloat,
        sampleX: CGFloat,
        sampleY: CGFloat
    ) -> CGFloat {
        let pressureOpacity = max(
            0.05,
            1.0 + ((sample.pressure - 1.0) * CGFloat(brush.opacityPressureSensitivity))
        )
        let flowOpacity = max(
            0.05,
            1.0 + ((sample.pressure - 1.0) * CGFloat(brush.flowPressureSensitivity))
        )
        let clampedOpacity = clampUnit(CGFloat(brush.opacity))
        let clampedFlow = clampUnit(CGFloat(brush.flow))
        let pigmentAlpha = clampUnit(
            clampedOpacity *
            clampedFlow *
            pressureOpacity *
            flowOpacity
        )
        let mixingCoverageAlpha = clampUnit(clampedOpacity * pressureOpacity)
        let baseAlpha =
            brush.colorMixingMode != .off &&
            clampedFlow <= 0.001 &&
            !brush.isEraser
            ? mixingCoverageAlpha
            : pigmentAlpha
        guard baseAlpha > 0.001 else { return 0 }

        let dx = sampleX - sample.point.x
        let dy = sampleY - sample.point.y
        let normalizedDistance = sqrt((dx * dx) + (dy * dy)) / max(radius, 0.001)
        guard normalizedDistance <= 1 else { return 0 }

        let hardness = max(0, min(1, CGFloat(brush.hardness)))
        let isPencil = brush.tipKind == .pencil
        let hardCore = isPencil
            ? min(0.78, pow(hardness, 4.8) * 0.72)
            : (hardness >= 0.995 ? 1.0 : pow(hardness, 3.2))

        let falloff: CGFloat
        if hardCore >= 0.999 || normalizedDistance <= hardCore {
            falloff = 1
        } else {
            let span = max(0.001, 1.0 - hardCore)
            let softened = max(0, min(1, (normalizedDistance - hardCore) / span))
            falloff = isPencil ? pow(1.0 - softened, 1.6) : (1.0 - softened)
        }

        let textureAlpha: CGFloat
        if isPencil {
            let grainNoise = noise(
                x: sampleX * max(CGFloat(brush.grainScale), 0.6),
                y: sampleY * max(CGFloat(brush.grainScale), 0.6)
            )
            let paperNoise = noise(
                x: sampleX * max(CGFloat(brush.paperScale) * 24.0, 1.0),
                y: sampleY * max(CGFloat(brush.paperScale) * 24.0, 1.0)
            )
            let grainContrast = max(0.35, CGFloat(brush.grainContrast))
            let contrastedGrain = max(0.0, min(1.0, ((grainNoise - 0.5) * grainContrast) + 0.5))
            let grainStrength = min(max(CGFloat(brush.textureStrength), 0), 1) * 0.55
            let paperStrength = min(max(CGFloat(brush.paperStrength), 0), 1) * 0.45
            let grainMask = max(0.14, 1.0 - grainStrength + (contrastedGrain * grainStrength))
            let paperThreshold = min(max(CGFloat(brush.paperThreshold), 0), 1)
            let paperMask = max(
                0.18,
                1.0 - paperStrength + (max(0.0, min(1.0, (paperNoise - paperThreshold + 1.0) * 0.75)) * paperStrength)
            )
            textureAlpha = grainMask * paperMask
        } else {
            textureAlpha = 1.0
        }

        return baseAlpha * falloff * textureAlpha
    }

    static func noise(x: CGFloat, y: CGFloat) -> CGFloat {
        let value = sin((x * 12.9898) + (y * 78.233)) * 43758.5453
        return value - floor(value)
    }

    private static func clampUnit(_ value: CGFloat) -> CGFloat {
        max(0, min(1, value))
    }
}
