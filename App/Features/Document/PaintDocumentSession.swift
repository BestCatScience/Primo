import Accelerate
import CoreGraphics
import Foundation
import os
import UIKit
import simd

final class PaintDocumentSession: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.atelierprime.app", category: "Document")
    private static let maxTimelapseFrames = 20_000
    let bridge: APPaintDocumentBridge
    private var revision: Int = 0
    private var activeStrokeLayerIndex: Int?
    private var activeStrokeBrush: BrushRuntimeSettings?
    private var activeStrokeSamples: [StylusSample] = []
    private var timelapseFrames: [TimelapseFrame] = []
    private var timelapseEvents: [TimelapseOperation] = []
    private var layerThumbnailCache: [Int: Data] = [:]
    private var paperStyle: CanvasPaperStyle = .default
    private let timelapseDirectoryURL: URL
    private var nextTimelapseFrameID: Int = 0
    private var usesOperationTimelapsePersistence = true
    private var activeBlurStrokeLayerIndex: Int?
    private var activeBlurStrokeBrush: BrushRuntimeSettings?
    private var activeBlurStrokeSamples: [StylusSample] = []
    private var blurStrokeHasCapturedHistory = false

    init(width: Int = 1152, height: Int = 1536) {
        let clock = ContinuousClock()
        let start = clock.now
        self.bridge = APPaintDocumentBridge(width: width, height: height)
        self.timelapseDirectoryURL = Self.makeTimelapseDirectoryURL()
        try? FileManager.default.createDirectory(at: timelapseDirectoryURL, withIntermediateDirectories: true)
        let duration = start.duration(to: clock.now)
        Self.logger.debug("PaintDocumentSession initialized \(width)x\(height) in \(String(describing: duration), privacy: .public)")
    }

    deinit {
        try? FileManager.default.removeItem(at: timelapseDirectoryURL)
    }

    var currentPaperStyle: CanvasPaperStyle {
        paperStyle
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
        bridge.beginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: sample))
    }

    func appendStroke(sample: StylusSample) {
        activeStrokeSamples.append(sample)
        bridge.appendStroke(point: makeStrokePoint(from: sample))
    }

    func endStroke() {
        if let layerIndex = activeStrokeLayerIndex,
           let brush = activeStrokeBrush,
           !activeStrokeSamples.isEmpty {
            timelapseEvents.append(
                .stroke(
                    layerIndex: layerIndex,
                    brush: brush,
                    samples: activeStrokeSamples
                )
            )
        }
        bridge.endStroke()
        invalidateThumbnailCache(for: Int(bridge.activeLayerIndex))
        activeStrokeLayerIndex = nil
        activeStrokeBrush = nil
        activeStrokeSamples.removeAll(keepingCapacity: true)
        captureTimelapseFrame()
    }

    func cancelStroke() {
        bridge.cancelStroke()
        invalidateThumbnailCache(for: Int(bridge.activeLayerIndex))
        activeStrokeLayerIndex = nil
        activeStrokeBrush = nil
        activeStrokeSamples.removeAll(keepingCapacity: true)
    }

    func fill(sample: StylusSample, brush: BrushRuntimeSettings) {
        let layerIndex = Int(bridge.activeLayerIndex)
        guard !isLayerLocked(index: layerIndex) else { return }
        bridge.fill(
            at: sample.point,
            brush: makeBrushDescriptor(from: brush)
        )
        invalidateThumbnailCache(for: Int(bridge.activeLayerIndex))
        timelapseEvents.append(
            .fill(
                layerIndex: layerIndex,
                brush: brush,
                sample: sample
            )
        )
        captureTimelapseFrame()
    }

    func blur(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, captureTimelapse: Bool) {
        guard !samples.isEmpty else { return }
        guard !isLayerLocked(index: layerIndex) else { return }
        if activeBlurStrokeLayerIndex != layerIndex {
            activeBlurStrokeLayerIndex = layerIndex
            activeBlurStrokeBrush = brush
            activeBlurStrokeSamples = []
            blurStrokeHasCapturedHistory = false
        }
        activeBlurStrokeSamples.append(contentsOf: samples)
        applyBlurStroke(samples: samples, brush: brush, layerIndex: layerIndex, transient: blurStrokeHasCapturedHistory)
        blurStrokeHasCapturedHistory = true
        invalidateThumbnailCache(for: layerIndex)
        if captureTimelapse {
            captureTimelapseFrame()
        }
    }

    func endBlurStroke() {
        if let layerIndex = activeBlurStrokeLayerIndex,
           let brush = activeBlurStrokeBrush,
           !activeBlurStrokeSamples.isEmpty {
            timelapseEvents.append(
                .blurStroke(
                    layerIndex: layerIndex,
                    brush: brush,
                    samples: activeBlurStrokeSamples
                )
            )
        }
        activeBlurStrokeLayerIndex = nil
        activeBlurStrokeBrush = nil
        activeBlurStrokeSamples.removeAll(keepingCapacity: true)
        blurStrokeHasCapturedHistory = false
        captureTimelapseFrame()
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
            invalidateThumbnailCache()
            timelapseEvents.append(.undo)
            captureTimelapseFrame()
        }
        return didUndo
    }

    @discardableResult
    func redo() -> Bool {
        let didRedo = bridge.redo()
        if didRedo {
            invalidateThumbnailCache()
            timelapseEvents.append(.redo)
            captureTimelapseFrame()
        }
        return didRedo
    }

    func addLayer(name: String) {
        bridge.activeLayerIndex = bridge.addLayer(name: name)
        invalidateThumbnailCache(for: Int(bridge.activeLayerIndex))
        timelapseEvents.append(.addLayer(name: name))
        captureTimelapseFrame()
    }

    @discardableResult
    func duplicateLayer(index: Int, name: String) -> Int {
        let duplicatedIndex = Int(bridge.duplicateLayer(at: index, name: name))
        if duplicatedIndex >= 0 {
            invalidateThumbnailCache()
            timelapseEvents.append(.duplicateLayer(index: index, name: name))
            captureTimelapseFrame()
        }
        return duplicatedIndex
    }

    @discardableResult
    func deleteLayer(index: Int) -> Bool {
        let didDelete = bridge.deleteLayer(at: index)
        if didDelete {
            invalidateThumbnailCache()
            timelapseEvents.append(.deleteLayer(index: index))
            captureTimelapseFrame()
        }
        return didDelete
    }

    @discardableResult
    func moveLayer(from index: Int, to destinationIndex: Int) -> Bool {
        let didMove = bridge.moveLayer(at: index, to: destinationIndex)
        if didMove {
            invalidateThumbnailCache()
            timelapseEvents.append(.moveLayer(index: index, destinationIndex: destinationIndex))
            captureTimelapseFrame()
        }
        return didMove
    }

    @discardableResult
    func createFolder(name: String, layerIndex: Int) -> Int {
        let folderID = Int(bridge.createFolder(name: name, layerIndex: layerIndex))
        timelapseEvents.append(.createFolder(folderID: folderID, name: name, anchorLayerIndex: layerIndex >= 0 ? layerIndex : nil))
        return folderID
    }

    @discardableResult
    func deleteFolder(folderID: Int) -> Bool {
        let didDelete = bridge.deleteFolder(id: folderID)
        if didDelete {
            timelapseEvents.append(.deleteFolder(folderID: folderID))
            captureTimelapseFrame()
        }
        return didDelete
    }

    func setFolderVisibility(folderID: Int, isVisible: Bool) {
        bridge.setFolderVisible(isVisible, folderID: folderID)
        timelapseEvents.append(.setFolderVisibility(folderID: folderID, isVisible: isVisible))
        captureTimelapseFrame()
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
            timelapseEvents.append(.assignLayerToFolder(index: index, folderID: folderID >= 0 ? folderID : nil))
            captureTimelapseFrame()
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
        timelapseEvents.append(.setLayerVisibility(index: index, isVisible: isVisible))
        captureTimelapseFrame()
    }

    func setLayerLocked(index: Int, isLocked: Bool) {
        bridge.setLayerLocked(isLocked, at: index)
        timelapseEvents.append(.setLayerLocked(index: index, isLocked: isLocked))
        captureTimelapseFrame()
    }

    func setLayerAlphaLocked(index: Int, isAlphaLocked: Bool) {
        bridge.setLayerAlphaLocked(isAlphaLocked, at: index)
        timelapseEvents.append(.setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked))
        captureTimelapseFrame()
    }

    func revealLayerForEditing(index: Int) {
        bridge.setLayerVisible(true, at: index)
    }

    func setLayerOpacity(index: Int, opacity: Double) {
        bridge.setLayerOpacity(CGFloat(opacity), at: index)
        invalidateThumbnailCache(for: index)
        timelapseEvents.append(.setLayerOpacity(index: index, opacity: opacity))
        captureTimelapseFrame()
    }

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) {
        bridge.setLayerBlendMode(blendMode.rawValue, at: index)
        invalidateThumbnailCache(for: index)
        timelapseEvents.append(.setLayerBlendMode(index: index, blendMode: blendMode))
        captureTimelapseFrame()
    }

    @discardableResult
    func mergeLayerDown(index: Int) -> Bool {
        guard index > 0 else { return false }
        guard !isLayerLocked(index: index), !isLayerLocked(index: index - 1) else { return false }
        guard let merged = mergedLayerDownPixelData(upperIndex: index, lowerIndex: index - 1) else {
            return false
        }
        replaceLayerPixels(index: index - 1, data: merged)
        return deleteLayer(index: index)
    }

    @discardableResult
    func applyLayerProcessing(index: Int, request: LayerProcessingRequest) -> Bool {
        guard !isLayerLocked(index: index) else { return false }
        let descriptor = makeProcessingDescriptor(from: request)
        let didApply = bridge.applyLayerProcessing(at: index, descriptor: descriptor)
        if didApply {
            invalidateThumbnailCache(for: index)
            let pixelData = bridge.pixelDataForLayer(at: index) as Data
            timelapseEvents.append(.replaceLayerPixels(index: index, data: pixelData))
            captureTimelapseFrame()
        }
        return didApply
    }

    func pixelDataForLayer(index: Int) -> Data {
        bridge.pixelDataForLayer(at: index) as Data
    }

    func isLayerLocked(index: Int) -> Bool {
        guard let layer = bridge.layerInfos().enumerated().first(where: { $0.offset == index })?.element else {
            return false
        }
        return layer.locked
    }

    func isLayerAlphaLocked(index: Int) -> Bool {
        guard let layer = bridge.layerInfos().enumerated().first(where: { $0.offset == index })?.element else {
            return false
        }
        return layer.alphaLocked
    }

    static func pixelDataByPreservingExistingAlpha(source: Data, existing: Data) -> Data {
        guard source.count == existing.count else { return source }
        var output = source
        output.withUnsafeMutableBytes { outputBytes in
            existing.withUnsafeBytes { existingBytes in
                guard let dst = outputBytes.bindMemory(to: UInt8.self).baseAddress,
                      let src = existingBytes.bindMemory(to: UInt8.self).baseAddress
                else { return }
                for offset in stride(from: 0, to: source.count, by: 4) {
                    let alpha = src[offset + 3]
                    if alpha == 0 {
                        dst[offset] = 0
                        dst[offset + 1] = 0
                        dst[offset + 2] = 0
                        dst[offset + 3] = 0
                    } else {
                        dst[offset + 3] = alpha
                    }
                }
            }
        }
        return output
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

    func replaceLayerPixels(index: Int, data: Data) {
        guard !isLayerLocked(index: index) else { return }
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
        invalidateThumbnailCache(for: index)
        timelapseEvents.append(.replaceLayerPixels(index: index, data: adjustedData))
        captureTimelapseFrame()
    }

    @discardableResult
    func replaceLayerMask(index: Int, maskData: Data) -> Bool {
        guard maskData.count == Int(bridge.width * bridge.height) else {
            return false
        }
        bridge.replaceLayerMask(at: index, data: maskData)
        invalidateThumbnailCache(for: index)
        timelapseEvents.append(.replaceLayerMask(index: index, data: maskData))
        captureTimelapseFrame()
        return true
    }

    @discardableResult
    func clearLayerMask(index: Int) -> Bool {
        guard bridge.layerMaskDataForLayer(at: index) != nil else {
            return false
        }
        bridge.clearLayerMask(at: index)
        invalidateThumbnailCache(for: index)
        timelapseEvents.append(.clearLayerMask(index: index))
        captureTimelapseFrame()
        return true
    }

    @discardableResult
    func applyLayerMask(index: Int) -> Bool {
        guard bridge.applyLayerMask(at: index) else {
            return false
        }
        invalidateThumbnailCache(for: index)
        let pixelData = bridge.pixelDataForLayer(at: index) as Data
        timelapseEvents.append(.applyLayerMask(index: index))
        timelapseEvents.append(.replaceLayerPixels(index: index, data: pixelData))
        captureTimelapseFrame()
        return true
    }

    func clearLayer(index: Int) {
        guard !isLayerLocked(index: index) else { return }
        let descriptor = APPaintLayerProcessingDescriptor()
        descriptor.kind = APPaintLayerProcessingKind.clear
        let didApply = bridge.applyLayerProcessing(at: index, descriptor: descriptor)
        if didApply {
            invalidateThumbnailCache(for: index)
            timelapseEvents.append(.clearLayer(index: index))
            captureTimelapseFrame()
        }
    }

    func setPaperStyle(_ style: CanvasPaperStyle) {
        guard paperStyle != style else { return }
        paperStyle = style
        timelapseEvents.append(.setPaperStyle(style))
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
                blendMode: LayerBlendMode(rawValue: layer.blendMode) ?? .normal,
                folderID: layer.folderID >= 0 ? Int(layer.folderID) : nil,
                hasMask: layer.hasMask
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

    func compositePNGData(paperStyle: CanvasPaperStyle) -> Data? {
        self.paperStyle = paperStyle
        return renderedCompositeImage(paperStyle: paperStyle)?.pngData()
    }

    func saveProject(to url: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

        let layersDirectory = url.appendingPathComponent("Layers", isDirectory: true)
        let timelapseDirectory = url.appendingPathComponent("Timelapse", isDirectory: true)
        let timelapseDataDirectory = url.appendingPathComponent("TimelapseData", isDirectory: true)
        try fileManager.createDirectory(at: layersDirectory, withIntermediateDirectories: true)
        if !usesOperationTimelapsePersistence {
            try fileManager.createDirectory(at: timelapseDirectory, withIntermediateDirectories: true)
        } else {
            try fileManager.createDirectory(at: timelapseDataDirectory, withIntermediateDirectories: true)
        }

        let layerInfos = bridge.layerInfos()
        let folderInfos = bridge.folderInfos()

        let storedLayers = try layerInfos.enumerated().map { index, layerInfo -> StoredAtelierDocument.Layer in
            let filename = String(format: "layer-%04d.rgba", index)
            let pixelURL = layersDirectory.appendingPathComponent(filename, isDirectory: false)
            let pixelData = bridge.pixelDataForLayer(at: index) as Data
            try pixelData.write(to: pixelURL, options: .atomic)
            let maskFilename: String?
            if let maskData = bridge.layerMaskDataForLayer(at: index) {
                let filename = String(format: "layer-mask-%04d.mask", index)
                try maskData.write(to: layersDirectory.appendingPathComponent(filename, isDirectory: false), options: .atomic)
                maskFilename = "Layers/\(filename)"
            } else {
                maskFilename = nil
            }
            return StoredAtelierDocument.Layer(
                index: index,
                name: layerInfo.name,
                visible: layerInfo.visible,
                locked: layerInfo.locked,
                alphaLocked: layerInfo.alphaLocked,
                opacity: layerInfo.opacity,
                blendMode: layerInfo.blendMode,
                folderID: layerInfo.folderID >= 0 ? Int(layerInfo.folderID) : nil,
                pixelFilename: "Layers/\(filename)",
                maskFilename: maskFilename
            )
        }

        let storedFolders = folderInfos.map { folderInfo in
            StoredAtelierDocument.Folder(
                id: Int(folderInfo.folderID),
                name: folderInfo.name,
                visible: folderInfo.visible,
                expanded: folderInfo.expanded,
                anchorLayerIndex: folderInfo.anchorLayerIndex >= 0 ? Int(folderInfo.anchorLayerIndex) : nil
            )
        }

        let storedTimelapseFrames: [StoredAtelierDocument.TimelapseFrame]
        if !usesOperationTimelapsePersistence {
            storedTimelapseFrames = try timelapseFrames.enumerated().map { index, frame in
                let filename = String(format: "frame-%06d.jpg", index)
                let destinationURL = timelapseDirectory.appendingPathComponent(filename, isDirectory: false)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: frame.imageURL, to: destinationURL)
                return StoredAtelierDocument.TimelapseFrame(
                    filename: "Timelapse/\(filename)",
                    width: Double(frame.size.width),
                    height: Double(frame.size.height)
                )
            }
        } else {
            storedTimelapseFrames = []
        }

        let storedTimelapseOperations = usesOperationTimelapsePersistence
            ? try timelapseEvents.enumerated().map { index, event in
                try event.storedRepresentation(index: index, dataDirectory: timelapseDataDirectory)
            }
            : []

        let document = StoredAtelierDocument(
            version: 3,
            canvasWidth: Int(bridge.width),
            canvasHeight: Int(bridge.height),
            activeLayerIndex: Int(bridge.activeLayerIndex),
            paperStyle: StoredAtelierDocument.PaperStyle(
                red: Double(paperStyle.red),
                green: Double(paperStyle.green),
                blue: Double(paperStyle.blue),
                alpha: Double(paperStyle.alpha),
                isTransparent: paperStyle.isTransparent
            ),
            layers: storedLayers,
            folders: storedFolders,
            timelapseFrames: storedTimelapseFrames,
            timelapseOperations: storedTimelapseOperations
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(document)
        try manifestData.write(to: url.appendingPathComponent("manifest.json"), options: .atomic)
    }

    static func loadProject(from url: URL) throws -> PaintDocumentSession {
        let manifestURL = url.appendingPathComponent("manifest.json", isDirectory: false)
        let data = try Data(contentsOf: manifestURL)
        let document = try JSONDecoder().decode(StoredAtelierDocument.self, from: data)
        guard !document.layers.isEmpty else {
            throw AtelierDocumentError.invalidDocument
        }

        let session = PaintDocumentSession(width: document.canvasWidth, height: document.canvasHeight)
        session.paperStyle = CanvasPaperStyle(
            red: Float(document.paperStyle.red),
            green: Float(document.paperStyle.green),
            blue: Float(document.paperStyle.blue),
            alpha: Float(document.paperStyle.alpha),
            isTransparent: document.paperStyle.isTransparent
        )

        while Int(session.bridge.layerInfos().count) < document.layers.count {
            _ = session.bridge.addLayer(name: "Layer \(Int(session.bridge.layerInfos().count) + 1)")
        }

        for layer in document.layers.sorted(by: { $0.index < $1.index }) {
            let pixelURL = url.appendingPathComponent(layer.pixelFilename, isDirectory: false)
            let pixelData = try Data(contentsOf: pixelURL)
            session.bridge.replaceLayerPixelsTransient(at: layer.index, data: pixelData)
            if let maskFilename = layer.maskFilename {
                let maskData = try Data(contentsOf: url.appendingPathComponent(maskFilename, isDirectory: false))
                session.bridge.replaceLayerMask(at: layer.index, data: maskData)
            } else {
                session.bridge.clearLayerMask(at: layer.index)
            }
            session.bridge.setLayerName(layer.name, at: layer.index)
            session.bridge.setLayerVisible(layer.visible, at: layer.index)
            session.bridge.setLayerLocked(layer.locked, at: layer.index)
            session.bridge.setLayerAlphaLocked(layer.alphaLocked, at: layer.index)
            session.bridge.setLayerOpacity(CGFloat(layer.opacity), at: layer.index)
            session.bridge.setLayerBlendMode(layer.blendMode, at: layer.index)
        }

        var folderIDMap: [Int: Int] = [:]
        for folder in document.folders {
            let newFolderID = Int(session.bridge.createFolder(name: folder.name, layerIndex: folder.anchorLayerIndex ?? -1))
            folderIDMap[folder.id] = newFolderID
            session.bridge.setFolderVisible(folder.visible, folderID: newFolderID)
            session.bridge.setFolderExpanded(folder.expanded, folderID: newFolderID)
        }

        for layer in document.layers {
            guard let storedFolderID = layer.folderID, let resolvedFolderID = folderIDMap[storedFolderID] else { continue }
            _ = session.bridge.setLayerFolder(at: layer.index, folderID: resolvedFolderID)
        }

        session.bridge.activeLayerIndex = min(max(document.activeLayerIndex, 0), document.layers.count - 1)

        session.timelapseFrames.removeAll(keepingCapacity: true)
        session.timelapseEvents.removeAll(keepingCapacity: true)
        if !document.timelapseOperations.isEmpty {
            session.usesOperationTimelapsePersistence = true
            session.timelapseEvents = try document.timelapseOperations.map { try TimelapseOperation(stored: $0, baseURL: url) }
        } else {
            session.usesOperationTimelapsePersistence = false
            for (index, storedFrame) in document.timelapseFrames.enumerated() {
                let sourceURL = url.appendingPathComponent(storedFrame.filename, isDirectory: false)
                let destinationURL = session.timelapseDirectoryURL.appendingPathComponent(String(format: "frame-%06d.jpg", index), isDirectory: false)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                session.timelapseFrames.append(
                    TimelapseFrame(
                        imageURL: destinationURL,
                        size: CGSize(width: storedFrame.width, height: storedFrame.height)
                    )
                )
            }
        }
        session.nextTimelapseFrameID = session.timelapseFrames.count
        session.layerThumbnailCache.removeAll(keepingCapacity: true)
        session.bridge.clearHistory()
        return session
    }

    func timelapseCapture() -> TimelapseCapture? {
        let previewData = makeTimelapseThumbnail()?.jpegData(compressionQuality: 0.72)
        if usesOperationTimelapsePersistence, !timelapseEvents.isEmpty {
            return TimelapseCapture(
                canvasSize: CGSize(width: bridge.width, height: bridge.height),
                paperStyle: paperStyle,
                previewImageData: previewData,
                source: .operations(timelapseEvents),
                framesPerSecond: 24
            )
        }

        guard timelapseFrames.count >= 2 else { return nil }
        return TimelapseCapture(
            canvasSize: CGSize(width: bridge.width, height: bridge.height),
            paperStyle: paperStyle,
            previewImageData: previewData,
            source: .frames(timelapseFrames),
            framesPerSecond: 24
        )
    }

    func consumeDirtyUpdate() -> IncrementalLayerUpdate? {
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

    private func makeBrushDescriptor(from brush: BrushRuntimeSettings) -> APBrushDescriptor {
        let descriptor = APBrushDescriptor()
        let usesCircularInkTip =
            brush.tipKind == .ink &&
            brush.customTip == nil &&
            brush.roundness >= 0.98 &&
            abs(brush.roundnessPressureSensitivity) <= 0.001 &&
            abs(brush.roundnessTiltSensitivity) <= 0.001 &&
            abs(brush.anglePressureSensitivity) <= 0.001 &&
            abs(brush.angleTiltSensitivity) <= 0.001 &&
            abs(brush.angleJitter) <= 0.001 &&
            abs(brush.roundnessJitter) <= 0.001
        descriptor.tipKind = brush.tipKind.rawValue
        descriptor.radius = brush.radius
        descriptor.sizeSpeedSensitivity = brush.sizeSpeedSensitivity
        descriptor.taperIn = brush.taperIn
        descriptor.taperOut = brush.taperOut
        descriptor.opacity = brush.opacity
        descriptor.hardness = brush.hardness
        descriptor.roundness = brush.roundness
        descriptor.roundnessPressureSensitivity = brush.roundnessPressureSensitivity
        descriptor.roundnessTiltSensitivity = brush.roundnessTiltSensitivity
        descriptor.angle = brush.angle
        descriptor.anglePressureSensitivity = brush.anglePressureSensitivity
        descriptor.angleTiltSensitivity = brush.angleTiltSensitivity
        descriptor.angleMode = {
            switch brush.angleMode {
            case .fixed: return 0
            case .strokeDirection: return 1
            case .stylusTilt: return 2
            }
        }()
        descriptor.stampSpacing = brush.stampSpacing
        descriptor.spacingJitter = brush.spacingJitter
        descriptor.scatterEnabled = brush.scatterEnabled
        descriptor.scatterMode = brush.scatterMode == .spray ? 1 : 0
        descriptor.scatterLateral = brush.scatterLateral
        descriptor.scatterLinear = brush.scatterLinear
        descriptor.count = brush.count
        descriptor.countJitter = brush.countJitter
        descriptor.countSizeJitter = brush.countSizeJitter
        descriptor.countOpacityJitter = brush.countOpacityJitter
        descriptor.angleJitter = brush.angleJitter
        descriptor.roundnessJitter = brush.roundnessJitter
        descriptor.textureMode = {
            switch brush.textureMode {
            case .off: return 0
            case .strokeLocked: return 1
            case .eachTip: return 2
            case .moving: return 3
            }
        }()
        descriptor.textureStrength = brush.textureStrength
        descriptor.flow = brush.flow
        descriptor.flowPressureSensitivity = brush.flowPressureSensitivity
        descriptor.flowJitter = brush.flowJitter
        descriptor.velocityInfluence = brush.velocityInfluence
        descriptor.wetness = brush.wetness
        descriptor.wetnessPressureSensitivity = brush.wetnessPressureSensitivity
        descriptor.opacityPressureSensitivity = brush.opacityPressureSensitivity
        descriptor.colorMixStrength = brush.colorMixStrength
        descriptor.paintLoad = brush.paintLoad
        descriptor.loadPressureSensitivity = brush.loadPressureSensitivity
        descriptor.dualBrushEnabled = brush.dualBrushEnabled
        descriptor.dualTipKind = brush.dualTipKind.rawValue
        descriptor.dualScale = brush.dualScale
        descriptor.dualSpacing = brush.dualSpacing
        descriptor.dualScatter = brush.dualScatter
        descriptor.dualAngle = brush.dualAngle
        descriptor.dualBlendMode = {
            switch brush.dualBlendMode {
            case .multiply: return 0
            case .darker: return 1
            case .subtract: return 2
            }
        }()
        descriptor.flipX = brush.flipX
        descriptor.flipY = brush.flipY
        descriptor.tipMaskWidth = brush.customTip?.width ?? 0
        descriptor.tipMaskHeight = brush.customTip?.height ?? 0
        descriptor.tipMaskData = brush.customTip?.alphaData
        descriptor.grainScale = brush.grainScale
        descriptor.grainContrast = brush.grainContrast
        descriptor.paperScale = brush.paperScale
        descriptor.paperThreshold = brush.paperThreshold
        descriptor.paperStrength = brush.paperStrength
        descriptor.tiltInfluence = usesCircularInkTip ? 0.0 : 0.75
        descriptor.maxDarkness = 1.0
        descriptor.pressureSensitivity = brush.pressureSensitivity
        descriptor.fillThresholdMode = brush.fillThresholdMode == .opacity ? 0 : 1
        descriptor.fillOpacityTolerance = brush.fillOpacityTolerance
        descriptor.fillColorTolerance = brush.fillColorTolerance
        descriptor.fillExpansion = brush.fillExpansion
        descriptor.red = brush.red
        descriptor.green = brush.green
        descriptor.blue = brush.blue
        descriptor.eraser = brush.isEraser
        return descriptor
    }

    private func makeProcessingDescriptor(from request: LayerProcessingRequest) -> APPaintLayerProcessingDescriptor {
        let descriptor = APPaintLayerProcessingDescriptor()
        switch request {
        case let .gradientMap(preset):
            descriptor.kind = APPaintLayerProcessingKind.gradientMap
            switch preset {
            case .graphite:
                descriptor.gradientMapPreset = APPaintGradientMapPreset.graphite
            case .sepia:
                descriptor.gradientMapPreset = APPaintGradientMapPreset.sepia
            case .ocean:
                descriptor.gradientMapPreset = APPaintGradientMapPreset.ocean
            case .sunset:
                descriptor.gradientMapPreset = APPaintGradientMapPreset.sunset
            case .toxic:
                descriptor.gradientMapPreset = APPaintGradientMapPreset.toxic
            }

        case let .hueSaturationBrightness(settings):
            descriptor.kind = APPaintLayerProcessingKind.hueSaturationBrightness
            descriptor.hueDegrees = CGFloat(settings.hueDegrees)
            descriptor.saturation = CGFloat(settings.saturation)
            descriptor.brightness = CGFloat(settings.brightness)

        case let .brightnessContrast(settings):
            descriptor.kind = APPaintLayerProcessingKind.brightnessContrast
            descriptor.brightness = CGFloat(settings.brightness)
            descriptor.contrast = CGFloat(settings.contrast)

        case let .levels(settings):
            descriptor.kind = APPaintLayerProcessingKind.levels
            descriptor.inputBlack = CGFloat(settings.inputBlack)
            descriptor.inputWhite = CGFloat(settings.inputWhite)
            descriptor.gamma = CGFloat(settings.gamma)
            descriptor.outputBlack = CGFloat(settings.outputBlack)
            descriptor.outputWhite = CGFloat(settings.outputWhite)

        case let .toneCurve(settings):
            descriptor.kind = APPaintLayerProcessingKind.toneCurve
            descriptor.shadows = CGFloat(settings.shadows)
            descriptor.midtones = CGFloat(settings.midtones)
            descriptor.highlights = CGFloat(settings.highlights)

        case let .colorBalance(settings):
            descriptor.kind = APPaintLayerProcessingKind.colorBalance
            descriptor.redCyan = CGFloat(settings.redCyan)
            descriptor.greenMagenta = CGFloat(settings.greenMagenta)
            descriptor.blueYellow = CGFloat(settings.blueYellow)

        case let .threshold(settings):
            descriptor.kind = APPaintLayerProcessingKind.threshold
            descriptor.threshold = CGFloat(settings.threshold)

        case let .posterize(settings):
            descriptor.kind = APPaintLayerProcessingKind.posterize
            descriptor.posterizeLevels = CGFloat(settings.levels)

        case let .transform(translation, scale, selection):
            descriptor.kind = APPaintLayerProcessingKind.transform
            descriptor.transformTranslateX = Int(translation.width.rounded())
            descriptor.transformTranslateY = Int(translation.height.rounded())
            descriptor.transformScale = scale
            if let selection, !selection.isEmpty {
                descriptor.selectionOriginX = Int(selection.bounds.minX.rounded(.down))
                descriptor.selectionOriginY = Int(selection.bounds.minY.rounded(.down))
                descriptor.selectionWidth = selection.maskWidth
                descriptor.selectionHeight = selection.maskHeight
                descriptor.selectionMaskData = selection.maskData
            }
        }
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
        max(0.08, min(max(pressure, 0.0), 1.0))
    }

    func replayTimelapseOperation(_ operation: TimelapseOperation, folderIDMap: inout [Int: Int]) {
        switch operation {
        case let .stroke(layerIndex, brush, samples):
            guard let first = samples.first else { return }
            bridge.activeLayerIndex = layerIndex
            bridge.beginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: first))
            for sample in samples.dropFirst() {
                bridge.appendStroke(point: makeStrokePoint(from: sample))
            }
            bridge.endStroke()
            invalidateThumbnailCache(for: layerIndex)

        case let .blurStroke(layerIndex, brush, samples):
            applyBlurStroke(samples: samples, brush: brush, layerIndex: layerIndex)
            invalidateThumbnailCache(for: layerIndex)

        case let .fill(layerIndex, brush, sample):
            bridge.activeLayerIndex = layerIndex
            bridge.fill(at: sample.point, brush: makeBrushDescriptor(from: brush))
            invalidateThumbnailCache(for: layerIndex)

        case .undo:
            _ = bridge.undo()
            invalidateThumbnailCache()

        case .redo:
            _ = bridge.redo()
            invalidateThumbnailCache()

        case let .addLayer(name):
            bridge.activeLayerIndex = bridge.addLayer(name: name)
            invalidateThumbnailCache()

        case let .duplicateLayer(index, name):
            bridge.activeLayerIndex = bridge.duplicateLayer(at: index, name: name)
            invalidateThumbnailCache()

        case let .deleteLayer(index):
            _ = bridge.deleteLayer(at: index)
            invalidateThumbnailCache()

        case let .moveLayer(index, destinationIndex):
            _ = bridge.moveLayer(at: index, to: destinationIndex)
            invalidateThumbnailCache()

        case let .createFolder(folderID, name, anchorLayerIndex):
            let createdID = Int(bridge.createFolder(name: name, layerIndex: anchorLayerIndex ?? -1))
            folderIDMap[folderID] = createdID

        case let .deleteFolder(folderID):
            if let resolved = folderIDMap[folderID] {
                _ = bridge.deleteFolder(id: resolved)
                folderIDMap.removeValue(forKey: folderID)
            }

        case let .setFolderVisibility(folderID, isVisible):
            if let resolved = folderIDMap[folderID] {
                bridge.setFolderVisible(isVisible, folderID: resolved)
            }

        case let .assignLayerToFolder(index, folderID):
            let resolvedFolderID = folderID.flatMap { folderIDMap[$0] } ?? -1
            _ = bridge.setLayerFolder(at: index, folderID: resolvedFolderID)
            invalidateThumbnailCache()

        case let .setLayerVisibility(index, isVisible):
            bridge.setLayerVisible(isVisible, at: index)
            invalidateThumbnailCache(for: index)

        case let .setLayerLocked(index, isLocked):
            bridge.setLayerLocked(isLocked, at: index)
            invalidateThumbnailCache(for: index)

        case let .setLayerAlphaLocked(index, isAlphaLocked):
            bridge.setLayerAlphaLocked(isAlphaLocked, at: index)
            invalidateThumbnailCache(for: index)

        case let .setLayerOpacity(index, opacity):
            bridge.setLayerOpacity(CGFloat(opacity), at: index)
            invalidateThumbnailCache(for: index)

        case let .setLayerBlendMode(index, blendMode):
            bridge.setLayerBlendMode(blendMode.rawValue, at: index)
            invalidateThumbnailCache(for: index)

        case let .replaceLayerPixels(index, data):
            bridge.replaceLayerPixels(at: index, data: data)
            invalidateThumbnailCache(for: index)

        case let .replaceLayerMask(index, data):
            bridge.replaceLayerMask(at: index, data: data)
            invalidateThumbnailCache(for: index)

        case let .clearLayerMask(index):
            bridge.clearLayerMask(at: index)
            invalidateThumbnailCache(for: index)

        case let .applyLayerMask(index):
            _ = bridge.applyLayerMask(at: index)
            invalidateThumbnailCache(for: index)

        case let .clearLayer(index):
            bridge.clearLayer(at: index)
            invalidateThumbnailCache(for: index)

        case let .setPaperStyle(style):
            paperStyle = style
        }
    }

    func timelapseCompositeImage() -> UIImage? {
        renderedCompositeImage(paperStyle: paperStyle)
    }

    private func captureTimelapseFrame() {
        guard let sourceImage = makeTimelapseThumbnail() else { return }
        appendTimelapseFrame(image: sourceImage)
    }

    private func makeTimelapseThumbnail() -> UIImage? {
        guard let sourceImage = renderedCompositeImage(paperStyle: paperStyle) else { return nil }
        let targetSize = timelapseFrameSize(
            for: CGSize(width: bridge.width, height: bridge.height),
            maxDimension: 512
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func appendTimelapseFrame(image: UIImage) {
        guard let jpegData = image.jpegData(compressionQuality: 0.72) else { return }
        let frameURL = timelapseDirectoryURL.appendingPathComponent(String(format: "frame-%06d.jpg", nextTimelapseFrameID))
        nextTimelapseFrameID += 1
        do {
            try jpegData.write(to: frameURL, options: .atomic)
        } catch {
            Self.logger.error("Failed to persist timelapse frame: \(error.localizedDescription, privacy: .public)")
            return
        }

        let frame = TimelapseFrame(imageURL: frameURL, size: image.size)
        timelapseFrames.append(frame)
        if timelapseFrames.count > Self.maxTimelapseFrames {
            let removed = timelapseFrames.remove(at: 1)
            try? FileManager.default.removeItem(at: removed.imageURL)
        }
    }

    private static func makeTimelapseDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("atelierprime-timelapse", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func timelapseFrameSize(for canvasSize: CGSize, maxDimension: CGFloat) -> CGSize {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return CGSize(width: maxDimension, height: maxDimension)
        }
        let scale = min(maxDimension / canvasSize.width, maxDimension / canvasSize.height, 1.0)
        let width = max(2, Int((canvasSize.width * scale).rounded()))
        let height = max(2, Int((canvasSize.height * scale).rounded()))
        return CGSize(width: width, height: height)
    }

    private func renderedCompositeImage(paperStyle: CanvasPaperStyle) -> UIImage? {
        guard let imageRef = bridge.makeCompositeImage() else { return nil }
        let compositeImage = UIImage(cgImage: imageRef)
        let size = CGSize(width: bridge.width, height: bridge.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !paperStyle.isTransparent
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            if !paperStyle.isTransparent {
                UIColor(
                    red: CGFloat(paperStyle.red),
                    green: CGFloat(paperStyle.green),
                    blue: CGFloat(paperStyle.blue),
                    alpha: CGFloat(paperStyle.alpha)
                ).setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            compositeImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func cachedLayerThumbnailData(index: Int) -> Data? {
        if let cached = layerThumbnailCache[index] {
            return cached
        }
        let thumbnail = makeLayerThumbnailData(index: index)
        layerThumbnailCache[index] = thumbnail
        return thumbnail
    }

    private func makeLayerThumbnailData(index: Int) -> Data? {
        guard let imageRef = bridge.makeImageForLayer(at: index) else { return nil }
        let sourceImage = UIImage(cgImage: imageRef)
        let targetSize = timelapseFrameSize(
            for: CGSize(width: bridge.width, height: bridge.height),
            maxDimension: 96
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let thumbnail = renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return thumbnail.pngData()
    }

    private func invalidateThumbnailCache(for index: Int? = nil) {
        if let index {
            layerThumbnailCache.removeValue(forKey: index)
        } else {
            layerThumbnailCache.removeAll(keepingCapacity: true)
        }
    }

    private func boxBlurredPixels(from original: [UInt8], width: Int, height: Int, radius: Double) -> [UInt8]? {
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

    private func blendBlurredPixels(
        original: [UInt8],
        blurred: [UInt8],
        width: Int,
        height: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> [UInt8] {
        var output = original
        let influenceRadius = max(4.0, brush.radius * 1.35)
        let blurStrength = max(0.08, min(brush.flow, 1.0))
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

    private func applyBlurStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, transient: Bool = false) {
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
    case setLayerOpacity(index: Int, opacity: Double)
    case setLayerBlendMode(index: Int, blendMode: LayerBlendMode)
    case replaceLayerPixels(index: Int, data: Data)
    case replaceLayerMask(index: Int, data: Data)
    case clearLayerMask(index: Int)
    case applyLayerMask(index: Int)
    case clearLayer(index: Int)
    case setPaperStyle(CanvasPaperStyle)

    func storedRepresentation(index: Int, dataDirectory: URL) throws -> StoredTimelapseOperation {
        let dataFilename: String?
        switch self {
        case let .replaceLayerPixels(_, data):
            let filename = String(format: "replace-layer-%06d.rgba", index)
            try data.write(to: dataDirectory.appendingPathComponent(filename, isDirectory: false), options: .atomic)
            dataFilename = "TimelapseData/\(filename)"
        case let .replaceLayerMask(_, data):
            let filename = String(format: "replace-mask-%06d.mask", index)
            try data.write(to: dataDirectory.appendingPathComponent(filename, isDirectory: false), options: .atomic)
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
            return StoredTimelapseOperation(kind: .setPaperStyle, paperStyle: StoredAtelierDocument.PaperStyle(
                red: Double(style.red),
                green: Double(style.green),
                blue: Double(style.blue),
                alpha: Double(style.alpha),
                isTransparent: style.isTransparent
            ))
        }
    }

    init(stored: StoredTimelapseOperation, baseURL: URL) throws {
        switch stored.kind {
        case .stroke:
            guard let layerIndex = stored.layerIndex,
                  let brush = stored.brush?.runtimeSettings,
                  let samples = stored.samples?.map(\.stylusSample)
            else { throw AtelierDocumentError.invalidDocument }
            self = .stroke(layerIndex: layerIndex, brush: brush, samples: samples)
        case .blurStroke:
            guard let layerIndex = stored.layerIndex,
                  let brush = stored.brush?.runtimeSettings,
                  let samples = stored.samples?.map(\.stylusSample)
            else { throw AtelierDocumentError.invalidDocument }
            self = .blurStroke(layerIndex: layerIndex, brush: brush, samples: samples)
        case .fill:
            guard let layerIndex = stored.layerIndex,
                  let brush = stored.brush?.runtimeSettings,
                  let sample = stored.sample?.stylusSample
            else { throw AtelierDocumentError.invalidDocument }
            self = .fill(layerIndex: layerIndex, brush: brush, sample: sample)
        case .undo:
            self = .undo
        case .redo:
            self = .redo
        case .addLayer:
            guard let name = stored.name else { throw AtelierDocumentError.invalidDocument }
            self = .addLayer(name: name)
        case .duplicateLayer:
            guard let layerIndex = stored.layerIndex, let name = stored.name else { throw AtelierDocumentError.invalidDocument }
            self = .duplicateLayer(index: layerIndex, name: name)
        case .deleteLayer:
            guard let layerIndex = stored.layerIndex else { throw AtelierDocumentError.invalidDocument }
            self = .deleteLayer(index: layerIndex)
        case .moveLayer:
            guard let layerIndex = stored.layerIndex, let destinationIndex = stored.destinationIndex else {
                throw AtelierDocumentError.invalidDocument
            }
            self = .moveLayer(index: layerIndex, destinationIndex: destinationIndex)
        case .createFolder:
            guard let folderID = stored.folderID, let name = stored.name else { throw AtelierDocumentError.invalidDocument }
            self = .createFolder(folderID: folderID, name: name, anchorLayerIndex: stored.anchorLayerIndex)
        case .deleteFolder:
            guard let folderID = stored.folderID else { throw AtelierDocumentError.invalidDocument }
            self = .deleteFolder(folderID: folderID)
        case .setFolderVisibility:
            guard let folderID = stored.folderID, let isVisible = stored.isVisible else { throw AtelierDocumentError.invalidDocument }
            self = .setFolderVisibility(folderID: folderID, isVisible: isVisible)
        case .assignLayerToFolder:
            guard let layerIndex = stored.layerIndex else { throw AtelierDocumentError.invalidDocument }
            self = .assignLayerToFolder(index: layerIndex, folderID: stored.folderID)
        case .setLayerVisibility:
            guard let layerIndex = stored.layerIndex, let isVisible = stored.isVisible else { throw AtelierDocumentError.invalidDocument }
            self = .setLayerVisibility(index: layerIndex, isVisible: isVisible)
        case .setLayerLocked:
            guard let layerIndex = stored.layerIndex, let isLocked = stored.isLocked else { throw AtelierDocumentError.invalidDocument }
            self = .setLayerLocked(index: layerIndex, isLocked: isLocked)
        case .setLayerAlphaLocked:
            guard let layerIndex = stored.layerIndex, let isAlphaLocked = stored.isAlphaLocked else { throw AtelierDocumentError.invalidDocument }
            self = .setLayerAlphaLocked(index: layerIndex, isAlphaLocked: isAlphaLocked)
        case .setLayerOpacity:
            guard let layerIndex = stored.layerIndex, let opacity = stored.opacity else { throw AtelierDocumentError.invalidDocument }
            self = .setLayerOpacity(index: layerIndex, opacity: opacity)
        case .setLayerBlendMode:
            guard let layerIndex = stored.layerIndex,
                  let blendModeRaw = stored.blendMode,
                  let blendMode = LayerBlendMode(rawValue: blendModeRaw)
            else { throw AtelierDocumentError.invalidDocument }
            self = .setLayerBlendMode(index: layerIndex, blendMode: blendMode)
        case .replaceLayerPixels:
            guard let layerIndex = stored.layerIndex, let dataFilename = stored.dataFilename else {
                throw AtelierDocumentError.invalidDocument
            }
            let data = try Data(contentsOf: baseURL.appendingPathComponent(dataFilename, isDirectory: false))
            self = .replaceLayerPixels(index: layerIndex, data: data)
        case .replaceLayerMask:
            guard let layerIndex = stored.layerIndex, let dataFilename = stored.dataFilename else {
                throw AtelierDocumentError.invalidDocument
            }
            let data = try Data(contentsOf: baseURL.appendingPathComponent(dataFilename, isDirectory: false))
            self = .replaceLayerMask(index: layerIndex, data: data)
        case .clearLayerMask:
            guard let layerIndex = stored.layerIndex else { throw AtelierDocumentError.invalidDocument }
            self = .clearLayerMask(index: layerIndex)
        case .applyLayerMask:
            guard let layerIndex = stored.layerIndex else { throw AtelierDocumentError.invalidDocument }
            self = .applyLayerMask(index: layerIndex)
        case .clearLayer:
            guard let layerIndex = stored.layerIndex else { throw AtelierDocumentError.invalidDocument }
            self = .clearLayer(index: layerIndex)
        case .setPaperStyle:
            guard let paperStyle = stored.paperStyle else { throw AtelierDocumentError.invalidDocument }
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

struct StoredAtelierDocument: Codable {
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
        let opacity: Double
        let blendMode: String
        let folderID: Int?
        let pixelFilename: String
        let maskFilename: String?

        enum CodingKeys: String, CodingKey {
            case index
            case name
            case visible
            case locked
            case alphaLocked
            case opacity
            case blendMode
            case folderID
            case pixelFilename
            case maskFilename
        }

        init(
            index: Int,
            name: String,
            visible: Bool,
            locked: Bool,
            alphaLocked: Bool,
            opacity: Double,
            blendMode: String,
            folderID: Int?,
            pixelFilename: String,
            maskFilename: String?
        ) {
            self.index = index
            self.name = name
            self.visible = visible
            self.locked = locked
            self.alphaLocked = alphaLocked
            self.opacity = opacity
            self.blendMode = blendMode
            self.folderID = folderID
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
            opacity = try container.decode(Double.self, forKey: .opacity)
            blendMode = try container.decode(String.self, forKey: .blendMode)
            folderID = try container.decodeIfPresent(Int.self, forKey: .folderID)
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
    let wetness: Double
    let wetnessPressureSensitivity: Double
    let opacityPressureSensitivity: Double
    let colorMixStrength: Double
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
        wetness = brush.wetness
        wetnessPressureSensitivity = brush.wetnessPressureSensitivity
        opacityPressureSensitivity = brush.opacityPressureSensitivity
        colorMixStrength = brush.colorMixStrength
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
            wetness: wetness,
            wetnessPressureSensitivity: wetnessPressureSensitivity,
            opacityPressureSensitivity: opacityPressureSensitivity,
            colorMixStrength: colorMixStrength,
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
    var opacity: Double?
    var blendMode: String?
    var brush: StoredBrushRuntimeSettings?
    var samples: [StoredStylusSample]?
    var sample: StoredStylusSample?
    var dataFilename: String?
    var paperStyle: StoredAtelierDocument.PaperStyle?

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
        opacity: Double? = nil,
        blendMode: String? = nil,
        brush: StoredBrushRuntimeSettings? = nil,
        samples: [StoredStylusSample]? = nil,
        sample: StoredStylusSample? = nil,
        dataFilename: String? = nil,
        paperStyle: StoredAtelierDocument.PaperStyle? = nil
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
        self.opacity = opacity
        self.blendMode = blendMode
        self.brush = brush
        self.samples = samples
        self.sample = sample
        self.dataFilename = dataFilename
        self.paperStyle = paperStyle
    }
}

private enum AtelierDocumentError: LocalizedError {
    case invalidDocument

    var errorDescription: String? {
        "The selected atelier document is invalid."
    }
}
