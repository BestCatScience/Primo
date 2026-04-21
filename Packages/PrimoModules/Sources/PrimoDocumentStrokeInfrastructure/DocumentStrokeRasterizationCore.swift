import CoreGraphics
import Foundation
import PrimoDocumentContracts

extension DocumentStrokeRasterizer {
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
            DocumentStrokeGeometry.resolvedStrokeRadius(for: start, progress: startProgress, brush: brush),
            DocumentStrokeGeometry.resolvedStrokeRadius(for: end, progress: endProgress, brush: brush)
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
                let interpolatedSample = DocumentStrokeGeometry.interpolatedStylusSample(
                    from: start,
                    to: end,
                    progress: t
                )
                let progress = startProgress + ((endProgress - startProgress) * t)
                let radius = DocumentStrokeGeometry.resolvedStrokeRadius(
                    for: interpolatedSample,
                    progress: progress,
                    brush: brush
                )
                let centerX = start.point.x + (dx * t)
                let centerY = start.point.y + (dy * t)
                let distanceToCenter = sqrt(
                    pow(sampleX - centerX, 2.0) + pow(sampleY - centerY, 2.0)
                )
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
                DocumentStrokeRasterizer.blendRasterizedPixel(
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
        let radius = DocumentStrokeGeometry.resolvedStrokeRadius(
            for: sample,
            progress: progress,
            brush: brush
        )
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
                DocumentStrokeRasterizer.blendRasterizedPixel(
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
        BrushStrokeKernel.rasterizedSourceAlpha(
            sample: sample,
            brush: brush,
            progress: progress,
            radius: radius,
            sampleX: sampleX,
            sampleY: sampleY
        )
    }
}
