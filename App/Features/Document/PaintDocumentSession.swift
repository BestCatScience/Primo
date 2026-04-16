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
    private(set) var bridge: APPaintDocumentBridge

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
