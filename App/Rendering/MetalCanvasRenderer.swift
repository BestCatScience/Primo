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
    var paperColor: SIMD4<Float>
    var checkerboard: Float
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
                    MetalQuadVertex(position: SIMD2<Float>(0, 0), uv: SIMD2<Float>(0, 0)),
                    MetalQuadVertex(position: SIMD2<Float>(1, 0), uv: SIMD2<Float>(1, 0)),
                    MetalQuadVertex(position: SIMD2<Float>(0, 1), uv: SIMD2<Float>(0, 1)),
                    MetalQuadVertex(position: SIMD2<Float>(1, 1), uv: SIMD2<Float>(1, 1))
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
    private var compositeTexture: MTLTexture?
    private var pendingSnapshot: MetalDocumentSnapshot?
    private var appliedRevision: Int = -1
    private var lastAppliedIncrementalUpdateID: IncrementalLayerUpdate.ID?
    private var viewportOffset: CGSize = .zero
    private var zoomScale: CGFloat = 1.0
    private var documentSize: CGSize = .zero
    private var paperStyle: CanvasPaperStyle = .default
    private var needsRedraw = false
    private(set) var currentSnapshot: MetalDocumentSnapshot?
    var currentActiveLayerIndex: Int = 0

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
        isOpaque = false
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
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

    func update(snapshot: MetalDocumentSnapshot?, viewportOffset: CGSize, zoomScale: CGFloat, paperStyle: CanvasPaperStyle) {
        let previousSnapshot = currentSnapshot
        let snapshotChanged =
            previousSnapshot?.revision != snapshot?.revision ||
            previousSnapshot?.width != snapshot?.width ||
            previousSnapshot?.height != snapshot?.height
        if snapshotChanged {
            pendingSnapshot = snapshot
            currentSnapshot = snapshot
            if let snapshot {
                documentSize = CGSize(width: snapshot.width, height: snapshot.height)
            }
        }
        let viewportChanged = self.viewportOffset != viewportOffset || self.zoomScale != zoomScale
        let paperChanged = self.paperStyle != paperStyle
        self.viewportOffset = viewportOffset
        self.zoomScale = zoomScale
        self.paperStyle = paperStyle
        if snapshotChanged || viewportChanged || paperChanged {
            scheduleRedraw()
        }
    }

    func applyIncrementalUpdate(_ update: IncrementalLayerUpdate) {
        guard lastAppliedIncrementalUpdateID != update.id else { return }
        guard let currentDevice = device, !update.isEmpty else { return }
        let texture = ensureCompositeTexture(device: currentDevice)
        guard let texture else { return }

        let maxWidth = max(0, texture.width - update.originX)
        let maxHeight = max(0, texture.height - update.originY)
        let copyWidth = min(update.width, maxWidth)
        let copyHeight = min(update.height, maxHeight)
        guard copyWidth > 0, copyHeight > 0 else { return }

        update.pixelData.withUnsafeBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                texture.replace(
                    region: MTLRegionMake2D(update.originX, update.originY, copyWidth, copyHeight),
                    mipmapLevel: 0,
                    withBytes: baseAddress,
                    bytesPerRow: update.width * 4
                )
            }
        }
        lastAppliedIncrementalUpdateID = update.id
        scheduleRedraw()
    }

    func updateDocumentSize(_ size: CGSize) {
        if documentSize != size {
            documentSize = size
            if let currentDevice = device, size.width > 0, size.height > 0 {
                _ = ensureCompositeTexture(device: currentDevice)
            }
            scheduleRedraw()
        }
    }

    func contentRect(for viewSize: CGSize, documentSize: CGSize, viewportOffset: CGSize, zoomScale: CGFloat) -> CGRect {
        let paperRect = CGRect(origin: .zero, size: viewSize).insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let fittedRect = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledSize = CGSize(
            width: fittedRect.width * zoomScale,
            height: fittedRect.height * zoomScale
        )
        return CGRect(
            x: fittedRect.midX - (scaledSize.width / 2) + viewportOffset.width,
            y: fittedRect.midY - (scaledSize.height / 2) + viewportOffset.height,
            width: scaledSize.width,
            height: scaledSize.height
        )
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
        let snapshotSize = documentSize.width > 0 ? documentSize : CGSize(width: 1, height: 1)

        let contentRect = self.contentRect(
            for: viewSize,
            documentSize: snapshotSize,
            viewportOffset: viewportOffset,
            zoomScale: zoomScale
        )

        if let paperPipeline {
            var paperUniforms = MetalQuadUniforms(
                origin: SIMD2<Float>(Float(contentRect.minX * contentScaleFactor), Float(contentRect.minY * contentScaleFactor)),
                size: SIMD2<Float>(Float(contentRect.width * contentScaleFactor), Float(contentRect.height * contentScaleFactor)),
                viewport: viewport,
                opacity: 1.0,
                paperColor: SIMD4<Float>(paperStyle.red, paperStyle.green, paperStyle.blue, paperStyle.alpha),
                checkerboard: paperStyle.isTransparent ? 1.0 : 0.0
            )
            encoder?.setRenderPipelineState(paperPipeline)
            encoder?.setVertexBytes(&paperUniforms, length: MemoryLayout<MetalQuadUniforms>.stride, index: 1)
            encoder?.setFragmentBytes(&paperUniforms, length: MemoryLayout<MetalQuadUniforms>.stride, index: 0)
            encoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        if let compositeTexture, let layerPipeline {
            var layerUniforms = MetalQuadUniforms(
                origin: SIMD2<Float>(Float(contentRect.minX * contentScaleFactor), Float(contentRect.minY * contentScaleFactor)),
                size: SIMD2<Float>(Float(contentRect.width * contentScaleFactor), Float(contentRect.height * contentScaleFactor)),
                viewport: viewport,
                opacity: 1.0,
                paperColor: SIMD4<Float>(0, 0, 0, 0),
                checkerboard: 0.0
            )

            encoder?.setRenderPipelineState(layerPipeline)
            encoder?.setVertexBytes(&layerUniforms, length: MemoryLayout<MetalQuadUniforms>.stride, index: 1)
            encoder?.setFragmentTexture(compositeTexture, index: 0)
            encoder?.setFragmentBytes(&layerUniforms, length: MemoryLayout<MetalQuadUniforms>.stride, index: 0)
            encoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        encoder?.endEncoding()
        commandBuffer?.present(currentDrawable)
        commandBuffer?.commit()
        needsRedraw = false
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    private func applyPendingSnapshotIfNeeded(device: MTLDevice) {
        guard let snapshot = pendingSnapshot, snapshot.revision != appliedRevision else { return }

        let clock = ContinuousClock()
        let start = clock.now

        let texture = ensureCompositeTexture(device: device)
        snapshot.compositePixelData.withUnsafeBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                texture?.replace(
                    region: MTLRegionMake2D(0, 0, snapshot.width, snapshot.height),
                    mipmapLevel: 0,
                    withBytes: baseAddress,
                    bytesPerRow: snapshot.width * 4
                )
            }
        }

        appliedRevision = snapshot.revision
        lastAppliedIncrementalUpdateID = nil
        pendingSnapshot = nil
        let duration = start.duration(to: clock.now)
        let megabytes = snapshot.compositePixelData.count / 1_048_576
        Self.logger.debug("Applied composite snapshot revision \(snapshot.revision) with \(megabytes) MB in \(String(describing: duration), privacy: .public)")
    }

    private func ensureCompositeTexture(device: MTLDevice) -> MTLTexture? {
        if let existing = compositeTexture {
            let currentWidth = Int(documentSize.width)
            let currentHeight = Int(documentSize.height)
            if existing.width == currentWidth && existing.height == currentHeight {
                return existing
            }
        }
        let width = max(1, Int(documentSize.width))
        let height = max(1, Int(documentSize.height))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        let texture = device.makeTexture(descriptor: descriptor)
        if let texture {
            // Zero-fill to transparent black — Metal textures have undefined initial contents
            let zeroData = Data(count: width * height * 4)
            zeroData.withUnsafeBytes { bytes in
                if let baseAddress = bytes.baseAddress {
                    texture.replace(
                        region: MTLRegionMake2D(0, 0, width, height),
                        mipmapLevel: 0,
                        withBytes: baseAddress,
                        bytesPerRow: width * 4
                    )
                }
            }
            compositeTexture = texture
        }
        return texture
    }

    private func scheduleRedraw() {
        guard !needsRedraw else { return }
        needsRedraw = true
        setNeedsDisplay()
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
            attachment?.sourceRGBBlendFactor = .one
            attachment?.sourceAlphaBlendFactor = .one
            attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
}
