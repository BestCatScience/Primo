import Accelerate
import CoreGraphics
import Foundation
import os
import UIKit
import simd

final class PaintDocumentSession: @unchecked Sendable {
    static let logger = Logger(subsystem: "com.primo.app", category: "Document")
    static let maxTimelapseFrames = 20_000
    private let services: PaintDocumentSessionServices
    private var state: PaintDocumentSessionState
    var bridge: APPaintDocumentBridge

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
        self.state = PaintDocumentSessionState(timelapseDirectoryURL: timelapseDirectoryURL)
        try? services.fileIO.createDirectory(timelapseDirectoryURL, true)
        let duration = start.duration(to: clock.now)
        Self.logger.debug("PaintDocumentSession initialized \(width)x\(height) in \(String(describing: duration), privacy: .public)")
    }

    deinit {
        try? services.timelapse.removeDirectory(at: timelapseDirectoryURL)
    }

    var currentPaperStyle: CanvasPaperStyle {
        paperStyle
    }

    var fileClient: FileClient { services.fileIO }
    var dateClient: DateClient { services.clock }
    var uuidClient: UUIDClient { services.ids }
    var persistenceService: PaintDocumentPersistenceService { services.persistence }
    var timelapseService: PaintDocumentTimelapseService { services.timelapse }
    var editingLifecycleService: PaintDocumentEditingLifecycleService { services.editingLifecycle }
    var bridgeService: PaintDocumentBridgeService { services.bridge }
    var timelapseDirectoryURL: URL { state.timelapseDirectoryURL }
    var timelapseFrames: [TimelapseFrame] {
        get { state.timelapseFrames }
        set { state.timelapseFrames = newValue }
    }
    var timelapseEvents: [TimelapseOperation] {
        get { state.timelapseEvents }
        set { state.timelapseEvents = newValue }
    }
    var layerThumbnailCache: [Int: Data] {
        get { state.layerThumbnailCache }
        set { state.layerThumbnailCache = newValue }
    }
    var paperStyle: CanvasPaperStyle {
        get { state.paperStyle }
        set { state.paperStyle = newValue }
    }
    var nextTimelapseFrameID: Int {
        get { state.nextTimelapseFrameID }
        set { state.nextTimelapseFrameID = newValue }
    }
    var usesOperationTimelapsePersistence: Bool {
        get { state.usesOperationTimelapsePersistence }
        set { state.usesOperationTimelapsePersistence = newValue }
    }
    var textLayers: [Int: TextLayerData] {
        get { state.textLayers }
        set { state.textLayers = newValue }
    }
    private var revision: Int {
        get { state.revision }
        set { state.revision = newValue }
    }
    private var activeStrokeLayerIndex: Int? {
        get { state.activeStrokeLayerIndex }
        set { state.activeStrokeLayerIndex = newValue }
    }
    private var activeStrokeBrush: BrushRuntimeSettings? {
        get { state.activeStrokeBrush }
        set { state.activeStrokeBrush = newValue }
    }
    private var activeStrokeSamples: [StylusSample] {
        get { state.activeStrokeSamples }
        set { state.activeStrokeSamples = newValue }
    }
    private var activeBlurStrokeLayerIndex: Int? {
        get { state.activeBlurStrokeLayerIndex }
        set { state.activeBlurStrokeLayerIndex = newValue }
    }
    private var activeBlurStrokeBrush: BrushRuntimeSettings? {
        get { state.activeBlurStrokeBrush }
        set { state.activeBlurStrokeBrush = newValue }
    }
    private var activeBlurStrokeSamples: [StylusSample] {
        get { state.activeBlurStrokeSamples }
        set { state.activeBlurStrokeSamples = newValue }
    }
    private var blurStrokeHasCapturedHistory: Bool {
        get { state.blurStrokeHasCapturedHistory }
        set { state.blurStrokeHasCapturedHistory = newValue }
    }

    func applyLifecycleMutation(_ mutation: PaintDocumentLifecycleMutation) {
        switch mutation.thumbnailInvalidation {
        case .none:
            break
        case let .layer(index):
            invalidateThumbnailCache(for: index)
        case .all:
            invalidateThumbnailCache()
        }
        if !mutation.timelapseEvents.isEmpty {
            timelapseEvents.append(contentsOf: mutation.timelapseEvents)
        }
        if mutation.shouldCaptureTimelapseFrame {
            captureTimelapseFrame()
        }
    }

    func lightweightPresentation() -> PaintDocumentPresentation {
        let clock = ContinuousClock()
        let start = clock.now
        let infos = bridge.layerInfos()
        let folderInfos = bridge.folderInfos()
        let rows = buildLayerRows(from: infos)
        let duration = start.duration(to: clock.now)
        Self.logger.debug("lightweightPresentation produced \(rows.count) layers in \(String(describing: duration), privacy: .public)")
        return PaintDocumentPresentation(
            canvasSize: CGSize(width: bridge.width, height: bridge.height),
            activeLayerIndex: bridge.activeLayerIndex,
            layerRows: rows,
            layerSidebarRows: buildSidebarRows(layerInfos: infos, layerRows: rows, folderInfos: folderInfos),
            renderSnapshot: nil
        )
    }

    func presentation() -> PaintDocumentPresentation {
        let clock = ContinuousClock()
        let start = clock.now
        revision += 1
        let infos = bridge.layerInfos()
        let folderInfos = bridge.folderInfos()
        let folderVisibilityByID = Dictionary(uniqueKeysWithValues: folderInfos.map { (Int($0.folderID), $0.visible) })
        let compositePixelData = bridge.compositePixelData() as Data
        let snapshots = infos.enumerated().map { element in
            let index = element.offset
            let info = element.element
            return MetalLayerSnapshot(
                index: index,
                opacity: Float(info.opacity),
                visible: info.visible && (info.folderID < 0 || (folderVisibilityByID[Int(info.folderID)] ?? true)),
                isClipped: info.clipped,
                blendMode: LayerBlendMode(rawValue: info.blendMode) ?? .normal,
                thumbnailData: cachedLayerThumbnailData(index: index),
                pixelData: bridge.pixelDataForLayer(at: index) as Data
            )
        }
        let rows = buildLayerRows(from: infos)
        let duration = start.duration(to: clock.now)
        let megabytes = snapshots.reduce(0) { $0 + $1.pixelData.count } / 1_048_576
        Self.logger.debug("presentation produced revision \(self.revision) with \(snapshots.count) layers and \(megabytes) MB in \(String(describing: duration), privacy: .public)")
        return PaintDocumentPresentation(
            canvasSize: CGSize(width: bridge.width, height: bridge.height),
            activeLayerIndex: bridge.activeLayerIndex,
            layerRows: rows,
            layerSidebarRows: buildSidebarRows(layerInfos: infos, layerRows: rows, folderInfos: folderInfos),
            renderSnapshot: MetalDocumentSnapshot(
                width: bridge.width,
                height: bridge.height,
                revision: revision,
                compositePixelData: compositePixelData,
                layers: snapshots
            )
        )
    }

    func prewarmDrawingResources() {
        _ = bridge.compositePixelData()
    }

    func compositePixelData() -> Data {
        bridge.compositePixelData() as Data
    }

    func beginStroke(sample: StylusSample, brush: BrushRuntimeSettings) {
        activeStrokeLayerIndex = Int(bridge.activeLayerIndex)
        activeStrokeBrush = brush
        activeStrokeSamples = [sample]
        if let activeStrokeLayerIndex {
            clearTextLayerData(index: activeStrokeLayerIndex)
        }
        bridge.beginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: sample))
    }

    func appendStroke(sample: StylusSample) {
        activeStrokeSamples.append(sample)
        bridge.appendStroke(point: makeStrokePoint(from: sample))
    }

    func endStroke() {
        let activeLayerIndex = Int(bridge.activeLayerIndex)
        let recordedEvent: TimelapseOperation? = if let layerIndex = activeStrokeLayerIndex,
                                                   let brush = activeStrokeBrush,
                                                   !activeStrokeSamples.isEmpty {
            TimelapseOperation.stroke(
                layerIndex: layerIndex,
                brush: brush,
                samples: activeStrokeSamples
            )
        } else {
            nil
        }
        bridge.endStroke()
        editingLifecycleService.resetStrokeState(
            activeLayerIndex: &activeStrokeLayerIndex,
            activeBrush: &activeStrokeBrush,
            activeSamples: &activeStrokeSamples
        )
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: recordedEvent.map { [$0] } ?? [],
                invalidating: .layer(activeLayerIndex)
            )
        )
    }

    func cancelStroke() {
        let activeLayerIndex = Int(bridge.activeLayerIndex)
        bridge.cancelStroke()
        editingLifecycleService.resetStrokeState(
            activeLayerIndex: &activeStrokeLayerIndex,
            activeBrush: &activeStrokeBrush,
            activeSamples: &activeStrokeSamples
        )
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                invalidating: .layer(activeLayerIndex),
                captureFrame: false
            )
        )
    }

    func fill(sample: StylusSample, brush: BrushRuntimeSettings) {
        let layerIndex = Int(bridge.activeLayerIndex)
        guard !isLayerLocked(index: layerIndex) else { return }
        clearTextLayerData(index: layerIndex)
        bridge.fill(
            at: sample.point,
            brush: makeBrushDescriptor(from: brush)
        )
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .fill(
                    layerIndex: layerIndex,
                    brush: brush,
                    sample: sample
                ),
                invalidating: .layer(Int(bridge.activeLayerIndex))
            )
        )
    }

    func blur(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, captureTimelapse: Bool) {
        guard !samples.isEmpty else { return }
        guard !isLayerLocked(index: layerIndex) else { return }
        clearTextLayerData(index: layerIndex)
        if activeBlurStrokeLayerIndex != layerIndex {
            activeBlurStrokeLayerIndex = layerIndex
            activeBlurStrokeBrush = brush
            activeBlurStrokeSamples = []
            blurStrokeHasCapturedHistory = false
        }
        activeBlurStrokeSamples.append(contentsOf: samples)
        applyBlurStroke(samples: samples, brush: brush, layerIndex: layerIndex, transient: blurStrokeHasCapturedHistory)
        blurStrokeHasCapturedHistory = true
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                invalidating: .layer(layerIndex),
                captureFrame: captureTimelapse
            )
        )
    }

    func endBlurStroke() {
        let recordedEvent: TimelapseOperation? = if let layerIndex = activeBlurStrokeLayerIndex,
                                                   let brush = activeBlurStrokeBrush,
                                                   !activeBlurStrokeSamples.isEmpty {
            TimelapseOperation.blurStroke(
                layerIndex: layerIndex,
                brush: brush,
                samples: activeBlurStrokeSamples
            )
        } else {
            nil
        }
        editingLifecycleService.resetBlurStrokeState(
            activeLayerIndex: &activeBlurStrokeLayerIndex,
            activeBrush: &activeBlurStrokeBrush,
            activeSamples: &activeBlurStrokeSamples,
            blurStrokeHasCapturedHistory: &blurStrokeHasCapturedHistory
        )
        applyLifecycleMutation(
            editingLifecycleService.mutation(recording: recordedEvent.map { [$0] } ?? [])
        )
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
            applyLifecycleMutation(
                editingLifecycleService.mutation(recording: .undo, invalidating: .all)
            )
        }
        return didUndo
    }

    @discardableResult
    func redo() -> Bool {
        let didRedo = bridge.redo()
        if didRedo {
            applyLifecycleMutation(
                editingLifecycleService.mutation(recording: .redo, invalidating: .all)
            )
        }
        return didRedo
    }

    func addLayer(name: String) {
        bridge.activeLayerIndex = bridge.addLayer(name: name)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .addLayer(name: name),
                invalidating: .layer(Int(bridge.activeLayerIndex))
            )
        )
    }

    @discardableResult
    func duplicateLayer(index: Int, name: String) -> Int {
        let duplicatedIndex = Int(bridge.duplicateLayer(at: index, name: name))
        if duplicatedIndex >= 0 {
            if let textLayer = textLayers[index] {
                textLayers = remappedTextLayersForDuplication(of: index, duplicatedIndex: duplicatedIndex, duplicate: textLayer)
            } else {
                textLayers = remappedTextLayersForInsertion(at: duplicatedIndex)
            }
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .duplicateLayer(index: index, name: name),
                    invalidating: .all
                )
            )
        }
        return duplicatedIndex
    }

    @discardableResult
    func deleteLayer(index: Int) -> Bool {
        let didDelete = bridge.deleteLayer(at: index)
        if didDelete {
            textLayers = remappedTextLayersForDeletion(of: index)
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .deleteLayer(index: index),
                    invalidating: .all
                )
            )
        }
        return didDelete
    }

    @discardableResult
    func moveLayer(from index: Int, to destinationIndex: Int) -> Bool {
        let didMove = bridge.moveLayer(at: index, to: destinationIndex)
        if didMove {
            textLayers = remappedTextLayersForMove(from: index, to: destinationIndex)
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .moveLayer(index: index, destinationIndex: destinationIndex),
                    invalidating: .all
                )
            )
        }
        return didMove
    }

    @discardableResult
    func createFolder(name: String, layerIndex: Int) -> Int {
        let folderID = Int(bridge.createFolder(name: name, layerIndex: layerIndex))
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .createFolder(
                    folderID: folderID,
                    name: name,
                    anchorLayerIndex: layerIndex >= 0 ? layerIndex : nil
                ),
                captureFrame: false
            )
        )
        return folderID
    }

    @discardableResult
    func deleteFolder(folderID: Int) -> Bool {
        let didDelete = bridge.deleteFolder(id: folderID)
        if didDelete {
            applyLifecycleMutation(
                editingLifecycleService.mutation(recording: .deleteFolder(folderID: folderID))
            )
        }
        return didDelete
    }

    func setFolderVisibility(folderID: Int, isVisible: Bool) {
        bridge.setFolderVisible(isVisible, folderID: folderID)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setFolderVisibility(folderID: folderID, isVisible: isVisible)
            )
        )
    }

    func setFolderName(folderID: Int, name: String) {
        bridge.setFolderName(name, folderID: folderID)
    }

    func setFolderExpanded(folderID: Int, isExpanded: Bool) {
        bridge.setFolderExpanded(isExpanded, folderID: folderID)
    }

    @discardableResult
    func assignLayer(index: Int, toFolder folderID: Int) -> Bool {
        let didAssign = bridge.setLayerFolder(at: index, folderID: folderID)
        if didAssign {
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .assignLayerToFolder(index: index, folderID: folderID >= 0 ? folderID : nil)
                )
            )
        }
        return didAssign
    }

    func setActiveLayer(index: Int) {
        bridge.activeLayerIndex = index
    }

    func setLayerName(index: Int, name: String) {
        bridge.setLayerName(name, at: index)
    }

    func setLayerVisibility(index: Int, isVisible: Bool) {
        bridge.setLayerVisible(isVisible, at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setLayerVisibility(index: index, isVisible: isVisible)
            )
        )
    }

    func setLayerLocked(index: Int, isLocked: Bool) {
        bridge.setLayerLocked(isLocked, at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setLayerLocked(index: index, isLocked: isLocked)
            )
        )
    }

    func setLayerAlphaLocked(index: Int, isAlphaLocked: Bool) {
        bridge.setLayerAlphaLocked(isAlphaLocked, at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked)
            )
        )
    }

    func setLayerClipped(index: Int, isClipped: Bool) {
        bridge.setLayerClipped(isClipped, at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setLayerClipped(index: index, isClipped: isClipped),
                invalidating: .layer(index)
            )
        )
    }

    func revealLayerForEditing(index: Int) {
        bridge.setLayerVisible(true, at: index)
    }

    func setLayerOpacity(index: Int, opacity: Double) {
        bridge.setLayerOpacity(CGFloat(opacity), at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setLayerOpacity(index: index, opacity: opacity),
                invalidating: .layer(index)
            )
        )
    }

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) {
        bridge.setLayerBlendMode(blendMode.rawValue, at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setLayerBlendMode(index: index, blendMode: blendMode),
                invalidating: .layer(index)
            )
        )
    }

    @discardableResult
    func mergeLayerDown(index: Int) -> Bool {
        guard index > 0 else { return false }
        guard !isLayerLocked(index: index), !isLayerLocked(index: index - 1) else { return false }
        guard let merged = mergedLayerDownPixelData(upperIndex: index, lowerIndex: index - 1) else {
            return false
        }
        clearTextLayerData(index: index)
        clearTextLayerData(index: index - 1)
        replaceLayerPixels(index: index - 1, data: merged)
        return deleteLayer(index: index)
    }

    @discardableResult
    func applyLayerProcessing(index: Int, request: LayerProcessingRequest) -> Bool {
        guard !isLayerLocked(index: index) else { return false }
        clearTextLayerData(index: index)
        let descriptor = makeProcessingDescriptor(from: request)
        let didApply = bridge.applyLayerProcessing(at: index, descriptor: descriptor)
        if didApply {
            let pixelData = bridge.pixelDataForLayer(at: index) as Data
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .replaceLayerPixels(index: index, data: pixelData),
                    invalidating: .layer(index)
                )
            )
        }
        return didApply
    }

    func mergedLayerDownPixelData(upperIndex: Int, lowerIndex: Int) -> Data? {
        let infos = bridge.layerInfos()
        guard infos.indices.contains(upperIndex), infos.indices.contains(lowerIndex) else {
            return nil
        }
        let upperInfo = infos[upperIndex]
        let lowerInfo = infos[lowerIndex]
        let lowerPixels = bridge.pixelDataForLayer(at: lowerIndex) as Data
        let upperPixels = bridge.pixelDataForLayer(at: upperIndex) as Data
        guard lowerPixels.count == upperPixels.count else { return nil }

        let upperMask = bridge.layerMaskDataForLayer(at: upperIndex) as Data?
        var maskedUpper = upperPixels
        if let upperMask, upperMask.count * 4 == upperPixels.count {
            maskedUpper.withUnsafeMutableBytes { upperBytes in
                upperMask.withUnsafeBytes { maskBytes in
                    guard let upperBase = upperBytes.bindMemory(to: UInt8.self).baseAddress,
                          let maskBase = maskBytes.bindMemory(to: UInt8.self).baseAddress
                    else { return }
                    for pixelIndex in 0..<upperMask.count {
                        let alphaOffset = (pixelIndex * 4) + 3
                        let sourceAlpha = Int(upperBase[alphaOffset])
                        let maskAlpha = Int(maskBase[pixelIndex])
                        upperBase[alphaOffset] = UInt8((sourceAlpha * maskAlpha) / 255)
                    }
                }
            }
        }

        var output = lowerPixels
        output.withUnsafeMutableBytes { outputBytes in
            maskedUpper.withUnsafeBytes { upperBytes in
                guard let dst = outputBytes.bindMemory(to: UInt8.self).baseAddress,
                      let src = upperBytes.bindMemory(to: UInt8.self).baseAddress
                else { return }
                for offset in stride(from: 0, to: lowerPixels.count, by: 4) {
                    AppFeature.blendPreviewPixel(
                        destination: dst + offset,
                        source: src + offset,
                        opacity: CGFloat(upperInfo.opacity),
                        blendMode: LayerBlendMode(rawValue: upperInfo.blendMode) ?? .normal
                    )
                }
            }
        }

        return lowerInfo.alphaLocked
            ? Self.pixelDataByPreservingExistingAlpha(source: output, existing: lowerPixels)
            : output
    }

    @discardableResult
    func applySoftwareStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int) -> Bool {
        guard !isLayerLocked(index: layerIndex) else { return false }
        let basePixelData = bridge.pixelDataForLayer(at: layerIndex) as Data
        guard let rasterized = AppFeature.layerPixelDataByApplyingCommittedStroke(
            basePixelData: basePixelData,
            canvasWidth: Int(bridge.width),
            canvasHeight: Int(bridge.height),
            samples: samples,
            brush: brush,
            preserveAlphaLockedPixels: isLayerAlphaLocked(index: layerIndex)
        ) else {
            return false
        }
        replaceLayerPixels(index: layerIndex, data: rasterized)
        return true
    }

    func replaceLayerPixels(index: Int, data: Data, preservesTextLayerMetadata: Bool = false) {
        guard !isLayerLocked(index: index) else { return }
        if !preservesTextLayerMetadata {
            clearTextLayerData(index: index)
        }
        let descriptor = APPaintLayerProcessingDescriptor()
        descriptor.kind = APPaintLayerProcessingKind.replacePixels
        let adjustedData = isLayerAlphaLocked(index: index)
            ? Self.pixelDataByPreservingExistingAlpha(source: data, existing: bridge.pixelDataForLayer(at: index) as Data)
            : data
        descriptor.pixelData = adjustedData
        let didApply = bridge.applyLayerProcessing(at: index, descriptor: descriptor)
        if !didApply {
            bridge.replaceLayerPixelsTransient(at: index, data: adjustedData)
        }
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .replaceLayerPixels(index: index, data: adjustedData),
                invalidating: .layer(index)
            )
        )
    }

    @discardableResult
    func replaceLayerMask(index: Int, maskData: Data) -> Bool {
        guard maskData.count == Int(bridge.width * bridge.height) else {
            return false
        }
        bridge.replaceLayerMask(at: index, data: maskData)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .replaceLayerMask(index: index, data: maskData),
                invalidating: .layer(index)
            )
        )
        return true
    }

    @discardableResult
    func clearLayerMask(index: Int) -> Bool {
        guard bridge.layerMaskDataForLayer(at: index) != nil else {
            return false
        }
        bridge.clearLayerMask(at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .clearLayerMask(index: index),
                invalidating: .layer(index)
            )
        )
        return true
    }

    @discardableResult
    func applyLayerMask(index: Int) -> Bool {
        guard bridge.applyLayerMask(at: index) else {
            return false
        }
        let pixelData = bridge.pixelDataForLayer(at: index) as Data
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: [
                    .applyLayerMask(index: index),
                    .replaceLayerPixels(index: index, data: pixelData)
                ],
                invalidating: .layer(index)
            )
        )
        return true
    }

    func clearLayer(index: Int) {
        guard !isLayerLocked(index: index) else { return }
        clearTextLayerData(index: index)
        let descriptor = APPaintLayerProcessingDescriptor()
        descriptor.kind = APPaintLayerProcessingKind.clear
        let didApply = bridge.applyLayerProcessing(at: index, descriptor: descriptor)
        if didApply {
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .clearLayer(index: index),
                    invalidating: .layer(index)
                )
            )
        }
    }

    func resizeCanvas(width: Int, height: Int) {
        let targetWidth = max(width, 1)
        let targetHeight = max(height, 1)
        let sourceWidth = Int(bridge.width)
        let sourceHeight = Int(bridge.height)
        guard targetWidth != sourceWidth || targetHeight != sourceHeight else { return }

        let layerInfos = bridge.layerInfos()
        let folderInfos = bridge.folderInfos()
        let activeLayerIndex = min(max(Int(bridge.activeLayerIndex), 0), max(layerInfos.count - 1, 0))
        let sourcePixels = layerInfos.indices.map { bridge.pixelDataForLayer(at: $0) as Data }
        let sourceMasks = layerInfos.indices.map { bridge.layerMaskDataForLayer(at: $0) as Data? }
        let sourceTextLayers = textLayers
        let widthScale = CGFloat(targetWidth) / CGFloat(max(sourceWidth, 1))
        let heightScale = CGFloat(targetHeight) / CGFloat(max(sourceHeight, 1))
        let textScale = min(widthScale, heightScale)

        let resizedBridge = APPaintDocumentBridge(width: targetWidth, height: targetHeight)
        if layerInfos.count > 1 {
            for index in 1..<layerInfos.count {
                _ = resizedBridge.addLayer(name: layerInfos[index].name)
            }
        }

        var folderIDMap: [Int: Int] = [:]
        for folder in folderInfos {
            let createdFolderID = Int(
                resizedBridge.createFolder(
                    name: folder.name,
                    layerIndex: folder.anchorLayerIndex >= 0 ? Int(folder.anchorLayerIndex) : -1
                )
            )
            folderIDMap[Int(folder.folderID)] = createdFolderID
            resizedBridge.setFolderVisible(folder.visible, folderID: createdFolderID)
            resizedBridge.setFolderExpanded(folder.expanded, folderID: createdFolderID)
            resizedBridge.setFolderName(folder.name, folderID: createdFolderID)
        }

        let resizedTextLayers = Dictionary(uniqueKeysWithValues: sourceTextLayers.map { index, textLayer in
            (
                index,
                TextLayerData(
                    text: textLayer.text,
                    positionX: textLayer.positionX * Double(widthScale),
                    positionY: textLayer.positionY * Double(heightScale),
                    fontPostScriptName: textLayer.fontPostScriptName,
                    fontDisplayName: textLayer.fontDisplayName,
                    fontSize: max(1, textLayer.fontSize * Double(textScale)),
                    scale: textLayer.scale,
                    rotationDegrees: textLayer.rotationDegrees,
                    red: textLayer.red,
                    green: textLayer.green,
                    blue: textLayer.blue,
                    alpha: textLayer.alpha
                )
            )
        })

        for (index, info) in layerInfos.enumerated() {
            resizedBridge.setLayerName(info.name, at: index)
            if let resizedPixels = Self.scaledLayerPixelData(
                sourcePixels[index],
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                targetWidth: targetWidth,
                targetHeight: targetHeight
            ) {
                resizedBridge.replaceLayerPixels(at: index, data: resizedPixels)
            }
            if let maskData = sourceMasks[index],
               let resizedMask = Self.scaledLayerMaskData(
                maskData,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                targetWidth: targetWidth,
                targetHeight: targetHeight
               ) {
                resizedBridge.replaceLayerMask(at: index, data: resizedMask)
            }
            resizedBridge.setLayerVisible(info.visible, at: index)
            resizedBridge.setLayerLocked(info.locked, at: index)
            resizedBridge.setLayerAlphaLocked(info.alphaLocked, at: index)
            resizedBridge.setLayerClipped(info.clipped, at: index)
            resizedBridge.setLayerOpacity(info.opacity, at: index)
            resizedBridge.setLayerBlendMode(info.blendMode, at: index)
            if info.folderID >= 0, let mappedFolderID = folderIDMap[Int(info.folderID)] {
                _ = resizedBridge.setLayerFolder(at: index, folderID: mappedFolderID)
            }
        }

        bridge = resizedBridge
        textLayers = resizedTextLayers
        for (index, textLayer) in resizedTextLayers {
            guard let rasterized = rasterizedTextLayerPixelData(textLayer) else { continue }
            bridge.replaceLayerPixels(at: index, data: rasterized)
        }
        bridge.activeLayerIndex = activeLayerIndex
        editingLifecycleService.resetActiveEditingState(
            activeStrokeLayerIndex: &activeStrokeLayerIndex,
            activeStrokeBrush: &activeStrokeBrush,
            activeStrokeSamples: &activeStrokeSamples,
            activeBlurStrokeLayerIndex: &activeBlurStrokeLayerIndex,
            activeBlurStrokeBrush: &activeBlurStrokeBrush,
            activeBlurStrokeSamples: &activeBlurStrokeSamples,
            blurStrokeHasCapturedHistory: &blurStrokeHasCapturedHistory
        )
        resetTimelapseHistory()
        applyLifecycleMutation(editingLifecycleService.mutation(invalidating: .all))
    }

    func resizeCanvasExtent(width: Int, height: Int) {
        let targetWidth = max(width, 1)
        let targetHeight = max(height, 1)
        let sourceWidth = Int(bridge.width)
        let sourceHeight = Int(bridge.height)
        guard targetWidth != sourceWidth || targetHeight != sourceHeight else { return }

        let layerInfos = bridge.layerInfos()
        let folderInfos = bridge.folderInfos()
        let activeLayerIndex = min(max(Int(bridge.activeLayerIndex), 0), max(layerInfos.count - 1, 0))
        let sourcePixels = layerInfos.indices.map { bridge.pixelDataForLayer(at: $0) as Data }
        let sourceMasks = layerInfos.indices.map { bridge.layerMaskDataForLayer(at: $0) as Data? }
        let sourceTextLayers = textLayers
        let offsetX = (targetWidth - sourceWidth) / 2
        let offsetY = (targetHeight - sourceHeight) / 2

        let resizedBridge = APPaintDocumentBridge(width: targetWidth, height: targetHeight)
        if layerInfos.count > 1 {
            for index in 1..<layerInfos.count {
                _ = resizedBridge.addLayer(name: layerInfos[index].name)
            }
        }

        var folderIDMap: [Int: Int] = [:]
        for folder in folderInfos {
            let createdFolderID = Int(
                resizedBridge.createFolder(
                    name: folder.name,
                    layerIndex: folder.anchorLayerIndex >= 0 ? Int(folder.anchorLayerIndex) : -1
                )
            )
            folderIDMap[Int(folder.folderID)] = createdFolderID
            resizedBridge.setFolderVisible(folder.visible, folderID: createdFolderID)
            resizedBridge.setFolderExpanded(folder.expanded, folderID: createdFolderID)
            resizedBridge.setFolderName(folder.name, folderID: createdFolderID)
        }

        let shiftedTextLayers = Dictionary(uniqueKeysWithValues: sourceTextLayers.map { index, textLayer in
            (
                index,
                TextLayerData(
                    text: textLayer.text,
                    positionX: textLayer.positionX + Double(offsetX),
                    positionY: textLayer.positionY + Double(offsetY),
                    fontPostScriptName: textLayer.fontPostScriptName,
                    fontDisplayName: textLayer.fontDisplayName,
                    fontSize: textLayer.fontSize,
                    scale: textLayer.scale,
                    rotationDegrees: textLayer.rotationDegrees,
                    red: textLayer.red,
                    green: textLayer.green,
                    blue: textLayer.blue,
                    alpha: textLayer.alpha
                )
            )
        })

        for (index, info) in layerInfos.enumerated() {
            resizedBridge.setLayerName(info.name, at: index)
            if let translatedPixels = Self.translatedLayerPixelData(
                sourcePixels[index],
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                targetWidth: targetWidth,
                targetHeight: targetHeight,
                offsetX: offsetX,
                offsetY: offsetY
            ) {
                resizedBridge.replaceLayerPixels(at: index, data: translatedPixels)
            }
            if let maskData = sourceMasks[index],
               let translatedMask = Self.translatedLayerMaskData(
                maskData,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                targetWidth: targetWidth,
                targetHeight: targetHeight,
                offsetX: offsetX,
                offsetY: offsetY
               ) {
                resizedBridge.replaceLayerMask(at: index, data: translatedMask)
            }
            resizedBridge.setLayerVisible(info.visible, at: index)
            resizedBridge.setLayerLocked(info.locked, at: index)
            resizedBridge.setLayerAlphaLocked(info.alphaLocked, at: index)
            resizedBridge.setLayerClipped(info.clipped, at: index)
            resizedBridge.setLayerOpacity(info.opacity, at: index)
            resizedBridge.setLayerBlendMode(info.blendMode, at: index)
            if info.folderID >= 0, let mappedFolderID = folderIDMap[Int(info.folderID)] {
                _ = resizedBridge.setLayerFolder(at: index, folderID: mappedFolderID)
            }
        }

        bridge = resizedBridge
        textLayers = shiftedTextLayers
        for (index, textLayer) in shiftedTextLayers {
            guard let rasterized = rasterizedTextLayerPixelData(textLayer) else { continue }
            bridge.replaceLayerPixels(at: index, data: rasterized)
        }
        bridge.activeLayerIndex = activeLayerIndex
        editingLifecycleService.resetActiveEditingState(
            activeStrokeLayerIndex: &activeStrokeLayerIndex,
            activeStrokeBrush: &activeStrokeBrush,
            activeStrokeSamples: &activeStrokeSamples,
            activeBlurStrokeLayerIndex: &activeBlurStrokeLayerIndex,
            activeBlurStrokeBrush: &activeBlurStrokeBrush,
            activeBlurStrokeSamples: &activeBlurStrokeSamples,
            blurStrokeHasCapturedHistory: &blurStrokeHasCapturedHistory
        )
        resetTimelapseHistory()
        applyLifecycleMutation(editingLifecycleService.mutation(invalidating: .all))
    }

    private func buildLayerRows(from infos: [APPaintLayerInfo]) -> [LayerRowModel] {
        Array(infos.enumerated().map { index, layer in
            LayerRowModel(
                index: index,
                name: layer.name,
                visible: layer.visible,
                opacity: layer.opacity,
                isLocked: layer.locked,
                isAlphaLocked: layer.alphaLocked,
                isClipped: layer.clipped,
                blendMode: LayerBlendMode(rawValue: layer.blendMode) ?? .normal,
                folderID: layer.folderID >= 0 ? Int(layer.folderID) : nil,
                hasMask: layer.hasMask,
                isTextLayer: textLayers[index] != nil,
                textLayer: textLayers[index]
            )
        }.reversed())
    }

    private func buildSidebarRows(
        layerInfos: [APPaintLayerInfo],
        layerRows: [LayerRowModel],
        folderInfos: [APPaintFolderInfo]
    ) -> [LayerSidebarRowModel] {
        let layerRowsByIndex = Dictionary(uniqueKeysWithValues: layerRows.map { ($0.index, $0) })
        let orderedFolders = folderInfos.map { folderInfo in
            let childIndices = layerInfos.enumerated().compactMap { index, layer in
                Int(layer.folderID) == Int(folderInfo.folderID) ? index : nil
            }.sorted(by: >)
            return LayerFolderModel(
                id: Int(folderInfo.folderID),
                name: folderInfo.name,
                visible: folderInfo.visible,
                isExpanded: folderInfo.expanded,
                anchorLayerIndex: folderInfo.anchorLayerIndex >= 0 ? Int(folderInfo.anchorLayerIndex) : nil,
                childLayerIndices: childIndices
            )
        }
        let folders = Dictionary(uniqueKeysWithValues: orderedFolders.map { ($0.id, $0) })

        var emittedFolderIDs = Set<Int>()
        var rows: [LayerSidebarRowModel] = []
        for layer in layerRows {
            for folder in orderedFolders where folder.anchorLayerIndex == layer.index && !emittedFolderIDs.contains(folder.id) {
                rows.append(.folder(folder))
                emittedFolderIDs.insert(folder.id)
                if folder.isExpanded {
                    for childIndex in folder.childLayerIndices {
                        if let childLayer = layerRowsByIndex[childIndex] {
                            rows.append(.layer(childLayer, depth: 1))
                        }
                    }
                }
            }

            if let folderID = layer.folderID {
                if folders[folderID] == nil {
                    rows.append(.layer(layer, depth: 0))
                }
            } else {
                rows.append(.layer(layer, depth: 0))
            }
        }

        for folder in orderedFolders where !emittedFolderIDs.contains(folder.id) {
            rows.append(.folder(folder))
        }

        return rows
    }


    private static func scaledLayerPixelData(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int
    ) -> Data? {
        guard sourceWidth > 0, sourceHeight > 0, targetWidth > 0, targetHeight > 0 else { return nil }
        guard source.count == sourceWidth * sourceHeight * 4 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: source as CFData),
              let image = CGImage(
                width: sourceWidth,
                height: sourceHeight,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: sourceWidth * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }

        var bytes = [UInt8](repeating: 0, count: targetWidth * targetHeight * 4)
        guard let context = CGContext(
            data: &bytes,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return Data(bytes)
    }

    private static func scaledLayerMaskData(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int
    ) -> Data? {
        guard sourceWidth > 0, sourceHeight > 0, targetWidth > 0, targetHeight > 0 else { return nil }
        guard source.count == sourceWidth * sourceHeight else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let provider = CGDataProvider(data: source as CFData),
              let image = CGImage(
                width: sourceWidth,
                height: sourceHeight,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: sourceWidth,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }

        var bytes = [UInt8](repeating: 0, count: targetWidth * targetHeight)
        guard let context = CGContext(
            data: &bytes,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return Data(bytes)
    }

    private static func translatedLayerPixelData(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int,
        offsetX: Int,
        offsetY: Int
    ) -> Data? {
        guard source.count == sourceWidth * sourceHeight * 4 else { return nil }
        var bytes = [UInt8](repeating: 0, count: targetWidth * targetHeight * 4)
        source.withUnsafeBytes { sourceBytes in
            guard let sourceBase = sourceBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<sourceHeight {
                let destinationY = y + offsetY
                guard destinationY >= 0, destinationY < targetHeight else { continue }
                for x in 0..<sourceWidth {
                    let destinationX = x + offsetX
                    guard destinationX >= 0, destinationX < targetWidth else { continue }
                    let sourceOffset = ((y * sourceWidth) + x) * 4
                    let destinationOffset = ((destinationY * targetWidth) + destinationX) * 4
                    bytes[destinationOffset] = sourceBase[sourceOffset]
                    bytes[destinationOffset + 1] = sourceBase[sourceOffset + 1]
                    bytes[destinationOffset + 2] = sourceBase[sourceOffset + 2]
                    bytes[destinationOffset + 3] = sourceBase[sourceOffset + 3]
                }
            }
        }
        return Data(bytes)
    }

    private static func translatedLayerMaskData(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        targetWidth: Int,
        targetHeight: Int,
        offsetX: Int,
        offsetY: Int
    ) -> Data? {
        guard source.count == sourceWidth * sourceHeight else { return nil }
        var bytes = [UInt8](repeating: 0, count: targetWidth * targetHeight)
        source.withUnsafeBytes { sourceBytes in
            guard let sourceBase = sourceBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<sourceHeight {
                let destinationY = y + offsetY
                guard destinationY >= 0, destinationY < targetHeight else { continue }
                for x in 0..<sourceWidth {
                    let destinationX = x + offsetX
                    guard destinationX >= 0, destinationX < targetWidth else { continue }
                    let sourceOffset = (y * sourceWidth) + x
                    let destinationOffset = (destinationY * targetWidth) + destinationX
                    bytes[destinationOffset] = sourceBase[sourceOffset]
                }
            }
        }
        return Data(bytes)
    }

    func boxBlurredPixels(from original: [UInt8], width: Int, height: Int, radius: Double) -> [UInt8]? {
        var source = original
        var destination = [UInt8](repeating: 0, count: original.count)
        var kernelSize = max(3, Int((radius * 0.9).rounded()))
        if kernelSize.isMultiple(of: 2) {
            kernelSize += 1
        }
        kernelSize = min(kernelSize, 63)

        for _ in 0..<2 {
            let error: vImage_Error = source.withUnsafeMutableBytes { sourceBytes in
                destination.withUnsafeMutableBytes { destinationBytes in
                    var sourceBuffer = vImage_Buffer(
                        data: sourceBytes.baseAddress!,
                        height: vImagePixelCount(height),
                        width: vImagePixelCount(width),
                        rowBytes: width * 4
                    )
                    var destinationBuffer = vImage_Buffer(
                        data: destinationBytes.baseAddress!,
                        height: vImagePixelCount(height),
                        width: vImagePixelCount(width),
                        rowBytes: width * 4
                    )
                    return vImageBoxConvolve_ARGB8888(
                        &sourceBuffer,
                        &destinationBuffer,
                        nil,
                        0,
                        0,
                        UInt32(kernelSize),
                        UInt32(kernelSize),
                        nil,
                        vImage_Flags(kvImageEdgeExtend)
                    )
                }
            }
            guard error == kvImageNoError else {
                return nil
            }
            swap(&source, &destination)
        }

        return source
    }

    func blendBlurredPixels(
        original: [UInt8],
        blurred: [UInt8],
        width: Int,
        height: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> [UInt8] {
        var output = original
        let influenceRadius = max(4.0, brush.radius * 1.35)
        let blurStrength = max(0.0, min(brush.flow, 1.0))
        let softness = max(0.12, 1.0 - brush.hardness)
        let sampleXs = samples.map { Double($0.point.x) }
        let sampleYs = samples.map { Double($0.point.y) }
        let minX = max(0, Int((sampleXs.min() ?? 0) - influenceRadius - 2))
        let maxX = min(width - 1, Int((sampleXs.max() ?? 0) + influenceRadius + 2))
        let minY = max(0, Int((sampleYs.min() ?? 0) - influenceRadius - 2))
        let maxY = min(height - 1, Int((sampleYs.max() ?? 0) + influenceRadius + 2))

        guard minX <= maxX, minY <= maxY else {
            return output
        }

        let maskWidth = maxX - minX + 1
        let maskHeight = maxY - minY + 1
        var mask = [Float](repeating: 0, count: maskWidth * maskHeight)

        for sample in samples {
            let centerX = Double(sample.point.x)
            let centerY = Double(sample.point.y)
            let sampleRadius = influenceRadius * max(0.35, Double(sample.pressure))
            let localMinX = max(minX, Int(floor(centerX - sampleRadius)))
            let localMaxX = min(maxX, Int(ceil(centerX + sampleRadius)))
            let localMinY = max(minY, Int(floor(centerY - sampleRadius)))
            let localMaxY = min(maxY, Int(ceil(centerY + sampleRadius)))

            for y in localMinY...localMaxY {
                let dy = Double(y) - centerY
                for x in localMinX...localMaxX {
                    let dx = Double(x) - centerX
                    let distance = sqrt((dx * dx) + (dy * dy))
                    guard distance <= sampleRadius else { continue }
                    let normalized = max(0.0, 1.0 - (distance / sampleRadius))
                    let feathered = pow(normalized, max(0.75, 2.4 - (softness * 1.6)))
                    let strength = Float(feathered * blurStrength)
                    let maskIndex = ((y - minY) * maskWidth) + (x - minX)
                    mask[maskIndex] = max(mask[maskIndex], strength)
                }
            }
        }

        for y in minY...maxY {
            for x in minX...maxX {
                let maskIndex = ((y - minY) * maskWidth) + (x - minX)
                let strength = max(0, min(mask[maskIndex], 1))
                guard strength > 0.001 else { continue }
                let pixelIndex = ((y * width) + x) * 4
                for channel in 0..<4 {
                    let originalValue = Float(original[pixelIndex + channel])
                    let blurredValue = Float(blurred[pixelIndex + channel])
                    output[pixelIndex + channel] = UInt8(max(0, min(255, Int((originalValue + ((blurredValue - originalValue) * strength)).rounded()))))
                }
            }
        }

        return output
    }

    func applyBlurStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, transient: Bool = false) {
        guard !samples.isEmpty else { return }
        guard !isLayerLocked(index: layerIndex) else { return }
        let width = Int(bridge.width)
        let height = Int(bridge.height)
        let sourceData = bridge.pixelDataForLayer(at: layerIndex) as Data
        guard sourceData.count == width * height * 4 else { return }

        let original = [UInt8](sourceData)
        guard let blurred = boxBlurredPixels(from: original, width: width, height: height, radius: brush.radius) else {
            return
        }

        let blended = blendBlurredPixels(
            original: original,
            blurred: blurred,
            width: width,
            height: height,
            samples: samples,
            brush: brush
        )
        let outputData = isLayerAlphaLocked(index: layerIndex)
            ? Self.pixelDataByPreservingExistingAlpha(source: Data(blended), existing: sourceData)
            : Data(blended)
        if transient {
            bridge.replaceLayerPixelsTransient(at: layerIndex, data: outputData)
        } else {
            bridge.replaceLayerPixels(at: layerIndex, data: outputData)
        }
    }
}

enum TimelapseOperation: Equatable, Sendable {
    case stroke(layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])
    case blurStroke(layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])
    case fill(layerIndex: Int, brush: BrushRuntimeSettings, sample: StylusSample)
    case undo
    case redo
    case addLayer(name: String)
    case duplicateLayer(index: Int, name: String)
    case deleteLayer(index: Int)
    case moveLayer(index: Int, destinationIndex: Int)
    case createFolder(folderID: Int, name: String, anchorLayerIndex: Int?)
    case deleteFolder(folderID: Int)
    case setFolderVisibility(folderID: Int, isVisible: Bool)
    case assignLayerToFolder(index: Int, folderID: Int?)
    case setLayerVisibility(index: Int, isVisible: Bool)
    case setLayerLocked(index: Int, isLocked: Bool)
    case setLayerAlphaLocked(index: Int, isAlphaLocked: Bool)
    case setLayerClipped(index: Int, isClipped: Bool)
    case setLayerOpacity(index: Int, opacity: Double)
    case setLayerBlendMode(index: Int, blendMode: LayerBlendMode)
    case replaceLayerPixels(index: Int, data: Data)
    case replaceLayerMask(index: Int, data: Data)
    case clearLayerMask(index: Int)
    case applyLayerMask(index: Int)
    case clearLayer(index: Int)
    case setPaperStyle(CanvasPaperStyle)

    func storedRepresentation(index: Int, dataDirectory: URL, fileClient: FileClient = .live) throws -> StoredTimelapseOperation {
        let dataFilename: String?
        switch self {
        case let .replaceLayerPixels(_, data):
            let filename = String(format: "replace-layer-%06d.rgba", index)
            try fileClient.writeData(data, dataDirectory.appendingPathComponent(filename, isDirectory: false), .atomic)
            dataFilename = "TimelapseData/\(filename)"
        case let .replaceLayerMask(_, data):
            let filename = String(format: "replace-mask-%06d.mask", index)
            try fileClient.writeData(data, dataDirectory.appendingPathComponent(filename, isDirectory: false), .atomic)
            dataFilename = "TimelapseData/\(filename)"
        default:
            dataFilename = nil
        }

        switch self {
        case let .stroke(layerIndex, brush, samples):
            return StoredTimelapseOperation(
                kind: .stroke,
                layerIndex: layerIndex,
                brush: StoredBrushRuntimeSettings(brush),
                samples: samples.map(StoredStylusSample.init),
                dataFilename: nil
            )
        case let .blurStroke(layerIndex, brush, samples):
            return StoredTimelapseOperation(
                kind: .blurStroke,
                layerIndex: layerIndex,
                brush: StoredBrushRuntimeSettings(brush),
                samples: samples.map(StoredStylusSample.init),
                dataFilename: nil
            )
        case let .fill(layerIndex, brush, sample):
            return StoredTimelapseOperation(
                kind: .fill,
                layerIndex: layerIndex,
                brush: StoredBrushRuntimeSettings(brush),
                sample: StoredStylusSample(sample),
                dataFilename: nil
            )
        case .undo:
            return StoredTimelapseOperation(kind: .undo)
        case .redo:
            return StoredTimelapseOperation(kind: .redo)
        case let .addLayer(name):
            return StoredTimelapseOperation(kind: .addLayer, name: name)
        case let .duplicateLayer(index, name):
            return StoredTimelapseOperation(kind: .duplicateLayer, layerIndex: index, name: name)
        case let .deleteLayer(index):
            return StoredTimelapseOperation(kind: .deleteLayer, layerIndex: index)
        case let .moveLayer(index, destinationIndex):
            return StoredTimelapseOperation(kind: .moveLayer, layerIndex: index, destinationIndex: destinationIndex)
        case let .createFolder(folderID, name, anchorLayerIndex):
            return StoredTimelapseOperation(
                kind: .createFolder,
                folderID: folderID,
                anchorLayerIndex: anchorLayerIndex,
                name: name
            )
        case let .deleteFolder(folderID):
            return StoredTimelapseOperation(kind: .deleteFolder, folderID: folderID)
        case let .setFolderVisibility(folderID, isVisible):
            return StoredTimelapseOperation(kind: .setFolderVisibility, folderID: folderID, isVisible: isVisible)
        case let .assignLayerToFolder(index, folderID):
            return StoredTimelapseOperation(kind: .assignLayerToFolder, layerIndex: index, folderID: folderID)
        case let .setLayerVisibility(index, isVisible):
            return StoredTimelapseOperation(kind: .setLayerVisibility, layerIndex: index, isVisible: isVisible)
        case let .setLayerLocked(index, isLocked):
            return StoredTimelapseOperation(kind: .setLayerLocked, layerIndex: index, isLocked: isLocked)
        case let .setLayerAlphaLocked(index, isAlphaLocked):
            return StoredTimelapseOperation(kind: .setLayerAlphaLocked, layerIndex: index, isAlphaLocked: isAlphaLocked)
        case let .setLayerClipped(index, isClipped):
            return StoredTimelapseOperation(kind: .setLayerClipped, layerIndex: index, isClipped: isClipped)
        case let .setLayerOpacity(index, opacity):
            return StoredTimelapseOperation(kind: .setLayerOpacity, layerIndex: index, opacity: opacity)
        case let .setLayerBlendMode(index, blendMode):
            return StoredTimelapseOperation(kind: .setLayerBlendMode, layerIndex: index, blendMode: blendMode.rawValue)
        case let .replaceLayerPixels(index, _):
            return StoredTimelapseOperation(kind: .replaceLayerPixels, layerIndex: index, dataFilename: dataFilename)
        case let .replaceLayerMask(index, _):
            return StoredTimelapseOperation(kind: .replaceLayerMask, layerIndex: index, dataFilename: dataFilename)
        case let .clearLayerMask(index):
            return StoredTimelapseOperation(kind: .clearLayerMask, layerIndex: index)
        case let .applyLayerMask(index):
            return StoredTimelapseOperation(kind: .applyLayerMask, layerIndex: index)
        case let .clearLayer(index):
            return StoredTimelapseOperation(kind: .clearLayer, layerIndex: index)
        case let .setPaperStyle(style):
            return StoredTimelapseOperation(kind: .setPaperStyle, paperStyle: StoredPrimoDocument.PaperStyle(
                red: Double(style.red),
                green: Double(style.green),
                blue: Double(style.blue),
                alpha: Double(style.alpha),
                isTransparent: style.isTransparent
            ))
        }
    }

    init(
        stored: StoredTimelapseOperation,
        baseURL: URL,
        fileClient: FileClient = .live
    ) throws {
        switch stored.kind {
        case .stroke:
            guard let layerIndex = stored.layerIndex,
                  let brush = stored.brush?.runtimeSettings,
                  let samples = stored.samples?.map(\.stylusSample)
            else { throw PrimoDocumentError.invalidDocument }
            self = .stroke(layerIndex: layerIndex, brush: brush, samples: samples)
        case .blurStroke:
            guard let layerIndex = stored.layerIndex,
                  let brush = stored.brush?.runtimeSettings,
                  let samples = stored.samples?.map(\.stylusSample)
            else { throw PrimoDocumentError.invalidDocument }
            self = .blurStroke(layerIndex: layerIndex, brush: brush, samples: samples)
        case .fill:
            guard let layerIndex = stored.layerIndex,
                  let brush = stored.brush?.runtimeSettings,
                  let sample = stored.sample?.stylusSample
            else { throw PrimoDocumentError.invalidDocument }
            self = .fill(layerIndex: layerIndex, brush: brush, sample: sample)
        case .undo:
            self = .undo
        case .redo:
            self = .redo
        case .addLayer:
            guard let name = stored.name else { throw PrimoDocumentError.invalidDocument }
            self = .addLayer(name: name)
        case .duplicateLayer:
            guard let layerIndex = stored.layerIndex, let name = stored.name else { throw PrimoDocumentError.invalidDocument }
            self = .duplicateLayer(index: layerIndex, name: name)
        case .deleteLayer:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .deleteLayer(index: layerIndex)
        case .moveLayer:
            guard let layerIndex = stored.layerIndex, let destinationIndex = stored.destinationIndex else {
                throw PrimoDocumentError.invalidDocument
            }
            self = .moveLayer(index: layerIndex, destinationIndex: destinationIndex)
        case .createFolder:
            guard let folderID = stored.folderID, let name = stored.name else { throw PrimoDocumentError.invalidDocument }
            self = .createFolder(folderID: folderID, name: name, anchorLayerIndex: stored.anchorLayerIndex)
        case .deleteFolder:
            guard let folderID = stored.folderID else { throw PrimoDocumentError.invalidDocument }
            self = .deleteFolder(folderID: folderID)
        case .setFolderVisibility:
            guard let folderID = stored.folderID, let isVisible = stored.isVisible else { throw PrimoDocumentError.invalidDocument }
            self = .setFolderVisibility(folderID: folderID, isVisible: isVisible)
        case .assignLayerToFolder:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .assignLayerToFolder(index: layerIndex, folderID: stored.folderID)
        case .setLayerVisibility:
            guard let layerIndex = stored.layerIndex, let isVisible = stored.isVisible else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerVisibility(index: layerIndex, isVisible: isVisible)
        case .setLayerLocked:
            guard let layerIndex = stored.layerIndex, let isLocked = stored.isLocked else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerLocked(index: layerIndex, isLocked: isLocked)
        case .setLayerAlphaLocked:
            guard let layerIndex = stored.layerIndex, let isAlphaLocked = stored.isAlphaLocked else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerAlphaLocked(index: layerIndex, isAlphaLocked: isAlphaLocked)
        case .setLayerClipped:
            guard let layerIndex = stored.layerIndex, let isClipped = stored.isClipped else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerClipped(index: layerIndex, isClipped: isClipped)
        case .setLayerOpacity:
            guard let layerIndex = stored.layerIndex, let opacity = stored.opacity else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerOpacity(index: layerIndex, opacity: opacity)
        case .setLayerBlendMode:
            guard let layerIndex = stored.layerIndex,
                  let blendModeRaw = stored.blendMode,
                  let blendMode = LayerBlendMode(rawValue: blendModeRaw)
            else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerBlendMode(index: layerIndex, blendMode: blendMode)
        case .replaceLayerPixels:
            guard let layerIndex = stored.layerIndex, let dataFilename = stored.dataFilename else {
                throw PrimoDocumentError.invalidDocument
            }
            let data = try fileClient.readData(baseURL.appendingPathComponent(dataFilename, isDirectory: false))
            self = .replaceLayerPixels(index: layerIndex, data: data)
        case .replaceLayerMask:
            guard let layerIndex = stored.layerIndex, let dataFilename = stored.dataFilename else {
                throw PrimoDocumentError.invalidDocument
            }
            let data = try fileClient.readData(baseURL.appendingPathComponent(dataFilename, isDirectory: false))
            self = .replaceLayerMask(index: layerIndex, data: data)
        case .clearLayerMask:
            guard let layerIndex: Int = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .clearLayerMask(index: layerIndex)
        case .applyLayerMask:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .applyLayerMask(index: layerIndex)
        case .clearLayer:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .clearLayer(index: layerIndex)
        case .setPaperStyle:
            guard let paperStyle = stored.paperStyle else { throw PrimoDocumentError.invalidDocument }
            self = .setPaperStyle(
                CanvasPaperStyle(
                    red: Float(paperStyle.red),
                    green: Float(paperStyle.green),
                    blue: Float(paperStyle.blue),
                    alpha: Float(paperStyle.alpha),
                    isTransparent: paperStyle.isTransparent
                )
            )
        }
    }
}

struct StoredPrimoDocument: Codable {
    struct PaperStyle: Codable, Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
        let isTransparent: Bool
    }

    struct Layer: Codable {
        let index: Int
        let name: String
        let visible: Bool
        let locked: Bool
        let alphaLocked: Bool
        let clipped: Bool
        let opacity: Double
        let blendMode: String
        let folderID: Int?
        let textLayer: TextLayerData?
        let pixelFilename: String
        let maskFilename: String?

        enum CodingKeys: String, CodingKey {
            case index
            case name
            case visible
            case locked
            case alphaLocked
            case clipped
            case opacity
            case blendMode
            case folderID
            case textLayer
            case pixelFilename
            case maskFilename
        }

        init(
            index: Int,
            name: String,
            visible: Bool,
            locked: Bool,
            alphaLocked: Bool,
            clipped: Bool,
            opacity: Double,
            blendMode: String,
            folderID: Int?,
            textLayer: TextLayerData?,
            pixelFilename: String,
            maskFilename: String?
        ) {
            self.index = index
            self.name = name
            self.visible = visible
            self.locked = locked
            self.alphaLocked = alphaLocked
            self.clipped = clipped
            self.opacity = opacity
            self.blendMode = blendMode
            self.folderID = folderID
            self.textLayer = textLayer
            self.pixelFilename = pixelFilename
            self.maskFilename = maskFilename
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            index = try container.decode(Int.self, forKey: .index)
            name = try container.decode(String.self, forKey: .name)
            visible = try container.decode(Bool.self, forKey: .visible)
            locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
            alphaLocked = try container.decodeIfPresent(Bool.self, forKey: .alphaLocked) ?? false
            clipped = try container.decodeIfPresent(Bool.self, forKey: .clipped) ?? false
            opacity = try container.decode(Double.self, forKey: .opacity)
            blendMode = try container.decode(String.self, forKey: .blendMode)
            folderID = try container.decodeIfPresent(Int.self, forKey: .folderID)
            textLayer = try container.decodeIfPresent(TextLayerData.self, forKey: .textLayer)
            pixelFilename = try container.decode(String.self, forKey: .pixelFilename)
            maskFilename = try container.decodeIfPresent(String.self, forKey: .maskFilename)
        }
    }

    struct Folder: Codable {
        let id: Int
        let name: String
        let visible: Bool
        let expanded: Bool
        let anchorLayerIndex: Int?
    }

    struct TimelapseFrame: Codable {
        let filename: String
        let width: Double
        let height: Double
    }

    let version: Int
    let canvasWidth: Int
    let canvasHeight: Int
    let activeLayerIndex: Int
    let paperStyle: PaperStyle
    let layers: [Layer]
    let folders: [Folder]
    let timelapseFrames: [TimelapseFrame]
    let timelapseOperations: [StoredTimelapseOperation]

    enum CodingKeys: String, CodingKey {
        case version
        case canvasWidth
        case canvasHeight
        case activeLayerIndex
        case paperStyle
        case layers
        case folders
        case timelapseFrames
        case timelapseOperations
    }

    init(
        version: Int,
        canvasWidth: Int,
        canvasHeight: Int,
        activeLayerIndex: Int,
        paperStyle: PaperStyle,
        layers: [Layer],
        folders: [Folder],
        timelapseFrames: [TimelapseFrame],
        timelapseOperations: [StoredTimelapseOperation]
    ) {
        self.version = version
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.activeLayerIndex = activeLayerIndex
        self.paperStyle = paperStyle
        self.layers = layers
        self.folders = folders
        self.timelapseFrames = timelapseFrames
        self.timelapseOperations = timelapseOperations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        canvasWidth = try container.decode(Int.self, forKey: .canvasWidth)
        canvasHeight = try container.decode(Int.self, forKey: .canvasHeight)
        activeLayerIndex = try container.decode(Int.self, forKey: .activeLayerIndex)
        paperStyle = try container.decode(PaperStyle.self, forKey: .paperStyle)
        layers = try container.decode([Layer].self, forKey: .layers)
        folders = try container.decodeIfPresent([Folder].self, forKey: .folders) ?? []
        timelapseFrames = try container.decodeIfPresent([TimelapseFrame].self, forKey: .timelapseFrames) ?? []
        timelapseOperations = try container.decodeIfPresent([StoredTimelapseOperation].self, forKey: .timelapseOperations) ?? []
    }
}

struct StoredStylusSample: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let pressure: Double
    let altitude: Double
    let azimuth: Double
    let timestamp: Double

    init(_ sample: StylusSample) {
        x = Double(sample.point.x)
        y = Double(sample.point.y)
        pressure = Double(sample.pressure)
        altitude = Double(sample.altitude)
        azimuth = Double(sample.azimuth)
        timestamp = sample.timestamp
    }

    var stylusSample: StylusSample {
        StylusSample(
            point: CGPoint(x: CGFloat(x), y: CGFloat(y)),
            pressure: CGFloat(pressure),
            altitude: CGFloat(altitude),
            azimuth: CGFloat(azimuth),
            timestamp: timestamp
        )
    }
}

struct StoredBrushTipRaster: Codable, Equatable, Sendable {
    let width: Int
    let height: Int
    let alphaData: Data

    init(_ raster: BrushTipRaster) {
        width = raster.width
        height = raster.height
        alphaData = raster.alphaData
    }

    var raster: BrushTipRaster {
        BrushTipRaster(width: width, height: height, alphaData: alphaData)
    }
}

struct StoredBrushRuntimeSettings: Codable, Equatable, Sendable {
    let tipKind: String
    let radius: Double
    let sizeSpeedSensitivity: Double
    let taperIn: Double
    let taperOut: Double
    let opacity: Double
    let hardness: Double
    let roundness: Double
    let roundnessPressureSensitivity: Double
    let roundnessTiltSensitivity: Double
    let angle: Double
    let anglePressureSensitivity: Double
    let angleTiltSensitivity: Double
    let angleMode: String
    let stampSpacing: Double
    let spacingJitter: Double
    let scatterEnabled: Bool
    let scatterMode: String
    let scatterLateral: Double
    let scatterLinear: Double
    let count: Int
    let countJitter: Double
    let countSizeJitter: Double
    let countOpacityJitter: Double
    let angleJitter: Double
    let roundnessJitter: Double
    let textureMode: String
    let textureStrength: Double
    let flow: Double
    let flowPressureSensitivity: Double
    let flowJitter: Double
    let velocityInfluence: Double
    let colorMixingMode: String?
    let wetness: Double
    let wetnessPressureSensitivity: Double
    let opacityPressureSensitivity: Double
    let colorMixStrength: Double
    let smudgeBlurEnabled: Bool
    let smudgeBleed: Double
    let smudgeRadius: Double
    let paintLoad: Double
    let loadPressureSensitivity: Double
    let dualBrushEnabled: Bool
    let dualTipKind: String
    let dualScale: Double
    let dualSpacing: Double
    let dualScatter: Double
    let dualAngle: Double
    let dualBlendMode: String
    let grainScale: Double
    let grainContrast: Double
    let paperScale: Double
    let paperStrength: Double
    let paperThreshold: Double
    let flipX: Bool
    let flipY: Bool
    let customTip: StoredBrushTipRaster?
    let pressureSensitivity: Double
    let stabilization: Double
    let fillThresholdMode: String
    let fillOpacityTolerance: Double
    let fillColorTolerance: Double
    let fillExpansion: Int
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let isEraser: Bool

    init(_ brush: BrushRuntimeSettings) {
        tipKind = brush.tipKind.rawValue
        radius = brush.radius
        sizeSpeedSensitivity = brush.sizeSpeedSensitivity
        taperIn = brush.taperIn
        taperOut = brush.taperOut
        opacity = brush.opacity
        hardness = brush.hardness
        roundness = brush.roundness
        roundnessPressureSensitivity = brush.roundnessPressureSensitivity
        roundnessTiltSensitivity = brush.roundnessTiltSensitivity
        angle = brush.angle
        anglePressureSensitivity = brush.anglePressureSensitivity
        angleTiltSensitivity = brush.angleTiltSensitivity
        angleMode = brush.angleMode.rawValue
        stampSpacing = brush.stampSpacing
        spacingJitter = brush.spacingJitter
        scatterEnabled = brush.scatterEnabled
        scatterMode = brush.scatterMode.rawValue
        scatterLateral = brush.scatterLateral
        scatterLinear = brush.scatterLinear
        count = brush.count
        countJitter = brush.countJitter
        countSizeJitter = brush.countSizeJitter
        countOpacityJitter = brush.countOpacityJitter
        angleJitter = brush.angleJitter
        roundnessJitter = brush.roundnessJitter
        textureMode = brush.textureMode.rawValue
        textureStrength = brush.textureStrength
        flow = brush.flow
        flowPressureSensitivity = brush.flowPressureSensitivity
        flowJitter = brush.flowJitter
        velocityInfluence = brush.velocityInfluence
        colorMixingMode = brush.colorMixingMode.rawValue
        wetness = brush.wetness
        wetnessPressureSensitivity = brush.wetnessPressureSensitivity
        opacityPressureSensitivity = brush.opacityPressureSensitivity
        colorMixStrength = brush.colorMixStrength
        smudgeBlurEnabled = brush.smudgeBlurEnabled
        smudgeBleed = brush.smudgeBleed
        smudgeRadius = brush.smudgeRadius
        paintLoad = brush.paintLoad
        loadPressureSensitivity = brush.loadPressureSensitivity
        dualBrushEnabled = brush.dualBrushEnabled
        dualTipKind = brush.dualTipKind.rawValue
        dualScale = brush.dualScale
        dualSpacing = brush.dualSpacing
        dualScatter = brush.dualScatter
        dualAngle = brush.dualAngle
        dualBlendMode = brush.dualBlendMode.rawValue
        grainScale = brush.grainScale
        grainContrast = brush.grainContrast
        paperScale = brush.paperScale
        paperStrength = brush.paperStrength
        paperThreshold = brush.paperThreshold
        flipX = brush.flipX
        flipY = brush.flipY
        customTip = brush.customTip.map(StoredBrushTipRaster.init)
        pressureSensitivity = brush.pressureSensitivity
        stabilization = brush.stabilization
        fillThresholdMode = brush.fillThresholdMode.rawValue
        fillOpacityTolerance = brush.fillOpacityTolerance
        fillColorTolerance = brush.fillColorTolerance
        fillExpansion = brush.fillExpansion
        red = brush.red
        green = brush.green
        blue = brush.blue
        isEraser = brush.isEraser
    }

    var runtimeSettings: BrushRuntimeSettings? {
        guard let tipKind = BrushTipKind(rawValue: tipKind),
              let angleMode = BrushAngleMode(rawValue: angleMode),
              let scatterMode = BrushScatterMode(rawValue: scatterMode),
              let textureMode = BrushTextureMode(rawValue: textureMode),
              let dualTipKind = BrushTipKind(rawValue: dualTipKind),
              let dualBlendMode = BrushDualBlendMode(rawValue: dualBlendMode),
              let fillThresholdMode = FillThresholdMode(rawValue: fillThresholdMode)
        else {
            return nil
        }
        let resolvedColorMixingMode = BrushColorMixingMode(rawValue: colorMixingMode ?? "") ?? BrushColorMixingMode.inferred(
            wetness: wetness,
            colorMixStrength: colorMixStrength,
            smudgeBlurEnabled: smudgeBlurEnabled,
            smudgeBleed: smudgeBleed,
            smudgeRadius: smudgeRadius,
            paintLoad: paintLoad
        )

        return BrushRuntimeSettings(
            tipKind: tipKind,
            radius: radius,
            sizeSpeedSensitivity: sizeSpeedSensitivity,
            taperIn: taperIn,
            taperOut: taperOut,
            opacity: opacity,
            hardness: hardness,
            roundness: roundness,
            roundnessPressureSensitivity: roundnessPressureSensitivity,
            roundnessTiltSensitivity: roundnessTiltSensitivity,
            angle: angle,
            anglePressureSensitivity: anglePressureSensitivity,
            angleTiltSensitivity: angleTiltSensitivity,
            angleMode: angleMode,
            stampSpacing: stampSpacing,
            spacingJitter: spacingJitter,
            scatterEnabled: scatterEnabled,
            scatterMode: scatterMode,
            scatterLateral: scatterLateral,
            scatterLinear: scatterLinear,
            count: count,
            countJitter: countJitter,
            countSizeJitter: countSizeJitter,
            countOpacityJitter: countOpacityJitter,
            angleJitter: angleJitter,
            roundnessJitter: roundnessJitter,
            textureMode: textureMode,
            textureStrength: textureStrength,
            flow: flow,
            flowPressureSensitivity: flowPressureSensitivity,
            flowJitter: flowJitter,
            velocityInfluence: velocityInfluence,
            colorMixingMode: resolvedColorMixingMode,
            wetness: wetness,
            wetnessPressureSensitivity: wetnessPressureSensitivity,
            opacityPressureSensitivity: opacityPressureSensitivity,
            colorMixStrength: colorMixStrength,
            smudgeBlurEnabled: smudgeBlurEnabled,
            smudgeBleed: smudgeBleed,
            smudgeRadius: smudgeRadius,
            paintLoad: paintLoad,
            loadPressureSensitivity: loadPressureSensitivity,
            dualBrushEnabled: dualBrushEnabled,
            dualTipKind: dualTipKind,
            dualScale: dualScale,
            dualSpacing: dualSpacing,
            dualScatter: dualScatter,
            dualAngle: dualAngle,
            dualBlendMode: dualBlendMode,
            grainScale: grainScale,
            grainContrast: grainContrast,
            paperScale: paperScale,
            paperStrength: paperStrength,
            paperThreshold: paperThreshold,
            flipX: flipX,
            flipY: flipY,
            customTip: customTip?.raster,
            pressureSensitivity: pressureSensitivity,
            stabilization: stabilization,
            fillThresholdMode: fillThresholdMode,
            fillOpacityTolerance: fillOpacityTolerance,
            fillColorTolerance: fillColorTolerance,
            fillExpansion: fillExpansion,
            red: red,
            green: green,
            blue: blue,
            isEraser: isEraser
        )
    }
}

struct StoredTimelapseOperation: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Equatable, Sendable {
        case stroke
        case blurStroke
        case fill
        case undo
        case redo
        case addLayer
        case duplicateLayer
        case deleteLayer
        case moveLayer
        case createFolder
        case deleteFolder
        case setFolderVisibility
        case assignLayerToFolder
        case setLayerVisibility
        case setLayerLocked
        case setLayerAlphaLocked
        case setLayerClipped
        case setLayerOpacity
        case setLayerBlendMode
        case replaceLayerPixels
        case replaceLayerMask
        case clearLayerMask
        case applyLayerMask
        case clearLayer
        case setPaperStyle
    }

    let kind: Kind
    var layerIndex: Int?
    var destinationIndex: Int?
    var folderID: Int?
    var anchorLayerIndex: Int?
    var name: String?
    var isVisible: Bool?
    var isLocked: Bool?
    var isAlphaLocked: Bool?
    var isClipped: Bool?
    var opacity: Double?
    var blendMode: String?
    var brush: StoredBrushRuntimeSettings?
    var samples: [StoredStylusSample]?
    var sample: StoredStylusSample?
    var dataFilename: String?
    var paperStyle: StoredPrimoDocument.PaperStyle?

    init(
        kind: Kind,
        layerIndex: Int? = nil,
        destinationIndex: Int? = nil,
        folderID: Int? = nil,
        anchorLayerIndex: Int? = nil,
        name: String? = nil,
        isVisible: Bool? = nil,
        isLocked: Bool? = nil,
        isAlphaLocked: Bool? = nil,
        isClipped: Bool? = nil,
        opacity: Double? = nil,
        blendMode: String? = nil,
        brush: StoredBrushRuntimeSettings? = nil,
        samples: [StoredStylusSample]? = nil,
        sample: StoredStylusSample? = nil,
        dataFilename: String? = nil,
        paperStyle: StoredPrimoDocument.PaperStyle? = nil
    ) {
        self.kind = kind
        self.layerIndex = layerIndex
        self.destinationIndex = destinationIndex
        self.folderID = folderID
        self.anchorLayerIndex = anchorLayerIndex
        self.name = name
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.isAlphaLocked = isAlphaLocked
        self.isClipped = isClipped
        self.opacity = opacity
        self.blendMode = blendMode
        self.brush = brush
        self.samples = samples
        self.sample = sample
        self.dataFilename = dataFilename
        self.paperStyle = paperStyle
    }
}

enum PrimoDocumentError: LocalizedError {
    case invalidDocument

    var errorDescription: String? {
        "The selected Primo document is invalid."
    }
}
