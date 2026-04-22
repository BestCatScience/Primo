import CoreGraphics
import Foundation
import PrimoDocumentContracts

extension AppFeature {
    private struct RasterizedSmudgeSample {
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat
        var alpha: CGFloat
    }

    private static func rasterizedPixelSample(
        from pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        x: Int,
        y: Int
    ) -> RasterizedSmudgeSample {
        guard canvasWidth > 0, canvasHeight > 0 else {
            return RasterizedSmudgeSample(red: 0, green: 0, blue: 0, alpha: 0)
        }
        let clampedX = min(max(x, 0), canvasWidth - 1)
        let clampedY = min(max(y, 0), canvasHeight - 1)
        let offset = ((clampedY * canvasWidth) + clampedX) * 4
        let alpha = CGFloat(pixels[offset + 3]) / 255.0
        return RasterizedSmudgeSample(
            red: (CGFloat(pixels[offset]) / 255.0) * alpha,
            green: (CGFloat(pixels[offset + 1]) / 255.0) * alpha,
            blue: (CGFloat(pixels[offset + 2]) / 255.0) * alpha,
            alpha: alpha
        )
    }

    private static func sampleRasterizedNeighborhood(
        from pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        tangentX: CGFloat,
        tangentY: CGFloat,
        normalX: CGFloat,
        normalY: CGFloat,
        extent: CGFloat,
        taps: [(dx: CGFloat, dy: CGFloat, weight: CGFloat)]
    ) -> RasterizedSmudgeSample {
        var accumulatedRed: CGFloat = 0
        var accumulatedGreen: CGFloat = 0
        var accumulatedBlue: CGFloat = 0
        var accumulatedAlpha: CGFloat = 0
        var accumulatedWeight: CGFloat = 0

        for tap in taps {
            let offsetX = ((tangentX * tap.dx) + (normalX * tap.dy)) * extent
            let offsetY = ((tangentY * tap.dx) + (normalY * tap.dy)) * extent
            let sample = rasterizedPixelSample(
                from: pixels,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                x: Int((CGFloat(centerX) + offsetX).rounded()),
                y: Int((CGFloat(centerY) + offsetY).rounded())
            )
            accumulatedRed += sample.red * tap.weight
            accumulatedGreen += sample.green * tap.weight
            accumulatedBlue += sample.blue * tap.weight
            accumulatedAlpha += sample.alpha * tap.weight
            accumulatedWeight += tap.weight
        }

        guard accumulatedWeight > 0.001 else {
            return RasterizedSmudgeSample(red: 0, green: 0, blue: 0, alpha: 0)
        }

        let inverseWeight = 1.0 / accumulatedWeight
        return RasterizedSmudgeSample(
            red: accumulatedRed * inverseWeight,
            green: accumulatedGreen * inverseWeight,
            blue: accumulatedBlue * inverseWeight,
            alpha: accumulatedAlpha * inverseWeight
        )
    }

    private static func sampleRasterizedSmearingColor(
        from pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        x: Int,
        y: Int,
        tangentX: CGFloat,
        tangentY: CGFloat,
        normalX: CGFloat,
        normalY: CGFloat,
        radius: CGFloat,
        brush: BrushRuntimeSettings
    ) -> RasterizedSmudgeSample {
        let bleedRadius = clampUnit(CGFloat(brush.smudgeRadius))
        let wetness = clampUnit(CGFloat(brush.wetness))
        let oilBias: CGFloat = brush.tipKind == .oil ? 0.30 : 0.0
        let extent = max(1.0, radius * (0.36 + max(bleedRadius, oilBias) * 1.88 + wetness * 0.28))
        let taps: [(dx: CGFloat, dy: CGFloat, weight: CGFloat)] = [
            (-0.18, 0.00, 0.08),
            (-0.52, 0.00, 0.20),
            (-0.92, 0.00, 0.22),
            (-1.34, 0.00, 0.18),
            (-1.74, 0.00, 0.10),
            (-0.64, 0.42, 0.07),
            (-0.64, -0.42, 0.07),
            (-1.08, 0.76, 0.04),
            (-1.08, -0.76, 0.04)
        ]
        return sampleRasterizedNeighborhood(
            from: pixels,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            centerX: x,
            centerY: y,
            tangentX: tangentX,
            tangentY: tangentY,
            normalX: normalX,
            normalY: normalY,
            extent: extent,
            taps: taps
        )
    }

    private static func sampleRasterizedDullingColor(
        from pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        x: Int,
        y: Int,
        tangentX: CGFloat,
        tangentY: CGFloat,
        normalX: CGFloat,
        normalY: CGFloat,
        radius: CGFloat,
        brush: BrushRuntimeSettings
    ) -> RasterizedSmudgeSample {
        let bleedRadius = clampUnit(CGFloat(brush.smudgeRadius))
        let wetness = clampUnit(CGFloat(brush.wetness))
        let mixStrength = clampUnit(CGFloat(brush.colorMixStrength))
        let oilBias: CGFloat = brush.tipKind == .oil ? 0.18 : 0.0
        let extent = max(1.0, radius * (0.28 + max(bleedRadius, oilBias) * 1.58 + mixStrength * 0.34 + wetness * 0.12))
        let taps: [(dx: CGFloat, dy: CGFloat, weight: CGFloat)] = [
            (0.00, 0.00, 0.20),
            (-0.46, 0.00, 0.12),
            (0.46, 0.00, 0.12),
            (0.00, 0.46, 0.12),
            (0.00, -0.46, 0.12),
            (-0.34, 0.34, 0.08),
            (-0.34, -0.34, 0.08),
            (0.34, 0.34, 0.08),
            (0.34, -0.34, 0.08)
        ]
        return sampleRasterizedNeighborhood(
            from: pixels,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            centerX: x,
            centerY: y,
            tangentX: tangentX,
            tangentY: tangentY,
            normalX: normalX,
            normalY: normalY,
            extent: extent,
            taps: taps
        )
    }

    private static func sampleRasterizedBlurColor(
        from pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        x: Int,
        y: Int,
        tangentX: CGFloat,
        tangentY: CGFloat,
        normalX: CGFloat,
        normalY: CGFloat,
        radius: CGFloat,
        brush: BrushRuntimeSettings
    ) -> RasterizedSmudgeSample {
        let blurAmount = clampUnit(CGFloat(brush.smudgeBleed))
        let blurRadius = clampUnit(CGFloat(brush.smudgeRadius))
        let mixStrength = clampUnit(CGFloat(brush.colorMixStrength))
        let oilBias: CGFloat = brush.tipKind == .oil ? 0.24 : 0.0
        let extent = max(1.0, radius * (0.34 + max(blurRadius, oilBias) * 1.92 + blurAmount * 0.40 + mixStrength * 0.18))
        let taps: [(dx: CGFloat, dy: CGFloat, weight: CGFloat)] = [
            (0.00, 0.00, 0.16),
            (-0.72, 0.00, 0.09),
            (0.72, 0.00, 0.09),
            (0.00, 0.72, 0.09),
            (0.00, -0.72, 0.09),
            (-0.52, 0.52, 0.07),
            (-0.52, -0.52, 0.07),
            (0.52, 0.52, 0.07),
            (0.52, -0.52, 0.07),
            (-1.08, 0.00, 0.05),
            (1.08, 0.00, 0.05),
            (0.00, 1.08, 0.05),
            (0.00, -1.08, 0.05)
        ]
        return sampleRasterizedNeighborhood(
            from: pixels,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            centerX: x,
            centerY: y,
            tangentX: tangentX,
            tangentY: tangentY,
            normalX: normalX,
            normalY: normalY,
            extent: extent,
            taps: taps
        )
    }

    static func blendRasterizedPixel(
        into pixels: UnsafeMutableBufferPointer<UInt8>,
        offset: Int,
        canvasWidth: Int,
        canvasHeight: Int,
        x: Int,
        y: Int,
        radius: CGFloat,
        sourceAlpha: CGFloat,
        pressure: CGFloat,
        tangentX: CGFloat,
        tangentY: CGFloat,
        normalX: CGFloat,
        normalY: CGFloat,
        brush: BrushRuntimeSettings
    ) {
        let destinationAlpha = CGFloat(pixels[offset + 3]) / 255.0

        if brush.isEraser {
            let outAlpha = destinationAlpha * (1.0 - sourceAlpha)
            pixels[offset + 3] = UInt8(max(0, min(255, Int((outAlpha * 255.0).rounded()))))
            return
        }

        let sourceRed = CGFloat(brush.red) / 255.0
        let sourceGreen = CGFloat(brush.green) / 255.0
        let sourceBlue = CGFloat(brush.blue) / 255.0
        let destinationRed = CGFloat(pixels[offset]) / 255.0
        let destinationGreen = CGFloat(pixels[offset + 1]) / 255.0
        let destinationBlue = CGFloat(pixels[offset + 2]) / 255.0
        let destinationPremulRed = destinationRed * destinationAlpha
        let destinationPremulGreen = destinationGreen * destinationAlpha
        let destinationPremulBlue = destinationBlue * destinationAlpha
        let mode = brush.colorMixingMode
        let configuredColorStretch = min(max(CGFloat(brush.wetness), 0), 1)
        let configuredUndercoatMix = min(max(CGFloat(brush.colorMixStrength), 0), 1)
        let configuredBlurAmount = min(max(CGFloat(brush.smudgeBleed), 0), 1)
        let configuredBlurRadius = min(max(CGFloat(brush.smudgeRadius), 0), 1)
        let pigmentDensity = clampUnit(CGFloat(brush.flow))
        var colorStretch: CGFloat
        var undercoatMix: CGFloat
        var blurAmount: CGFloat
        var blurRadius: CGFloat
        var blurEnabled: Bool
        switch mode {
        case .off:
            colorStretch = 0
            undercoatMix = 0
            blurAmount = 0
            blurRadius = 0
            blurEnabled = false
        case .blend:
            colorStretch = configuredColorStretch
            undercoatMix = max(configuredUndercoatMix, 0.72)
            blurAmount = 0
            blurRadius = 0
            blurEnabled = false
        case .runningColor:
            colorStretch = configuredColorStretch
            undercoatMix = max(configuredUndercoatMix, 0.84)
            blurAmount = max(configuredBlurAmount, 0.18)
            blurRadius = max(configuredBlurRadius, 0.18)
            blurEnabled = brush.smudgeBlurEnabled
        case .smear:
            colorStretch = configuredColorStretch
            undercoatMix = 0
            blurAmount = 0
            blurRadius = 0
            blurEnabled = false
        }
        if mode != .off &&
            pigmentDensity <= 0.001 &&
            colorStretch <= 0.001 &&
            undercoatMix <= 0.001 &&
            blurAmount <= 0.001 &&
            blurRadius <= 0.001 {
            undercoatMix = 0.58
            blurAmount = 0.44
            blurRadius = 0.36
            blurEnabled = true
        }
        let clampedPressure = clampUnit(max(0.08, min(pressure, 1.0)))
        let lowPressureMix = clampUnit((1.0 - clampedPressure) / 0.92)
        let activeBlurAmount = blurEnabled ? blurAmount : 0
        let activeBlurRadius = blurEnabled ? blurRadius : 0
        let effectiveColorStretch = clampUnit(colorStretch * (0.74 + (lowPressureMix * 0.82)))
        let effectiveUndercoatMix = clampUnit(undercoatMix * (0.78 + (lowPressureMix * 0.72)))
        let effectiveBlurAmount = clampUnit(activeBlurAmount * (0.72 + (lowPressureMix * 0.88)))
        let effectiveBlurRadius = clampUnit(activeBlurRadius * (0.84 + (lowPressureMix * 0.44)))
        let spacingFactor = min(max((CGFloat(brush.stampSpacing) - 0.02) / 0.38, 0), 1)
        let smudgeOpacityGate = clampUnit((sourceAlpha - 0.04) / 0.86)
        let mixActivation = clampUnit(smudgeOpacityGate + (lowPressureMix * 0.42))
        let edgeColorGuard = clampUnit((sourceAlpha - 0.10) / 0.36)
        let contourFade = clampUnit((sourceAlpha - 0.20) / 0.44)
        let corePresence = clampUnit((sourceAlpha - 0.46) / 0.34)
        let edgeMixGuard = clampUnit(edgeColorGuard + (lowPressureMix * 0.20)) * (0.18 + (contourFade * 0.82))
        let edgeAlphaGuard = clampUnit((max(destinationAlpha, sourceAlpha) - 0.02) / 0.16)
        let colorRate = clampUnit(CGFloat(brush.paintLoad))
        let effectiveColorRate = clampUnit(colorRate * (0.24 + (clampedPressure * 0.76)))
        let effectivePigmentDensity = clampUnit(pigmentDensity * (0.16 + (clampedPressure * 0.84)))
        let smudgeEnabled =
            mode != .off &&
            (
                effectiveColorStretch > 0.001 ||
                effectiveUndercoatMix > 0.001 ||
                effectiveBlurAmount > 0.001 ||
                effectiveBlurRadius > 0.001 ||
                effectiveColorRate < 0.999 ||
                pigmentDensity <= 0.001
            )

        var resolvedSourceRed = sourceRed
        var resolvedSourceGreen = sourceGreen
        var resolvedSourceBlue = sourceBlue
        var resolvedSourceAlpha = sourceAlpha
        if smudgeEnabled {
            let smearSample = sampleRasterizedSmearingColor(
                from: pixels,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                x: x,
                y: y,
                tangentX: tangentX,
                tangentY: tangentY,
                normalX: normalX,
                normalY: normalY,
                radius: radius,
                brush: brush
            )
            let dullSample = undercoatMix > 0.001
                ? sampleRasterizedDullingColor(
                    from: pixels,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    x: x,
                    y: y,
                    tangentX: tangentX,
                    tangentY: tangentY,
                    normalX: normalX,
                    normalY: normalY,
                    radius: radius,
                    brush: brush
                )
                : RasterizedSmudgeSample(red: destinationPremulRed, green: destinationPremulGreen, blue: destinationPremulBlue, alpha: destinationAlpha)
            let blurSample = blurEnabled
                ? sampleRasterizedBlurColor(
                    from: pixels,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    x: x,
                    y: y,
                    tangentX: tangentX,
                    tangentY: tangentY,
                    normalX: normalX,
                    normalY: normalY,
                    radius: radius,
                    brush: brush
                )
                : RasterizedSmudgeSample(red: destinationPremulRed, green: destinationPremulGreen, blue: destinationPremulBlue, alpha: destinationAlpha)
            let transparentSurface =
                destinationAlpha <= 0.02 &&
                smearSample.alpha <= 0.02 &&
                dullSample.alpha <= 0.02 &&
                blurSample.alpha <= 0.02
            if !transparentSurface {
                let smearStrength = clampUnit(
                    mixActivation *
                    (0.14 + (effectiveColorStretch * 0.98) + ((1.0 - spacingFactor) * 0.10))
                )
                let dullStrength = clampUnit(
                    mixActivation *
                    (0.04 + (effectiveUndercoatMix * 0.94) + (effectiveBlurAmount * 0.10))
                )
                var mixedPremulRed = interpolate(destinationPremulRed, smearSample.red, amount: smearStrength)
                var mixedPremulGreen = interpolate(destinationPremulGreen, smearSample.green, amount: smearStrength)
                var mixedPremulBlue = interpolate(destinationPremulBlue, smearSample.blue, amount: smearStrength)
                var mixedAlpha = interpolate(destinationAlpha, smearSample.alpha, amount: smearStrength)
                mixedPremulRed = interpolate(mixedPremulRed, dullSample.red, amount: dullStrength)
                mixedPremulGreen = interpolate(mixedPremulGreen, dullSample.green, amount: dullStrength)
                mixedPremulBlue = interpolate(mixedPremulBlue, dullSample.blue, amount: dullStrength)
                mixedAlpha = interpolate(mixedAlpha, dullSample.alpha, amount: dullStrength)

                if blurEnabled && (effectiveBlurAmount > 0.001 || effectiveBlurRadius > 0.001) {
                    let blurStrength = clampUnit(
                        mixActivation *
                        (
                            0.02 +
                            (effectiveUndercoatMix * 0.26) +
                            (effectiveBlurAmount * 0.86) +
                            (effectiveBlurRadius * 0.32)
                        )
                    )
                    let blurRed = (blurSample.red * 0.86) + (mixedPremulRed * 0.14)
                    let blurGreen = (blurSample.green * 0.86) + (mixedPremulGreen * 0.14)
                    let blurBlue = (blurSample.blue * 0.86) + (mixedPremulBlue * 0.14)
                    let blurAlpha = (blurSample.alpha * 0.82) + (mixedAlpha * 0.18)
                    mixedPremulRed = interpolate(mixedPremulRed, blurRed, amount: blurStrength)
                    mixedPremulGreen = interpolate(mixedPremulGreen, blurGreen, amount: blurStrength)
                    mixedPremulBlue = interpolate(mixedPremulBlue, blurBlue, amount: blurStrength)
                    mixedAlpha = interpolate(mixedAlpha, blurAlpha, amount: blurStrength)
                }

                let mixedColorAlpha = max(mixedAlpha, 0.0001)
                let mixedRed = mixedPremulRed / mixedColorAlpha
                let mixedGreen = mixedPremulGreen / mixedColorAlpha
                let mixedBlue = mixedPremulBlue / mixedColorAlpha
                let mixedLuminance = rasterizedLuminance(red: mixedRed, green: mixedGreen, blue: mixedBlue)
                let pigmentLuminance = rasterizedLuminance(red: sourceRed, green: sourceGreen, blue: sourceBlue)
                let luminanceSimilarity = clampUnit(
                    1.0 - Swift.abs(mixedLuminance - pigmentLuminance) * 0.38
                )
                let undercoatBlend = clampUnit(edgeMixGuard * (0.18 + (effectiveUndercoatMix * 0.82)) * luminanceSimilarity * (1.0 - (corePresence * 0.18)))
                let baseBlend = (mode == .smear ? edgeMixGuard : undercoatBlend) * (1.0 - (corePresence * 0.12))
                let centerPigmentRetention = clampUnit(effectivePigmentDensity * (1.0 + (corePresence * 0.30)))
                let brushBaseRed = interpolate(mixedRed, sourceRed, amount: centerPigmentRetention)
                let brushBaseGreen = interpolate(mixedGreen, sourceGreen, amount: centerPigmentRetention)
                let brushBaseBlue = interpolate(mixedBlue, sourceBlue, amount: centerPigmentRetention)
                let smudgedRed = interpolate(brushBaseRed, mixedRed, amount: baseBlend)
                let smudgedGreen = interpolate(brushBaseGreen, mixedGreen, amount: baseBlend)
                let smudgedBlue = interpolate(brushBaseBlue, mixedBlue, amount: baseBlend)
                let pigmentInfluence = clampUnit(
                    ((mode == .smear ? min(effectiveColorRate, 0.28) : effectiveColorRate) * 0.96) +
                    ((1.0 - edgeAlphaGuard) * 0.04)
                ) * centerPigmentRetention
                resolvedSourceRed = interpolate(smudgedRed, sourceRed, amount: pigmentInfluence)
                resolvedSourceGreen = interpolate(smudgedGreen, sourceGreen, amount: pigmentInfluence)
                resolvedSourceBlue = interpolate(smudgedBlue, sourceBlue, amount: pigmentInfluence)

                let smudgedCoverage = clampUnit((smearSample.alpha * 0.44) + (dullSample.alpha * 0.26) + (blurSample.alpha * 0.30))
                let coverageInfluence = clampUnit((1.0 - effectiveColorRate) * (0.24 + (effectiveColorStretch * 0.40) + (effectiveUndercoatMix * 0.22) + (lowPressureMix * 0.14)) * (0.92 + ((1.0 - contourFade) * 0.52)) * (1.0 - (corePresence * 0.42)))
                let coverageFloor = min(0.92, interpolate(0.02 + (effectiveColorRate * 0.06), 0.24 + (effectiveColorRate * 0.26) + (corePresence * (0.10 + (effectiveColorRate * 0.08))), amount: contourFade))
                let coverage = max(coverageFloor, interpolate(1.0, smudgedCoverage, amount: coverageInfluence))
                resolvedSourceAlpha = sourceAlpha * coverage * (0.60 + (contourFade * 0.40))
            }
        }
        let outAlpha = destinationAlpha + (resolvedSourceAlpha * (1.0 - destinationAlpha))
        guard outAlpha > 0.001 else { return }

        let outRed = ((resolvedSourceRed * resolvedSourceAlpha) + (destinationRed * destinationAlpha * (1.0 - resolvedSourceAlpha))) / outAlpha
        let outGreen = ((resolvedSourceGreen * resolvedSourceAlpha) + (destinationGreen * destinationAlpha * (1.0 - resolvedSourceAlpha))) / outAlpha
        let outBlue = ((resolvedSourceBlue * resolvedSourceAlpha) + (destinationBlue * destinationAlpha * (1.0 - resolvedSourceAlpha))) / outAlpha

        pixels[offset] = UInt8(max(0, min(255, Int((outRed * 255.0).rounded()))))
        pixels[offset + 1] = UInt8(max(0, min(255, Int((outGreen * 255.0).rounded()))))
        pixels[offset + 2] = UInt8(max(0, min(255, Int((outBlue * 255.0).rounded()))))
        pixels[offset + 3] = UInt8(max(0, min(255, Int((outAlpha * 255.0).rounded()))))
    }
}
