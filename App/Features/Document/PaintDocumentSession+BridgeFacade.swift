import CoreGraphics
import Foundation
import UIKit

extension PaintDocumentSession {
    var bridgeCanvasWidth: Int {
        Int(bridge.width)
    }

    var bridgeCanvasHeight: Int {
        Int(bridge.height)
    }

    var bridgeCanvasSize: CGSize {
        CGSize(width: bridge.width, height: bridge.height)
    }

    func bridgeLayerInfos() -> [APPaintLayerInfo] {
        bridge.layerInfos()
    }

    func bridgeFolderInfos() -> [APPaintFolderInfo] {
        bridge.folderInfos()
    }

    func bridgeActiveLayerIndex() -> Int {
        Int(bridge.activeLayerIndex)
    }

    func setBridgeActiveLayerIndex(_ index: Int) {
        bridge.activeLayerIndex = index
    }

    func requireExistingLayerIndex(_ index: Int, label: String = "Layer index") {
        precondition(bridgeLayerInfos().indices.contains(index), "\(label) must resolve to an existing layer.")
    }

    func requireValidLayerAnchor(_ index: Int, label: String = "Layer anchor index") {
        precondition(index < 0 || bridgeLayerInfos().indices.contains(index), "\(label) must resolve to an existing layer or be -1.")
    }

    func consumeDirtyUpdate() -> IncrementalLayerUpdate? {
        bridgeQueryService.consumeDirtyUpdate(from: bridge)
    }

    func pixelDataForLayer(index: Int) -> Data {
        bridgeQueryService.pixelDataForLayer(index: index, bridge: bridge)
    }

    func bridgeMaskDataForLayer(index: Int) -> Data? {
        bridge.layerMaskDataForLayer(at: index) as Data?
    }

    func bridgeCompositePixelData() -> Data {
        bridge.compositePixelData() as Data
    }

    func bridgeCompositeImageRef() -> CGImage? {
        bridge.makeCompositeImage()
    }

    func bridgeImageRefForLayer(index: Int) -> CGImage? {
        bridge.makeImageForLayer(at: index)
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

    func bridgeBeginStroke(brush: APBrushDescriptor, point: APStrokePoint) {
        bridge.beginStroke(brush: brush, point: point)
    }

    func bridgeAppendStroke(point: APStrokePoint) {
        bridge.appendStroke(point: point)
    }

    func bridgeEndStroke() {
        bridge.endStroke()
    }

    func bridgeCancelStroke() {
        bridge.cancelStroke()
    }

    func bridgeFill(at point: CGPoint, brush: APBrushDescriptor) {
        bridge.fill(at: point, brush: brush)
    }

    func bridgeCanUndo() -> Bool {
        bridge.canUndo()
    }

    func bridgeCanRedo() -> Bool {
        bridge.canRedo()
    }

    func bridgeUndo() -> Bool {
        bridge.undo()
    }

    func bridgeRedo() -> Bool {
        bridge.redo()
    }

    func bridgeAddLayer(name: String) -> Int {
        Int(bridge.addLayer(name: name))
    }

    func bridgeDuplicateLayer(index: Int, name: String) -> Int {
        Int(bridge.duplicateLayer(at: index, name: name))
    }

    func bridgeDeleteLayer(index: Int) -> Bool {
        bridge.deleteLayer(at: index)
    }

    func bridgeMoveLayer(from index: Int, to destinationIndex: Int) -> Bool {
        bridge.moveLayer(at: index, to: destinationIndex)
    }

    func bridgeCreateFolder(name: String, layerIndex: Int) -> Int {
        Int(bridge.createFolder(name: name, layerIndex: layerIndex))
    }

    func bridgeDeleteFolder(id folderID: Int) -> Bool {
        bridge.deleteFolder(id: folderID)
    }

    func bridgeSetFolderVisible(_ isVisible: Bool, folderID: Int) {
        bridge.setFolderVisible(isVisible, folderID: folderID)
    }

    func bridgeSetFolderName(_ name: String, folderID: Int) {
        bridge.setFolderName(name, folderID: folderID)
    }

    func bridgeSetFolderExpanded(_ isExpanded: Bool, folderID: Int) {
        bridge.setFolderExpanded(isExpanded, folderID: folderID)
    }

    func bridgeSetLayerFolder(index: Int, folderID: Int) -> Bool {
        bridge.setLayerFolder(at: index, folderID: folderID)
    }

    func bridgeSetLayerName(_ name: String, index: Int) {
        bridge.setLayerName(name, at: index)
    }

    func bridgeSetLayerVisible(_ isVisible: Bool, index: Int) {
        bridge.setLayerVisible(isVisible, at: index)
    }

    func bridgeSetLayerLocked(_ isLocked: Bool, index: Int) {
        bridge.setLayerLocked(isLocked, at: index)
    }

    func bridgeSetLayerAlphaLocked(_ isAlphaLocked: Bool, index: Int) {
        bridge.setLayerAlphaLocked(isAlphaLocked, at: index)
    }

    func bridgeSetLayerClipped(_ isClipped: Bool, index: Int) {
        bridge.setLayerClipped(isClipped, at: index)
    }

    func bridgeSetLayerOpacity(_ opacity: CGFloat, index: Int) {
        bridge.setLayerOpacity(opacity, at: index)
    }

    func bridgeSetLayerBlendMode(_ blendMode: String, index: Int) {
        bridge.setLayerBlendMode(blendMode, at: index)
    }

    func bridgeReplaceLayerPixels(index: Int, data: Data, transient: Bool = false) {
        if transient {
            bridge.replaceLayerPixelsTransient(at: index, data: data)
        } else {
            bridge.replaceLayerPixels(at: index, data: data)
        }
    }

    func bridgeReplaceLayerMask(index: Int, data: Data) {
        bridge.replaceLayerMask(at: index, data: data)
    }

    func bridgeClearLayerMask(index: Int) {
        bridge.clearLayerMask(at: index)
    }

    func bridgeApplyLayerMask(index: Int) -> Bool {
        bridge.applyLayerMask(at: index)
    }

    func bridgeClearLayer(index: Int) {
        bridge.clearLayer(at: index)
    }

    func bridgeApplyLayerProcessing(index: Int, descriptor: APPaintLayerProcessingDescriptor) -> Bool {
        bridge.applyLayerProcessing(at: index, descriptor: descriptor)
    }

    func bridgeClearHistory() {
        bridge.clearHistory()
    }
}
