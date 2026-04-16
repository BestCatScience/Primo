import CoreGraphics
import Foundation
import UIKit

extension PaintDocumentSession {
    func consumeDirtyUpdate() -> IncrementalLayerUpdate? {
        bridgeService.consumeDirtyUpdate(from: bridge)
    }

    func pixelDataForLayer(index: Int) -> Data {
        bridgeService.pixelDataForLayer(index: index, bridge: bridge)
    }

    func isLayerLocked(index: Int) -> Bool {
        bridgeService.isLayerLocked(index: index, bridge: bridge)
    }

    func isLayerAlphaLocked(index: Int) -> Bool {
        bridgeService.isLayerAlphaLocked(index: index, bridge: bridge)
    }

    static func pixelDataByPreservingExistingAlpha(source: Data, existing: Data) -> Data {
        PaintDocumentBridgeService().pixelDataByPreservingExistingAlpha(source: source, existing: existing)
    }

    static func pixelData(from cgImage: CGImage, size: CGSize) -> Data? {
        PaintDocumentBridgeService().pixelData(from: cgImage, size: size)
    }

    func makeBrushDescriptor(from brush: BrushRuntimeSettings) -> APBrushDescriptor {
        bridgeService.makeBrushDescriptor(from: brush)
    }

    func makeProcessingDescriptor(from request: LayerProcessingRequest) -> APPaintLayerProcessingDescriptor {
        bridgeService.makeProcessingDescriptor(from: request)
    }

    func makeStrokePoint(from sample: StylusSample) -> APStrokePoint {
        bridgeService.makeStrokePoint(from: sample)
    }

    func normalizedPressure(_ pressure: CGFloat) -> CGFloat {
        bridgeService.normalizedPressure(pressure)
    }
}
