import CoreGraphics
import Foundation
import os
import UIKit
import simd

final class PaintDocumentSession: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.atelierprime.app", category: "Document")
    private static let maxTimelapseFrames = 20_000
    let bridge: APPaintDocumentBridge
    private var revision: Int = 0
    private var activeStrokeLayerIndex: Int?
    private var timelapseFrames: [TimelapseFrame] = []
    private var layerThumbnailCache: [Int: Data] = [:]
    private var paperStyle: CanvasPaperStyle = .default

    init(width: Int = 1152, height: Int = 1536) {
        let clock = ContinuousClock()
        let start = clock.now
        self.bridge = APPaintDocumentBridge(width: width, height: height)
        let duration = start.duration(to: clock.now)
        Self.logger.debug("PaintDocumentSession initialized \(width)x\(height) in \(String(describing: duration), privacy: .public)")
    }

    func lightweightPresentation() -> PaintDocumentPresentation {
        let clock = ContinuousClock()
        let start = clock.now
        let infos = bridge.layerInfos()
        let rows = Array(infos.enumerated().map { index, layer in
            LayerRowModel(
                index: index,
                name: layer.name,
                visible: layer.visible,
                opacity: layer.opacity,
                blendMode: LayerBlendMode(rawValue: layer.blendMode) ?? .normal
            )
        }.reversed())
        let duration = start.duration(to: clock.now)
        Self.logger.debug("lightweightPresentation produced \(rows.count) layers in \(String(describing: duration), privacy: .public)")
        return PaintDocumentPresentation(
            canvasSize: CGSize(width: bridge.width, height: bridge.height),
            activeLayerIndex: bridge.activeLayerIndex,
            layerRows: rows,
            renderSnapshot: nil
        )
    }

    func presentation() -> PaintDocumentPresentation {
        let clock = ContinuousClock()
        let start = clock.now
        revision += 1
        let infos = bridge.layerInfos()
        let snapshots = infos.enumerated().map { index, info in
            MetalLayerSnapshot(
                index: index,
                opacity: Float(info.opacity),
                visible: info.visible,
                blendMode: LayerBlendMode(rawValue: info.blendMode) ?? .normal,
                thumbnailData: cachedLayerThumbnailData(index: index),
                pixelData: bridge.pixelDataForLayer(at: index) as Data
            )
        }
        let rows = Array(infos.enumerated().map { index, layer in
            LayerRowModel(
                index: index,
                name: layer.name,
                visible: layer.visible,
                opacity: layer.opacity,
                blendMode: LayerBlendMode(rawValue: layer.blendMode) ?? .normal
            )
        }.reversed())
        let duration = start.duration(to: clock.now)
        let megabytes = snapshots.reduce(0) { $0 + $1.pixelData.count } / 1_048_576
        Self.logger.debug("presentation produced revision \(self.revision) with \(snapshots.count) layers and \(megabytes) MB in \(String(describing: duration), privacy: .public)")
        return PaintDocumentPresentation(
            canvasSize: CGSize(width: bridge.width, height: bridge.height),
            activeLayerIndex: bridge.activeLayerIndex,
            layerRows: rows,
            renderSnapshot: MetalDocumentSnapshot(
                width: bridge.width,
                height: bridge.height,
                revision: revision,
                compositePixelData: bridge.compositePixelData() as Data,
                layers: snapshots
            )
        )
    }

    func beginStroke(sample: StylusSample, brush: BrushRuntimeSettings) {
        activeStrokeLayerIndex = Int(bridge.activeLayerIndex)
        bridge.beginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: sample))
    }

    func appendStroke(sample: StylusSample) {
        bridge.appendStroke(point: makeStrokePoint(from: sample))
    }

    func endStroke() {
        bridge.endStroke()
        invalidateThumbnailCache(for: Int(bridge.activeLayerIndex))
        activeStrokeLayerIndex = nil
        captureTimelapseFrame()
    }

    func fill(sample: StylusSample, brush: BrushRuntimeSettings) {
        bridge.fill(
            at: sample.point,
            brush: makeBrushDescriptor(from: brush)
        )
        invalidateThumbnailCache(for: Int(bridge.activeLayerIndex))
        captureTimelapseFrame()
    }

    func canUndo() -> Bool {
        bridge.canUndo()
    }

    func canRedo() -> Bool {
        bridge.canRedo()
    }

    @discardableResult
    func undo() -> Bool {
        let didUndo = bridge.undo()
        if didUndo {
            invalidateThumbnailCache()
            captureTimelapseFrame()
        }
        return didUndo
    }

    @discardableResult
    func redo() -> Bool {
        let didRedo = bridge.redo()
        if didRedo {
            invalidateThumbnailCache()
            captureTimelapseFrame()
        }
        return didRedo
    }

    func addLayer(name: String) {
        bridge.activeLayerIndex = bridge.addLayer(name: name)
        invalidateThumbnailCache(for: Int(bridge.activeLayerIndex))
        captureTimelapseFrame()
    }

    func setActiveLayer(index: Int) {
        bridge.activeLayerIndex = index
    }

    func setLayerVisibility(index: Int, isVisible: Bool) {
        bridge.setLayerVisible(isVisible, at: index)
        captureTimelapseFrame()
    }

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) {
        bridge.setLayerBlendMode(blendMode.rawValue, at: index)
        invalidateThumbnailCache(for: index)
        captureTimelapseFrame()
    }

    func replaceLayerPixels(index: Int, data: Data) {
        bridge.replaceLayerPixels(at: index, data: data)
        invalidateThumbnailCache(for: index)
        captureTimelapseFrame()
    }

    func clearLayer(index: Int) {
        bridge.clearLayer(at: index)
        invalidateThumbnailCache(for: index)
        captureTimelapseFrame()
    }

    func setPaperStyle(_ style: CanvasPaperStyle) {
        paperStyle = style
    }

    func compositePNGData(paperStyle: CanvasPaperStyle) -> Data? {
        self.paperStyle = paperStyle
        return renderedCompositeImage(paperStyle: paperStyle)?.pngData()
    }

    func timelapseCapture() -> TimelapseCapture? {
        guard timelapseFrames.count >= 2 else { return nil }
        return TimelapseCapture(
            canvasSize: CGSize(width: bridge.width, height: bridge.height),
            frames: timelapseFrames,
            framesPerSecond: 24
        )
    }

    func consumeDirtyUpdate() -> IncrementalLayerUpdate? {
        let dirtyRect = bridge.consumeDirtyRect()
        guard !dirtyRect.empty else { return nil }
        let pixelData = bridge.compositePixelData(in: dirtyRect) as Data
        guard !pixelData.isEmpty else { return nil }
        return IncrementalLayerUpdate(
            layerIndex: -1,
            originX: Int(dirtyRect.originX),
            originY: Int(dirtyRect.originY),
            width: Int(dirtyRect.width),
            height: Int(dirtyRect.height),
            pixelData: pixelData
        )
    }

    private func makeBrushDescriptor(from brush: BrushRuntimeSettings) -> APBrushDescriptor {
        let descriptor = APBrushDescriptor()
        descriptor.tipKind = brush.tipKind.rawValue
        descriptor.radius = brush.radius
        descriptor.opacity = brush.opacity
        descriptor.hardness = brush.hardness
        descriptor.grainScale = 1.35
        descriptor.grainContrast = 1.7
        descriptor.paperScale = 0.12
        descriptor.paperThreshold = 0.42
        descriptor.paperStrength = 0.32
        descriptor.velocityInfluence = 0.012
        descriptor.tiltInfluence = 0.75
        descriptor.maxDarkness = 0.95
        descriptor.pressureSensitivity = brush.pressureSensitivity
        descriptor.fillThresholdMode = brush.fillThresholdMode == .opacity ? 0 : 1
        descriptor.fillOpacityTolerance = brush.fillOpacityTolerance
        descriptor.fillColorTolerance = brush.fillColorTolerance
        descriptor.fillExpansion = brush.fillExpansion
        descriptor.red = brush.red
        descriptor.green = brush.green
        descriptor.blue = brush.blue
        descriptor.eraser = brush.isEraser
        return descriptor
    }

    private func makeStrokePoint(from sample: StylusSample) -> APStrokePoint {
        let point = APStrokePoint()
        point.x = sample.point.x
        point.y = sample.point.y
        point.pressure = normalizedPressure(sample.pressure)
        point.altitude = sample.altitude
        point.azimuth = sample.azimuth
        point.timestamp = sample.timestamp
        return point
    }

    private func normalizedPressure(_ pressure: CGFloat) -> CGFloat {
        max(0.08, min(max(pressure, 0.0), 1.0))
    }

    private func captureTimelapseFrame() {
        guard let sourceImage = makeTimelapseThumbnail() else { return }
        appendTimelapseFrame(image: sourceImage)
    }

    private func makeTimelapseThumbnail() -> UIImage? {
        guard let sourceImage = renderedCompositeImage(paperStyle: paperStyle) else { return nil }
        let targetSize = timelapseFrameSize(
            for: CGSize(width: bridge.width, height: bridge.height),
            maxDimension: 512
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func appendTimelapseFrame(image: UIImage) {
        guard let jpegData = image.jpegData(compressionQuality: 0.72) else { return }

        let frame = TimelapseFrame(imageData: jpegData, size: image.size)
        timelapseFrames.append(frame)
        if timelapseFrames.count > Self.maxTimelapseFrames {
            timelapseFrames.remove(at: 1)
        }
    }

    private func timelapseFrameSize(for canvasSize: CGSize, maxDimension: CGFloat) -> CGSize {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return CGSize(width: maxDimension, height: maxDimension)
        }
        let scale = min(maxDimension / canvasSize.width, maxDimension / canvasSize.height, 1.0)
        let width = max(2, Int((canvasSize.width * scale).rounded()))
        let height = max(2, Int((canvasSize.height * scale).rounded()))
        return CGSize(width: width, height: height)
    }

    private func renderedCompositeImage(paperStyle: CanvasPaperStyle) -> UIImage? {
        guard let imageRef = bridge.makeCompositeImage() else { return nil }
        let compositeImage = UIImage(cgImage: imageRef)
        let size = CGSize(width: bridge.width, height: bridge.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !paperStyle.isTransparent
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            if !paperStyle.isTransparent {
                UIColor(
                    red: CGFloat(paperStyle.red),
                    green: CGFloat(paperStyle.green),
                    blue: CGFloat(paperStyle.blue),
                    alpha: CGFloat(paperStyle.alpha)
                ).setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            compositeImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func cachedLayerThumbnailData(index: Int) -> Data? {
        if let cached = layerThumbnailCache[index] {
            return cached
        }
        let thumbnail = makeLayerThumbnailData(index: index)
        layerThumbnailCache[index] = thumbnail
        return thumbnail
    }

    private func makeLayerThumbnailData(index: Int) -> Data? {
        guard let imageRef = bridge.makeImageForLayer(at: index) else { return nil }
        let sourceImage = UIImage(cgImage: imageRef)
        let targetSize = timelapseFrameSize(
            for: CGSize(width: bridge.width, height: bridge.height),
            maxDimension: 96
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let thumbnail = renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return thumbnail.pngData()
    }

    private func invalidateThumbnailCache(for index: Int? = nil) {
        if let index {
            layerThumbnailCache.removeValue(forKey: index)
        } else {
            layerThumbnailCache.removeAll(keepingCapacity: true)
        }
    }
}
