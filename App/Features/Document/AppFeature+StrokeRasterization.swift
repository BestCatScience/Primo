import CoreGraphics
import Foundation

extension AppFeature {
    private struct RasterizedSmudgeSample {
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat
        var alpha: CGFloat
    }

    static func normalizedCommittedStrokeSamples(
        _ samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> [StylusSample] {
        var normalized = samples.map { sample in
            StylusSample(
                point: CGPoint(
                    x: sample.point.x.isFinite ? sample.point.x : 0,
                    y: sample.point.y.isFinite ? sample.point.y : 0
                ),
                pressure: sample.pressure.isFinite ? sample.pressure : 1.0,
                altitude: sample.altitude.isFinite ? sample.altitude : .pi / 2,
                azimuth: sample.azimuth.isFinite ? sample.azimuth : 0,
                timestamp: sample.timestamp.isFinite ? sample.timestamp : 0
            )
        }
        guard normalized.count > 1 else { return normalized }

        let jumpThreshold = max(CGFloat(brush.radius) * 8.0, 24.0)
        while normalized.count > 1 {
            let last = normalized[normalized.count - 1]
            let previous = normalized[normalized.count - 2]
            let dx = last.point.x - previous.point.x
            let dy = last.point.y - previous.point.y
            let distance = sqrt((dx * dx) + (dy * dy))
            let pressureDropThreshold = max(0.08, previous.pressure * 0.5)
            let isTrailingJump = distance > jumpThreshold && last.pressure < pressureDropThreshold
            if !isTrailingJump {
                break
            }
            normalized.removeLast()
        }

        var deduplicated: [StylusSample] = []
        deduplicated.reserveCapacity(normalized.count)
        for sample in normalized {
            if let previous = deduplicated.last {
                let dx = sample.point.x - previous.point.x
                let dy = sample.point.y - previous.point.y
                let distance = sqrt((dx * dx) + (dy * dy))
                let pressureDelta = abs(sample.pressure - previous.pressure)
                if distance < 0.001, pressureDelta < 0.001 {
                    continue
                }
            }
            deduplicated.append(sample)
        }
        guard deduplicated.count > 1 else { return deduplicated }

        return deduplicated
    }

    static func strokeTaperScale(progress: CGFloat, taperIn: CGFloat, taperOut: CGFloat) -> CGFloat {
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

    static func strokeProgressTable(_ samples: [StylusSample]) -> [CGFloat] {
        guard !samples.isEmpty else { return [] }
        guard samples.count > 1 else { return [0] }

        var cumulative: [CGFloat] = [0]
        cumulative.reserveCapacity(samples.count)
        var totalLength: CGFloat = 0
        for pair in zip(samples, samples.dropFirst()) {
            let dx = pair.1.point.x - pair.0.point.x
            let dy = pair.1.point.y - pair.0.point.y
            totalLength += sqrt((dx * dx) + (dy * dy))
            cumulative.append(totalLength)
        }

        guard totalLength > 0.001 else {
            return Array(repeating: 0, count: samples.count)
        }

        return cumulative.map { $0 / totalLength }
    }

    static func layerPixelDataByApplyingCommittedShortStroke(
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool = false
    ) -> Data? {
        guard shouldRasterizeCommittedShortStroke(samples, brush: brush) else { return nil }
        guard
            let snapshot,
            let layer = snapshot.layers.first(where: { $0.index == activeLayerIndex })
        else {
            return nil
        }

        let expectedCount = snapshot.width * snapshot.height * 4
        guard layer.pixelData.count == expectedCount else { return nil }

        let committedSamples = normalizedCommittedStrokeSamples(samples, brush: brush)
        guard !committedSamples.isEmpty else { return nil }
        let progressTable = strokeProgressTable(committedSamples)

        var output = layer.pixelData
        let didRasterize = output.withUnsafeMutableBytes { rawBytes in
            guard let baseAddress = rawBytes.bindMemory(to: UInt8.self).baseAddress else { return false }
            let pixels = UnsafeMutableBufferPointer(start: baseAddress, count: expectedCount)
            if committedSamples.count == 1 {
                rasterizeShortStrokeStamp(
                    into: pixels,
                    canvasWidth: snapshot.width,
                    canvasHeight: snapshot.height,
                    sample: committedSamples[0],
                    progress: progressTable[0],
                    brush: brush
                )
                return true
            }

            for (index, pair) in zip(committedSamples.indices, zip(committedSamples, committedSamples.dropFirst())) {
                rasterizeShortStrokeSegment(
                    into: pixels,
                    canvasWidth: snapshot.width,
                    canvasHeight: snapshot.height,
                    start: pair.0,
                    end: pair.1,
                    startProgress: progressTable[index],
                    endProgress: progressTable[index + 1],
                    brush: brush
                )
            }
            return true
        }

        guard didRasterize else { return nil }
        return preserveAlphaLockedPixels
            ? pixelDataByPreservingExistingAlpha(source: output, existing: layer.pixelData)
            : output
    }

    static func layerPixelDataByApplyingCommittedStroke(
        basePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool = false
    ) -> Data? {
        let expectedCount = canvasWidth * canvasHeight * 4
        guard basePixelData.count == expectedCount else { return nil }

        let committedSamples = normalizedCommittedStrokeSamples(samples, brush: brush)
        guard !committedSamples.isEmpty else { return nil }
        let progressTable = strokeProgressTable(committedSamples)

        var output = basePixelData
        let didRasterize = output.withUnsafeMutableBytes { rawBytes in
            guard let baseAddress = rawBytes.bindMemory(to: UInt8.self).baseAddress else { return false }
            let pixels = UnsafeMutableBufferPointer(start: baseAddress, count: expectedCount)
            if committedSamples.count == 1 {
                rasterizeShortStrokeStamp(
                    into: pixels,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    sample: committedSamples[0],
                    progress: progressTable[0],
                    brush: brush
                )
                return true
            }

            for (index, pair) in zip(committedSamples.indices, zip(committedSamples, committedSamples.dropFirst())) {
                rasterizeShortStrokeSegment(
                    into: pixels,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    start: pair.0,
                    end: pair.1,
                    startProgress: progressTable[index],
                    endProgress: progressTable[index + 1],
                    brush: brush
                )
            }
            return true
        }

        guard didRasterize else { return nil }
        return preserveAlphaLockedPixels
            ? pixelDataByPreservingExistingAlpha(source: output, existing: basePixelData)
            : output
    }

    static func pixelDataByPreservingExistingAlpha(source: Data, existing: Data) -> Data {
        guard source.count == existing.count else { return source }
        var output = source
        output.withUnsafeMutableBytes { outputBytes in
            existing.withUnsafeBytes { existingBytes in
                guard let dst = outputBytes.bindMemory(to: UInt8.self).baseAddress,
                      let src = existingBytes.bindMemory(to: UInt8.self).baseAddress
                else { return }
                for offset in stride(from: 0, to: source.count, by: 4) {
                    let alpha = src[offset + 3]
                    if alpha == 0 {
                        dst[offset] = 0
                        dst[offset + 1] = 0
                        dst[offset + 2] = 0
                        dst[offset + 3] = 0
                    } else {
                        dst[offset + 3] = alpha
                    }
                }
            }
        }
        return output
    }

    static func shouldRasterizeCommittedShortStroke(
        _ samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> Bool {
        guard !samples.isEmpty else { return false }
        if samples.count == 1 {
            return true
        }

        let visualThreshold = max(CGFloat(brush.radius) * 6.0, 18.0)
        let endpointDistance = strokeEndpointDistance(samples)
        let pathLength = strokePathLength(samples)
        if endpointDistance <= visualThreshold * 0.75 {
            return true
        }
        if endpointDistance <= visualThreshold * 1.5 && pathLength >= max(endpointDistance * 3.0, visualThreshold * 2.0) {
            return true
        }
        return strokeVisualSpan(samples) <= visualThreshold
    }

    static func strokePathLength(_ samples: [StylusSample]) -> CGFloat {
        zip(samples, samples.dropFirst()).reduce(.zero) { partial, pair in
            let dx = pair.1.point.x - pair.0.point.x
            let dy = pair.1.point.y - pair.0.point.y
            return partial + sqrt((dx * dx) + (dy * dy))
        }
    }

    static func strokeEndpointDistance(_ samples: [StylusSample]) -> CGFloat {
        guard let first = samples.first, let last = samples.last else { return .zero }
        let dx = last.point.x - first.point.x
        let dy = last.point.y - first.point.y
        return sqrt((dx * dx) + (dy * dy))
    }

    static func strokeVisualSpan(_ samples: [StylusSample]) -> CGFloat {
        guard let first = samples.first, let last = samples.last else { return .zero }
        var minX = first.point.x
        var maxX = first.point.x
        var minY = first.point.y
        var maxY = first.point.y

        for sample in samples.dropFirst() {
            minX = min(minX, sample.point.x)
            maxX = max(maxX, sample.point.x)
            minY = min(minY, sample.point.y)
            maxY = max(maxY, sample.point.y)
        }

        let width = maxX - minX
        let height = maxY - minY
        let endpointDX = last.point.x - first.point.x
        let endpointDY = last.point.y - first.point.y
        let endpointDistance = sqrt((endpointDX * endpointDX) + (endpointDY * endpointDY))
        return max(width, height, endpointDistance)
    }

    static func averagedStylusSample(_ samples: [StylusSample]) -> StylusSample {
        guard let first = samples.first else {
            return StylusSample(
                point: .zero,
                pressure: 1.0,
                altitude: .pi / 2,
                azimuth: 0,
                timestamp: 0
            )
        }
        let count = CGFloat(samples.count)
        let summed = samples.reduce(
            (x: CGFloat.zero, y: CGFloat.zero, pressure: CGFloat.zero, altitude: CGFloat.zero, azimuth: CGFloat.zero, timestamp: TimeInterval.zero)
        ) { partial, sample in
            (
                x: partial.x + sample.point.x,
                y: partial.y + sample.point.y,
                pressure: partial.pressure + sample.pressure,
                altitude: partial.altitude + sample.altitude,
                azimuth: partial.azimuth + sample.azimuth,
                timestamp: partial.timestamp + sample.timestamp
            )
        }
        return StylusSample(
            point: CGPoint(x: summed.x / count, y: summed.y / count),
            pressure: summed.pressure / count,
            altitude: summed.altitude / count,
            azimuth: summed.azimuth / count,
            timestamp: summed.timestamp / Double(samples.count)
        )
    }

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

    static func interpolatedStylusSample(from start: StylusSample, to end: StylusSample, progress t: CGFloat) -> StylusSample {
        StylusSample(
            point: CGPoint(
                x: start.point.x + ((end.point.x - start.point.x) * t),
                y: start.point.y + ((end.point.y - start.point.y) * t)
            ),
            pressure: start.pressure + ((end.pressure - start.pressure) * t),
            altitude: start.altitude + ((end.altitude - start.altitude) * t),
            azimuth: start.azimuth + ((end.azimuth - start.azimuth) * t),
            timestamp: start.timestamp + ((end.timestamp - start.timestamp) * Double(t))
        )
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
                let luminanceSimilarity = clampUnit(1.0 - abs(mixedLuminance - pigmentLuminance) * 0.38)
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

    static func resolvedStrokeRadius(for sample: StylusSample, progress: CGFloat = 0, brush: BrushRuntimeSettings) -> CGFloat {
        let clampedPressure = max(0.08, min(sample.pressure, 1.0))
        let pressureFactor = max(
            0.1,
            1.0 + ((clampedPressure - 1.0) * CGFloat(brush.pressureSensitivity))
        )
        let taperScale = strokeTaperScale(
            progress: progress,
            taperIn: CGFloat(brush.taperIn),
            taperOut: CGFloat(brush.taperOut)
        )
        return max(CGFloat(brush.radius) * pressureFactor * taperScale, 1.5)
    }

    static func previewNoise(x: CGFloat, y: CGFloat) -> CGFloat {
        let value = sin((x * 12.9898) + (y * 78.233)) * 43758.5453
        return value - floor(value)
    }
}
