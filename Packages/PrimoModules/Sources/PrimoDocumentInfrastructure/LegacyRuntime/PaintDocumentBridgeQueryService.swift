import Foundation

struct PaintDocumentBridgeQueryService {
    func consumeDirtyUpdate(from bridge: APPaintDocumentBridge) -> IncrementalLayerUpdate? {
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

    func pixelDataForLayer(index: Int, bridge: APPaintDocumentBridge) -> Data {
        bridge.pixelDataForLayer(at: index) as Data
    }

    func isLayerLocked(index: Int, bridge: APPaintDocumentBridge) -> Bool {
        guard let layer = bridge.layerInfos().enumerated().first(where: { $0.offset == index })?.element else {
            return false
        }
        return layer.locked
    }

    func isLayerAlphaLocked(index: Int, bridge: APPaintDocumentBridge) -> Bool {
        guard let layer = bridge.layerInfos().enumerated().first(where: { $0.offset == index })?.element else {
            return false
        }
        return layer.alphaLocked
    }
}
