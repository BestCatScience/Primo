import CoreGraphics
import Foundation
import Metal
import os

private struct MetalCompositeLayerDescriptor {
    let documentIndex: Int32
    let opacity: Float
    let visible: UInt32
    let isClipped: UInt32
    let blendMode: Int32
}

private struct MetalCompositeRequestDescriptor {
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

private struct MetalMaskKernelDescriptor {
    let width: UInt32
    let height: UInt32
    let radius: UInt32
}

private struct MetalColorRangeSelectionDescriptor {
    let width: UInt32
    let height: UInt32
    let red: UInt32
    let green: UInt32
    let blue: UInt32
    let tolerance: Float
    let minimumAlpha: Float
}

private struct MetalBufferPair {
    var current: MTLBuffer
    var scratch: MTLBuffer
}

final class MetalDocumentProcessingClient {
    static let shared = MetalDocumentProcessingClient()

    private struct SnapshotTextureSignature: Equatable {
        let revision: Int
        let width: Int
        let height: Int
        let layerIndices: [Int]
    }

    private static let logger = Logger(subsystem: "com.primo.app", category: "MetalDocumentProcessing")

    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let library: MTLLibrary?
    private let compositePipeline: MTLComputePipelineState?
    private let invertMaskPipeline: MTLComputePipelineState?
    private let dilateMaskPipeline: MTLComputePipelineState?
    private let erodeMaskPipeline: MTLComputePipelineState?
    private let featherHorizontalPipeline: MTLComputePipelineState?
    private let featherVerticalPipeline: MTLComputePipelineState?
    private let colorRangePipeline: MTLComputePipelineState?

    private var cachedSignature: SnapshotTextureSignature?
    private var cachedLayerTexture: MTLTexture?

    private init() {
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        self.library = device?.makeDefaultLibrary()
        self.compositePipeline = Self.makePipeline(device: device, library: library, functionName: "compositePreviewKernel")
        self.invertMaskPipeline = Self.makePipeline(device: device, library: library, functionName: "invertMaskKernel")
        self.dilateMaskPipeline = Self.makePipeline(device: device, library: library, functionName: "dilateMaskKernel")
        self.erodeMaskPipeline = Self.makePipeline(device: device, library: library, functionName: "erodeMaskKernel")
        self.featherHorizontalPipeline = Self.makePipeline(device: device, library: library, functionName: "featherHorizontalKernel")
        self.featherVerticalPipeline = Self.makePipeline(device: device, library: library, functionName: "featherVerticalKernel")
        self.colorRangePipeline = Self.makePipeline(device: device, library: library, functionName: "colorRangeSelectionKernel")
    }

    var isAvailable: Bool {
        device != nil &&
        commandQueue != nil &&
        compositePipeline != nil &&
        invertMaskPipeline != nil &&
        dilateMaskPipeline != nil &&
        erodeMaskPipeline != nil &&
        featherHorizontalPipeline != nil &&
        featherVerticalPipeline != nil &&
        colorRangePipeline != nil
    }

    func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        compose(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: nil
        )
    }

    func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        guard let pixelData = compose(
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

    func invertMask(_ source: [UInt8]) -> [UInt8]? {
        mutateMask(source, pipeline: invertMaskPipeline, radius: 0)
    }

    func expandedMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8]? {
        iterateMask(source, width: width, height: height, iterations: expansion, pipeline: dilateMaskPipeline)
    }

    func contractedMask(_ source: [UInt8], width: Int, height: Int, contraction: Int) -> [UInt8]? {
        iterateMask(source, width: width, height: height, iterations: contraction, pipeline: erodeMaskPipeline)
    }

    func featheredMask(_ source: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8]? {
        guard radius > 0 else { return source }
        guard
            let device,
            let commandQueue,
            let horizontalPipeline = featherHorizontalPipeline,
            let verticalPipeline = featherVerticalPipeline,
            let sourceBuffer = makeBuffer(source),
            let temporary = device.makeBuffer(length: source.count * MemoryLayout<Float>.stride, options: .storageModeShared),
            let outputBuffer = device.makeBuffer(length: source.count, options: .storageModeShared),
            let requestBuffer = makeBuffer(
                MetalMaskKernelDescriptor(
                    width: UInt32(width),
                    height: UInt32(height),
                    radius: UInt32(radius)
                )
            )
        else {
            return nil
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
        guard
            let horizontalEncoder = commandBuffer.makeComputeCommandEncoder(),
            let verticalEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        horizontalEncoder.setComputePipelineState(horizontalPipeline)
        horizontalEncoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        horizontalEncoder.setBuffer(temporary, offset: 0, index: 1)
        horizontalEncoder.setBuffer(requestBuffer, offset: 0, index: 2)
        dispatch2D(encoder: horizontalEncoder, pipeline: horizontalPipeline, width: width, height: height)
        horizontalEncoder.endEncoding()

        verticalEncoder.setComputePipelineState(verticalPipeline)
        verticalEncoder.setBuffer(temporary, offset: 0, index: 0)
        verticalEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        verticalEncoder.setBuffer(requestBuffer, offset: 0, index: 2)
        dispatch2D(encoder: verticalEncoder, pipeline: verticalPipeline, width: width, height: height)
        verticalEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: source.count)
    }

    func colorRangeSelection(
        pixelData: Data,
        width: Int,
        height: Int,
        request: ColorRangeSelectionRequest
    ) -> [UInt8]? {
        guard
            let commandQueue,
            let pipeline = colorRangePipeline,
            let pixelBuffer = makeBuffer(pixelData),
            let outputBuffer = device?.makeBuffer(length: width * height, options: .storageModeShared),
            let requestBuffer = makeBuffer(
                MetalColorRangeSelectionDescriptor(
                    width: UInt32(width),
                    height: UInt32(height),
                    red: UInt32(request.red),
                    green: UInt32(request.green),
                    blue: UInt32(request.blue),
                    tolerance: Float(min(max(request.tolerance, 0.0), 1.0)),
                    minimumAlpha: Float(min(max(request.minimumAlpha, 0.0), 1.0))
                )
            )
        else {
            return nil
        }

        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(pixelBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(requestBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: width * height)
    }

    private func compose(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?
    ) -> Data? {
        guard isAvailable, snapshot.width > 0, snapshot.height > 0 else { return nil }
        let orderedLayers = snapshot.layers.sorted(by: { $0.index < $1.index })
        guard adjustedActiveLayerPixels.count == snapshot.width * snapshot.height * 4 else { return nil }

        guard
            let layerTexture = rebuildLayerTextureIfNeeded(snapshot: snapshot, orderedLayers: orderedLayers),
            let commandQueue,
            let pipeline = compositePipeline,
            let layerBuffer = makeBuffer(orderedLayers.map(Self.makeLayerDescriptor(for:))),
            let overrideBuffer = makeBuffer(adjustedActiveLayerPixels),
            let requestBuffer = makeBuffer(makeCompositeRequest(snapshot: snapshot, orderedLayers: orderedLayers, activeLayerIndex: activeLayerIndex, dirtyRect: dirtyRect))
        else {
            return nil
        }

        let outputWidth = dirtyRect?.width ?? snapshot.width
        let outputHeight = dirtyRect?.height ?? snapshot.height
        guard let outputBuffer = device?.makeBuffer(length: outputWidth * outputHeight * 4, options: .storageModeShared) else {
            return nil
        }

        let clock = ContinuousClock()
        let start = clock.now

        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

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

        guard commandBuffer.status == .completed else {
            Self.logger.error("Metal composite command buffer failed with status \(commandBuffer.status.rawValue)")
            return nil
        }

        let duration = start.duration(to: clock.now)
        AppDiagnostics.debug(Self.logger, "Composite preview via Metal completed in \(String(describing: duration))")
        return bytes(from: outputBuffer, count: outputWidth * outputHeight * 4)
    }

    private func mutateMask(_ source: [UInt8], pipeline: MTLComputePipelineState?, radius: Int) -> [UInt8]? {
        guard
            let commandQueue,
            let pipeline,
            let inputBuffer = makeBuffer(source),
            let outputBuffer = device?.makeBuffer(length: source.count, options: .storageModeShared),
            let requestBuffer = makeBuffer(
                MetalMaskKernelDescriptor(
                    width: UInt32(source.isEmpty ? 0 : source.count),
                    height: 1,
                    radius: UInt32(radius)
                )
            )
        else {
            return nil
        }

        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(requestBuffer, offset: 0, index: 2)
        dispatchLinear(encoder: encoder, pipeline: pipeline, count: source.count)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: source.count)
    }

    private func iterateMask(
        _ source: [UInt8],
        width: Int,
        height: Int,
        iterations: Int,
        pipeline: MTLComputePipelineState?
    ) -> [UInt8]? {
        guard iterations > 0 else { return source }
        guard
            let device,
            let commandQueue,
            let pipeline,
            let first = makeBuffer(source),
            let second = device.makeBuffer(length: source.count, options: .storageModeShared),
            let requestBuffer = makeBuffer(
                MetalMaskKernelDescriptor(
                    width: UInt32(width),
                    height: UInt32(height),
                    radius: 1
                )
            )
        else {
            return nil
        }

        var buffers = MetalBufferPair(current: first, scratch: second)
        for _ in 0..<iterations {
            guard
                let commandBuffer = commandQueue.makeCommandBuffer(),
                let encoder = commandBuffer.makeComputeCommandEncoder()
            else {
                return nil
            }

            encoder.setComputePipelineState(pipeline)
            encoder.setBuffer(buffers.current, offset: 0, index: 0)
            encoder.setBuffer(buffers.scratch, offset: 0, index: 1)
            encoder.setBuffer(requestBuffer, offset: 0, index: 2)
            dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
            encoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            guard commandBuffer.status == .completed else { return nil }
            swap(&buffers.current, &buffers.scratch)
        }
        return bytes(from: buffers.current, count: source.count)
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

    private func makeCompositeRequest(
        snapshot: MetalDocumentSnapshot,
        orderedLayers: [MetalLayerSnapshot],
        activeLayerIndex: Int,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?
    ) -> MetalCompositeRequestDescriptor {
        MetalCompositeRequestDescriptor(
            canvasWidth: UInt32(snapshot.width),
            canvasHeight: UInt32(snapshot.height),
            originX: UInt32(dirtyRect?.originX ?? 0),
            originY: UInt32(dirtyRect?.originY ?? 0),
            outputWidth: UInt32(dirtyRect?.width ?? snapshot.width),
            outputHeight: UInt32(dirtyRect?.height ?? snapshot.height),
            layerCount: UInt32(orderedLayers.count),
            activeLayerIndex: Int32(activeLayerIndex),
            hasActiveLayerOverride: 1,
            includeActiveLayerWhenHidden: dirtyRect == nil ? 0 : 1
        )
    }

    private func makeBuffer<T>(_ values: [T]) -> MTLBuffer? {
        guard !values.isEmpty else { return device?.makeBuffer(length: MemoryLayout<T>.stride, options: .storageModeShared) }
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

    private func makeBuffer(_ values: [UInt8]) -> MTLBuffer? {
        values.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device?.makeBuffer(bytes: baseAddress, length: values.count, options: .storageModeShared)
        }
    }

    private func bytes(from buffer: MTLBuffer, count: Int) -> [UInt8] {
        Array(UnsafeBufferPointer(start: buffer.contents().assumingMemoryBound(to: UInt8.self), count: count))
    }

    private func bytes(from buffer: MTLBuffer, count: Int) -> Data {
        Data(bytes: buffer.contents(), count: count)
    }

    private func dispatch2D(
        encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        width: Int,
        height: Int
    ) {
        let threadWidth = min(pipeline.threadExecutionWidth, max(width, 1))
        let threadHeight = max(1, min(pipeline.maxTotalThreadsPerThreadgroup / max(threadWidth, 1), 8))
        let threadsPerThreadgroup = MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        let threadsPerGrid = MTLSize(width: max(width, 1), height: max(height, 1), depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    private func dispatchLinear(
        encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        count: Int
    ) {
        let width = max(1, min(pipeline.threadExecutionWidth, count))
        let threadsPerThreadgroup = MTLSize(width: width, height: 1, depth: 1)
        let threadsPerGrid = MTLSize(width: max(count, 1), height: 1, depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    private static func makePipeline(device: MTLDevice?, library: MTLLibrary?, functionName: String) -> MTLComputePipelineState? {
        guard let device, let function = library?.makeFunction(name: functionName) else { return nil }
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            return nil
        }
    }

    private static func makeLayerDescriptor(for layer: MetalLayerSnapshot) -> MetalCompositeLayerDescriptor {
        MetalCompositeLayerDescriptor(
            documentIndex: Int32(layer.index),
            opacity: layer.opacity,
            visible: layer.visible ? 1 : 0,
            isClipped: layer.isClipped ? 1 : 0,
            blendMode: Int32(blendModeIdentifier(layer.blendMode))
        )
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

extension AppFeature {
    static func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        MetalDocumentProcessingClient.shared.compositedPreviewPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        ) ?? cpuCompositedPreviewPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    static func strokePreviewDirtyRect(
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
            let pressureFactor = max(
                0.1,
                1.0 + ((sample.pressure - 1.0) * CGFloat(brush.pressureSensitivity))
            )
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
        return (
            originX: originX,
            originY: originY,
            width: maxRectX - originX + 1,
            height: maxRectY - originY + 1
        )
    }

    static func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        MetalDocumentProcessingClient.shared.compositedPreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
        ) ?? cpuCompositedPreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
        )
    }

    static func shouldUseIncrementalPreviewUpdate(for brush: BrushRuntimeSettings) -> Bool {
        let scatterExtent = brush.scatterEnabled ? max(CGFloat(brush.scatterLateral), CGFloat(brush.scatterLinear)) : 0
        let effectiveDiameter = (CGFloat(brush.radius) * 2.0) * (1.0 + scatterExtent)
        let softness = 1.0 - CGFloat(brush.hardness)

        if brush.tipKind == .airbrush && effectiveDiameter >= 42 {
            return false
        }
        if softness >= 0.34 && effectiveDiameter >= 56 {
            return false
        }
        return true
    }

    static func cpuCompositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        guard adjustedActiveLayerPixels.count == snapshot.width * snapshot.height * 4 else { return nil }

        var composite = Data(count: snapshot.width * snapshot.height * 4)
        var clipMask = [CGFloat](repeating: 0, count: snapshot.width * snapshot.height)
        composite.withUnsafeMutableBytes { destinationBytes in
            guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for layer in snapshot.layers.sorted(by: { $0.index < $1.index }) where layer.visible {
                let sourceData = layer.index == activeLayerIndex ? adjustedActiveLayerPixels : layer.pixelData
                sourceData.withUnsafeBytes { sourceBytes in
                    guard let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    for pixelIndex in 0..<(snapshot.width * snapshot.height) {
                        let offset = pixelIndex * 4
                        let baseAlpha = (CGFloat(source[offset + 3]) / 255.0) * CGFloat(layer.opacity)
                        let effectiveOpacity = layer.isClipped
                            ? (CGFloat(layer.opacity) * clipMask[pixelIndex])
                            : CGFloat(layer.opacity)
                        if !layer.isClipped {
                            clipMask[pixelIndex] = baseAlpha
                        }
                        blendPreviewPixel(
                            destination: destination + offset,
                            source: source + offset,
                            opacity: effectiveOpacity,
                            blendMode: layer.blendMode
                        )
                    }
                }
            }
        }
        return composite
    }

    static func cpuCompositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        guard adjustedActiveLayerPixels.count == snapshot.width * snapshot.height * 4 else { return nil }
        guard dirtyRect.width > 0, dirtyRect.height > 0 else { return nil }

        let rectDataCount = dirtyRect.width * dirtyRect.height * 4
        var composite = Data(count: rectDataCount)
        var clipMask = [CGFloat](repeating: 0, count: dirtyRect.width * dirtyRect.height)
        composite.withUnsafeMutableBytes { destinationBytes in
            guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for layer in snapshot.layers.sorted(by: { $0.index < $1.index }) {
                let isActiveLayer = layer.index == activeLayerIndex
                guard isActiveLayer || layer.visible else { continue }
                let sourceData = isActiveLayer ? adjustedActiveLayerPixels : layer.pixelData
                sourceData.withUnsafeBytes { sourceBytes in
                    guard let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    for localY in 0..<dirtyRect.height {
                        let sourceY = dirtyRect.originY + localY
                        for localX in 0..<dirtyRect.width {
                            let sourceX = dirtyRect.originX + localX
                            let sourceOffset = ((sourceY * snapshot.width) + sourceX) * 4
                            let destinationOffset = ((localY * dirtyRect.width) + localX) * 4
                            let maskIndex = (localY * dirtyRect.width) + localX
                            let baseAlpha = (CGFloat(source[sourceOffset + 3]) / 255.0) * CGFloat(layer.opacity)
                            let effectiveOpacity = layer.isClipped
                                ? (CGFloat(layer.opacity) * clipMask[maskIndex])
                                : CGFloat(layer.opacity)
                            if !layer.isClipped {
                                clipMask[maskIndex] = baseAlpha
                            }
                            blendPreviewPixel(
                                destination: destination + destinationOffset,
                                source: source + sourceOffset,
                                opacity: effectiveOpacity,
                                blendMode: layer.blendMode
                            )
                        }
                    }
                }
            }
        }

        return IncrementalLayerUpdate(
            layerIndex: -1,
            originX: dirtyRect.originX,
            originY: dirtyRect.originY,
            width: dirtyRect.width,
            height: dirtyRect.height,
            pixelData: composite
        )
    }

    static func blendPreviewPixel(
        destination: UnsafeMutablePointer<UInt8>,
        source: UnsafePointer<UInt8>,
        opacity: CGFloat,
        blendMode: LayerBlendMode
    ) {
        let srcAlpha = (CGFloat(source[3]) / 255.0) * opacity
        guard srcAlpha > 0.001 else { return }
        let dstAlpha = CGFloat(destination[3]) / 255.0
        let outAlpha = srcAlpha + (dstAlpha * (1 - srcAlpha))
        guard outAlpha > 0.001 else { return }

        let srcR = CGFloat(source[0]) / 255.0
        let srcG = CGFloat(source[1]) / 255.0
        let srcB = CGFloat(source[2]) / 255.0
        let dstR = CGFloat(destination[0]) / 255.0
        let dstG = CGFloat(destination[1]) / 255.0
        let dstB = CGFloat(destination[2]) / 255.0
        let blended = blendedPreviewColor(
            backdrop: (dstR, dstG, dstB),
            source: (srcR, srcG, srcB),
            blendMode: blendMode
        )

        let outR = (
            srcAlpha * ((1 - dstAlpha) * srcR + (dstAlpha * blended.r)) +
            (dstAlpha * (1 - srcAlpha) * dstR)
        ) / outAlpha
        let outG = (
            srcAlpha * ((1 - dstAlpha) * srcG + (dstAlpha * blended.g)) +
            (dstAlpha * (1 - srcAlpha) * dstG)
        ) / outAlpha
        let outB = (
            srcAlpha * ((1 - dstAlpha) * srcB + (dstAlpha * blended.b)) +
            (dstAlpha * (1 - srcAlpha) * dstB)
        ) / outAlpha

        destination[0] = UInt8(max(0, min(255, Int((outR * 255.0).rounded()))))
        destination[1] = UInt8(max(0, min(255, Int((outG * 255.0).rounded()))))
        destination[2] = UInt8(max(0, min(255, Int((outB * 255.0).rounded()))))
        destination[3] = UInt8(max(0, min(255, Int((outAlpha * 255.0).rounded()))))
    }

    static func blendedPreviewColor(
        backdrop: (r: CGFloat, g: CGFloat, b: CGFloat),
        source: (r: CGFloat, g: CGFloat, b: CGFloat),
        blendMode: LayerBlendMode
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        if blendMode == .darkerColor {
            return previewLuminosity(source) < previewLuminosity(backdrop) ? source : backdrop
        }
        if blendMode == .lighterColor {
            return previewLuminosity(source) > previewLuminosity(backdrop) ? source : backdrop
        }
        if blendMode == .hue {
            var output = source
            output = previewSetSaturation(output, previewSaturation(backdrop))
            output = previewSetLuminosity(output, previewLuminosity(backdrop))
            return previewClamped(output)
        }
        if blendMode == .saturation {
            var output = backdrop
            output = previewSetSaturation(output, previewSaturation(source))
            output = previewSetLuminosity(output, previewLuminosity(backdrop))
            return previewClamped(output)
        }
        if blendMode == .color {
            var output = source
            output = previewSetSaturation(output, previewSaturation(source))
            output = previewSetLuminosity(output, previewLuminosity(backdrop))
            return previewClamped(output)
        }
        if blendMode == .luminosity {
            var output = backdrop
            output = previewSetLuminosity(output, previewLuminosity(source))
            return previewClamped(output)
        }

        return (
            r: max(0, min(1, previewBlendChannel(backdrop: backdrop.r, source: source.r, blendMode: blendMode))),
            g: max(0, min(1, previewBlendChannel(backdrop: backdrop.g, source: source.g, blendMode: blendMode))),
            b: max(0, min(1, previewBlendChannel(backdrop: backdrop.b, source: source.b, blendMode: blendMode)))
        )
    }

    static func previewBlendChannel(backdrop: CGFloat, source: CGFloat, blendMode: LayerBlendMode) -> CGFloat {
        switch blendMode {
        case .normal:
            return source
        case .darken:
            return min(backdrop, source)
        case .multiply:
            return backdrop * source
        case .colorBurn:
            return source <= 0 ? 0 : max(0, 1 - ((1 - backdrop) / max(0.001, source)))
        case .linearBurn:
            return max(0, backdrop + source - 1)
        case .subtract:
            return max(0, backdrop - source)
        case .lighten:
            return max(backdrop, source)
        case .screen:
            return 1 - ((1 - backdrop) * (1 - source))
        case .add:
            return min(1, backdrop + source)
        case .colorDodge:
            return source >= 1 ? 1 : min(1, backdrop / max(0.001, 1 - source))
        case .glowDodge:
            return source >= 1 ? 1 : min(1, backdrop / max(0.0005, 1 - (source * 0.92)))
        case .overlay:
            return backdrop <= 0.5 ? (2 * backdrop * source) : (1 - 2 * (1 - backdrop) * (1 - source))
        case .softLight:
            return source <= 0.5
                ? (backdrop - ((1 - 2 * source) * backdrop * (1 - backdrop)))
                : (backdrop + ((2 * source - 1) * ((backdrop <= 0.25)
                    ? ((((16 * backdrop - 12) * backdrop) + 4) * backdrop)
                    : sqrt(backdrop)) - backdrop))
        case .hardLight:
            return source <= 0.5 ? (2 * backdrop * source) : (1 - 2 * (1 - backdrop) * (1 - source))
        case .difference:
            return abs(backdrop - source)
        case .vividLight:
            return source <= 0.5
                ? (1 - ((1 - backdrop) / max(0.001, 2 * source)))
                : (backdrop / max(0.001, 2 * (1 - source)))
        case .linearLight:
            return max(0, min(1, backdrop + (2 * source) - 1))
        case .pinLight:
            return source > 0.5 ? max(backdrop, 2 * (source - 0.5)) : min(backdrop, 2 * source)
        case .hardMix:
            return previewBlendChannel(backdrop: backdrop, source: source, blendMode: .vividLight) < 0.5 ? 0 : 1
        case .exclusion:
            return backdrop + source - (2 * backdrop * source)
        case .divide:
            return source <= 0.001 ? 1 : min(1, backdrop / source)
        case .addGlow:
            return min(1, backdrop + (source * 1.15))
        case .darkerColor, .lighterColor, .hue, .saturation, .color, .luminosity:
            return source
        }
    }

    static func previewLuminosity(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        (0.3 * color.r) + (0.59 * color.g) + (0.11 * color.b)
    }

    static func previewSaturation(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b))
    }

    static func previewSetLuminosity(_ color: (r: CGFloat, g: CGFloat, b: CGFloat), _ luminosity: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let delta = luminosity - previewLuminosity(color)
        return previewClipColor((color.r + delta, color.g + delta, color.b + delta))
    }

    static func previewSetSaturation(_ color: (r: CGFloat, g: CGFloat, b: CGFloat), _ saturation: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var components = [color.r, color.g, color.b]
        let minValue = components.min() ?? 0
        let maxValue = components.max() ?? 0
        guard maxValue > minValue else { return (0, 0, 0) }

        for index in components.indices {
            components[index] = ((components[index] - minValue) * saturation) / (maxValue - minValue)
        }

        let updatedMin = components.min() ?? 0
        let updatedMax = components.max() ?? 1
        guard updatedMax > updatedMin else { return (0, 0, 0) }

        for index in components.indices {
            components[index] = (components[index] - updatedMin) / (updatedMax - updatedMin) * saturation
        }

        return previewClipColor((components[0], components[1], components[2]))
    }

    static func previewClipColor(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let luminosity = previewLuminosity(color)
        let minValue = min(color.r, min(color.g, color.b))
        let maxValue = max(color.r, max(color.g, color.b))
        var result = color

        if minValue < 0 {
            result.r = luminosity + (((result.r - luminosity) * luminosity) / (luminosity - minValue))
            result.g = luminosity + (((result.g - luminosity) * luminosity) / (luminosity - minValue))
            result.b = luminosity + (((result.b - luminosity) * luminosity) / (luminosity - minValue))
        }
        if maxValue > 1 {
            result.r = luminosity + (((result.r - luminosity) * (1 - luminosity)) / (maxValue - luminosity))
            result.g = luminosity + (((result.g - luminosity) * (1 - luminosity)) / (maxValue - luminosity))
            result.b = luminosity + (((result.b - luminosity) * (1 - luminosity)) / (maxValue - luminosity))
        }

        return previewClamped(result)
    }

    static func previewClamped(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        (
            r: max(0, min(1, color.r)),
            g: max(0, min(1, color.g)),
            b: max(0, min(1, color.b))
        )
    }
}
