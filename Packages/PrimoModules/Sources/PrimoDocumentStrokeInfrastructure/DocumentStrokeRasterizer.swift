import CoreGraphics
import Foundation
import PrimoDocumentContracts

extension DocumentStrokeRasterizer {
    public static func layerPixelDataByApplyingCommittedShortStroke(
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

        let committedSamples = DocumentStrokeGeometry.normalizedCommittedStrokeSamples(samples, brush: brush)
        guard !committedSamples.isEmpty else { return nil }
        let progressTable = DocumentStrokeGeometry.strokeProgressTable(committedSamples)

        var output = layer.pixelData
        let didRasterize = output.withUnsafeMutableBytes { rawBytes in
            guard let baseAddress = rawBytes.bindMemory(to: UInt8.self).baseAddress else { return false }
            let pixels = UnsafeMutableBufferPointer(start: baseAddress, count: expectedCount)
            if committedSamples.count == 1 {
                DocumentStrokeRasterizer.rasterizeShortStrokeStamp(
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
                DocumentStrokeRasterizer.rasterizeShortStrokeSegment(
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

    public static func layerPixelDataByApplyingCommittedStroke(
        basePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool = false
    ) -> Data? {
        if brush.smudgeEngineEnabled,
           let smudgePixels = DocumentColorSmudgeEngine().applyStroke(
                basePixelData: basePixelData,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                samples: samples,
                brush: brush
           )?.pixelData {
            return preserveAlphaLockedPixels
                ? pixelDataByPreservingExistingAlpha(source: smudgePixels, existing: basePixelData)
                : smudgePixels
        }

        let expectedCount = canvasWidth * canvasHeight * 4
        guard basePixelData.count == expectedCount else { return nil }

        let committedSamples = DocumentStrokeGeometry.normalizedCommittedStrokeSamples(samples, brush: brush)
        guard !committedSamples.isEmpty else { return nil }
        let progressTable = DocumentStrokeGeometry.strokeProgressTable(committedSamples)

        var output = basePixelData
        let didRasterize = output.withUnsafeMutableBytes { rawBytes in
            guard let baseAddress = rawBytes.bindMemory(to: UInt8.self).baseAddress else { return false }
            let pixels = UnsafeMutableBufferPointer(start: baseAddress, count: expectedCount)
            if committedSamples.count == 1 {
                DocumentStrokeRasterizer.rasterizeShortStrokeStamp(
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
                DocumentStrokeRasterizer.rasterizeShortStrokeSegment(
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

    public static func colorSmudgeResult(
        basePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool = false
    ) -> DocumentColorSmudgeResult? {
        guard brush.smudgeEngineEnabled else { return nil }
        guard let result = DocumentColorSmudgeEngine().applyStroke(
            basePixelData: basePixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            samples: samples,
            brush: brush
        ) else {
            return nil
        }
        guard preserveAlphaLockedPixels else { return result }
        let resolvedPixels = pixelDataByPreservingExistingAlpha(source: result.pixelData, existing: basePixelData)
        let resolvedRectData = result.dirtyRect.map {
            extractRectPixelData(
                from: resolvedPixels,
                canvasWidth: canvasWidth,
                rect: $0
            )
        }
        return DocumentColorSmudgeResult(
            pixelData: resolvedPixels,
            dirtyRect: result.dirtyRect,
            rectPixelData: resolvedRectData ?? result.rectPixelData
        )
    }

    public static func pixelDataByPreservingExistingAlpha(source: Data, existing: Data) -> Data {
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

    public static func shouldRasterizeCommittedShortStroke(
        _ samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> Bool {
        guard !samples.isEmpty else { return false }
        if samples.count == 1 {
            return true
        }

        let visualThreshold = max(CGFloat(brush.radius) * 6.0, 18.0)
        let endpointDistance = DocumentStrokeGeometry.strokeEndpointDistance(samples)
        let pathLength = DocumentStrokeGeometry.strokePathLength(samples)
        if endpointDistance <= visualThreshold * 0.75 {
            return true
        }
        if endpointDistance <= visualThreshold * 1.5 && pathLength >= max(endpointDistance * 3.0, visualThreshold * 2.0) {
            return true
        }
        return DocumentStrokeGeometry.strokeVisualSpan(samples) <= visualThreshold
    }

    private static func extractRectPixelData(
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
