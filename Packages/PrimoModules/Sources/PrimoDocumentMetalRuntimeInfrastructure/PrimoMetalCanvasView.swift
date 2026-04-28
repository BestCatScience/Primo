import AVFoundation
import Foundation
import Metal
import MetalKit
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain
import os
import simd

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private struct PrimoMetalQuadVertex {
    var position: SIMD2<Float>
    var uv: SIMD2<Float>
}

private struct PrimoMetalQuadUniforms {
    var origin: SIMD2<Float>
    var size: SIMD2<Float>
    var viewport: SIMD2<Float>
    var opacity: Float
    var paperColor: SIMD4<Float>
    var checkerboard: Float
}

public enum PrimoMetalSurfaceFiltering: Sendable {
    case linear
    case nearest
}

fileprivate func primoMakeRenderPipeline(
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

@MainActor
private enum PrimoMetalCanvasRendererCache {
    static let shared = Resources()

    final class Resources {
        let device: MTLDevice?
        let commandQueue: MTLCommandQueue?
        let layerPipeline: MTLRenderPipelineState?
        let nearestLayerPipeline: MTLRenderPipelineState?
        let paperPipeline: MTLRenderPipelineState?
        let vertexBuffer: MTLBuffer?

        init() {
            let metalDevice = MTLCreateSystemDefaultDevice()
            self.device = metalDevice
            self.commandQueue = metalDevice?.makeCommandQueue()

            if let metalDevice {
                self.vertexBuffer = metalDevice.makeBuffer(bytes: [
                    PrimoMetalQuadVertex(position: SIMD2<Float>(0, 0), uv: SIMD2<Float>(0, 0)),
                    PrimoMetalQuadVertex(position: SIMD2<Float>(1, 0), uv: SIMD2<Float>(1, 0)),
                    PrimoMetalQuadVertex(position: SIMD2<Float>(0, 1), uv: SIMD2<Float>(0, 1)),
                    PrimoMetalQuadVertex(position: SIMD2<Float>(1, 1), uv: SIMD2<Float>(1, 1)),
                ], length: MemoryLayout<PrimoMetalQuadVertex>.stride * 4)

                let library = PrimoMetalShaderLibrary.makeDefaultLibrary(device: metalDevice)
                self.paperPipeline = primoMakeRenderPipeline(
                    device: metalDevice,
                    library: library,
                    vertex: "canvasVertex",
                    fragment: "paperFragment",
                    blending: false
                )
                self.layerPipeline = primoMakeRenderPipeline(
                    device: metalDevice,
                    library: library,
                    vertex: "canvasVertex",
                    fragment: "layerFragment",
                    blending: true
                )
                self.nearestLayerPipeline = primoMakeRenderPipeline(
                    device: metalDevice,
                    library: library,
                    vertex: "canvasVertex",
                    fragment: "nearestLayerFragment",
                    blending: true
                )
            } else {
                self.vertexBuffer = nil
                self.paperPipeline = nil
                self.layerPipeline = nil
                self.nearestLayerPipeline = nil
            }
        }
    }
}

@MainActor
public final class PrimoMetalCanvasView: MTKView, MTKViewDelegate {
    private static let logger = Logger(subsystem: "com.primo.modules", category: "Renderer")
    private let commandQueue: MTLCommandQueue?
    private let layerPipeline: MTLRenderPipelineState?
    private let nearestLayerPipeline: MTLRenderPipelineState?
    private let paperPipeline: MTLRenderPipelineState?
    private let vertexBuffer: MTLBuffer?
    private var compositeTexture: MTLTexture?
    private var pendingSnapshot: MetalDocumentSnapshot?
    private var pendingSurface: DocumentCompositeSurface?
    private var appliedRevision: Int = -1
    private var appliedSurfaceNonce: Int = -1
    private var pendingSurfaceNonce: Int = 0
    private var lastAppliedIncrementalUpdateID: IncrementalLayerUpdate.ID?
    private var viewportOffset: CGSize = .zero
    private var zoomScale: CGFloat = 1.0
    private var documentSize: CGSize = .zero
    private var paperStyle: CanvasPaperStyle = .default
    private var needsRedraw = false
    private var showsPaper = true
    private var surfaceFiltering: PrimoMetalSurfaceFiltering = .linear
    private var surfaceOpacity: Float = 1.0
    public private(set) var currentSnapshot: MetalDocumentSnapshot?
    public var currentActiveLayerIndex: Int = 0

    public init() {
        let clock = ContinuousClock()
        let start = clock.now
        let resources = PrimoMetalCanvasRendererCache.shared
        let metalDevice = resources.device
        self.commandQueue = resources.commandQueue
        self.vertexBuffer = resources.vertexBuffer
        self.paperPipeline = resources.paperPipeline
        self.layerPipeline = resources.layerPipeline
        self.nearestLayerPipeline = resources.nearestLayerPipeline

        super.init(frame: .zero, device: metalDevice)

        framebufferOnly = false
#if canImport(UIKit)
        isOpaque = false
#endif
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        preferredFramesPerSecond = 60
        enableSetNeedsDisplay = true
        isPaused = true
        delegate = self
        let duration = start.duration(to: clock.now)
        Self.logger.debug("PrimoMetalCanvasView initialized in \(String(describing: duration), privacy: .public)")
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func update(snapshot: MetalDocumentSnapshot?, viewportOffset: CGSize, zoomScale: CGFloat, paperStyle: CanvasPaperStyle) {
        showsPaper = true
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

    public func applyIncrementalUpdate(_ update: IncrementalLayerUpdate) {
        guard showsPaper else { return }
        guard lastAppliedIncrementalUpdateID != update.id else { return }
        guard let currentDevice = device, !update.isEmpty else { return }
        applyPendingSnapshotIfNeeded(device: currentDevice)
        guard let texture = ensureCompositeTexture(device: currentDevice) else { return }

        let maxWidth = max(0, texture.width - update.originX)
        let maxHeight = max(0, texture.height - update.originY)
        let copyWidth = min(update.width, maxWidth)
        let copyHeight = min(update.height, maxHeight)
        guard copyWidth > 0, copyHeight > 0 else { return }

        if let handle = update.gpuBufferHandle,
           MetalResourceStore().populateTexture(
               texture,
               from: handle,
               sourceOriginX: 0,
               sourceOriginY: 0,
               destinationOriginX: update.originX,
               destinationOriginY: update.originY,
               width: copyWidth,
               height: copyHeight
           ) {
            MetalResourceStore().release(handle)
            lastAppliedIncrementalUpdateID = update.id
            scheduleRedraw()
            return
        }

        update.pixelData.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            texture.replace(
                region: MTLRegionMake2D(update.originX, update.originY, copyWidth, copyHeight),
                mipmapLevel: 0,
                withBytes: baseAddress,
                bytesPerRow: update.width * 4
            )
        }
        lastAppliedIncrementalUpdateID = update.id
        scheduleRedraw()
    }

    public func reloadSnapshot(_ snapshot: MetalDocumentSnapshot?) {
        showsPaper = true
        pendingSnapshot = snapshot
        currentSnapshot = snapshot
        appliedRevision = -1
        lastAppliedIncrementalUpdateID = nil
        if let snapshot {
            documentSize = CGSize(width: snapshot.width, height: snapshot.height)
        }
        scheduleRedraw()
    }

    public func updateSurface(
        _ surface: DocumentCompositeSurface?,
        opacity: Float = 1.0,
        filtering: PrimoMetalSurfaceFiltering = .linear
    ) {
        pendingSnapshot = nil
        currentSnapshot = nil
        showsPaper = false
        surfaceFiltering = filtering
        surfaceOpacity = opacity
        pendingSurface = surface
        pendingSurfaceNonce += 1
        documentSize = CGSize(
            width: max(surface?.width ?? 1, 1),
            height: max(surface?.height ?? 1, 1)
        )
        scheduleRedraw()
    }

    public func updateDocumentSize(_ size: CGSize) {
        if documentSize != size {
            documentSize = size
            if let currentDevice = device, size.width > 0, size.height > 0 {
                _ = ensureCompositeTexture(device: currentDevice)
            }
            scheduleRedraw()
        }
    }

    public func contentRect(for viewSize: CGSize, documentSize: CGSize, viewportOffset: CGSize, zoomScale: CGFloat) -> CGRect {
        let paperRect = CGRect(origin: .zero, size: viewSize).insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let fittedRect = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledSize = CGSize(width: fittedRect.width * zoomScale, height: fittedRect.height * zoomScale)
        return CGRect(
            x: fittedRect.midX - (scaledSize.width / 2) + viewportOffset.width,
            y: fittedRect.midY - (scaledSize.height / 2) + viewportOffset.height,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }

    public func draw(in view: MTKView) {
        guard let currentDevice = device,
              let queue = commandQueue,
              let descriptor = currentRenderPassDescriptor,
              let currentDrawable = currentDrawable,
              let quadVertexBuffer = vertexBuffer else { return }

        applyPendingSnapshotIfNeeded(device: currentDevice)
        applyPendingSurfaceIfNeeded(device: currentDevice)

        let commandBuffer = queue.makeCommandBuffer()
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)

        let scaleFactor: CGFloat
#if canImport(UIKit)
        scaleFactor = contentScaleFactor
#else
        let widthScale = bounds.width > 0 ? CGFloat(drawableSize.width) / bounds.width : 1
        let heightScale = bounds.height > 0 ? CGFloat(drawableSize.height) / bounds.height : 1
        scaleFactor = max(widthScale, heightScale)
#endif

        let viewport = SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))
        let viewSize = CGSize(width: drawableSize.width / scaleFactor, height: drawableSize.height / scaleFactor)
        let snapshotSize = documentSize.width > 0 ? documentSize : CGSize(width: 1, height: 1)
        let contentRect = showsPaper
            ? self.contentRect(
                for: viewSize,
                documentSize: snapshotSize,
                viewportOffset: viewportOffset,
                zoomScale: zoomScale
            )
            : CGRect(origin: .zero, size: viewSize)

        if showsPaper, let paperPipeline {
            let minX = Float(contentRect.minX * scaleFactor)
            let minY = Float(contentRect.minY * scaleFactor)
            let width = Float(contentRect.width * scaleFactor)
            let height = Float(contentRect.height * scaleFactor)
            var paperUniforms = PrimoMetalQuadUniforms(
                origin: SIMD2<Float>(minX, minY),
                size: SIMD2<Float>(width, height),
                viewport: viewport,
                opacity: 1.0,
                paperColor: SIMD4<Float>(paperStyle.red, paperStyle.green, paperStyle.blue, paperStyle.alpha),
                checkerboard: paperStyle.isTransparent ? 1.0 : 0.0
            )
            encoder?.setRenderPipelineState(paperPipeline)
            encoder?.setVertexBytes(&paperUniforms, length: MemoryLayout<PrimoMetalQuadUniforms>.stride, index: 1)
            encoder?.setFragmentBytes(&paperUniforms, length: MemoryLayout<PrimoMetalQuadUniforms>.stride, index: 0)
            encoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        let activeLayerPipeline = surfaceFiltering == .nearest ? nearestLayerPipeline : layerPipeline
        if let compositeTexture, let activeLayerPipeline {
            let minX = Float(contentRect.minX * scaleFactor)
            let minY = Float(contentRect.minY * scaleFactor)
            let width = Float(contentRect.width * scaleFactor)
            let height = Float(contentRect.height * scaleFactor)
            var layerUniforms = PrimoMetalQuadUniforms(
                origin: SIMD2<Float>(minX, minY),
                size: SIMD2<Float>(width, height),
                viewport: viewport,
                opacity: surfaceOpacity,
                paperColor: SIMD4<Float>(0, 0, 0, 0),
                checkerboard: 0.0
            )

            encoder?.setRenderPipelineState(activeLayerPipeline)
            encoder?.setVertexBytes(&layerUniforms, length: MemoryLayout<PrimoMetalQuadUniforms>.stride, index: 1)
            encoder?.setFragmentTexture(compositeTexture, index: 0)
            encoder?.setFragmentBytes(&layerUniforms, length: MemoryLayout<PrimoMetalQuadUniforms>.stride, index: 0)
            encoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        encoder?.endEncoding()
        commandBuffer?.present(currentDrawable)
        commandBuffer?.commit()
        needsRedraw = false
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    private func applyPendingSnapshotIfNeeded(device: MTLDevice) {
        guard showsPaper else { return }
        guard let snapshot = pendingSnapshot, snapshot.revision != appliedRevision else { return }

        let clock = ContinuousClock()
        let start = clock.now

        let texture = ensureCompositeTexture(device: device)
        if let handle = snapshot.compositeBufferHandle,
           let texture,
           MetalResourceStore().populateTexture(texture, from: handle) {
            // GPU-backed snapshot upload completed directly from cached buffer.
        } else {
            snapshot.compositePixelData.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
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
        Self.logger.debug("Applied composite snapshot revision \(snapshot.revision, privacy: .public) with \(megabytes, privacy: .public) MB in \(String(describing: duration), privacy: .public)")
    }

    private func applyPendingSurfaceIfNeeded(device: MTLDevice) {
        guard !showsPaper else { return }
        guard appliedSurfaceNonce != pendingSurfaceNonce else { return }

        guard let surface = pendingSurface else {
            compositeTexture = nil
            appliedSurfaceNonce = pendingSurfaceNonce
            return
        }

        let texture = ensureCompositeTexture(device: device)
        surface.pixelData.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            texture?.replace(
                region: MTLRegionMake2D(0, 0, surface.width, surface.height),
                mipmapLevel: 0,
                withBytes: baseAddress,
                bytesPerRow: surface.width * 4
            )
        }
        appliedSurfaceNonce = pendingSurfaceNonce
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
            let zeroData = Data(count: width * height * 4)
            zeroData.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
                texture.replace(
                    region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0,
                    withBytes: baseAddress,
                    bytesPerRow: width * 4
                )
            }
            compositeTexture = texture
        }
        return texture
    }

    private func scheduleRedraw() {
        guard !needsRedraw else { return }
        needsRedraw = true
#if canImport(UIKit)
        setNeedsDisplay()
#else
        setNeedsDisplay(bounds)
#endif
    }
}
