import Accelerate
import CoreGraphics
import Foundation
import os
import PrimoDocumentApplication
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
        DocumentInfrastructureDiagnostics.debug(
            Self.logger,
            "PaintDocumentSession initialized \(width)x\(height) in \(String(describing: duration))"
        )
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
    var documentLayerMutationContext: DocumentLayerMutationContext {
        DocumentLayerMutationContext(
            layerCount: documentGateway.queries.layerInfos().count,
            folderIDs: Set(documentGateway.queries.folderInfos().map { Int($0.folderID) }),
            isLayerLocked: { [documentGateway] index in
                documentGateway.queries.isLayerLocked(index: index)
            }
        )
    }

    struct SessionMutationContract<Success> {
        let requirements: [DocumentMutationCommand]
        let applySideEffects: (PaintDocumentSession, Success) -> Void

        init(
            requirements: [DocumentMutationCommand] = [],
            applySideEffects: @escaping (PaintDocumentSession, Success) -> Void = { _, _ in }
        ) {
            self.requirements = requirements
            self.applySideEffects = applySideEffects
        }
    }

    var documentGateway: PaintDocumentSessionDocumentGateway {
        PaintDocumentSessionDocumentGateway(
            bridge: bridge,
            bridgeService: services.bridge
        )
    }

    var documentMutationValidator: DocumentMutationValidator {
        DocumentMutationValidator()
    }

    var documentMutationValidationContext: DocumentMutationValidationContext {
        DocumentMutationValidationContext(
            layerCount: documentGateway.queries.layerInfos().count,
            folderIDs: Set(documentGateway.queries.folderInfos().map { Int($0.folderID) }),
            isLayerLocked: { [documentGateway] index in
                documentGateway.queries.isLayerLocked(index: index)
            }
        )
    }

    func mutationFailure(
        for issue: DocumentMutationValidationIssue
    ) -> DocumentMutationFailure {
        switch issue {
        case let .invalidLayerIndex(index):
            return .invalidLayerIndex(index)
        case let .invalidFolderID(folderID):
            return .invalidFolderID(folderID)
        case let .layerLocked(index):
            return .layerLocked(index)
        }
    }

    func mutationFailure(
        for failure: DocumentLayerMutationFailure
    ) -> DocumentMutationFailure {
        switch failure {
        case let .invalidLayerIndex(index):
            return .invalidLayerIndex(index)
        case let .invalidFolderID(folderID):
            return .invalidFolderID(folderID)
        case let .layerLocked(index):
            return .layerLocked(index)
        case let .invalidOpacity(opacity):
            return .invalidOpacity(opacity)
        case let .bridgeMutationFailed(message):
            return .bridgeMutationFailed(message)
        }
    }

    func validate(
        _ command: DocumentMutationCommand
    ) -> DocumentMutationFailure? {
        documentMutationValidator
            .validate(command, in: documentMutationValidationContext)
            .map(mutationFailure(for:))
    }

    func validate(
        _ commands: [DocumentMutationCommand]
    ) -> DocumentMutationFailure? {
        commands.lazy.compactMap(validate(_:)).first
    }

    func applyLayerIndexMutation(
        _ mutation: DocumentLayerIndexMutation
    ) {
        switch mutation {
        case let .duplication(sourceIndex, duplicatedIndex):
            if let textLayer = storedTextLayer(at: sourceIndex) {
                remapStoredTextLayersForDuplication(
                    of: sourceIndex,
                    duplicatedIndex: duplicatedIndex,
                    duplicate: textLayer
                )
            } else {
                remapStoredTextLayersForInsertion(at: duplicatedIndex)
            }
        case let .deletion(index):
            remapStoredTextLayersForDeletion(of: index)
        case let .move(sourceIndex, destinationIndex):
            remapStoredTextLayersForMove(from: sourceIndex, to: destinationIndex)
        }
    }

    func applyLayerLifecycleEvent(
        _ event: DocumentLayerMutationEvent
    ) {
        switch event {
        case let .addLayer(name, index):
            applyLayerLifecycleMutation(
                at: index,
                recording: .addLayer(name: name)
            )
        case let .duplicateLayer(index, _, name):
            applyDocumentLifecycleMutation(
                recording: .duplicateLayer(index: .unchecked(index), name: name)
            )
        case let .deleteLayer(index):
            applyDocumentLifecycleMutation(
                recording: .deleteLayer(index: .unchecked(index))
            )
        case let .moveLayer(index, destinationIndex):
            applyDocumentLifecycleMutation(
                recording: .moveLayer(
                    index: .unchecked(index),
                    destinationIndex: .unchecked(destinationIndex)
                )
            )
        case let .createFolder(folderID, name, anchorLayerIndex):
            applyRecordedLifecycleMutation(
                recording: .createFolder(
                    folderID: .unchecked(folderID),
                    name: name,
                    anchorLayerIndex: anchorLayerIndex.map(DocumentLayerIndex.unchecked)
                ),
                captureFrame: false
            )
        case let .deleteFolder(folderID):
            applyRecordedLifecycleMutation(
                recording: .deleteFolder(folderID: .unchecked(folderID))
            )
        case let .assignLayerToFolder(index, folderID):
            applyRecordedLifecycleMutation(
                recording: .assignLayerToFolder(
                    index: .unchecked(index),
                    folderID: folderID.map(DocumentFolderID.unchecked)
                )
            )
        case let .setLayerVisibility(index, isVisible):
            applyLayerLifecycleMutation(
                at: index,
                recording: .setLayerVisibility(index: .unchecked(index), isVisible: isVisible)
            )
        case let .setLayerLocked(index, isLocked):
            applyLayerLifecycleMutation(
                at: index,
                recording: .setLayerLocked(index: .unchecked(index), isLocked: isLocked)
            )
        case let .setLayerAlphaLocked(index, isAlphaLocked):
            applyLayerLifecycleMutation(
                at: index,
                recording: .setLayerAlphaLocked(index: .unchecked(index), isAlphaLocked: isAlphaLocked)
            )
        case let .setLayerClipped(index, isClipped):
            applyLayerLifecycleMutation(
                at: index,
                recording: .setLayerClipped(index: .unchecked(index), isClipped: isClipped)
            )
        case let .setLayerOpacity(index, opacity):
            applyLayerLifecycleMutation(
                at: index,
                recording: .setLayerOpacity(index: .unchecked(index), opacity: opacity)
            )
        case let .setLayerBlendMode(index, blendMode):
            applyLayerLifecycleMutation(
                at: index,
                recording: .setLayerBlendMode(index: .unchecked(index), blendMode: blendMode)
            )
        case let .setFolderVisibility(folderID, isVisible):
            applyRecordedLifecycleMutation(
                recording: .setFolderVisibility(folderID: .unchecked(folderID), isVisible: isVisible)
            )
        }
    }

    func executeMutation<Success>(
        _ contract: SessionMutationContract<Success> = .init(),
        perform: () -> Result<Success, DocumentMutationFailure>
    ) -> Result<Success, DocumentMutationFailure> {
        if let failure = validate(contract.requirements) {
            return .failure(failure)
        }

        switch perform() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(value):
            contract.applySideEffects(self, value)
            return .success(value)
        }
    }

    func beginPixelLayerMutation(
        at index: Int,
        preservesTextLayerMetadata: Bool = false
    ) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.layer(index: index, requiresUnlocked: true)],
                applySideEffects: { session, _ in
                    guard !preservesTextLayerMetadata else { return }
                    session.clearTextLayerData(index: index)
                }
            )
        ) {
            .success(())
        }
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

        func pixelDataForLayer(index: Int, rect: LayerPixelRect) -> Data {
            bridgeService.queries.pixelDataForLayer(index: index, rect: rect, bridge: bridge)
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

        func undoResult() -> DocumentMutationResult {
            bridge.undo()
                ? .success(())
                : .failure(.bridgeMutationFailed("undo"))
        }

        func redoResult() -> DocumentMutationResult {
            bridge.redo()
                ? .success(())
                : .failure(.bridgeMutationFailed("redo"))
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

        func applyCommittedStroke(
            samples: [StylusSample],
            brush: BrushRuntimeSettings,
            layerIndex: Int
        ) -> Bool {
            bridge.applyCommittedStroke(
                brush: bridgeService.descriptors.makeBrushDescriptor(from: brush),
                points: bridgeService.strokePoints.makeStrokePoints(from: samples),
                layerIndex: layerIndex
            )
        }

        func applyBlurStroke(
            samples: [StylusSample],
            brush: BrushRuntimeSettings,
            layerIndex: Int,
            transient: Bool
        ) -> Bool {
            bridge.applyBlurStroke(
                brush: bridgeService.descriptors.makeBrushDescriptor(from: brush),
                points: bridgeService.strokePoints.makeStrokePoints(from: samples),
                layerIndex: layerIndex,
                transient: transient
            )
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

        func deleteLayerResult(index: Int) -> DocumentMutationResult {
            bridge.deleteLayer(at: index)
                ? .success(())
                : .failure(.bridgeMutationFailed("deleteLayer"))
        }

        func moveLayerResult(
            from index: Int,
            to destinationIndex: Int
        ) -> DocumentMutationResult {
            bridge.moveLayer(at: index, to: destinationIndex)
                ? .success(())
                : .failure(.bridgeMutationFailed("moveLayer"))
        }

        func createFolder(name: String, layerIndex: Int) -> Int {
            Int(bridge.createFolder(name: name, layerIndex: layerIndex))
        }

        func deleteFolderResult(id folderID: Int) -> DocumentMutationResult {
            bridge.deleteFolder(id: folderID)
                ? .success(())
                : .failure(.bridgeMutationFailed("deleteFolder"))
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

        func setLayerFolderResult(index: Int, folderID: Int) -> DocumentMutationResult {
            bridge.setLayerFolder(at: index, folderID: folderID)
                ? .success(())
                : .failure(.bridgeMutationFailed("assignLayerToFolder"))
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

        func replaceLayerPixels(index: Int, rect: LayerPixelRect, data: Data) -> Bool {
            guard !rect.isEmpty else { return false }
            let dirtyRect = APDirtyRect(
                originX: rect.originX,
                originY: rect.originY,
                width: rect.width,
                height: rect.height
            )
            return bridge.replaceLayerPixels(at: index, rect: dirtyRect, data: data)
        }

        func replaceLayerMask(index: Int, data: Data) {
            bridge.replaceLayerMask(at: index, data: data)
        }

        func clearLayerMask(index: Int) {
            bridge.clearLayerMask(at: index)
        }

        func applyLayerMaskResult(index: Int) -> DocumentMutationResult {
            bridge.applyLayerMask(at: index)
                ? .success(())
                : .failure(.bridgeMutationFailed("applyLayerMask"))
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

        func applyLayerProcessingResult(
            index: Int,
            descriptor: APPaintLayerProcessingDescriptor,
            operation: String
        ) -> DocumentMutationResult {
            bridge.applyLayerProcessing(at: index, descriptor: descriptor)
                ? .success(())
                : .failure(.bridgeMutationFailed(operation))
        }

        func applyLayerProcessingResult(
            index: Int,
            request: LayerProcessingRequest,
            operation: String
        ) -> DocumentMutationResult {
            applyLayerProcessingResult(
                index: index,
                descriptor: makeProcessingDescriptor(from: request),
                operation: operation
            )
        }
    }
}

extension PaintDocumentSessionDocumentGateway.LayerAccess: LayerStructureGateway {
    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentLayerMutationResult {
        moveLayerResult(from: index, to: destinationIndex)
            .mapError { failure in
                switch failure {
                case let .bridgeMutationFailed(message):
                    return .bridgeMutationFailed(message)
                default:
                    return .bridgeMutationFailed("moveLayer")
                }
            }
    }

    func createFolder(name: String, anchorLayerIndex: Int) -> Int {
        createFolder(name: name, layerIndex: anchorLayerIndex)
    }

    func assignLayer(index: Int, toFolder folderID: Int) -> DocumentLayerMutationResult {
        setLayerFolderResult(index: index, folderID: folderID)
            .mapError { failure in
                switch failure {
                case let .bridgeMutationFailed(message):
                    return .bridgeMutationFailed(message)
                default:
                    return .bridgeMutationFailed("assignLayerToFolder")
                }
            }
    }

    func deleteLayer(index: Int) -> DocumentLayerMutationResult {
        deleteLayerResult(index: index)
            .mapError { failure in
                switch failure {
                case let .bridgeMutationFailed(message):
                    return .bridgeMutationFailed(message)
                default:
                    return .bridgeMutationFailed("deleteLayer")
                }
            }
    }

    func deleteFolder(id folderID: Int) -> DocumentLayerMutationResult {
        deleteFolderResult(id: folderID)
            .mapError { failure in
                switch failure {
                case let .bridgeMutationFailed(message):
                    return .bridgeMutationFailed(message)
                default:
                    return .bridgeMutationFailed("deleteFolder")
                }
            }
    }
}

extension PaintDocumentSessionDocumentGateway.LayerAccess: LayerAttributeGateway {
    func setLayerOpacity(_ opacity: Double, index: Int) {
        setLayerOpacity(CGFloat(opacity), index: index)
    }

    func setLayerBlendMode(_ blendMode: LayerBlendMode, index: Int) {
        setLayerBlendMode(blendMode.rawValue, index: index)
    }
}

extension PaintDocumentSessionDocumentGateway.LayerAccess: DocumentEditorGateway {}
