import CoreGraphics
import Foundation
import os

final class PaintDocumentSession: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.atelierprime.app", category: "Document")
    let bridge: APPaintDocumentBridge
    private var revision: Int = 0

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
            LayerRowModel(index: index, name: layer.name, visible: layer.visible, opacity: layer.opacity)
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
                pixelData: bridge.pixelDataForLayer(at: index) as Data
            )
        }
        let rows = Array(infos.enumerated().map { index, layer in
            LayerRowModel(index: index, name: layer.name, visible: layer.visible, opacity: layer.opacity)
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
                layers: snapshots
            )
        )
    }

    func beginStroke(sample: StylusSample, brush: BrushRuntimeSettings) {
        bridge.beginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: sample))
    }

    func appendStroke(sample: StylusSample) {
        bridge.appendStroke(point: makeStrokePoint(from: sample))
    }

    func endStroke() {
        bridge.endStroke()
    }

    func addLayer(name: String) {
        bridge.activeLayerIndex = bridge.addLayer(name: name)
    }

    func setActiveLayer(index: Int) {
        bridge.activeLayerIndex = index
    }

    func setLayerVisibility(index: Int, isVisible: Bool) {
        bridge.setLayerVisible(isVisible, at: index)
    }

    func clearLayer(index: Int) {
        bridge.clearLayer(at: index)
    }

    private func makeBrushDescriptor(from brush: BrushRuntimeSettings) -> APBrushDescriptor {
        let descriptor = APBrushDescriptor()
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
        if pressure <= 0 {
            return 0.65
        }
        return min(max(pressure, 0.15), 1.0)
    }
}
