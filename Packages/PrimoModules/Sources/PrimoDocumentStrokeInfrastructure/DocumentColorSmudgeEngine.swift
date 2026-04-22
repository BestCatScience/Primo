import CoreGraphics
import Foundation
import PrimoDocumentContracts

public struct DocumentColorSmudgeDab: Equatable, Sendable {
    public let center: CGPoint
    public let radius: CGFloat
    public let progress: CGFloat
    public let sample: StylusSample
    public let destinationRect: CGRect

    public init(
        center: CGPoint,
        radius: CGFloat,
        progress: CGFloat,
        sample: StylusSample,
        destinationRect: CGRect
    ) {
        self.center = center
        self.radius = radius
        self.progress = progress
        self.sample = sample
        self.destinationRect = destinationRect
    }
}

public enum DocumentColorSmudgeSampleStrategy: Equatable, Sendable {
    case weighted
}

public struct DocumentColorSmudgeResult: Sendable {
    public let pixelData: Data
    public let dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?
    public let rectPixelData: Data?

    public init(
        pixelData: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?,
        rectPixelData: Data?
    ) {
        self.pixelData = pixelData
        self.dirtyRect = dirtyRect
        self.rectPixelData = rectPixelData
    }
}

public struct DocumentColorSmudgeEngine: Sendable {
    public var sampleStrategy: DocumentColorSmudgeSampleStrategy

    public init(sampleStrategy: DocumentColorSmudgeSampleStrategy = .weighted) {
        self.sampleStrategy = sampleStrategy
    }

    public func applyStroke(
        basePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> DocumentColorSmudgeResult? {
        let expectedCount = canvasWidth * canvasHeight * 4
        guard basePixelData.count == expectedCount else { return nil }

        let normalizedSamples = DocumentStrokeGeometry
            .normalizedCommittedStrokeSamples(samples, brush: brush)
            .filter(\.isFinite)
        guard !normalizedSamples.isEmpty else { return nil }
        let progressTable = DocumentStrokeGeometry.strokeProgressTable(normalizedSamples)
        let dabs = makeDabs(
            samples: normalizedSamples,
            progressTable: progressTable,
            brush: brush,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
        guard !dabs.isEmpty else { return nil }

        var output = basePixelData
        var dirtyRect: CGRect?
        var carriedColor = PremultipliedPixel.zero

        output.withUnsafeMutableBytes { rawBytes in
            guard let outputBase = rawBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            let outputPixels = UnsafeMutableBufferPointer(start: outputBase, count: expectedCount)

            for (index, dab) in dabs.enumerated() {
                let sourceSnapshot = Data(
                    bytes: outputBase,
                    count: expectedCount
                )
                sourceSnapshot.withUnsafeBytes { sourceBytes in
                    guard let sourceBase = sourceBytes.bindMemory(to: UInt8.self).baseAddress else { return }
                    let sourcePixels = UnsafeBufferPointer(start: sourceBase, count: expectedCount)
                    let previousCenter = index > 0 ? dabs[index - 1].center : dab.center
                    let result = applyDab(
                        dab,
                        previousCenter: previousCenter,
                        sourcePixels: sourcePixels,
                        destinationPixels: outputPixels,
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight,
                        brush: brush,
                        carriedColor: carriedColor
                    )
                    if result.didWrite {
                        dirtyRect = dirtyRect.map { $0.union(dab.destinationRect) } ?? dab.destinationRect
                        carriedColor = result.carriedColor
                    }
                }
            }
        }

        let clippedDirtyRect = dirtyRect.map { clip(rect: $0.integral, canvasWidth: canvasWidth, canvasHeight: canvasHeight) }
        let resolvedDirtyRect = clippedDirtyRect.flatMap { rect -> (originX: Int, originY: Int, width: Int, height: Int)? in
            guard rect.width > 0, rect.height > 0 else { return nil }
            guard rect.isFinite else { return nil }
            return (
                originX: Int(rect.origin.x),
                originY: Int(rect.origin.y),
                width: Int(rect.width),
                height: Int(rect.height)
            )
        }

        let rectPixelData = resolvedDirtyRect.map {
            extractRectPixelData(
                from: output,
                canvasWidth: canvasWidth,
                rect: $0
            )
        }

        return DocumentColorSmudgeResult(
            pixelData: output,
            dirtyRect: resolvedDirtyRect,
            rectPixelData: rectPixelData
        )
    }

    public func makeDabs(
        samples: [StylusSample],
        progressTable: [CGFloat],
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> [DocumentColorSmudgeDab] {
        guard let first = samples.first else { return [] }
        var dabs: [DocumentColorSmudgeDab] = []
        let firstRadius = DocumentStrokeGeometry.resolvedStrokeRadius(for: first, progress: progressTable.first ?? 0, brush: brush)
        if let firstDab = makeDab(
            sample: first,
            progress: progressTable.first ?? 0,
            radius: firstRadius,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        ) {
            dabs.append(firstDab)
        }

        guard samples.count > 1 else { return dabs }

        for index in samples.indices.dropFirst() {
            let start = samples[index - 1]
            let end = samples[index]
            let startProgress = progressTable[index - 1]
            let endProgress = progressTable[index]
            let startRadius = DocumentStrokeGeometry.resolvedStrokeRadius(for: start, progress: startProgress, brush: brush)
            let endRadius = DocumentStrokeGeometry.resolvedStrokeRadius(for: end, progress: endProgress, brush: brush)
            let dx = end.point.x - start.point.x
            let dy = end.point.y - start.point.y
            let distance = sqrt((dx * dx) + (dy * dy))
            let spacing = max(1.0, ((startRadius + endRadius) * 0.5) * max(CGFloat(brush.stampSpacing), 0.02))
            guard distance.isFinite, spacing.isFinite, spacing > 0 else { continue }
            let steps = max(1, Int(ceil(distance / spacing)))
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let interpolated = DocumentStrokeGeometry.interpolatedStylusSample(from: start, to: end, progress: t)
                let progress = startProgress + ((endProgress - startProgress) * t)
                let radius = DocumentStrokeGeometry.resolvedStrokeRadius(for: interpolated, progress: progress, brush: brush)
                if let dab = makeDab(
                    sample: interpolated,
                    progress: progress,
                    radius: radius,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight
                ) {
                    dabs.append(dab)
                }
            }
        }
        return dabs
    }

    private func makeDab(
        sample: StylusSample,
        progress: CGFloat,
        radius: CGFloat,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentColorSmudgeDab? {
        guard sample.isFinite, progress.isFinite, radius.isFinite else { return nil }
        let margin = max(2.0, radius + 2.0)
        guard margin.isFinite else { return nil }
        let rawRect = CGRect(
            x: floor(sample.point.x - margin),
            y: floor(sample.point.y - margin),
            width: ceil(margin * 2.0),
            height: ceil(margin * 2.0)
        )
        guard rawRect.isFinite else { return nil }
        let clipped = clip(rect: rawRect, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        guard clipped.isFinite else { return nil }
        return DocumentColorSmudgeDab(
            center: sample.point,
            radius: radius,
            progress: progress,
            sample: sample,
            destinationRect: clipped
        )
    }

    private func applyDab(
        _ dab: DocumentColorSmudgeDab,
        previousCenter: CGPoint,
        sourcePixels: UnsafeBufferPointer<UInt8>,
        destinationPixels: UnsafeMutableBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        brush: BrushRuntimeSettings,
        carriedColor: PremultipliedPixel
    ) -> AppliedDabResult {
        guard dab.destinationRect.width > 0, dab.destinationRect.height > 0, dab.destinationRect.isFinite else {
            return AppliedDabResult(didWrite: false, carriedColor: carriedColor)
        }

        let dx = previousCenter.x - dab.center.x
        let dy = previousCenter.y - dab.center.y
        let baseOpacity = min(max(CGFloat(brush.opacity * brush.flow), 0.0), 1.0)
        let spacingInfluence = min(max(CGFloat(brush.stampSpacing), 0.02), 1.0)
        let pressureMixScale = max(
            0.12,
            1.0 - CGFloat(brush.loadPressureSensitivity)
                + (CGFloat(brush.loadPressureSensitivity) * max(0.0, min(dab.sample.pressure, 1.0)))
        )
        let smudgeBlend = min(max(CGFloat(brush.smudgeLength) * pressureMixScale, 0.0), 1.0)
        let colorBlend = min(max(CGFloat(brush.colorRate) * pressureMixScale, 0.0), 1.0)
        let colorContribution = min(
            max(colorBlend * colorBlend * baseOpacity * (1.0 - (smudgeBlend * 0.55)), 0.0),
            0.85
        )
        let smudgeContribution = min(max(smudgeBlend * (0.35 + (baseOpacity * 0.65)) * (1.08 - min(spacingInfluence, 0.9) * 0.35), 0.0), 1.0)
        let representative = representativeColor(
            for: dab,
            sourcePixels: sourcePixels,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            brush: brush
        )
        var didWrite = false

        let startX = Int(dab.destinationRect.minX)
        let endX = Int(dab.destinationRect.maxX)
        let startY = Int(dab.destinationRect.minY)
        let endY = Int(dab.destinationRect.maxY)

        for y in startY..<endY {
            for x in startX..<endX {
                let sampleX = CGFloat(x) + 0.5
                let sampleY = CGFloat(y) + 0.5
                let maskAlpha = BrushStrokeKernel.rasterizedSourceAlpha(
                    sample: dab.sample,
                    brush: brush,
                    progress: dab.progress,
                    radius: dab.radius,
                    sampleX: sampleX,
                    sampleY: sampleY
                )
                guard maskAlpha > 0.001 else { continue }

                let source: PremultipliedPixel
                switch brush.smudgeMode {
                case .smearing:
                    let sampledSource = sampleSmearingPixel(
                        pixels: sourcePixels,
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight,
                        x: sampleX + dx,
                        y: sampleY + dy,
                        dabRadius: dab.radius,
                        brush: brush
                    )
                    if sampledSource.alpha > 0.001 {
                        let softenedSource = sampledSource.mixed(
                            with: representative,
                            ratio: 0.12 + (0.18 * (1.0 - min(max(CGFloat(brush.hardness), 0.0), 1.0)))
                        )
                        source = PremultipliedPixel(
                            red: softenedSource.red,
                            green: softenedSource.green,
                            blue: softenedSource.blue,
                            alpha: max(softenedSource.alpha, sampledSource.alpha * 0.92)
                        )
                    } else if carriedColor.alpha > 0.001 {
                        source = carriedColor
                    } else {
                        source = representative
                    }
                case .dulling:
                    source = representative
                }

                let smudged = source.scaled(alphaScale: maskAlpha * smudgeContribution)
                let pigment = PremultipliedPixel(
                    red: (CGFloat(brush.red) / 255.0) * (maskAlpha * colorContribution),
                    green: (CGFloat(brush.green) / 255.0) * (maskAlpha * colorContribution),
                    blue: (CGFloat(brush.blue) / 255.0) * (maskAlpha * colorContribution),
                    alpha: maskAlpha * colorContribution
                )
                let combined = colorContribution > 0.001 ? pigment.over(smudged) : smudged
                guard combined.alpha > 0.001 else { continue }

                let offset = ((y * canvasWidth) + x) * 4
                let destination = PremultipliedPixel.fromRGBA(
                    red: destinationPixels[offset],
                    green: destinationPixels[offset + 1],
                    blue: destinationPixels[offset + 2],
                    alpha: destinationPixels[offset + 3]
                )
                let resolved = combined.over(destination)
                destinationPixels[offset] = resolved.redByte
                destinationPixels[offset + 1] = resolved.greenByte
                destinationPixels[offset + 2] = resolved.blueByte
                destinationPixels[offset + 3] = resolved.alphaByte
                didWrite = true
            }
        }

        guard didWrite, let destinationBase = destinationPixels.baseAddress else {
            return AppliedDabResult(didWrite: false, carriedColor: carriedColor)
        }

        let resolvedCarriedColor = samplePixel(
            pixels: UnsafeBufferPointer(start: destinationBase, count: destinationPixels.count),
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            x: dab.center.x,
            y: dab.center.y
        )
        return AppliedDabResult(
            didWrite: true,
            carriedColor: resolvedCarriedColor.alpha > 0.001 ? resolvedCarriedColor : carriedColor
        )
    }

    private func representativeColor(
        for dab: DocumentColorSmudgeDab,
        sourcePixels: UnsafeBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        brush: BrushRuntimeSettings
    ) -> PremultipliedPixel {
        let radiusFactor = 0.18 + (min(max(CGFloat(brush.smudgeRadius), 0.0), 1.0) * 0.82)
        let sampleRadius = max(1.0, dab.radius * radiusFactor)
        var totalWeight: CGFloat = 0
        var accum = PremultipliedPixel.zero
        let offsets: [CGPoint] = [
            .zero,
            CGPoint(x: -0.6, y: 0),
            CGPoint(x: 0.6, y: 0),
            CGPoint(x: 0, y: -0.6),
            CGPoint(x: 0, y: 0.6),
            CGPoint(x: -0.42, y: -0.42),
            CGPoint(x: 0.42, y: -0.42),
            CGPoint(x: -0.42, y: 0.42),
            CGPoint(x: 0.42, y: 0.42)
        ]

        for offset in offsets {
            let point = CGPoint(
                x: dab.center.x + (offset.x * sampleRadius),
                y: dab.center.y + (offset.y * sampleRadius)
            )
            let sampled = samplePixel(
                pixels: sourcePixels,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                x: point.x,
                y: point.y
            )
            let weight: CGFloat
            switch sampleStrategy {
            case .weighted:
                let mask = BrushStrokeKernel.rasterizedSourceAlpha(
                    sample: dab.sample,
                    brush: brush,
                    progress: dab.progress,
                    radius: max(sampleRadius, dab.radius),
                    sampleX: point.x,
                    sampleY: point.y
                )
                weight = max(0.05, mask)
            }
            accum.red += sampled.red * weight
            accum.green += sampled.green * weight
            accum.blue += sampled.blue * weight
            accum.alpha += sampled.alpha * weight
            totalWeight += weight
        }

        guard totalWeight > 0.0001 else { return .zero }
        return PremultipliedPixel(
            red: accum.red / totalWeight,
            green: accum.green / totalWeight,
            blue: accum.blue / totalWeight,
            alpha: accum.alpha / totalWeight
        )
    }

    private func samplePixel(
        pixels: UnsafeBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        x: CGFloat,
        y: CGFloat
    ) -> PremultipliedPixel {
        guard x.isFinite, y.isFinite else { return .zero }
        let clampedX = min(max(Int(x.rounded(.toNearestOrAwayFromZero)), 0), canvasWidth - 1)
        let clampedY = min(max(Int(y.rounded(.toNearestOrAwayFromZero)), 0), canvasHeight - 1)
        let offset = ((clampedY * canvasWidth) + clampedX) * 4
        return PremultipliedPixel.fromRGBA(
            red: pixels[offset],
            green: pixels[offset + 1],
            blue: pixels[offset + 2],
            alpha: pixels[offset + 3]
        )
    }

    private func sampleSmearingPixel(
        pixels: UnsafeBufferPointer<UInt8>,
        canvasWidth: Int,
        canvasHeight: Int,
        x: CGFloat,
        y: CGFloat,
        dabRadius: CGFloat,
        brush: BrushRuntimeSettings
    ) -> PremultipliedPixel {
        let softness = 1.0 - min(max(CGFloat(brush.hardness), 0.0), 1.0)
        let sampleRadius = max(0.2, dabRadius * (0.025 + (softness * 0.05)))
        let taps: [(CGPoint, CGFloat)] = [
            (CGPoint(x: 0, y: 0), 0.58),
            (CGPoint(x: -0.55, y: 0), 0.10),
            (CGPoint(x: 0.55, y: 0), 0.10),
            (CGPoint(x: 0, y: -0.55), 0.10),
            (CGPoint(x: 0, y: 0.55), 0.10),
            (CGPoint(x: -0.4, y: -0.4), 0.06),
            (CGPoint(x: 0.4, y: 0.4), 0.06)
        ]

        var accum = PremultipliedPixel.zero
        var totalWeight: CGFloat = 0
        for (offset, weight) in taps {
            let sample = samplePixel(
                pixels: pixels,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                x: x + (offset.x * sampleRadius),
                y: y + (offset.y * sampleRadius)
            )
            accum.red += sample.red * weight
            accum.green += sample.green * weight
            accum.blue += sample.blue * weight
            accum.alpha += sample.alpha * weight
            totalWeight += weight
        }

        guard totalWeight > 0.0001 else { return .zero }
        return PremultipliedPixel(
            red: accum.red / totalWeight,
            green: accum.green / totalWeight,
            blue: accum.blue / totalWeight,
            alpha: accum.alpha / totalWeight
        )
    }

    private func clip(rect: CGRect, canvasWidth: Int, canvasHeight: Int) -> CGRect {
        guard rect.isFinite else { return .null }
        return rect.intersection(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    }

    private func extractRectPixelData(
        from pixelData: Data,
        canvasWidth: Int,
        rect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> Data {
        var output = Data(capacity: rect.width * rect.height * 4)
        pixelData.withUnsafeBytes { rawBytes in
            guard let base = rawBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for row in 0..<rect.height {
                let offset = (((rect.originY + row) * canvasWidth) + rect.originX) * 4
                output.append(base + offset, count: rect.width * 4)
            }
        }
        return output
    }
}

private extension StylusSample {
    var isFinite: Bool {
        point.x.isFinite &&
        point.y.isFinite &&
        pressure.isFinite &&
        altitude.isFinite &&
        azimuth.isFinite &&
        timestamp.isFinite
    }
}

private extension CGRect {
    var isFinite: Bool {
        origin.x.isFinite &&
        origin.y.isFinite &&
        width.isFinite &&
        height.isFinite
    }
}

private struct AppliedDabResult {
    let didWrite: Bool
    let carriedColor: PremultipliedPixel
}

private struct PremultipliedPixel: Equatable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    static let zero = PremultipliedPixel(red: 0, green: 0, blue: 0, alpha: 0)

    static func fromRGBA(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) -> PremultipliedPixel {
        let resolvedAlpha = CGFloat(alpha) / 255.0
        return PremultipliedPixel(
            red: (CGFloat(red) / 255.0) * resolvedAlpha,
            green: (CGFloat(green) / 255.0) * resolvedAlpha,
            blue: (CGFloat(blue) / 255.0) * resolvedAlpha,
            alpha: resolvedAlpha
        )
    }

    func scaled(alphaScale: CGFloat) -> PremultipliedPixel {
        PremultipliedPixel(
            red: red * alphaScale,
            green: green * alphaScale,
            blue: blue * alphaScale,
            alpha: alpha * alphaScale
        )
    }

    func over(_ background: PremultipliedPixel) -> PremultipliedPixel {
        let remaining = 1.0 - alpha
        return PremultipliedPixel(
            red: red + (background.red * remaining),
            green: green + (background.green * remaining),
            blue: blue + (background.blue * remaining),
            alpha: alpha + (background.alpha * remaining)
        )
    }

    func mixed(with other: PremultipliedPixel, ratio: CGFloat) -> PremultipliedPixel {
        let clampedRatio = min(max(ratio, 0.0), 1.0)
        let inverse = 1.0 - clampedRatio
        return PremultipliedPixel(
            red: (red * inverse) + (other.red * clampedRatio),
            green: (green * inverse) + (other.green * clampedRatio),
            blue: (blue * inverse) + (other.blue * clampedRatio),
            alpha: (alpha * inverse) + (other.alpha * clampedRatio)
        )
    }

    var redByte: UInt8 {
        colorByte(red)
    }

    var greenByte: UInt8 {
        colorByte(green)
    }

    var blueByte: UInt8 {
        colorByte(blue)
    }

    var alphaByte: UInt8 {
        UInt8(max(0, min(255, Int((alpha * 255.0).rounded()))))
    }

    private func colorByte(_ premultiplied: CGFloat) -> UInt8 {
        guard alpha > 0.0001 else { return 0 }
        return UInt8(max(0, min(255, Int(((premultiplied / alpha) * 255.0).rounded()))))
    }
}
