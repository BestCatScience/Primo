import CoreGraphics
import Foundation
import Metal
import os
import PrimoBrushDomain
import PrimoBrushFileFormats
import PrimoDocumentContracts
import PrimoDocumentDomain

private struct PrimoMetalCompositeLayerDescriptor {
    let documentIndex: Int32
    let opacity: Float
    let visible: UInt32
    let isClipped: UInt32
    let blendMode: Int32
}

private struct PrimoMetalCompositeRequestDescriptor {
    let canvasWidth: UInt32
    let canvasHeight: UInt32
    let originX: UInt32
    let originY: UInt32
    let outputWidth: UInt32
    let outputHeight: UInt32
    let layerCount: UInt32
    let activeLayerIndex: Int32
    let hasActiveLayerOverride: UInt32
    let includeActiveLayerWhenHidden: UInt32
}

private struct PrimoMetalStrokeSampleDescriptor: Equatable {
    let x: Float
    let y: Float
    let pressure: Float
    let progress: Float
}

private struct PrimoMetalStrokeBrushDescriptor {
    let radius: Float
    let pressureSensitivity: Float
    let taperIn: Float
    let taperOut: Float
    let opacity: Float
    let flow: Float
    let hardness: Float
    let opacityPressureSensitivity: Float
    let flowPressureSensitivity: Float
    let grainScale: Float
    let grainContrast: Float
    let paperScale: Float
    let paperStrength: Float
    let paperThreshold: Float
    let textureStrength: Float
    let wetness: Float
    let colorMixStrength: Float
    let smudgeBleed: Float
    let smudgeRadius: Float
    let paintLoad: Float
    let red: Float
    let green: Float
    let blue: Float
    let scatterLateral: Float
    let scatterLinear: Float
    let dualScale: Float
    let dualSpacing: Float
    let dualScatter: Float
    let customTipWidth: UInt32
    let customTipHeight: UInt32
    let isEraser: UInt32
    let isPencil: UInt32
    let isOil: UInt32
    let isAirbrush: UInt32
    let dualBrushEnabled: UInt32
    let customTipEnabled: UInt32
    let scatterMode: UInt32
    let textureMode: UInt32
    let dualBlendMode: UInt32
    let colorMixingMode: UInt32
}

private struct PrimoMetalStrokeRasterRequestDescriptor {
    let canvasWidth: UInt32
    let canvasHeight: UInt32
    let originX: UInt32
    let originY: UInt32
    let rectWidth: UInt32
    let rectHeight: UInt32
    let sampleCount: UInt32
    let tileSize: UInt32
    let tileColumns: UInt32
}

private struct PrimoMetalStrokePrimitiveDescriptor {
    let startX: Float
    let startY: Float
    let endX: Float
    let endY: Float
    let startPressure: Float
    let endPressure: Float
    let startProgress: Float
    let endProgress: Float
    let maxRadius: Float
    let isSegment: UInt32
    let padding0: UInt32
    let padding1: UInt32
}

private struct PrimoMetalStrokeTileRangeDescriptor {
    let startIndex: UInt32
    let primitiveCount: UInt32
}

private struct PrimoMetalStrokeRectCopyDescriptor {
    let canvasWidth: UInt32
    let canvasHeight: UInt32
    let originX: UInt32
    let originY: UInt32
    let rectWidth: UInt32
    let rectHeight: UInt32
}

public enum PrimoMetalStrokeExecutionMode: Equatable, Sendable {
    case interactive
    case commit
    case previewAdopt
}

public struct PrimoMetalStrokeExecutionRequest: Sendable {
    public let basePixelData: Data
    public let canvasWidth: Int
    public let canvasHeight: Int
    public let samples: [StylusSample]
    public let brush: BrushRuntimeSettings
    public let mode: PrimoMetalStrokeExecutionMode
    public let snapshotRevision: Int?
    public let activeLayerIndex: Int?

    public init(
        basePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        mode: PrimoMetalStrokeExecutionMode,
        snapshotRevision: Int?,
        activeLayerIndex: Int?
    ) {
        self.basePixelData = basePixelData
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.samples = samples
        self.brush = brush
        self.mode = mode
        self.snapshotRevision = snapshotRevision
        self.activeLayerIndex = activeLayerIndex
    }
}

public struct PrimoMetalStrokeExecutionResult: Sendable {
    public let pixelData: Data
    public let dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    public let rectPixelData: Data?

    public init(
        pixelData: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int),
        rectPixelData: Data?
    ) {
        self.pixelData = pixelData
        self.dirtyRect = dirtyRect
        self.rectPixelData = rectPixelData
    }
}

private struct PrimoMetalStrokeDirtyRect: Equatable {
    let originX: Int
    let originY: Int
    let width: Int
    let height: Int
}

private struct PrimoMetalBufferPair {
    var current: MTLBuffer
    var scratch: MTLBuffer
}

public final class PrimoMetalDocumentProcessingClient: @unchecked Sendable {
    public static let shared = PrimoMetalDocumentProcessingClient()

    private struct SnapshotTextureSignature: Equatable {
        let revision: Int
        let width: Int
        let height: Int
        let layerIndices: [Int]
    }

    private struct StrokeExecutionCache {
        let width: Int
        let height: Int
        let baseSnapshotRevision: Int?
        let activeLayerIndex: Int?
        let brush: BrushRuntimeSettings
        let previewSamples: [PrimoMetalStrokeSampleDescriptor]
        let committableSamples: [PrimoMetalStrokeSampleDescriptor]
        let dirtyRect: PrimoMetalStrokeDirtyRect?
        let rectPixelData: Data?
        var buffers: PrimoMetalBufferPair
        var lastOutputValid: Bool
    }

    private struct StrokePrimitiveBinning {
        let dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
        let tileSize: Int
        let tileColumns: Int
        let primitives: [PrimoMetalStrokePrimitiveDescriptor]
        let tileRanges: [PrimoMetalStrokeTileRangeDescriptor]
        let primitiveIndices: [UInt32]
    }

    private struct StrokeExecutionContext {
        let buffers: PrimoMetalBufferPair
        let shouldAdoptCachedOutput: Bool
        let cachedDirtyRect: PrimoMetalStrokeDirtyRect?
        let cachedRectPixelData: Data?
    }

    private static let logger = Logger(subsystem: "com.primo.modules", category: "MetalRuntime")

    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let library: MTLLibrary?
    private let compositePipeline: MTLComputePipelineState?
    private let strokeRasterPipeline: MTLComputePipelineState?
    private let copyStrokeRectPipeline: MTLComputePipelineState?

    private var cachedSignature: SnapshotTextureSignature?
    private var cachedLayerTexture: MTLTexture?
    private var cachedStrokeExecution: StrokeExecutionCache?

    public init() {
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        self.library = device?.makeDefaultLibrary()
        self.compositePipeline = Self.makePipeline(device: device, library: library, functionName: "compositePreviewKernel")
        self.strokeRasterPipeline = Self.makePipeline(device: device, library: library, functionName: "strokeRasterKernel")
        self.copyStrokeRectPipeline = Self.makePipeline(device: device, library: library, functionName: "copyStrokeRectKernel")
    }

    public func resetStrokeExecutionSession() {
        cachedStrokeExecution = nil
    }

    public func compositedPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int?,
        adjustedActiveLayerPixels: Data?,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)? = nil
    ) -> Data? {
        guard snapshot.width > 0, snapshot.height > 0 else { return nil }
        let orderedLayers = snapshot.layers.sorted(by: { $0.index < $1.index })
        guard
            let commandQueue,
            let pipeline = compositePipeline,
            let layerTexture = rebuildLayerTextureIfNeeded(snapshot: snapshot, orderedLayers: orderedLayers),
            let layerBuffer = makeBuffer(orderedLayers.map(Self.makeLayerDescriptor(for:))),
            let requestBuffer = makeBuffer(
                PrimoMetalCompositeRequestDescriptor(
                    canvasWidth: UInt32(snapshot.width),
                    canvasHeight: UInt32(snapshot.height),
                    originX: UInt32(dirtyRect?.originX ?? 0),
                    originY: UInt32(dirtyRect?.originY ?? 0),
                    outputWidth: UInt32(dirtyRect?.width ?? snapshot.width),
                    outputHeight: UInt32(dirtyRect?.height ?? snapshot.height),
                    layerCount: UInt32(orderedLayers.count),
                    activeLayerIndex: Int32(activeLayerIndex ?? -1),
                    hasActiveLayerOverride: adjustedActiveLayerPixels == nil ? 0 : 1,
                    includeActiveLayerWhenHidden: dirtyRect == nil ? 0 : 1
                )
            ),
            let outputBuffer = device?.makeBuffer(
                length: (dirtyRect?.width ?? snapshot.width) * (dirtyRect?.height ?? snapshot.height) * 4,
                options: .storageModeShared
            )
        else {
            return nil
        }

        let expectedCount = snapshot.width * snapshot.height * 4
        let overridePixels = adjustedActiveLayerPixels ?? Data(count: expectedCount)
        guard overridePixels.count == expectedCount, let overrideBuffer = makeBuffer(overridePixels) else {
            return nil
        }

        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        let outputWidth = dirtyRect?.width ?? snapshot.width
        let outputHeight = dirtyRect?.height ?? snapshot.height
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(layerTexture, index: 0)
        encoder.setBuffer(layerBuffer, offset: 0, index: 0)
        encoder.setBuffer(overrideBuffer, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        encoder.setBuffer(requestBuffer, offset: 0, index: 3)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: outputWidth, height: outputHeight)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: outputWidth * outputHeight * 4)
    }

    public func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        compositedPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: nil
        )
    }

    public func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        guard let pixelData = compositedPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
        ) else {
            return nil
        }
        return IncrementalLayerUpdate(
            layerIndex: -1,
            originX: dirtyRect.originX,
            originY: dirtyRect.originY,
            width: dirtyRect.width,
            height: dirtyRect.height,
            pixelData: pixelData
        )
    }

    public func executeStroke(
        _ request: PrimoMetalStrokeExecutionRequest
    ) -> PrimoMetalStrokeExecutionResult? {
        guard Self.supportsStrokeRasterization(request.brush) else { return nil }
        let normalizedSamples = Self.normalizedCommittedStrokeSamples(request.samples, brush: request.brush)
        let descriptors = Self.strokeSampleDescriptors(samples: normalizedSamples)
        guard !descriptors.isEmpty else { return nil }
        guard
            request.canvasWidth > 0,
            request.canvasHeight > 0,
            request.basePixelData.count == request.canvasWidth * request.canvasHeight * 4,
            let commandQueue,
            let pipeline = strokeRasterPipeline,
            let copyPipeline = copyStrokeRectPipeline
        else {
            return nil
        }

        let fullDirtyRect = Self.strokePreviewDirtyRect(
            samples: normalizedSamples,
            brush: request.brush,
            canvasWidth: request.canvasWidth,
            canvasHeight: request.canvasHeight
        )
        guard let executionContext = prepareStrokeExecutionContext(request: request, descriptors: descriptors) else {
            return nil
        }
        if executionContext.shouldAdoptCachedOutput {
            let resolvedDirtyRect = fullDirtyRect
                ?? executionContext.cachedDirtyRect.map { ($0.originX, $0.originY, $0.width, $0.height) }
                ?? (0, 0, request.canvasWidth, request.canvasHeight)
            return PrimoMetalStrokeExecutionResult(
                pixelData: bytes(from: executionContext.buffers.current, count: request.basePixelData.count),
                dirtyRect: resolvedDirtyRect,
                rectPixelData: executionContext.cachedRectPixelData
            )
        }

        guard
            let dirtyRect = Self.strokePreviewDirtyRect(
                samples: normalizedSamples,
                brush: request.brush,
                canvasWidth: request.canvasWidth,
                canvasHeight: request.canvasHeight
            ),
            let primitiveBinning = Self.makeStrokePrimitiveBinning(
                descriptors: descriptors,
                brush: request.brush,
                canvasWidth: request.canvasWidth,
                canvasHeight: request.canvasHeight,
                dirtyRect: dirtyRect
            )
        else {
            return PrimoMetalStrokeExecutionResult(
                pixelData: bytes(from: executionContext.buffers.current, count: request.basePixelData.count),
                dirtyRect: fullDirtyRect ?? (0, 0, request.canvasWidth, request.canvasHeight),
                rectPixelData: nil
            )
        }

        let customTip = Self.makeCustomTipMask(request.brush.customTip)
        guard
            let primitiveBuffer = makeBuffer(primitiveBinning.primitives),
            let tileRangeBuffer = makeBuffer(primitiveBinning.tileRanges),
            let primitiveIndexBuffer = makeBuffer(primitiveBinning.primitiveIndices),
            let brushBuffer = makeBuffer(Self.makeStrokeBrushDescriptor(request.brush, customTip: customTip)),
            let customTipBuffer = makeBuffer(customTip.alphaData),
            let requestBuffer = makeBuffer(
                PrimoMetalStrokeRasterRequestDescriptor(
                    canvasWidth: UInt32(request.canvasWidth),
                    canvasHeight: UInt32(request.canvasHeight),
                    originX: UInt32(dirtyRect.originX),
                    originY: UInt32(dirtyRect.originY),
                    rectWidth: UInt32(dirtyRect.width),
                    rectHeight: UInt32(dirtyRect.height),
                    sampleCount: UInt32(primitiveBinning.primitives.count),
                    tileSize: UInt32(primitiveBinning.tileSize),
                    tileColumns: UInt32(primitiveBinning.tileColumns)
                )
            ),
            let copyRequestBuffer = makeBuffer(
                PrimoMetalStrokeRectCopyDescriptor(
                    canvasWidth: UInt32(request.canvasWidth),
                    canvasHeight: UInt32(request.canvasHeight),
                    originX: UInt32(dirtyRect.originX),
                    originY: UInt32(dirtyRect.originY),
                    rectWidth: UInt32(dirtyRect.width),
                    rectHeight: UInt32(dirtyRect.height)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let copyEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        copyEncoder.setComputePipelineState(copyPipeline)
        copyEncoder.setBuffer(executionContext.buffers.current, offset: 0, index: 0)
        copyEncoder.setBuffer(executionContext.buffers.scratch, offset: 0, index: 1)
        copyEncoder.setBuffer(copyRequestBuffer, offset: 0, index: 2)
        dispatch2D(encoder: copyEncoder, pipeline: copyPipeline, width: dirtyRect.width, height: dirtyRect.height)
        copyEncoder.endEncoding()

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(executionContext.buffers.current, offset: 0, index: 0)
        encoder.setBuffer(executionContext.buffers.scratch, offset: 0, index: 1)
        encoder.setBuffer(primitiveBuffer, offset: 0, index: 2)
        encoder.setBuffer(brushBuffer, offset: 0, index: 3)
        encoder.setBuffer(requestBuffer, offset: 0, index: 4)
        encoder.setBuffer(customTipBuffer, offset: 0, index: 5)
        encoder.setBuffer(tileRangeBuffer, offset: 0, index: 6)
        encoder.setBuffer(primitiveIndexBuffer, offset: 0, index: 7)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: dirtyRect.width, height: dirtyRect.height)
        encoder.endEncoding()

        guard let finalizeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        finalizeEncoder.setComputePipelineState(copyPipeline)
        finalizeEncoder.setBuffer(executionContext.buffers.scratch, offset: 0, index: 0)
        finalizeEncoder.setBuffer(executionContext.buffers.current, offset: 0, index: 1)
        finalizeEncoder.setBuffer(copyRequestBuffer, offset: 0, index: 2)
        dispatch2D(encoder: finalizeEncoder, pipeline: copyPipeline, width: dirtyRect.width, height: dirtyRect.height)
        finalizeEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let cachedDirtyRect = PrimoMetalStrokeDirtyRect(
            originX: dirtyRect.originX,
            originY: dirtyRect.originY,
            width: dirtyRect.width,
            height: dirtyRect.height
        )
        let rectPixelData = bytes(
            from: executionContext.buffers.current,
            dirtyRect: cachedDirtyRect,
            canvasWidth: request.canvasWidth,
            canvasHeight: request.canvasHeight
        )
        cachedStrokeExecution = StrokeExecutionCache(
            width: request.canvasWidth,
            height: request.canvasHeight,
            baseSnapshotRevision: request.snapshotRevision,
            activeLayerIndex: request.activeLayerIndex,
            brush: request.brush,
            previewSamples: descriptors,
            committableSamples: descriptors,
            dirtyRect: cachedDirtyRect,
            rectPixelData: rectPixelData,
            buffers: executionContext.buffers,
            lastOutputValid: true
        )
        return PrimoMetalStrokeExecutionResult(
            pixelData: bytes(from: executionContext.buffers.current, count: request.basePixelData.count),
            dirtyRect: dirtyRect,
            rectPixelData: rectPixelData
        )
    }

    public func rasterizedStrokePixelData(
        basePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        mode: PrimoMetalStrokeExecutionMode = .commit,
        snapshotRevision: Int? = nil,
        activeLayerIndex: Int? = nil
    ) -> Data? {
        executeStroke(
            PrimoMetalStrokeExecutionRequest(
                basePixelData: basePixelData,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                samples: samples,
                brush: brush,
                mode: mode,
                snapshotRevision: snapshotRevision,
                activeLayerIndex: activeLayerIndex
            )
        )?.pixelData
    }

    private func prepareStrokeExecutionContext(
        request: PrimoMetalStrokeExecutionRequest,
        descriptors: [PrimoMetalStrokeSampleDescriptor]
    ) -> StrokeExecutionContext? {
        if let cachedStrokeExecution,
           cachedStrokeExecution.width == request.canvasWidth,
           cachedStrokeExecution.height == request.canvasHeight,
           cachedStrokeExecution.baseSnapshotRevision == request.snapshotRevision,
           cachedStrokeExecution.activeLayerIndex == request.activeLayerIndex,
           cachedStrokeExecution.brush == request.brush,
           cachedStrokeExecution.lastOutputValid {
            switch request.mode {
            case .interactive:
                if descriptors == cachedStrokeExecution.previewSamples {
                    return StrokeExecutionContext(
                        buffers: cachedStrokeExecution.buffers,
                        shouldAdoptCachedOutput: true,
                        cachedDirtyRect: cachedStrokeExecution.dirtyRect,
                        cachedRectPixelData: cachedStrokeExecution.rectPixelData
                    )
                }
            case .commit:
                if descriptors == cachedStrokeExecution.committableSamples {
                    return StrokeExecutionContext(
                        buffers: cachedStrokeExecution.buffers,
                        shouldAdoptCachedOutput: true,
                        cachedDirtyRect: cachedStrokeExecution.dirtyRect,
                        cachedRectPixelData: cachedStrokeExecution.rectPixelData
                    )
                }
            case .previewAdopt:
                break
            }
        }

        guard
            let current = makeBuffer(request.basePixelData),
            let scratch = makeBuffer(request.basePixelData)
        else {
            return nil
        }
        return StrokeExecutionContext(
            buffers: PrimoMetalBufferPair(current: current, scratch: scratch),
            shouldAdoptCachedOutput: false,
            cachedDirtyRect: nil,
            cachedRectPixelData: nil
        )
    }

    private func rebuildLayerTextureIfNeeded(snapshot: MetalDocumentSnapshot, orderedLayers: [MetalLayerSnapshot]) -> MTLTexture? {
        let signature = SnapshotTextureSignature(
            revision: snapshot.revision,
            width: snapshot.width,
            height: snapshot.height,
            layerIndices: orderedLayers.map(\.index)
        )
        if cachedSignature == signature, let cachedLayerTexture {
            return cachedLayerTexture
        }
        guard let device else { return nil }
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2DArray
        descriptor.pixelFormat = .rgba8Unorm
        descriptor.width = max(snapshot.width, 1)
        descriptor.height = max(snapshot.height, 1)
        descriptor.depth = 1
        descriptor.mipmapLevelCount = 1
        descriptor.arrayLength = max(orderedLayers.count, 1)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        let expectedCount = snapshot.width * snapshot.height * 4
        for (slice, layer) in orderedLayers.enumerated() where layer.pixelData.count == expectedCount {
            layer.pixelData.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
                texture.replace(
                    region: MTLRegionMake2D(0, 0, snapshot.width, snapshot.height),
                    mipmapLevel: 0,
                    slice: slice,
                    withBytes: baseAddress,
                    bytesPerRow: snapshot.width * 4,
                    bytesPerImage: layer.pixelData.count
                )
            }
        }
        cachedSignature = signature
        cachedLayerTexture = texture
        return texture
    }

    private func makeBuffer<T>(_ values: [T]) -> MTLBuffer? {
        guard !values.isEmpty else {
            return device?.makeBuffer(length: MemoryLayout<T>.stride, options: .storageModeShared)
        }
        return values.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device?.makeBuffer(bytes: baseAddress, length: bytes.count, options: .storageModeShared)
        }
    }

    private func makeBuffer<T>(_ value: T) -> MTLBuffer? {
        var mutableValue = value
        return withUnsafeBytes(of: &mutableValue) { bytes in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device?.makeBuffer(bytes: baseAddress, length: bytes.count, options: .storageModeShared)
        }
    }

    private func makeBuffer(_ data: Data) -> MTLBuffer? {
        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device?.makeBuffer(bytes: baseAddress, length: data.count, options: .storageModeShared)
        }
    }

    private func bytes(from buffer: MTLBuffer, count: Int) -> Data {
        Data(bytes: buffer.contents(), count: count)
    }

    private func bytes(
        from buffer: MTLBuffer,
        dirtyRect: PrimoMetalStrokeDirtyRect,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> Data? {
        guard dirtyRect.originX >= 0, dirtyRect.originY >= 0 else { return nil }
        guard dirtyRect.originX + dirtyRect.width <= canvasWidth else { return nil }
        guard dirtyRect.originY + dirtyRect.height <= canvasHeight else { return nil }
        var data = Data(count: dirtyRect.width * dirtyRect.height * 4)
        let source = buffer.contents().assumingMemoryBound(to: UInt8.self)
        data.withUnsafeMutableBytes { destinationBytes in
            guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for row in 0..<dirtyRect.height {
                let srcOffset = ((dirtyRect.originY + row) * canvasWidth + dirtyRect.originX) * 4
                let dstOffset = row * dirtyRect.width * 4
                memcpy(destination + dstOffset, source + srcOffset, dirtyRect.width * 4)
            }
        }
        return data
    }

    private func dispatch2D(
        encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        width: Int,
        height: Int
    ) {
        let threadWidth = min(pipeline.threadExecutionWidth, max(width, 1))
        let threadHeight = max(1, min(pipeline.maxTotalThreadsPerThreadgroup / max(threadWidth, 1), 8))
        encoder.dispatchThreads(
            MTLSize(width: max(width, 1), height: max(height, 1), depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        )
    }

    private static func makePipeline(device: MTLDevice?, library: MTLLibrary?, functionName: String) -> MTLComputePipelineState? {
        guard let device, let function = library?.makeFunction(name: functionName) else { return nil }
        return try? device.makeComputePipelineState(function: function)
    }

    private static func makeLayerDescriptor(for layer: MetalLayerSnapshot) -> PrimoMetalCompositeLayerDescriptor {
        PrimoMetalCompositeLayerDescriptor(
            documentIndex: Int32(layer.index),
            opacity: layer.opacity,
            visible: layer.visible ? 1 : 0,
            isClipped: layer.isClipped ? 1 : 0,
            blendMode: Int32(blendModeIdentifier(layer.blendMode))
        )
    }

    private static func strokeSampleDescriptors(samples: [StylusSample]) -> [PrimoMetalStrokeSampleDescriptor] {
        let progressTable = strokeProgressTable(samples)
        return zip(samples, progressTable).map { sample, progress in
            PrimoMetalStrokeSampleDescriptor(
                x: Float(sample.point.x),
                y: Float(sample.point.y),
                pressure: Float(sample.pressure),
                progress: Float(progress)
            )
        }
    }

    private static func normalizedCommittedStrokeSamples(_ samples: [StylusSample], brush: BrushRuntimeSettings) -> [StylusSample] {
        var normalized = samples.map { sample in
            StylusSample(
                point: CGPoint(x: sample.point.x.isFinite ? sample.point.x : 0, y: sample.point.y.isFinite ? sample.point.y : 0),
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
            if !(distance > jumpThreshold && last.pressure < pressureDropThreshold) { break }
            normalized.removeLast()
        }
        var deduplicated: [StylusSample] = []
        deduplicated.reserveCapacity(normalized.count)
        for sample in normalized {
            if let previous = deduplicated.last {
                let dx = sample.point.x - previous.point.x
                let dy = sample.point.y - previous.point.y
                if sqrt((dx * dx) + (dy * dy)) < 0.001 && abs(sample.pressure - previous.pressure) < 0.001 {
                    continue
                }
            }
            deduplicated.append(sample)
        }
        return deduplicated
    }

    private static func strokeProgressTable(_ samples: [StylusSample]) -> [CGFloat] {
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

    private static func strokePreviewDirtyRect(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> (originX: Int, originY: Int, width: Int, height: Int)? {
        guard !samples.isEmpty, canvasWidth > 0, canvasHeight > 0 else { return nil }
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        let scatterExtent = brush.scatterEnabled ? max(CGFloat(brush.scatterLateral), CGFloat(brush.scatterLinear)) : 0
        let softness = max(0, 1.0 - CGFloat(brush.hardness))
        let featherPadding = max(
            brush.tipKind == .airbrush ? CGFloat(brush.radius) * (0.9 + softness * 0.6) : CGFloat(brush.radius) * (0.35 + softness * 0.75),
            brush.tipKind == .airbrush ? 18.0 : 10.0
        )
        for sample in samples {
            let pressureFactor = max(0.1, 1.0 + ((sample.pressure - 1.0) * CGFloat(brush.pressureSensitivity)))
            let radiusPadding = max(CGFloat(brush.radius) * pressureFactor, 1.5)
                + (scatterExtent * CGFloat(brush.radius))
                + featherPadding
                + 6.0
            minX = min(minX, sample.point.x - radiusPadding)
            minY = min(minY, sample.point.y - radiusPadding)
            maxX = max(maxX, sample.point.x + radiusPadding)
            maxY = max(maxY, sample.point.y + radiusPadding)
        }
        guard minX.isFinite, minY.isFinite, maxX.isFinite, maxY.isFinite else { return nil }
        let originX = max(0, Int(floor(minX)))
        let originY = max(0, Int(floor(minY)))
        let maxRectX = min(canvasWidth - 1, Int(ceil(maxX)))
        let maxRectY = min(canvasHeight - 1, Int(ceil(maxY)))
        guard maxRectX >= originX, maxRectY >= originY else { return nil }
        return (originX, originY, maxRectX - originX + 1, maxRectY - originY + 1)
    }

    private static func makeStrokePrimitiveBinning(
        descriptors: [PrimoMetalStrokeSampleDescriptor],
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> StrokePrimitiveBinning? {
        guard !descriptors.isEmpty, dirtyRect.width > 0, dirtyRect.height > 0 else { return nil }
        let tileSize = 32
        let tileColumns = max(1, (dirtyRect.width + tileSize - 1) / tileSize)
        var tileBuckets = Array(repeating: [UInt32](), count: tileColumns * max(1, (dirtyRect.height + tileSize - 1) / tileSize))
        var primitives: [PrimoMetalStrokePrimitiveDescriptor] = []
        let scatterExtent = brush.scatterEnabled ? max(brush.scatterLateral, brush.scatterLinear) : 0.0
        let softness = max(0.0, 1.0 - brush.hardness)
        let primitiveSourceIndices = descriptors.count > 1 ? Array(descriptors.indices.dropLast()) : Array(descriptors.indices)
        for index in primitiveSourceIndices {
            let start = descriptors[index]
            let hasFollowing = index + 1 < descriptors.count
            let end = hasFollowing ? descriptors[index + 1] : start
            let startRadius = max(1.5, brush.radius * max(0.1, 1.0 + ((Double(start.pressure) - 1.0) * brush.pressureSensitivity)))
            let endRadius = max(1.5, brush.radius * max(0.1, 1.0 + ((Double(end.pressure) - 1.0) * brush.pressureSensitivity)))
            let maxRadius = max(startRadius, endRadius)
            let featherPadding = brush.tipKind == .airbrush
                ? max(18.0, maxRadius * (0.9 + softness * 0.6))
                : max(10.0, maxRadius * (0.35 + softness * 0.75))
            let oilSpread = brush.tipKind == .oil
                ? maxRadius * min(0.85, 0.24 + (brush.smudgeRadius * 1.45) + (brush.wetness * 0.35) + 0.18)
                : 0.0
            let padding = maxRadius + featherPadding + oilSpread + (scatterExtent * brush.radius) + 6.0
            let minX = min(Double(start.x), Double(end.x)) - padding
            let minY = min(Double(start.y), Double(end.y)) - padding
            let maxX = max(Double(start.x), Double(end.x)) + padding
            let maxY = max(Double(start.y), Double(end.y)) + padding
            let clampedMinX = max(Double(dirtyRect.originX), minX)
            let clampedMinY = max(Double(dirtyRect.originY), minY)
            let clampedMaxX = min(Double(dirtyRect.originX + dirtyRect.width - 1), maxX)
            let clampedMaxY = min(Double(dirtyRect.originY + dirtyRect.height - 1), maxY)
            guard clampedMinX <= clampedMaxX, clampedMinY <= clampedMaxY else { continue }
            let primitiveIndex = UInt32(primitives.count)
            primitives.append(
                PrimoMetalStrokePrimitiveDescriptor(
                    startX: start.x,
                    startY: start.y,
                    endX: end.x,
                    endY: end.y,
                    startPressure: start.pressure,
                    endPressure: end.pressure,
                    startProgress: start.progress,
                    endProgress: end.progress,
                    maxRadius: Float(maxRadius),
                    isSegment: hasFollowing ? 1 : 0,
                    padding0: 0,
                    padding1: 0
                )
            )
            let tileMinX = max(0, Int((clampedMinX - Double(dirtyRect.originX)) / Double(tileSize)))
            let tileMinY = max(0, Int((clampedMinY - Double(dirtyRect.originY)) / Double(tileSize)))
            let tileMaxX = min(tileColumns - 1, Int((clampedMaxX - Double(dirtyRect.originX)) / Double(tileSize)))
            let tileMaxY = min(max(1, (dirtyRect.height + tileSize - 1) / tileSize) - 1, Int((clampedMaxY - Double(dirtyRect.originY)) / Double(tileSize)))
            for tileY in tileMinY...tileMaxY {
                for tileX in tileMinX...tileMaxX {
                    tileBuckets[(tileY * tileColumns) + tileX].append(primitiveIndex)
                }
            }
        }
        guard !primitives.isEmpty else { return nil }
        var tileRanges: [PrimoMetalStrokeTileRangeDescriptor] = []
        var primitiveIndices: [UInt32] = []
        tileRanges.reserveCapacity(tileBuckets.count)
        var cursor: UInt32 = 0
        for bucket in tileBuckets {
            tileRanges.append(PrimoMetalStrokeTileRangeDescriptor(startIndex: cursor, primitiveCount: UInt32(bucket.count)))
            primitiveIndices.append(contentsOf: bucket)
            cursor += UInt32(bucket.count)
        }
        return StrokePrimitiveBinning(
            dirtyRect: dirtyRect,
            tileSize: tileSize,
            tileColumns: tileColumns,
            primitives: primitives,
            tileRanges: tileRanges,
            primitiveIndices: primitiveIndices
        )
    }

    private static func makeStrokeBrushDescriptor(_ brush: BrushRuntimeSettings, customTip: BrushTipRaster) -> PrimoMetalStrokeBrushDescriptor {
        let profile = strokeRasterProfile(for: brush)
        return PrimoMetalStrokeBrushDescriptor(
            radius: Float(brush.radius),
            pressureSensitivity: Float(brush.pressureSensitivity),
            taperIn: Float(brush.taperIn),
            taperOut: Float(brush.taperOut),
            opacity: Float(brush.opacity),
            flow: Float(brush.flow),
            hardness: Float(brush.hardness),
            opacityPressureSensitivity: Float(brush.opacityPressureSensitivity),
            flowPressureSensitivity: Float(brush.flowPressureSensitivity),
            grainScale: Float(brush.grainScale),
            grainContrast: Float(brush.grainContrast),
            paperScale: Float(brush.paperScale),
            paperStrength: Float(brush.paperStrength),
            paperThreshold: Float(brush.paperThreshold),
            textureStrength: Float(brush.textureStrength),
            wetness: profile.wetness,
            colorMixStrength: profile.colorMixStrength,
            smudgeBleed: profile.smudgeBleed,
            smudgeRadius: profile.smudgeRadius,
            paintLoad: profile.paintLoad,
            red: Float(brush.red) / 255.0,
            green: Float(brush.green) / 255.0,
            blue: Float(brush.blue) / 255.0,
            scatterLateral: Float(brush.scatterEnabled ? brush.scatterLateral : 0),
            scatterLinear: Float(brush.scatterEnabled ? brush.scatterLinear : 0),
            dualScale: Float(brush.dualBrushEnabled ? brush.dualScale : 0),
            dualSpacing: Float(brush.dualBrushEnabled ? brush.dualSpacing : 0),
            dualScatter: Float(brush.dualBrushEnabled ? brush.dualScatter : 0),
            customTipWidth: UInt32(customTip.width),
            customTipHeight: UInt32(customTip.height),
            isEraser: brush.isEraser ? 1 : 0,
            isPencil: brush.tipKind == .pencil ? 1 : 0,
            isOil: brush.tipKind == .oil ? 1 : 0,
            isAirbrush: brush.tipKind == .airbrush ? 1 : 0,
            dualBrushEnabled: brush.dualBrushEnabled ? 1 : 0,
            customTipEnabled: brush.customTip == nil ? 0 : 1,
            scatterMode: brush.scatterMode == .spray ? 1 : 0,
            textureMode: {
                switch brush.textureMode {
                case .off: return 0
                case .strokeLocked: return 1
                case .eachTip: return 2
                case .moving: return 3
                }
            }(),
            dualBlendMode: {
                switch brush.dualBlendMode {
                case .multiply: return 0
                case .darker: return 1
                case .subtract: return 2
                }
            }(),
            colorMixingMode: {
                switch brush.colorMixingMode {
                case .off: return 0
                case .blend: return 1
                case .runningColor: return 2
                case .smear: return 3
                }
            }()
        )
    }

    private static func supportsStrokeRasterization(_ brush: BrushRuntimeSettings) -> Bool {
        guard brush.radius >= 0.5 else { return false }
        let isOil = brush.tipKind == .oil
        if brush.dualBrushEnabled,
           ((isOil ? brush.dualScale > 2.6 : brush.dualScale > 1.8) ||
            (isOil ? brush.dualScatter > 2.2 : brush.dualScatter > 1.6) ||
            (!isOil && brush.count > 1) ||
            (!isOil && brush.countJitter > 0.001)) {
            return false
        }
        if brush.scatterEnabled,
           ((!isOil && brush.count > 1) ||
            (!isOil && brush.countJitter > 0.001) ||
            brush.scatterLateral > brush.radius * (isOil ? 2.1 : 1.35) ||
            brush.scatterLinear > brush.radius * (isOil ? 2.1 : 1.35)) {
            return false
        }
        if brush.tipKind == .airbrush, brush.colorMixingMode == .runningColor || brush.smudgeBleed > 0.001 {
            return false
        }
        if brush.textureMode == .moving && brush.tipKind == .oil && brush.textureStrength > 0.98 {
            return false
        }
        return true
    }

    private static func makeCustomTipMask(_ raster: BrushTipRaster?) -> BrushTipRaster {
        guard let raster else { return BrushTipRaster(width: 1, height: 1, alphaData: Data([255])) }
        guard raster.width > 0, raster.height > 0, raster.alphaData.count == raster.width * raster.height else {
            return BrushTipRaster(width: 1, height: 1, alphaData: Data([255]))
        }
        let maxDimension = 64
        if max(raster.width, raster.height) <= maxDimension { return raster }
        let scale = min(Double(maxDimension) / Double(raster.width), Double(maxDimension) / Double(raster.height))
        let targetWidth = max(1, Int((Double(raster.width) * scale).rounded(.toNearestOrEven)))
        let targetHeight = max(1, Int((Double(raster.height) * scale).rounded(.toNearestOrEven)))
        var output = [UInt8](repeating: 0, count: targetWidth * targetHeight)
        raster.alphaData.withUnsafeBytes { sourceBytes in
            guard let source = sourceBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<targetHeight {
                let sourceY0 = Int((Double(y) * Double(raster.height) / Double(targetHeight)).rounded(.down))
                let sourceY1 = max(sourceY0 + 1, Int((Double(y + 1) * Double(raster.height) / Double(targetHeight)).rounded(.up)))
                for x in 0..<targetWidth {
                    let sourceX0 = Int((Double(x) * Double(raster.width) / Double(targetWidth)).rounded(.down))
                    let sourceX1 = max(sourceX0 + 1, Int((Double(x + 1) * Double(raster.width) / Double(targetWidth)).rounded(.up)))
                    var total = 0
                    var count = 0
                    for sampleY in sourceY0..<min(sourceY1, raster.height) {
                        for sampleX in sourceX0..<min(sourceX1, raster.width) {
                            total += Int(source[(sampleY * raster.width) + sampleX])
                            count += 1
                        }
                    }
                    output[(y * targetWidth) + x] = UInt8(max(0, min(255, count > 0 ? total / count : 0)))
                }
            }
        }
        return BrushTipRaster(width: targetWidth, height: targetHeight, alphaData: Data(output))
    }

    private static func strokeRasterProfile(for brush: BrushRuntimeSettings) -> (wetness: Float, colorMixStrength: Float, smudgeBleed: Float, smudgeRadius: Float, paintLoad: Float) {
        switch brush.tipKind {
        case .pencil:
            return (0, 0, 0, 0, 1)
        case .ink:
            return (
                Float(min(max(brush.wetness * 0.35, 0), 0.22)),
                Float(min(max(brush.colorMixStrength * 0.28, 0), 0.18)),
                Float(min(max(brush.smudgeBleed * 0.22, 0), 0.16)),
                Float(min(max(brush.smudgeRadius * 0.20, 0), 0.18)),
                Float(max(0.82, min(brush.paintLoad, 1.0)))
            )
        case .oil:
            return (
                Float(min(max((brush.wetness * 0.88) + 0.08, 0), 1)),
                Float(min(max((brush.colorMixStrength * 0.92) + 0.06, 0), 1)),
                Float(min(max((brush.smudgeBleed * 0.78) + 0.08, 0), 1)),
                Float(min(max((brush.smudgeRadius * 0.82) + 0.06, 0), 1)),
                Float(min(max((brush.paintLoad * 0.90) + 0.05, 0.08), 1))
            )
        case .airbrush:
            return (
                Float(min(max(brush.wetness * 0.16, 0), 0.12)),
                Float(min(max(brush.colorMixStrength * 0.12, 0), 0.10)),
                0,
                Float(min(max(brush.smudgeRadius * 0.08, 0), 0.08)),
                Float(max(0.88, min(brush.paintLoad, 1.0)))
            )
        }
    }

    private static func blendModeIdentifier(_ mode: LayerBlendMode) -> Int {
        switch mode {
        case .normal: return 0
        case .darken: return 1
        case .multiply: return 2
        case .colorBurn: return 3
        case .linearBurn: return 4
        case .subtract: return 5
        case .lighten: return 6
        case .screen: return 7
        case .colorDodge: return 8
        case .glowDodge: return 9
        case .overlay: return 10
        case .softLight: return 11
        case .hardLight: return 12
        case .difference: return 13
        case .vividLight: return 14
        case .linearLight: return 15
        case .pinLight: return 16
        case .hardMix: return 17
        case .exclusion: return 18
        case .darkerColor: return 19
        case .lighterColor: return 20
        case .divide: return 21
        case .hue: return 22
        case .saturation: return 23
        case .color: return 24
        case .add: return 25
        case .addGlow: return 26
        case .luminosity: return 27
        }
    }
}
