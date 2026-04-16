import CoreGraphics
import Foundation

extension AppFeature {
    static func rasterizeShortStrokeSegment(
        into pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        start: StylusSample,
        end: StylusSample,
        startProgress: CGFloat,
        endProgress: CGFloat,
        brush: BrushRuntimeSettings
    ) {
        let dx = end.point.x - start.point.x
        let dy = end.point.y - start.point.y
        let lengthSquared = max((dx * dx) + (dy * dy), 0.0001)
        let length = max(sqrt(lengthSquared), 0.0001)
        let tangentX = dx / length
        let tangentY = dy / length
        let normalX = -tangentY
        let normalY = tangentX
        let maxRadius = max(
            resolvedStrokeRadius(for: start, progress: startProgress, brush: brush),
            resolvedStrokeRadius(for: end, progress: endProgress, brush: brush)
        )

        let minX = max(Int(floor(min(start.point.x, end.point.x) - maxRadius)), 0)
        let maxX = min(Int(ceil(max(start.point.x, end.point.x) + maxRadius)), canvasWidth - 1)
        let minY = max(Int(floor(min(start.point.y, end.point.y) - maxRadius)), 0)
        let maxY = min(Int(ceil(max(start.point.y, end.point.y) + maxRadius)), canvasHeight - 1)
        guard minX <= maxX, minY <= maxY else { return }

        for y in minY...maxY {
            for x in minX...maxX {
                let sampleX = CGFloat(x) + 0.5
                let sampleY = CGFloat(y) + 0.5
                let projection = (((sampleX - start.point.x) * dx) + ((sampleY - start.point.y) * dy)) / lengthSquared
                let t = max(0, min(1, projection))
                let interpolatedSample = interpolatedStylusSample(from: start, to: end, progress: t)
                let progress = startProgress + ((endProgress - startProgress) * t)
                let radius = resolvedStrokeRadius(for: interpolatedSample, progress: progress, brush: brush)
                let centerX = start.point.x + (dx * t)
                let centerY = start.point.y + (dy * t)
                let distanceToCenter = sqrt(pow(sampleX - centerX, 2) + pow(sampleY - centerY, 2))
                guard distanceToCenter <= radius else { continue }
                let sourceAlpha = sourceAlphaForRasterizedSample(
                    interpolatedSample,
                    brush: brush,
                    progress: progress,
                    radius: radius,
                    sampleX: sampleX,
                    sampleY: sampleY
                )
                guard sourceAlpha > 0.001 else { continue }
                let clampedPressure = max(0.08, min(interpolatedSample.pressure, 1.0))
                blendRasterizedPixel(
                    into: pixels,
                    offset: ((y * canvasWidth) + x) * 4,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    x: x,
                    y: y,
                    radius: radius,
                    sourceAlpha: sourceAlpha,
                    pressure: clampedPressure,
                    tangentX: tangentX,
                    tangentY: tangentY,
                    normalX: normalX,
                    normalY: normalY,
                    brush: brush
                )
            }
        }
    }

    static func rasterizeShortStrokeStamp(
        into pixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        sample: StylusSample,
        progress: CGFloat,
        brush: BrushRuntimeSettings
    ) {
        let radius = resolvedStrokeRadius(for: sample, progress: progress, brush: brush)
        let minX = max(Int(floor(sample.point.x - radius)), 0)
        let maxX = min(Int(ceil(sample.point.x + radius)), canvasWidth - 1)
        let minY = max(Int(floor(sample.point.y - radius)), 0)
        let maxY = min(Int(ceil(sample.point.y + radius)), canvasHeight - 1)
        guard minX <= maxX, minY <= maxY else { return }
        let tangentX: CGFloat = 1.0
        let tangentY: CGFloat = 0.0
        let normalX: CGFloat = 0.0
        let normalY: CGFloat = 1.0

        for y in minY...maxY {
            for x in minX...maxX {
                let sampleX = CGFloat(x) + 0.5
                let sampleY = CGFloat(y) + 0.5
                let sourceAlpha = sourceAlphaForRasterizedSample(
                    sample,
                    brush: brush,
                    progress: progress,
                    radius: radius,
                    sampleX: sampleX,
                    sampleY: sampleY
                )
                guard sourceAlpha > 0.001 else { continue }
                let clampedPressure = max(0.08, min(sample.pressure, 1.0))
                blendRasterizedPixel(
                    into: pixels,
                    offset: ((y * canvasWidth) + x) * 4,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    x: x,
                    y: y,
                    radius: radius,
                    sourceAlpha: sourceAlpha,
                    pressure: clampedPressure,
                    tangentX: tangentX,
                    tangentY: tangentY,
                    normalX: normalX,
                    normalY: normalY,
                    brush: brush
                )
            }
        }
    }

    static func sourceAlphaForRasterizedSample(
        _ sample: StylusSample,
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
            let grainNoise = previewNoise(
                x: sampleX * max(CGFloat(brush.grainScale), 0.6),
                y: sampleY * max(CGFloat(brush.grainScale), 0.6)
            )
            let paperNoise = previewNoise(
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
}
