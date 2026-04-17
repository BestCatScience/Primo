import Accelerate
import CoreGraphics
import Foundation
import os
import UIKit
import simd

final class PaintDocumentSession {
    static let logger = Logger(subsystem: "com.primo.app", category: "Document")
    static let maxTimelapseFrames = 20_000

    private let services: PaintDocumentSessionServices
    private let sessionState: PaintDocumentSessionState
    private var bridge: APPaintDocumentBridge

    init(
        width: Int = 1152,
        height: Int = 1536,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) {
        let clock = ContinuousClock()
        let start = clock.now
        self.services = PaintDocumentSessionServices(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
        self.bridge = APPaintDocumentBridge(width: width, height: height)
        let timelapseDirectoryURL = services.timelapse.makeDirectoryURL()
        self.sessionState = PaintDocumentSessionState(timelapseDirectoryURL: timelapseDirectoryURL)
        try? services.fileIO.createDirectory(timelapseDirectoryURL, true)
        let duration = start.duration(to: clock.now)
        Self.logger.debug("PaintDocumentSession initialized \(width)x\(height) in \(String(describing: duration), privacy: .public)")
    }

    deinit {
        try? services.timelapse.removeDirectory(at: timelapseDirectoryURL)
    }

    var currentPaperStyle: CanvasPaperStyle {
        paperStyleValue
    }

    var fileClient: FileClient { services.fileIO }
    var dateClient: DateClient { services.clock }
    var uuidClient: UUIDClient { services.ids }
    var persistenceService: PaintDocumentPersistenceService { services.persistence }
    var timelapseService: PaintDocumentTimelapseService { services.timelapse }
    var editingLifecycleService: PaintDocumentEditingLifecycleService { services.editingLifecycle }
    var bridgeQueryService: PaintDocumentBridgeQueryService { services.bridge.queries }
    var bridgePixelService: PaintDocumentBridgePixelService { services.bridge.pixels }
    var bridgeDescriptorService: PaintDocumentBridgeDescriptorService { services.bridge.descriptors }
    var bridgeStrokeService: PaintDocumentBridgeStrokeService { services.bridge.strokePoints }
    var geometryService: PaintDocumentGeometryService { services.geometry }
    var blurService: PaintDocumentBlurService { services.blur }

    var timelapseDirectoryURL: URL { sessionState.timelapse.directoryURL }

    var paperStyleValue: CanvasPaperStyle { sessionState.presentation.paperStyle }
    var timelapseUsesOperationPersistence: Bool { sessionState.timelapse.usesOperationPersistence }
    var timelapseFramesSnapshot: [TimelapseFrame] { sessionState.timelapse.frames }
    var timelapseEventsSnapshot: [TimelapseOperation] { sessionState.timelapse.events }

    func replaceBridge(with newBridge: APPaintDocumentBridge) {
        bridge = newBridge
    }

    func advancePresentationRevision() -> Int {
        sessionState.presentation.advanceRevision()
    }

    func setStoredPaperStyle(_ paperStyle: CanvasPaperStyle) {
        sessionState.presentation.setPaperStyle(paperStyle)
    }

    func cachedThumbnailData(for index: Int) -> Data? {
        sessionState.presentation.cachedThumbnailData(for: index)
    }

    func storeThumbnailData(_ data: Data?, for index: Int) {
        sessionState.presentation.storeThumbnailData(data, for: index)
    }

    func invalidateStoredThumbnailCache(for index: Int? = nil) {
        sessionState.presentation.invalidateThumbnailCache(for: index)
    }

    func recordTimelapseEvents(_ events: [TimelapseOperation]) {
        sessionState.timelapse.record(events: events)
    }

    func reserveNextTimelapseFrameURL() -> URL {
        sessionState.timelapse.reserveNextFrameURL(using: timelapseService)
    }

    func appendStoredTimelapseFrame(_ frame: TimelapseFrame) -> TimelapseFrame? {
        sessionState.timelapse.appendFrame(frame, maxFrameCount: Self.maxTimelapseFrames)
    }

    @discardableResult
    func resetStoredTimelapseHistory(keepingCapacity: Bool = false) -> [TimelapseFrame] {
        sessionState.timelapse.resetHistory(keepingCapacity: keepingCapacity)
    }

    func restoreStoredTimelapseOperations(_ events: [TimelapseOperation]) {
        sessionState.timelapse.restoreOperations(events)
    }

    func restoreStoredTimelapseFrames(_ frames: [TimelapseFrame]) {
        sessionState.timelapse.restoreFrames(frames)
    }

    func beginTrackedStroke(on layerIndex: Int, brush: BrushRuntimeSettings, sample: StylusSample) {
        sessionState.editing.stroke.begin(on: layerIndex, brush: brush, sample: sample)
    }

    func appendTrackedStroke(_ sample: StylusSample) {
        sessionState.editing.stroke.append(sample)
    }

    func finishTrackedStroke() -> TimelapseOperation? {
        sessionState.editing.stroke.takeRecordedOperation()
    }

    func resetTrackedStroke() {
        sessionState.editing.stroke.reset()
    }

    func beginOrContinueTrackedBlurStroke(on layerIndex: Int, brush: BrushRuntimeSettings) {
        sessionState.editing.blurStroke.beginOrContinue(on: layerIndex, brush: brush)
    }

    func appendTrackedBlurSamples(_ samples: [StylusSample]) {
        sessionState.editing.blurStroke.append(contentsOf: samples)
    }

    var shouldApplyTrackedBlurTransiently: Bool {
        sessionState.editing.blurStroke.shouldApplyTransiently
    }

    func markTrackedBlurHistoryCaptured() {
        sessionState.editing.blurStroke.markHistoryCaptured()
    }

    func finishTrackedBlurStroke() -> TimelapseOperation? {
        sessionState.editing.blurStroke.takeRecordedOperation()
    }

    func resetTrackedEditingState() {
        sessionState.editing.resetAll()
    }

    func hasStoredTextLayer(at index: Int) -> Bool {
        sessionState.textLayers.contains(index)
    }

    func storedTextLayer(at index: Int) -> TextLayerData? {
        sessionState.textLayers.data(at: index)
    }

    func setStoredTextLayer(_ textLayer: TextLayerData, at index: Int) {
        sessionState.textLayers.set(textLayer, at: index)
    }

    func removeStoredTextLayer(at index: Int) {
        sessionState.textLayers.remove(at: index)
    }

    func storedTextLayerSnapshot() -> [Int: TextLayerData] {
        sessionState.textLayers.snapshot()
    }

    func replaceStoredTextLayers(with newValues: [Int: TextLayerData]) {
        sessionState.textLayers.replaceAll(with: newValues)
    }

    func remapStoredTextLayersForInsertion(at insertedIndex: Int) {
        sessionState.textLayers.remapForInsertion(at: insertedIndex)
    }

    func remapStoredTextLayersForDuplication(of sourceIndex: Int, duplicatedIndex: Int, duplicate: TextLayerData) {
        sessionState.textLayers.remapForDuplication(of: sourceIndex, duplicatedIndex: duplicatedIndex, duplicate: duplicate)
    }

    func remapStoredTextLayersForDeletion(of deletedIndex: Int) {
        sessionState.textLayers.remapForDeletion(of: deletedIndex)
    }

    func remapStoredTextLayersForMove(from sourceIndex: Int, to destinationIndex: Int) {
        sessionState.textLayers.remapForMove(from: sourceIndex, to: destinationIndex)
    }
}

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

    func containsLayerIndex(_ index: Int) -> Bool {
        bridgeLayerInfos().indices.contains(index)
    }

    func containsValidLayerAnchor(_ index: Int) -> Bool {
        index < 0 || containsLayerIndex(index)
    }

    func containsFolderID(_ folderID: Int) -> Bool {
        bridgeFolderInfos().contains { Int($0.folderID) == folderID }
    }

    @discardableResult
    func beginPixelLayerMutation(
        at index: Int,
        preservesTextLayerMetadata: Bool = false
    ) -> Bool {
        guard containsLayerIndex(index) else { return false }
        guard !isLayerLocked(index: index) else { return false }
        if !preservesTextLayerMetadata {
            clearTextLayerData(index: index)
        }
        return true
    }

    func applyRecordedLifecycleMutation(
        invalidating invalidation: PaintDocumentThumbnailInvalidation = .none,
        recording events: [TimelapseOperation] = [],
        captureFrame: Bool = true
    ) {
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: events,
                invalidating: invalidation,
                captureFrame: captureFrame
            )
        )
    }

    func applyRecordedLifecycleMutation(
        invalidating invalidation: PaintDocumentThumbnailInvalidation = .none,
        recording event: TimelapseOperation,
        captureFrame: Bool = true
    ) {
        applyRecordedLifecycleMutation(
            invalidating: invalidation,
            recording: [event],
            captureFrame: captureFrame
        )
    }

    func applyLayerLifecycleMutation(
        at index: Int,
        recording events: [TimelapseOperation] = [],
        captureFrame: Bool = true
    ) {
        applyRecordedLifecycleMutation(
            invalidating: .layer(index),
            recording: events,
            captureFrame: captureFrame
        )
    }

    func applyLayerLifecycleMutation(
        at index: Int,
        recording event: TimelapseOperation,
        captureFrame: Bool = true
    ) {
        applyLayerLifecycleMutation(
            at: index,
            recording: [event],
            captureFrame: captureFrame
        )
    }

    func applyDocumentLifecycleMutation(
        recording events: [TimelapseOperation] = [],
        captureFrame: Bool = true
    ) {
        applyRecordedLifecycleMutation(
            invalidating: .all,
            recording: events,
            captureFrame: captureFrame
        )
    }

    func applyDocumentLifecycleMutation(
        recording event: TimelapseOperation,
        captureFrame: Bool = true
    ) {
        applyDocumentLifecycleMutation(
            recording: [event],
            captureFrame: captureFrame
        )
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
