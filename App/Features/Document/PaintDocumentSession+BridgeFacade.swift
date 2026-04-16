import CoreGraphics
import Foundation
import UIKit

extension PaintDocumentSession {
    func consumeDirtyUpdate() -> IncrementalLayerUpdate? {
        bridgeQueryService.consumeDirtyUpdate(from: bridge)
    }

    func pixelDataForLayer(index: Int) -> Data {
        bridgeQueryService.pixelDataForLayer(index: index, bridge: bridge)
    }

    func isLayerLocked(index: Int) -> Bool {
        bridgeQueryService.isLayerLocked(index: index, bridge: bridge)
    }

    func isLayerAlphaLocked(index: Int) -> Bool {
        bridgeQueryService.isLayerAlphaLocked(index: index, bridge: bridge)
    }

    static func pixelDataByPreservingExistingAlpha(source: Data, existing: Data) -> Data {
        PaintDocumentBridgePixelService().pixelDataByPreservingExistingAlpha(source: source, existing: existing)
    }

    static func pixelData(from cgImage: CGImage, size: CGSize) -> Data? {
        PaintDocumentBridgePixelService().pixelData(from: cgImage, size: size)
    }

    func makeBrushDescriptor(from brush: BrushRuntimeSettings) -> APBrushDescriptor {
        bridgeDescriptorService.makeBrushDescriptor(from: brush)
    }

    func makeProcessingDescriptor(from request: LayerProcessingRequest) -> APPaintLayerProcessingDescriptor {
        bridgeDescriptorService.makeProcessingDescriptor(from: request)
    }

    func makeStrokePoint(from sample: StylusSample) -> APStrokePoint {
        bridgeStrokeService.makeStrokePoint(from: sample)
    }

    func normalizedPressure(_ pressure: CGFloat) -> CGFloat {
        bridgeStrokeService.normalizedPressure(pressure)
    }
}
