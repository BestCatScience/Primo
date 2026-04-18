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
        do {
            // Best-effort cleanup/setup for transient timelapse artifacts owned by the session.
            try services.fileIO.createDirectory(timelapseDirectoryURL, true)
        } catch {
        }
        let duration = start.duration(to: clock.now)
        Self.logger.debug("PaintDocumentSession initialized \(width)x\(height) in \(String(describing: duration), privacy: .public)")
    }

    deinit {
        do {
            // Best-effort cleanup for transient timelapse artifacts owned by the session.
            try services.timelapse.removeDirectory(at: timelapseDirectoryURL)
        } catch {
        }
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
    var documentGateway: PaintDocumentSessionDocumentGateway {
        PaintDocumentSessionDocumentGateway(
            bridge: bridge,
            bridgeService: services.bridge
        )
    }

    func containsLayerIndex(_ index: Int) -> Bool {
        documentGateway.queries.layerInfos().indices.contains(index)
    }

    func containsValidLayerAnchor(_ index: Int) -> Bool {
        index < 0 || containsLayerIndex(index)
    }

    func containsFolderID(_ folderID: Int) -> Bool {
        documentGateway.queries.folderInfos().contains { Int($0.folderID) == folderID }
    }

    func layerMutationFailure(
        _ index: Int,
        requiresUnlocked: Bool = false
    ) -> DocumentMutationFailure? {
        guard containsLayerIndex(index) else {
            return .invalidLayerIndex(index)
        }
        if requiresUnlocked, isLayerLocked(index: index) {
            return .layerLocked(index)
        }
        return nil
    }

    func folderMutationFailure(_ folderID: Int) -> DocumentMutationFailure? {
        guard containsFolderID(folderID) else {
            return .invalidFolderID(folderID)
        }
        return nil
    }

    func wrapMutationResult(
        _ didMutate: Bool,
        operation: String
    ) -> DocumentMutationResult {
        didMutate ? .success(()) : .failure(.bridgeMutationFailed(operation))
    }

    func wrapIndexedMutationResult(
        _ value: Int,
        operation: String
    ) -> DocumentIndexedMutationResult {
        value >= 0 ? .success(value) : .failure(.bridgeMutationFailed(operation))
    }

    func beginPixelLayerMutation(
        at index: Int,
        preservesTextLayerMetadata: Bool = false
    ) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index, requiresUnlocked: true) {
            return .failure(failure)
        }
        if !preservesTextLayerMetadata {
            clearTextLayerData(index: index)
        }
        return .success(())
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
        documentGateway.queries.consumeDirtyUpdate()
    }

    func pixelDataForLayer(index: Int) -> Data {
        documentGateway.queries.pixelDataForLayer(index: index)
    }

    func isLayerLocked(index: Int) -> Bool {
        documentGateway.queries.isLayerLocked(index: index)
    }

    func isLayerAlphaLocked(index: Int) -> Bool {
        documentGateway.queries.isLayerAlphaLocked(index: index)
    }

    static func pixelDataByPreservingExistingAlpha(source: Data, existing: Data) -> Data {
        PaintDocumentBridgePixelService().pixelDataByPreservingExistingAlpha(source: source, existing: existing)
    }

    static func pixelData(from cgImage: CGImage, size: CGSize) -> Data? {
        PaintDocumentBridgePixelService().pixelData(from: cgImage, size: size)
    }
}

struct PaintDocumentSessionDocumentGateway {
    fileprivate let bridge: APPaintDocumentBridge
    fileprivate let bridgeService: PaintDocumentBridgeService

    var queries: QueryAccess {
        QueryAccess(bridge: bridge, bridgeService: bridgeService)
    }

    var history: HistoryAccess {
        HistoryAccess(bridge: bridge)
    }

    var strokes: StrokeAccess {
        StrokeAccess(bridge: bridge, bridgeService: bridgeService)
    }

    var layers: LayerAccess {
        LayerAccess(bridge: bridge)
    }

    var processing: ProcessingAccess {
        ProcessingAccess(bridge: bridge, bridgeService: bridgeService)
    }

    struct QueryAccess {
        fileprivate let bridge: APPaintDocumentBridge
        fileprivate let bridgeService: PaintDocumentBridgeService

        var canvasWidth: Int {
            Int(bridge.width)
        }

        var canvasHeight: Int {
            Int(bridge.height)
        }

        var canvasSize: CGSize {
            CGSize(width: bridge.width, height: bridge.height)
        }

        func layerInfos() -> [APPaintLayerInfo] {
            bridge.layerInfos()
        }

        func folderInfos() -> [APPaintFolderInfo] {
            bridge.folderInfos()
        }

        func activeLayerIndex() -> Int {
            Int(bridge.activeLayerIndex)
        }

        func layerMaskDataForLayer(index: Int) -> Data? {
            bridge.layerMaskDataForLayer(at: index) as Data?
        }

        func compositePixelData() -> Data {
            bridge.compositePixelData() as Data
        }

        func compositeImageRef() -> CGImage? {
            bridge.makeCompositeImage()
        }

        func imageRefForLayer(index: Int) -> CGImage? {
            bridge.makeImageForLayer(at: index)
        }

        func consumeDirtyUpdate() -> IncrementalLayerUpdate? {
            bridgeService.queries.consumeDirtyUpdate(from: bridge)
        }

        func pixelDataForLayer(index: Int) -> Data {
            bridgeService.queries.pixelDataForLayer(index: index, bridge: bridge)
        }

        func isLayerLocked(index: Int) -> Bool {
            bridgeService.queries.isLayerLocked(index: index, bridge: bridge)
        }

        func isLayerAlphaLocked(index: Int) -> Bool {
            bridgeService.queries.isLayerAlphaLocked(index: index, bridge: bridge)
        }
    }

    struct HistoryAccess {
        fileprivate let bridge: APPaintDocumentBridge

        func canUndo() -> Bool {
            bridge.canUndo()
        }

        func canRedo() -> Bool {
            bridge.canRedo()
        }

        func undo() -> Bool {
            bridge.undo()
        }

        func redo() -> Bool {
            bridge.redo()
        }

        func clearHistory() {
            bridge.clearHistory()
        }
    }

    struct StrokeAccess {
        fileprivate let bridge: APPaintDocumentBridge
        fileprivate let bridgeService: PaintDocumentBridgeService

        func begin(sample: StylusSample, brush: BrushRuntimeSettings) {
            bridge.beginStroke(
                brush: bridgeService.descriptors.makeBrushDescriptor(from: brush),
                point: bridgeService.strokePoints.makeStrokePoint(from: sample)
            )
        }

        func append(sample: StylusSample) {
            bridge.appendStroke(
                point: bridgeService.strokePoints.makeStrokePoint(from: sample)
            )
        }

        func end() {
            bridge.endStroke()
        }

        func cancel() {
            bridge.cancelStroke()
        }

        func fill(sample: StylusSample, brush: BrushRuntimeSettings) {
            bridge.fill(
                at: sample.point,
                brush: bridgeService.descriptors.makeBrushDescriptor(from: brush)
            )
        }
    }

    struct LayerAccess {
        fileprivate let bridge: APPaintDocumentBridge

        func setActiveLayerIndex(_ index: Int) {
            bridge.activeLayerIndex = index
        }

        func addLayer(name: String) -> Int {
            Int(bridge.addLayer(name: name))
        }

        func duplicateLayer(index: Int, name: String) -> Int {
            Int(bridge.duplicateLayer(at: index, name: name))
        }

        func deleteLayer(index: Int) -> Bool {
            bridge.deleteLayer(at: index)
        }

        func moveLayer(from index: Int, to destinationIndex: Int) -> Bool {
            bridge.moveLayer(at: index, to: destinationIndex)
        }

        func createFolder(name: String, layerIndex: Int) -> Int {
            Int(bridge.createFolder(name: name, layerIndex: layerIndex))
        }

        func deleteFolder(id folderID: Int) -> Bool {
            bridge.deleteFolder(id: folderID)
        }

        func setFolderVisible(_ isVisible: Bool, folderID: Int) {
            bridge.setFolderVisible(isVisible, folderID: folderID)
        }

        func setFolderName(_ name: String, folderID: Int) {
            bridge.setFolderName(name, folderID: folderID)
        }

        func setFolderExpanded(_ isExpanded: Bool, folderID: Int) {
            bridge.setFolderExpanded(isExpanded, folderID: folderID)
        }

        func setLayerFolder(index: Int, folderID: Int) -> Bool {
            bridge.setLayerFolder(at: index, folderID: folderID)
        }

        func setLayerName(_ name: String, index: Int) {
            bridge.setLayerName(name, at: index)
        }

        func setLayerVisible(_ isVisible: Bool, index: Int) {
            bridge.setLayerVisible(isVisible, at: index)
        }

        func setLayerLocked(_ isLocked: Bool, index: Int) {
            bridge.setLayerLocked(isLocked, at: index)
        }

        func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: Int) {
            bridge.setLayerAlphaLocked(isAlphaLocked, at: index)
        }

        func setLayerClipped(_ isClipped: Bool, index: Int) {
            bridge.setLayerClipped(isClipped, at: index)
        }

        func setLayerOpacity(_ opacity: CGFloat, index: Int) {
            bridge.setLayerOpacity(opacity, at: index)
        }

        func setLayerBlendMode(_ blendMode: String, index: Int) {
            bridge.setLayerBlendMode(blendMode, at: index)
        }

        func replaceLayerPixels(index: Int, data: Data, transient: Bool = false) {
            if transient {
                bridge.replaceLayerPixelsTransient(at: index, data: data)
            } else {
                bridge.replaceLayerPixels(at: index, data: data)
            }
        }

        func replaceLayerMask(index: Int, data: Data) {
            bridge.replaceLayerMask(at: index, data: data)
        }

        func clearLayerMask(index: Int) {
            bridge.clearLayerMask(at: index)
        }

        func applyLayerMask(index: Int) -> Bool {
            bridge.applyLayerMask(at: index)
        }

        func clearLayer(index: Int) {
            bridge.clearLayer(at: index)
        }
    }

    struct ProcessingAccess {
        fileprivate let bridge: APPaintDocumentBridge
        fileprivate let bridgeService: PaintDocumentBridgeService

        func makeReplacePixelsDescriptor(pixelData: Data) -> APPaintLayerProcessingDescriptor {
            let descriptor = APPaintLayerProcessingDescriptor()
            descriptor.kind = APPaintLayerProcessingKind.replacePixels
            descriptor.pixelData = pixelData
            return descriptor
        }

        func makeClearLayerDescriptor() -> APPaintLayerProcessingDescriptor {
            let descriptor = APPaintLayerProcessingDescriptor()
            descriptor.kind = APPaintLayerProcessingKind.clear
            return descriptor
        }

        func makeProcessingDescriptor(from request: LayerProcessingRequest) -> APPaintLayerProcessingDescriptor {
            bridgeService.descriptors.makeProcessingDescriptor(from: request)
        }

        func applyLayerProcessing(index: Int, descriptor: APPaintLayerProcessingDescriptor) -> Bool {
            bridge.applyLayerProcessing(at: index, descriptor: descriptor)
        }

        func applyLayerProcessing(index: Int, request: LayerProcessingRequest) -> Bool {
            applyLayerProcessing(
                index: index,
                descriptor: makeProcessingDescriptor(from: request)
            )
        }
    }
}
