import CoreGraphics
import Foundation
import PrimoDocumentContracts

extension AppFeature {
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
        mode: MetalStrokeExecutionMode = .commit,
        snapshotRevision: Int? = nil,
        activeLayerIndex: Int? = nil,
        preserveAlphaLockedPixels: Bool = false
    ) -> Data? {
        if let gpuOutput = MetalDocumentProcessingClient.shared.rasterizedStrokePixelData(
            basePixelData: basePixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            samples: samples,
            brush: brush,
            mode: mode,
            snapshotRevision: snapshotRevision,
            activeLayerIndex: activeLayerIndex
        ) {
            return preserveAlphaLockedPixels
                ? pixelDataByPreservingExistingAlpha(source: gpuOutput, existing: basePixelData)
                : gpuOutput
        }

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
}
