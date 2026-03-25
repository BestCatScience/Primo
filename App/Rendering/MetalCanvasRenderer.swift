import Foundation
import Metal
import MetalKit
import AVFoundation
import os
import simd

private struct MetalQuadVertex {
    var position: SIMD2<Float>
    var uv: SIMD2<Float>
}

private struct MetalQuadUniforms {
    var origin: SIMD2<Float>
    var size: SIMD2<Float>
    var viewport: SIMD2<Float>
    var opacity: Float
    var paperSeed: Float
}

private enum MetalCanvasRendererCache {
    static let shared = Resources()

    final class Resources {
        let device: MTLDevice?
        let commandQueue: MTLCommandQueue?
        let layerPipeline: MTLRenderPipelineState?
        let paperPipeline: MTLRenderPipelineState?
        let vertexBuffer: MTLBuffer?

        init() {
            let metalDevice = MTLCreateSystemDefaultDevice()
            self.device = metalDevice
            self.commandQueue = metalDevice?.makeCommandQueue()

            if let metalDevice {
                self.vertexBuffer = metalDevice.makeBuffer(bytes: [
                    MetalQuadVertex(position: SIMD2<Float>(0, 0), uv: SIMD2<Float>(0, 1)),
                    MetalQuadVertex(position: SIMD2<Float>(1, 0), uv: SIMD2<Float>(1, 1)),
                    MetalQuadVertex(position: SIMD2<Float>(0, 1), uv: SIMD2<Float>(0, 0)),
                    MetalQuadVertex(position: SIMD2<Float>(1, 1), uv: SIMD2<Float>(1, 0))
                ], length: MemoryLayout<MetalQuadVertex>.stride * 4)

                let library = metalDevice.makeDefaultLibrary()
                self.paperPipeline = MetalCanvasView.makePipeline(
                    device: metalDevice,
                    library: library,
                    vertex: "canvasVertex",
                    fragment: "paperFragment",
                    blending: false
                )
                self.layerPipeline = MetalCanvasView.makePipeline(
                    device: metalDevice,
                    library: library,
                    vertex: "canvasVertex",
                    fragment: "layerFragment",
                    blending: true
                )
            } else {
                self.vertexBuffer = nil
                self.paperPipeline = nil
                self.layerPipeline = nil
            }
        }
    }
}

final class MetalCanvasView: MTKView, MTKViewDelegate {
    private static let logger = Logger(subsystem: "com.atelierprime.app", category: "Renderer")
    private let commandQueue: MTLCommandQueue?
    private let layerPipeline: MTLRenderPipelineState?
    private let paperPipeline: MTLRenderPipelineState?
    private let vertexBuffer: MTLBuffer?
    private var layerTextures: [Int: MTLTexture] = [:]
    private var pendingSnapshot: MetalDocumentSnapshot?
    private var appliedRevision: Int = -1

    init() {
        let clock = ContinuousClock()
        let start = clock.now
        let resources = MetalCanvasRendererCache.shared
        let metalDevice = resources.device
        self.commandQueue = resources.commandQueue
        self.vertexBuffer = resources.vertexBuffer
        self.paperPipeline = resources.paperPipeline
        self.layerPipeline = resources.layerPipeline

        super.init(frame: .zero, device: metalDevice)

        framebufferOnly = false
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0.84, green: 0.83, blue: 0.79, alpha: 1.0)
        preferredFramesPerSecond = 120
        enableSetNeedsDisplay = false
        isPaused = false
        delegate = self
        let duration = start.duration(to: clock.now)
        Self.logger.debug("MetalCanvasView initialized in \(String(describing: duration), privacy: .public)")
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(snapshot: MetalDocumentSnapshot?) {
        pendingSnapshot = snapshot
    }

    func contentRect(for viewSize: CGSize, documentSize: CGSize) -> CGRect {
        let paperRect = CGRect(origin: .zero, size: viewSize).insetBy(dx: 18, dy: 18)
        let drawableRect = paperRect.insetBy(dx: 20, dy: 20)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        return AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
    }

    func draw(in view: MTKView) {
        guard let currentDevice = device,
              let queue = commandQueue,
              let descriptor = currentRenderPassDescriptor,
              let currentDrawable = currentDrawable,
              let quadVertexBuffer = vertexBuffer else { return }

        applyPendingSnapshotIfNeeded(device: currentDevice)

        let commandBuffer = queue.makeCommandBuffer()
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)

        let viewport = SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))
        let viewSize = CGSize(width: drawableSize.width / contentScaleFactor, height: drawableSize.height / contentScaleFactor)
        let snapshotSize = CGSize(
            width: pendingSnapshot?.width ?? 1,
            height: pendingSnapshot?.height ?? 1
        )

        let paperRect = CGRect(origin: .zero, size: viewSize).insetBy(dx: 18, dy: 18)
        let contentRect = self.contentRect(for: viewSize, documentSize: snapshotSize)

        if let paperPipeline {
            var paperUniforms = MetalQuadUniforms(
                origin: SIMD2<Float>(Float(paperRect.minX * contentScaleFactor), Float(paperRect.minY * contentScaleFactor)),
                size: SIMD2<Float>(Float(paperRect.width * contentScaleFactor), Float(paperRect.height * contentScaleFactor)),
                viewport: viewport,
                opacity: 1.0,
                paperSeed: 0.17
            )
            encoder?.setRenderPipelineState(paperPipeline)
            encoder?.setVertexBytes(&paperUniforms, length: MemoryLayout<MetalQuadUniforms>.stride, index: 1)
            encoder?.setFragmentBytes(&paperUniforms, length: MemoryLayout<MetalQuadUniforms>.stride, index: 0)
            encoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        if let snapshot = pendingSnapshot, let layerPipeline {
            var layerUniforms = MetalQuadUniforms(
                origin: SIMD2<Float>(Float(contentRect.minX * contentScaleFactor), Float(contentRect.minY * contentScaleFactor)),
                size: SIMD2<Float>(Float(contentRect.width * contentScaleFactor), Float(contentRect.height * contentScaleFactor)),
                viewport: viewport,
                opacity: 1.0,
                paperSeed: 0.0
            )

            encoder?.setRenderPipelineState(layerPipeline)
            encoder?.setVertexBytes(&layerUniforms, length: MemoryLayout<MetalQuadUniforms>.stride, index: 1)

            for layer in snapshot.layers where layer.visible {
                guard let texture = layerTextures[layer.index] else { continue }
                var fragmentUniforms = layerUniforms
                fragmentUniforms.opacity = layer.opacity
                encoder?.setFragmentTexture(texture, index: 0)
                encoder?.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<MetalQuadUniforms>.stride, index: 0)
                encoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
        }

        encoder?.endEncoding()
        commandBuffer?.present(currentDrawable)
        commandBuffer?.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    private func applyPendingSnapshotIfNeeded(device: MTLDevice) {
        guard let snapshot = pendingSnapshot, snapshot.revision != appliedRevision else { return }

        let clock = ContinuousClock()
        let start = clock.now
        var nextTextures: [Int: MTLTexture] = [:]
        for layer in snapshot.layers {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: snapshot.width,
                height: snapshot.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead]
            let texture = device.makeTexture(descriptor: descriptor)
            layer.pixelData.withUnsafeBytes { bytes in
                if let baseAddress = bytes.baseAddress {
                    texture?.replace(
                        region: MTLRegionMake2D(0, 0, snapshot.width, snapshot.height),
                        mipmapLevel: 0,
                        withBytes: baseAddress,
                        bytesPerRow: snapshot.width * 4
                    )
                }
            }
            if let texture {
                nextTextures[layer.index] = texture
            }
        }
        layerTextures = nextTextures
        appliedRevision = snapshot.revision
        let duration = start.duration(to: clock.now)
        let megabytes = snapshot.layers.reduce(0) { $0 + $1.pixelData.count } / 1_048_576
        Self.logger.debug("Applied snapshot revision \(snapshot.revision) with \(snapshot.layers.count) layers and \(megabytes) MB in \(String(describing: duration), privacy: .public)")
    }

    static func makePipeline(
        device: MTLDevice,
        library: MTLLibrary?,
        vertex: String,
        fragment: String,
        blending: Bool
    ) -> MTLRenderPipelineState? {
        guard let library,
              let vertexFunction = library.makeFunction(name: vertex),
              let fragmentFunction = library.makeFunction(name: fragment) else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        if blending {
            let attachment = descriptor.colorAttachments[0]
            attachment?.isBlendingEnabled = true
            attachment?.rgbBlendOperation = .add
            attachment?.alphaBlendOperation = .add
            attachment?.sourceRGBBlendFactor = .sourceAlpha
            attachment?.sourceAlphaBlendFactor = .sourceAlpha
            attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
}
