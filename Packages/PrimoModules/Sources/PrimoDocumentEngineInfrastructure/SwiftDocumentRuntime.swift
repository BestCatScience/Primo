import CoreGraphics
import Foundation
import os
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoBrushRuntimeContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain
import PrimoDocumentInfrastructure
import PrimoDocumentPersistenceInfrastructure
import PrimoDocumentStrokeInfrastructure
import PrimoDocumentTimelapseInfrastructure

struct RuntimeResizeCanvasPlan: Sendable {
    enum Mode: Sendable {
        case scale
        case extent
    }

    let mode: Mode
    let before: SwiftDocumentStoreSnapshot
    let sourceWidth: Int
    let sourceHeight: Int
    let targetWidth: Int
    let targetHeight: Int
    let layers: [SwiftDocumentLayerRecord]
    let gpuServices: DocumentRuntimeGpuServices

    func resizedLayers() -> [SwiftDocumentLayerRecord]? {
        switch mode {
        case .scale:
            return scaledLayers()
        case .extent:
            return extentAdjustedLayers()
        }
    }

    private func scaledLayers() -> [SwiftDocumentLayerRecord]? {
        let widthScale = Double(targetWidth) / Double(sourceWidth)
        let heightScale = Double(targetHeight) / Double(sourceHeight)
        let textScale = min(widthScale, heightScale)
        var output: [SwiftDocumentLayerRecord] = []
        output.reserveCapacity(layers.count)
        for var layer in layers {
            guard let scaled = gpuServices.scaledPixelData(
                layer.pixelData,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                targetWidth: targetWidth,
                targetHeight: targetHeight
            ) else {
                return nil
            }
            layer.pixelData = scaled
            if let mask = layer.maskData {
                guard let scaledMask = gpuServices.scaledMaskData(
                    mask,
                    sourceWidth: sourceWidth,
                    sourceHeight: sourceHeight,
                    targetWidth: targetWidth,
                    targetHeight: targetHeight
                ) else {
                    return nil
                }
                layer.maskData = scaledMask
            }
            if let textLayer = layer.textLayer {
                layer.textLayer = TextLayerData(
                    text: textLayer.text,
                    positionX: textLayer.positionX * widthScale,
                    positionY: textLayer.positionY * heightScale,
                    fontPostScriptName: textLayer.fontPostScriptName,
                    fontDisplayName: textLayer.fontDisplayName,
                    fontSize: max(1, textLayer.fontSize * textScale),
                    scale: textLayer.scale,
                    rotationDegrees: textLayer.rotationDegrees,
                    red: textLayer.red,
                    green: textLayer.green,
                    blue: textLayer.blue,
                    alpha: textLayer.alpha
                )
            }
            output.append(layer)
        }
        return output
    }

    private func extentAdjustedLayers() -> [SwiftDocumentLayerRecord]? {
        let offsetX = (targetWidth - sourceWidth) / 2
        let offsetY = (targetHeight - sourceHeight) / 2
        var output: [SwiftDocumentLayerRecord] = []
        output.reserveCapacity(layers.count)
        for var layer in layers {
            guard let translated = gpuServices.translatedPixelData(
                layer.pixelData,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                targetWidth: targetWidth,
                targetHeight: targetHeight,
                offsetX: offsetX,
                offsetY: offsetY
            ) else {
                return nil
            }
            layer.pixelData = translated
            if let mask = layer.maskData {
                guard let translatedMask = gpuServices.translatedMaskData(
                    mask,
                    sourceWidth: sourceWidth,
                    sourceHeight: sourceHeight,
                    targetWidth: targetWidth,
                    targetHeight: targetHeight,
                    offsetX: offsetX,
                    offsetY: offsetY
                ) else {
                    return nil
                }
                layer.maskData = translatedMask
            }
            if let textLayer = layer.textLayer {
                layer.textLayer = TextLayerData(
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
            }
            output.append(layer)
        }
        return output
    }
}

struct RuntimeLayerProcessingPlan: Sendable {
    let index: Int
    let request: LayerProcessingRequest
    let revision: Int
    let canvasWidth: Int
    let canvasHeight: Int
    let pixelData: Data
    let gpuServices: DocumentRuntimeGpuServices
}

struct RuntimeFillPlan: Sendable {
    let layerIndex: Int
    let revision: Int
    let canvasWidth: Int
    let canvasHeight: Int
    let pixelData: Data
    let sourceBufferHandle: MetalBufferHandle?
    let retainedResource: GpuResourceLease?
    let sample: StylusSample
    let brush: BrushRuntimeSettings
    let gpuServices: DocumentRuntimeGpuServices
}

struct RuntimeStrokeCommitPlan: Sendable {
    let layerIndex: Int
    let revision: Int
    let canvasWidth: Int
    let canvasHeight: Int
    let pixelData: Data
    let baseBufferHandle: MetalBufferHandle?
    let retainedResource: GpuResourceLease?
    let samples: [StylusSample]
    let brush: BrushRuntimeSettings
    let gpuServices: DocumentRuntimeGpuServices
}

struct RuntimeBlurPlan: Sendable {
    let layerIndex: Int
    let revision: Int
    let canvasWidth: Int
    let canvasHeight: Int
    let pixelData: Data
    let sourceBufferHandle: MetalBufferHandle?
    let retainedResource: GpuResourceLease?
    let samples: [StylusSample]
    let brush: BrushRuntimeSettings
    let captureTimelapse: Bool
    let gpuServices: DocumentRuntimeGpuServices
}

final class GpuResourceLease: @unchecked Sendable {
    private let handle: MetalBufferHandle?
    private let releaseHandle: @Sendable (MetalBufferHandle?) -> Void

    init?(handle: MetalBufferHandle?, services: DocumentRuntimeGpuServices) {
        guard let handle, services.retain(handle) else { return nil }
        self.handle = handle
        self.releaseHandle = services.release
    }

    deinit {
        releaseHandle(handle)
    }
}

private struct GpuLayerStoragePolicy: Sendable {
    private var handles: [Int: MetalBufferHandle] = [:]

    func handle(for index: Int) -> MetalBufferHandle? {
        handles[index]
    }

    func materializedSnapshot(
        from snapshot: SwiftDocumentStoreSnapshot,
        rgbaByteCount: Int,
        services: DocumentRuntimeGpuServices
    ) -> SwiftDocumentStoreSnapshot {
        var snapshot = snapshot
        for index in handles.keys where snapshot.layers.indices.contains(index) {
            snapshot.layers[index].pixelData = currentPixelData(
                for: index,
                in: snapshot,
                rgbaByteCount: rgbaByteCount,
                services: services
            )
        }
        return snapshot
    }

    func currentPixelData(
        for index: Int,
        in snapshot: SwiftDocumentStoreSnapshot,
        rgbaByteCount: Int,
        services: DocumentRuntimeGpuServices
    ) -> Data {
        guard snapshot.layers.indices.contains(index) else { return Data() }
        if let handle = handles[index],
           let pixelData = services.materializedPixelData(for: handle),
           pixelData.count == rgbaByteCount {
            return pixelData
        }
        return snapshot.layers[index].pixelData
    }

    mutating func materializeGpuBackedLayerPixels(
        in store: SwiftDocumentStore,
        rgbaByteCount: Int,
        services: DocumentRuntimeGpuServices
    ) {
        for index in handles.keys where store.snapshot.layers.indices.contains(index) {
            store.snapshot.layers[index].pixelData = currentPixelData(
                for: index,
                in: store.snapshot,
                rgbaByteCount: rgbaByteCount,
                services: services
            )
        }
    }

    mutating func setLayerPixelState(
        index: Int,
        pixelData: Data,
        gpuBufferHandle: MetalBufferHandle?,
        in store: SwiftDocumentStore,
        services: DocumentRuntimeGpuServices
    ) {
        let previousHandle = handles[index]
        store.snapshot.layers[index].pixelData = pixelData
        if let gpuBufferHandle {
            handles[index] = gpuBufferHandle
        } else {
            handles.removeValue(forKey: index)
        }
        if previousHandle != gpuBufferHandle {
            services.release(previousHandle)
        }
    }

    mutating func releaseLayerBufferHandles(services: DocumentRuntimeGpuServices) {
        for handle in handles.values {
            services.release(handle)
        }
        handles.removeAll(keepingCapacity: true)
    }

    func layerSourceForGpuPlan(
        index: Int,
        snapshot: SwiftDocumentStoreSnapshot,
        services: DocumentRuntimeGpuServices
    ) -> (
        pixelData: Data,
        bufferHandle: MetalBufferHandle?,
        retainedResource: GpuResourceLease?
    ) {
        guard snapshot.layers.indices.contains(index) else {
            return (Data(), nil, nil)
        }
        guard let handle = handles[index] else {
            return (snapshot.layers[index].pixelData, nil, nil)
        }
        guard let lease = GpuResourceLease(handle: handle, services: services) else {
            return (snapshot.layers[index].pixelData, nil, nil)
        }
        return (snapshot.layers[index].pixelData, handle, lease)
    }
}

private struct TimelapseRecorder: Sendable {
    func record(
        _ event: TimelapseOperation?,
        marksOperationPersistence: Bool = false,
        in store: SwiftDocumentStore
    ) {
        if let event {
            if marksOperationPersistence {
                store.snapshot.timelapseUsesOperationPersistence = true
            }
            store.snapshot.timelapseEvents.append(event)
        }
    }
}

private struct UndoSnapshotPolicy: Sendable {
    struct Limits: Sendable {
        var maxEntryCount: Int = 50
        var maxRetainedBytes: Int = 128 * 1024 * 1024
    }

    struct DebugStats: Sendable, Equatable {
        var retainedBytes: Int
        var undoCount: Int
        var redoCount: Int
        var evictedCount: Int
        var droppedOversizedCount: Int
    }

    private var undoStack: [UndoHistoryEntry] = []
    private var redoStack: [UndoHistoryEntry] = []
    private var retainedBytes = 0
    private var evictedCount = 0
    private var droppedOversizedCount = 0
    private let limits: Limits

    init(limits: Limits = Limits()) {
        self.limits = limits
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var debugStats: DebugStats {
        DebugStats(
            retainedBytes: retainedBytes,
            undoCount: undoStack.count,
            redoCount: redoStack.count,
            evictedCount: evictedCount,
            droppedOversizedCount: droppedOversizedCount
        )
    }

    mutating func recordMutation(
        before: SwiftDocumentStoreSnapshot,
        after: SwiftDocumentStoreSnapshot,
        changedLayerIndex: Int?,
        dirtyRect: LayerPixelRect?
    ) -> DebugStats {
        let entry = UndoHistoryEntry(
            before: before,
            after: after,
            changedLayerIndex: changedLayerIndex,
            dirtyRect: dirtyRect
        )
        clearRedo()
        appendUndo(entry)
        enforceLimits()
        return debugStats
    }

    mutating func restoreUndo(current: SwiftDocumentStoreSnapshot) -> Result<SwiftDocumentStoreSnapshot, DocumentMutationFailure> {
        while let entry = popUndo() {
            guard let previous = entry.undoSnapshot(from: current),
                  !previous.hasSameDocumentContent(as: current)
            else {
                continue
            }
            appendRedo(entry.flipped(current: current))
            enforceLimits()
            return .success(previous)
        }
        return .failure(.noUndoState)
    }

    mutating func restoreRedo(current: SwiftDocumentStoreSnapshot) -> Result<SwiftDocumentStoreSnapshot, DocumentMutationFailure> {
        while let entry = popRedo() {
            guard let next = entry.redoSnapshot(from: current),
                  !next.hasSameDocumentContent(as: current)
            else {
                continue
            }
            appendUndo(entry.flipped(current: current))
            enforceLimits()
            return .success(next)
        }
        return .failure(.noRedoState)
    }

    mutating func trimForMemoryPressure() -> DebugStats {
        clearRedo()
        let targetBytes = limits.maxRetainedBytes / 4
        while undoStack.count > 8 || retainedBytes > targetBytes {
            guard !undoStack.isEmpty else { break }
            removeOldestUndoEntry()
        }
        return debugStats
    }

    mutating func clear() {
        undoStack.removeAll(keepingCapacity: true)
        redoStack.removeAll(keepingCapacity: true)
        retainedBytes = 0
    }

    private mutating func appendUndo(_ entry: UndoHistoryEntry) {
        guard entry.byteCount <= limits.maxRetainedBytes else {
            droppedOversizedCount += 1
            return
        }
        undoStack.append(entry)
        retainedBytes += entry.byteCount
    }

    private mutating func appendRedo(_ entry: UndoHistoryEntry) {
        guard entry.byteCount <= limits.maxRetainedBytes else {
            droppedOversizedCount += 1
            return
        }
        redoStack.append(entry)
        retainedBytes += entry.byteCount
    }

    private mutating func popUndo() -> UndoHistoryEntry? {
        guard let entry = undoStack.popLast() else { return nil }
        retainedBytes -= entry.byteCount
        return entry
    }

    private mutating func popRedo() -> UndoHistoryEntry? {
        guard let entry = redoStack.popLast() else { return nil }
        retainedBytes -= entry.byteCount
        return entry
    }

    private mutating func clearRedo() {
        retainedBytes -= redoStack.reduce(0) { $0 + $1.byteCount }
        redoStack.removeAll(keepingCapacity: true)
    }

    private mutating func enforceLimits() {
        while undoStack.count + redoStack.count > limits.maxEntryCount || retainedBytes > limits.maxRetainedBytes {
            if !undoStack.isEmpty {
                removeOldestUndoEntry()
            } else if !redoStack.isEmpty {
                removeOldestRedoEntry()
            } else {
                break
            }
        }
    }

    private mutating func removeOldestUndoEntry() {
        let entry = undoStack.removeFirst()
        retainedBytes -= entry.byteCount
        evictedCount += 1
    }

    private mutating func removeOldestRedoEntry() {
        let entry = redoStack.removeFirst()
        retainedBytes -= entry.byteCount
        evictedCount += 1
    }
}

private enum UndoHistoryEntry: Sendable {
    case snapshot(SwiftDocumentStoreSnapshot)
    case layerRectDelta(LayerRectDeltaUndoEntry)

    init(
        before: SwiftDocumentStoreSnapshot,
        after: SwiftDocumentStoreSnapshot,
        changedLayerIndex: Int?,
        dirtyRect: LayerPixelRect?
    ) {
        guard let changedLayerIndex,
              let dirtyRect,
              let delta = LayerRectDeltaUndoEntry(
                before: before,
                after: after,
                layerIndex: changedLayerIndex,
                rect: dirtyRect
              )
        else {
            self = .snapshot(before)
            return
        }
        self = .layerRectDelta(delta)
    }

    var byteCount: Int {
        switch self {
        case let .snapshot(snapshot):
            return snapshot.undoRetainedByteCount
        case let .layerRectDelta(delta):
            return delta.byteCount
        }
    }

    func undoSnapshot(from current: SwiftDocumentStoreSnapshot) -> SwiftDocumentStoreSnapshot? {
        switch self {
        case let .snapshot(snapshot):
            return snapshot
        case let .layerRectDelta(delta):
            return delta.snapshot(from: current, direction: .undo)
        }
    }

    func redoSnapshot(from current: SwiftDocumentStoreSnapshot) -> SwiftDocumentStoreSnapshot? {
        switch self {
        case let .snapshot(snapshot):
            return snapshot
        case let .layerRectDelta(delta):
            return delta.snapshot(from: current, direction: .redo)
        }
    }

    func flipped(current: SwiftDocumentStoreSnapshot) -> UndoHistoryEntry {
        switch self {
        case .snapshot:
            return .snapshot(current)
        case .layerRectDelta:
            return self
        }
    }
}

private struct LayerRectDeltaUndoEntry: Sendable {
    enum Direction {
        case undo
        case redo
    }

    var layerIndex: Int
    var rect: LayerPixelRect
    var canvasWidth: Int
    var canvasHeight: Int
    var beforeLayer: LayerUndoMetadata
    var afterLayer: LayerUndoMetadata
    var beforePixels: Data
    var afterPixels: Data

    init?(
        before: SwiftDocumentStoreSnapshot,
        after: SwiftDocumentStoreSnapshot,
        layerIndex: Int,
        rect: LayerPixelRect
    ) {
        guard before.canvasWidth == after.canvasWidth,
              before.canvasHeight == after.canvasHeight,
              before.layers.indices.contains(layerIndex),
              after.layers.indices.contains(layerIndex),
              rect.isContained(inWidth: before.canvasWidth, height: before.canvasHeight),
              let beforePixels = before.layers[layerIndex].pixelData.cropped(width: before.canvasWidth, rect: rect),
              let afterPixels = after.layers[layerIndex].pixelData.cropped(width: after.canvasWidth, rect: rect)
        else {
            return nil
        }
        self.layerIndex = layerIndex
        self.rect = rect
        self.canvasWidth = before.canvasWidth
        self.canvasHeight = before.canvasHeight
        self.beforeLayer = LayerUndoMetadata(layer: before.layers[layerIndex])
        self.afterLayer = LayerUndoMetadata(layer: after.layers[layerIndex])
        self.beforePixels = beforePixels
        self.afterPixels = afterPixels
    }

    var byteCount: Int {
        beforePixels.count + afterPixels.count + beforeLayer.byteCount + afterLayer.byteCount
    }

    func snapshot(from current: SwiftDocumentStoreSnapshot, direction: Direction) -> SwiftDocumentStoreSnapshot? {
        guard current.canvasWidth == canvasWidth,
              current.canvasHeight == canvasHeight,
              current.layers.indices.contains(layerIndex)
        else {
            return nil
        }
        let pixels = direction == .undo ? beforePixels : afterPixels
        let metadata = direction == .undo ? beforeLayer : afterLayer
        guard let patchedPixels = current.layers[layerIndex].pixelData.patching(
            pixels,
            width: canvasWidth,
            rect: rect
        ) else {
            return nil
        }
        var snapshot = current
        metadata.apply(to: &snapshot.layers[layerIndex])
        snapshot.layers[layerIndex].pixelData = patchedPixels
        return snapshot
    }
}

private struct LayerUndoMetadata: Sendable {
    var name: String
    var visible: Bool
    var locked: Bool
    var alphaLocked: Bool
    var clipped: Bool
    var opacity: Double
    var blendMode: LayerBlendMode
    var folderID: Int?
    var textLayer: TextLayerData?

    init(layer: SwiftDocumentLayerRecord) {
        name = layer.name
        visible = layer.visible
        locked = layer.locked
        alphaLocked = layer.alphaLocked
        clipped = layer.clipped
        opacity = layer.opacity
        blendMode = layer.blendMode
        folderID = layer.folderID
        textLayer = layer.textLayer
    }

    var byteCount: Int {
        name.utf8.count + (textLayer?.text.utf8.count ?? 0)
    }

    func apply(to layer: inout SwiftDocumentLayerRecord) {
        layer.name = name
        layer.visible = visible
        layer.locked = locked
        layer.alphaLocked = alphaLocked
        layer.clipped = clipped
        layer.opacity = opacity
        layer.blendMode = blendMode
        layer.folderID = folderID
        layer.textLayer = textLayer
    }
}

private extension SwiftDocumentStoreSnapshot {
    var undoRetainedByteCount: Int {
        layers.reduce(0) { partial, layer in
            partial +
                layer.pixelData.count +
                (layer.maskData?.count ?? 0) +
                layer.name.utf8.count +
                (layer.textLayer?.text.utf8.count ?? 0)
        } + thumbnailCache.values.reduce(0) { $0 + $1.count } +
            timelapseFrames.reduce(0) { $0 + $1.imageURL.absoluteString.utf8.count } +
            timelapseEvents.undoRetainedByteCount
    }

    func hasSameDocumentContent(as other: SwiftDocumentStoreSnapshot) -> Bool {
        canvasWidth == other.canvasWidth &&
            canvasHeight == other.canvasHeight &&
            activeLayerIndex == other.activeLayerIndex &&
            paperStyle == other.paperStyle &&
            nextFolderID == other.nextFolderID &&
            layers == other.layers &&
            folders == other.folders &&
            thumbnailCache == other.thumbnailCache
    }
}

private extension Array where Element == TimelapseOperation {
    var undoRetainedByteCount: Int {
        reduce(0) { partial, operation in
            partial + operation.undoRetainedByteCount
        }
    }
}

private extension TimelapseOperation {
    var undoRetainedByteCount: Int {
        switch self {
        case let .stroke(_, brush, samples),
             let .blurStroke(_, brush, samples):
            return brushMemoryByteCount(brush) + samples.count * MemoryLayout<StylusSample>.stride
        case let .fill(_, brush, _):
            return brushMemoryByteCount(brush) + MemoryLayout<StylusSample>.stride
        case let .addLayer(name),
             let .duplicateLayer(_, name),
             let .setLayerName(_, name),
             let .createFolder(_, name, _),
             let .setFolderName(_, name):
            return name.utf8.count
        case let .replaceLayerPixels(_, data),
             let .replaceLayerMask(_, data):
            return data.count
        default:
            return 0
        }
    }

    private func brushMemoryByteCount(_ brush: BrushRuntimeSettings) -> Int {
        MemoryLayout<BrushRuntimeSettings>.stride + (brush.customTip?.alphaData.count ?? 0)
    }
}

private extension LayerPixelRect {
    func isContained(inWidth width: Int, height: Int) -> Bool {
        originX >= 0 &&
            originY >= 0 &&
            self.width > 0 &&
            self.height > 0 &&
            originX <= width &&
            originY <= height &&
            self.width <= width - originX &&
            self.height <= height - originY
    }
}

private extension Data {
    func cropped(width: Int, rect: LayerPixelRect) -> Data? {
        guard let requiredByteCount = requiredByteCount(width: width, rect: rect),
              count >= requiredByteCount
        else {
            return nil
        }
        var output = Data(count: rect.width * rect.height * 4)
        output.withUnsafeMutableBytes { destinationBytes in
            withUnsafeBytes { sourceBytes in
                guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else { return }
                for row in 0..<rect.height {
                    let sourceOffset = (((rect.originY + row) * width) + rect.originX) * 4
                    let destinationOffset = row * rect.width * 4
                    memcpy(destination + destinationOffset, source + sourceOffset, rect.width * 4)
                }
            }
        }
        return output
    }

    func patching(_ patch: Data, width: Int, rect: LayerPixelRect) -> Data? {
        guard patch.count == rect.width * rect.height * 4,
              let requiredByteCount = requiredByteCount(width: width, rect: rect),
              count >= requiredByteCount
        else {
            return nil
        }
        var output = self
        output.withUnsafeMutableBytes { destinationBytes in
            patch.withUnsafeBytes { sourceBytes in
                guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else { return }
                for row in 0..<rect.height {
                    let destinationOffset = (((rect.originY + row) * width) + rect.originX) * 4
                    let sourceOffset = row * rect.width * 4
                    memcpy(destination + destinationOffset, source + sourceOffset, rect.width * 4)
                }
            }
        }
        return output
    }

    private func requiredByteCount(width: Int, rect: LayerPixelRect) -> Int? {
        guard rect.isContained(inWidth: width, height: Int.max) else { return nil }
        let rowResult = rect.originY.addingReportingOverflow(rect.height)
        guard !rowResult.overflow else { return nil }
        let pixelResult = width.multipliedReportingOverflow(by: rowResult.partialValue)
        guard !pixelResult.overflow else { return nil }
        let byteResult = pixelResult.partialValue.multipliedReportingOverflow(by: 4)
        guard !byteResult.overflow else { return nil }
        return byteResult.partialValue
    }
}

final class SwiftDocumentRuntime: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.primo.app", category: "SwiftDocumentRuntime")

    private let services: DocumentEngineServices
    private let gpuServices: DocumentRuntimeGpuServices
    private let store: SwiftDocumentStore
    private var undoPolicy: UndoSnapshotPolicy
    private var pendingDirtyUpdate: IncrementalLayerUpdate?
    private var currentStroke: (layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])?
    private var currentBlurStroke: (baseline: SwiftDocumentStoreSnapshot?, layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])?
    private var thumbnailSurfaceCache: [Int: DocumentCompositeSurface] = [:]
    private var gpuLayerStorage = GpuLayerStoragePolicy()
    private let timelapseRecorder = TimelapseRecorder()

    init(
        width: Int = 1152,
        height: Int = 1536,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live,
        gpuServices: DocumentRuntimeGpuServices,
        maxUndoEntryCount: Int = 50,
        maxUndoRetainedBytes: Int = 128 * 1024 * 1024
    ) {
        self.services = DocumentEngineServices(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
        self.gpuServices = gpuServices
        self.store = SwiftDocumentStore(width: width, height: height)
        self.undoPolicy = UndoSnapshotPolicy(
            limits: UndoSnapshotPolicy.Limits(
                maxEntryCount: maxUndoEntryCount,
                maxRetainedBytes: maxUndoRetainedBytes
            )
        )
        captureDirtyUpdate()
    }

    var currentPaperStyle: CanvasPaperStyle {
        store.snapshot.paperStyle
    }

    func lightweightPresentation() -> PaintDocumentPresentation {
        PaintDocumentPresentation(
            canvasSize: canvasSize,
            activeLayerIndex: store.snapshot.activeLayerIndex,
            layerRows: buildLayerRows(),
            layerSidebarRows: buildSidebarRows(),
            renderSnapshot: nil
        )
    }

    func presentation() -> PaintDocumentPresentation {
        PaintDocumentPresentation(
            canvasSize: canvasSize,
            activeLayerIndex: store.snapshot.activeLayerIndex,
            layerRows: buildLayerRows(),
            layerSidebarRows: buildSidebarRows(),
            renderSnapshot: makeRenderSnapshot()
        )
    }

    func prewarmDrawingResources() {
        _ = compositeSurface()
    }

    func compositeSurface() -> DocumentCompositeSurface {
        compositeSurfaceForSnapshot(store.snapshot)
    }

    func compositePixelData() -> Data {
        // Legacy convenience retained for callers that still expect raw bytes.
        compositeSurface().pixelData
    }

    func consumeDirtyUpdate() -> IncrementalLayerUpdate? {
        defer { pendingDirtyUpdate = nil }
        return pendingDirtyUpdate
    }

    func pixelDataForLayer(index: Int) -> Data {
        guard store.snapshot.layers.indices.contains(index) else { return Data() }
        return currentPixelData(for: index)
    }

    func materializedSnapshot() -> SwiftDocumentStoreSnapshot {
        var snapshot = store.snapshot
        for index in snapshot.layers.indices {
            snapshot.layers[index].pixelData = currentPixelData(for: index)
        }
        return snapshot
    }

    private func undoSnapshot() -> SwiftDocumentStoreSnapshot {
        gpuBackedMaterializedSnapshot()
    }

    private func gpuBackedMaterializedSnapshot() -> SwiftDocumentStoreSnapshot {
        gpuLayerStorage.materializedSnapshot(
            from: store.snapshot,
            rgbaByteCount: rgbaByteCount,
            services: gpuServices
        )
    }

    private func materializeGpuBackedLayerPixels() {
        gpuLayerStorage.materializeGpuBackedLayerPixels(
            in: store,
            rgbaByteCount: rgbaByteCount,
            services: gpuServices
        )
    }

    func canUndo() -> Bool {
        undoPolicy.canUndo
    }

    func canRedo() -> Bool {
        undoPolicy.canRedo
    }

    func undo() -> DocumentMutationResult {
        let previous: SwiftDocumentStoreSnapshot
        switch undoPolicy.restoreUndo(current: undoSnapshot()) {
        case let .success(snapshot):
            previous = snapshot
        case let .failure(failure):
            return .failure(failure)
        }
        store.restore(previous)
        thumbnailSurfaceCache.removeAll(keepingCapacity: true)
        releaseLayerBufferHandles()
        timelapseRecorder.record(.undo, in: store)
        store.snapshot.revision += 1
        captureDirtyUpdate()
        return .success(())
    }

    func redo() -> DocumentMutationResult {
        let next: SwiftDocumentStoreSnapshot
        switch undoPolicy.restoreRedo(current: undoSnapshot()) {
        case let .success(snapshot):
            next = snapshot
        case let .failure(failure):
            return .failure(failure)
        }
        store.restore(next)
        thumbnailSurfaceCache.removeAll(keepingCapacity: true)
        releaseLayerBufferHandles()
        timelapseRecorder.record(.redo, in: store)
        store.snapshot.revision += 1
        captureDirtyUpdate()
        return .success(())
    }

    func trimUndoHistoryForMemoryPressure() {
        let stats = undoPolicy.trimForMemoryPressure()
        logUndoHistoryStats(stats, reason: "memoryPressure")
    }

    func resizeCanvas(width: Int, height: Int) -> DocumentMutationResult {
        switch makeResizeCanvasPlan(width: width, height: height) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let plan else { return .success(()) }
            guard let layers = plan.resizedLayers() else {
                return .failure(.bridgeMutationFailed("resizeCanvas"))
            }
            return applyResizeCanvasPlan(plan, layers: layers)
        }
    }

    func resizeCanvasExtent(width: Int, height: Int) -> DocumentMutationResult {
        switch makeResizeCanvasExtentPlan(width: width, height: height) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let plan else { return .success(()) }
            guard let layers = plan.resizedLayers() else {
                return .failure(.bridgeMutationFailed("resizeCanvasExtent"))
            }
            return applyResizeCanvasPlan(plan, layers: layers)
        }
    }

    func makeResizeCanvasPlan(width: Int, height: Int) -> Result<RuntimeResizeCanvasPlan?, DocumentMutationFailure> {
        makeResizeCanvasPlan(width: width, height: height, mode: .scale)
    }

    func makeResizeCanvasExtentPlan(width: Int, height: Int) -> Result<RuntimeResizeCanvasPlan?, DocumentMutationFailure> {
        makeResizeCanvasPlan(width: width, height: height, mode: .extent)
    }

    private func makeResizeCanvasPlan(
        width: Int,
        height: Int,
        mode: RuntimeResizeCanvasPlan.Mode
    ) -> Result<RuntimeResizeCanvasPlan?, DocumentMutationFailure> {
        guard width > 0 && height > 0 else {
            return .failure(.invalidCanvasSize(width: width, height: height))
        }
        let sourceSize = PaintDocumentCanvasSize(width: store.snapshot.canvasWidth, height: store.snapshot.canvasHeight)
        let targetSize = PaintDocumentCanvasSize(width: width, height: height)
        guard sourceSize != targetSize else { return .success(nil) }
        let before = undoSnapshot()
        let layers = before.layers
        return .success(
            RuntimeResizeCanvasPlan(
                mode: mode,
                before: before,
                sourceWidth: sourceSize.width,
                sourceHeight: sourceSize.height,
                targetWidth: targetSize.width,
                targetHeight: targetSize.height,
                layers: layers,
                gpuServices: gpuServices
            )
        )
    }

    func applyResizeCanvasPlan(
        _ plan: RuntimeResizeCanvasPlan,
        layers: [SwiftDocumentLayerRecord]
    ) -> DocumentMutationResult {
        guard store.snapshot.revision == plan.before.revision,
              store.snapshot.canvasWidth == plan.sourceWidth,
              store.snapshot.canvasHeight == plan.sourceHeight,
              store.snapshot.layers.count == plan.before.layers.count,
              layers.count == plan.before.layers.count else {
            return .failure(.gpu(.staleSnapshot(operation: "resizeCanvas")))
        }
        store.snapshot.layers = layers
        store.snapshot.canvasWidth = plan.targetWidth
        store.snapshot.canvasHeight = plan.targetHeight
        store.snapshot.thumbnailCache.removeAll()
        thumbnailSurfaceCache.removeAll(keepingCapacity: true)
        releaseLayerBufferHandles()
        recordMutation(before: plan.before, timelapseEvent: nil)
        return .success(())
    }

    func addLayer(name: String) -> DocumentIndexedMutationResult {
        let before = undoSnapshot()
        let size = PaintDocumentCanvasSize(width: store.snapshot.canvasWidth, height: store.snapshot.canvasHeight)
        let layer = SwiftDocumentLayerRecord(
            name: name,
            visible: true,
            locked: false,
            alphaLocked: false,
            clipped: false,
            opacity: 1.0,
            blendMode: .normal,
            folderID: nil,
            textLayer: nil,
            pixelData: Data(count: size.rgbaByteCount),
            maskData: nil
        )
        store.snapshot.layers.append(layer)
        let index = store.snapshot.layers.count - 1
        store.snapshot.activeLayerIndex = index
        materializeGpuBackedLayerPixels()
        releaseLayerBufferHandles()
        recordMutation(before: before, timelapseEvent: .addLayer(name: name))
        return .success(index)
    }

    func setActiveLayer(index: Int) -> DocumentMutationResult {
        guard store.snapshot.layers.indices.contains(index) else {
            return .failure(.invalidLayerIndex(index))
        }
        store.snapshot.activeLayerIndex = index
        return .success(())
    }

    func setLayerName(index: Int, name: String) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        let before = undoSnapshot()
        store.snapshot.layers[index].name = name
        recordMutation(before: before, timelapseEvent: .setLayerName(index: .unchecked(index), name: name))
        return .success(())
    }

    func setLayerVisibility(index: Int, isVisible: Bool) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        guard store.snapshot.layers[index].visible != isVisible else {
            return .success(())
        }
        let before = undoSnapshot()
        store.snapshot.layers[index].visible = isVisible
        recordMutation(before: before, timelapseEvent: .setLayerVisibility(index: .unchecked(index), isVisible: isVisible))
        return .success(())
    }

    func revealLayerForEditing(index: Int) -> DocumentMutationResult {
        setLayerVisibility(index: index, isVisible: true)
    }

    func replaceLayerPixels(index: Int, data: Data) -> DocumentMutationResult {
        guard !data.isEmpty else { return .failure(.emptyInput) }
        guard let failure = validateEditableLayer(index) else {
            return replaceLayerPixelsUnchecked(index: index, data: data, timelapseEvent: .replaceLayerPixels(index: .unchecked(index), data: data))
        }
        return .failure(failure)
    }

    func replaceLayerPixels(index: Int, in rect: LayerPixelRect, data: Data) -> DocumentMutationResult {
        guard !data.isEmpty else { return .failure(.emptyInput) }
        guard rect.width > 0, rect.height > 0 else {
            return .failure(.gpu(.invalidDirtyRect(operation: "replaceLayerPixelsInRect")))
        }
        guard data.count == rect.width * rect.height * 4 else {
            return .failure(.gpu(.invalidPayloadSize(
                operation: "replaceLayerPixelsInRect",
                expected: rect.width * rect.height * 4,
                actual: data.count
            )))
        }
        guard rect.originX >= 0,
              rect.originY >= 0,
              rect.originX + rect.width <= store.snapshot.canvasWidth,
              rect.originY + rect.height <= store.snapshot.canvasHeight
        else {
            return .failure(.gpu(.invalidDirtyRect(operation: "replaceLayerPixelsInRect")))
        }
        guard let failure = validateEditableLayer(index) else {
            let before = undoSnapshot()
            let existing = currentPixelData(for: index)
            var output = existing
            output.withUnsafeMutableBytes { destinationBytes in
                data.withUnsafeBytes { sourceBytes in
                    guard let destination = destinationBytes.bindMemory(to: UInt8.self).baseAddress,
                          let source = sourceBytes.bindMemory(to: UInt8.self).baseAddress
                    else { return }
                    for row in 0..<rect.height {
                        let destOffset = (((rect.originY + row) * store.snapshot.canvasWidth) + rect.originX) * 4
                        let srcOffset = row * rect.width * 4
                        memcpy(destination + destOffset, source + srcOffset, rect.width * 4)
                    }
                }
            }
            output = preserveExistingAlphaIfNeeded(
                output,
                existing: existing,
                isAlphaLocked: store.snapshot.layers[index].alphaLocked
            )
            setLayerPixelState(index: index, pixelData: output, gpuBufferHandle: nil)
            invalidateThumbnail(for: index)
            recordMutation(before: before, timelapseEvent: nil, changedLayerIndex: index, dirtyRect: rect)
            return .success(())
        }
        return .failure(failure)
    }

    func applyLayerSurfaceMutation(index: Int, payload: GpuLayerMutationPayload) -> DocumentMutationResult {
        guard payload.canvasWidth == store.snapshot.canvasWidth,
              payload.canvasHeight == store.snapshot.canvasHeight else {
            return .failure(.gpu(.invalidPayloadSize(
                operation: "applyLayerSurfaceMutation",
                expected: rgbaByteCount,
                actual: payload.fallbackPixelData?.count ?? 0
            )))
        }
        guard GpuLayerMutationPayload(
            validatingCanvasWidth: payload.canvasWidth,
            canvasHeight: payload.canvasHeight,
            dirtyRect: payload.dirtyRect,
            gpuBufferHandle: payload.gpuBufferHandle,
            fallbackPixelData: payload.fallbackPixelData
        ) != nil else {
            return .failure(.gpu(.invalidPayloadSize(
                operation: "applyLayerSurfaceMutation",
                expected: rgbaByteCount,
                actual: payload.fallbackPixelData?.count ?? 0
            )))
        }
        guard !payload.dirtyRect.isEmpty else {
            return .failure(.gpu(.invalidDirtyRect(operation: "applyLayerSurfaceMutation")))
        }
        guard let failure = validateEditableLayer(index) else {
            let layer = store.snapshot.layers[index]
            guard let fallbackPayload = DocumentLayerMutationPayload(
                validatingCanvasWidth: payload.canvasWidth,
                canvasHeight: payload.canvasHeight,
                dirtyRect: payload.dirtyRect,
                gpuBufferHandle: payload.gpuBufferHandle,
                rectPixelData: Data(),
                fullPixelData: payload.fallbackPixelData
            ) else {
                return .failure(.gpu(.invalidPayloadSize(
                    operation: "applyLayerSurfaceMutation",
                    expected: rgbaByteCount,
                    actual: payload.fallbackPixelData?.count ?? 0
                )))
            }
            return applyLayerMutationPayload(
                index: index,
                payload: fallbackPayload,
                timelapseEvent: nil,
                recordsFinalLayerPixels: layer.alphaLocked
            )
        }
        return .failure(failure)
    }

    func applyLayerMutation(index: Int, payload: DocumentLayerMutationPayload) -> DocumentMutationResult {
        guard let failure = validateEditableLayer(index) else {
            return applyLayerMutationPayload(
                index: index,
                payload: payload,
                timelapseEvent: nil,
                recordsFinalLayerPixels: true
            )
        }
        return .failure(failure)
    }

    func applyTextLayerMutation(index: Int, textLayer: TextLayerData, payload: DocumentLayerMutationPayload) -> DocumentMutationResult {
        if let failure = validateEditableLayer(index) { return .failure(failure) }
        return applyTextLayerMutationPayload(index: index, textLayer: textLayer, payload: payload)
    }

    func replaceLayerMask(index: Int, data: Data) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        guard !data.isEmpty else { return .failure(.emptyInput) }
        guard data.count == store.snapshot.canvasWidth * store.snapshot.canvasHeight else {
            return .failure(.bridgeMutationFailed("replaceLayerMask"))
        }
        let before = undoSnapshot()
        store.snapshot.layers[index].maskData = data
        invalidateThumbnail(for: index)
        recordMutation(before: before, timelapseEvent: .replaceLayerMask(index: .unchecked(index), data: data))
        return .success(())
    }

    func clearLayerMask(index: Int) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        guard store.snapshot.layers[index].maskData != nil else { return .success(()) }
        let before = undoSnapshot()
        store.snapshot.layers[index].maskData = nil
        invalidateThumbnail(for: index)
        recordMutation(before: before, timelapseEvent: .clearLayerMask(index: .unchecked(index)))
        return .success(())
    }

    func applyLayerMask(index: Int) -> DocumentMutationResult {
        guard let failure = validateLayer(index) else {
            guard let mask = store.snapshot.layers[index].maskData else { return .success(()) }
            guard let maskedPixels = gpuServices.applyLayerMask(
                pixelData: currentPixelData(for: index),
                maskData: mask,
                width: store.snapshot.canvasWidth,
                height: store.snapshot.canvasHeight
            ) else {
                return .failure(.gpu(.kernelFailed(operation: "applyLayerMask")))
            }
            let before = undoSnapshot()
            setLayerPixelState(index: index, pixelData: maskedPixels, gpuBufferHandle: nil)
            store.snapshot.layers[index].maskData = nil
            invalidateThumbnail(for: index)
            recordMutation(
                before: before,
                timelapseEvent: .applyLayerMask(index: .unchecked(index))
            )
            return .success(())
        }
        return .failure(failure)
    }

    func clearLayer(index: Int) -> DocumentMutationResult {
        guard let failure = validateEditableLayer(index) else {
            let before = undoSnapshot()
            setLayerPixelState(index: index, pixelData: Data(count: rgbaByteCount), gpuBufferHandle: nil)
            invalidateThumbnail(for: index)
            recordMutation(
                before: before,
                timelapseEvent: .clearLayer(index: .unchecked(index)),
                changedLayerIndex: index,
                dirtyRect: fullCanvasRect()
            )
            return .success(())
        }
        return .failure(failure)
    }

    func applyLayerProcessing(index: Int, request: LayerProcessingRequest) -> DocumentMutationResult {
        switch makeLayerProcessingPlan(index: index, request: request) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let payload = plan.gpuServices.processLayer(
                pixelData: plan.pixelData,
                canvasWidth: plan.canvasWidth,
                canvasHeight: plan.canvasHeight,
                request: plan.request
            ) else {
                return .failure(.gpu(.kernelFailed(operation: "applyLayerProcessing")))
            }
            return applyLayerProcessingPlan(plan, payload: payload)
        }
    }

    func makeLayerProcessingPlan(
        index: Int,
        request: LayerProcessingRequest
    ) -> Result<RuntimeLayerProcessingPlan, DocumentMutationFailure> {
        if let failure = validateEditableLayer(index) { return .failure(failure) }
        return .success(
            RuntimeLayerProcessingPlan(
                index: index,
                request: request,
                revision: store.snapshot.revision,
                canvasWidth: store.snapshot.canvasWidth,
                canvasHeight: store.snapshot.canvasHeight,
                pixelData: currentPixelData(for: index),
                gpuServices: gpuServices
            )
        )
    }

    func applyLayerProcessingPlan(
        _ plan: RuntimeLayerProcessingPlan,
        payload: DocumentLayerMutationPayload
    ) -> DocumentMutationResult {
        guard store.snapshot.revision == plan.revision,
              store.snapshot.canvasWidth == plan.canvasWidth,
              store.snapshot.canvasHeight == plan.canvasHeight else {
            gpuServices.release(payload.gpuBufferHandle)
            return .failure(.gpu(.staleSnapshot(operation: "applyLayerProcessing")))
        }
        if let failure = validateEditableLayer(plan.index) {
            gpuServices.release(payload.gpuBufferHandle)
            return .failure(failure)
        }
        return applyLayerMutationPayload(
            index: plan.index,
            payload: payload,
            timelapseEvent: nil,
            recordsFinalLayerPixels: true
        )
    }

    func processedLayerPayload(for plan: RuntimeLayerProcessingPlan) -> DocumentLayerMutationPayload? {
        plan.gpuServices.processLayer(
            pixelData: plan.pixelData,
            canvasWidth: plan.canvasWidth,
            canvasHeight: plan.canvasHeight,
            request: plan.request
        )
    }

    func makeFillPlan(
        sample: StylusSample,
        brush: BrushRuntimeSettings
    ) -> Result<RuntimeFillPlan, DocumentMutationFailure> {
        let layerIndex = store.snapshot.activeLayerIndex
        if let failure = validateEditableLayer(layerIndex) { return .failure(failure) }
        let source = layerSourceForGpuPlan(index: layerIndex)
        return .success(
            RuntimeFillPlan(
                layerIndex: layerIndex,
                revision: store.snapshot.revision,
                canvasWidth: store.snapshot.canvasWidth,
                canvasHeight: store.snapshot.canvasHeight,
                pixelData: source.pixelData,
                sourceBufferHandle: source.bufferHandle,
                retainedResource: source.retainedResource,
                sample: sample,
                brush: brush,
                gpuServices: gpuServices
            )
        )
    }

    func fillPayload(for plan: RuntimeFillPlan) -> DocumentLayerMutationPayload? {
        plan.gpuServices.fillPixels(
            pixelData: plan.pixelData,
            sourceBufferHandle: plan.sourceBufferHandle,
            canvasWidth: plan.canvasWidth,
            canvasHeight: plan.canvasHeight,
            sample: plan.sample,
            brush: plan.brush
        )
    }

    func applyFillPlan(
        _ plan: RuntimeFillPlan,
        payload: DocumentLayerMutationPayload
    ) -> DocumentMutationResult {
        guard store.snapshot.revision == plan.revision,
              store.snapshot.canvasWidth == plan.canvasWidth,
              store.snapshot.canvasHeight == plan.canvasHeight else {
            gpuServices.release(payload.gpuBufferHandle)
            return .failure(.gpu(.staleSnapshot(operation: "fill")))
        }
        if let failure = validateEditableLayer(plan.layerIndex) {
            gpuServices.release(payload.gpuBufferHandle)
            return .failure(failure)
        }
        return applyLayerMutationPayload(
            index: plan.layerIndex,
            payload: payload,
            timelapseEvent: .fill(layerIndex: .unchecked(plan.layerIndex), brush: plan.brush, sample: plan.sample)
        )
    }

    func makeStrokeCommitPlan(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        layerIndex: Int
    ) -> Result<RuntimeStrokeCommitPlan, DocumentMutationFailure> {
        guard !samples.isEmpty else { return .failure(.emptyInput) }
        if let failure = validateEditableLayer(layerIndex) { return .failure(failure) }
        let source = layerSourceForGpuPlan(index: layerIndex)
        return .success(
            RuntimeStrokeCommitPlan(
                layerIndex: layerIndex,
                revision: store.snapshot.revision,
                canvasWidth: store.snapshot.canvasWidth,
                canvasHeight: store.snapshot.canvasHeight,
                pixelData: source.pixelData,
                baseBufferHandle: source.bufferHandle,
                retainedResource: source.retainedResource,
                samples: samples,
                brush: brush,
                gpuServices: gpuServices
            )
        )
    }

    func strokeCommitResult(for plan: RuntimeStrokeCommitPlan) -> DocumentRuntimeStrokeMutationResult? {
        plan.gpuServices.commitStrokeMutation(
            basePixelData: plan.pixelData,
            baseBufferHandle: plan.baseBufferHandle,
            canvasWidth: plan.canvasWidth,
            canvasHeight: plan.canvasHeight,
            samples: plan.samples,
            brush: plan.brush,
            snapshotRevision: plan.revision,
            activeLayerIndex: plan.layerIndex
        )
    }

    func applyStrokeCommitPlan(
        _ plan: RuntimeStrokeCommitPlan,
        gpuResult: DocumentRuntimeStrokeMutationResult
    ) -> DocumentMutationResult {
        guard store.snapshot.revision == plan.revision,
              store.snapshot.canvasWidth == plan.canvasWidth,
              store.snapshot.canvasHeight == plan.canvasHeight else {
            gpuServices.release(gpuResult.gpuBufferHandle)
            return .failure(.gpu(.staleSnapshot(operation: "applyCommittedStroke")))
        }
        if let failure = validateEditableLayer(plan.layerIndex) {
            gpuServices.release(gpuResult.gpuBufferHandle)
            return .failure(failure)
        }
        let dirtyRect = LayerPixelRect.unsafeUnchecked(originX: gpuResult.dirtyRect.originX,
            originY: gpuResult.dirtyRect.originY,
            width: gpuResult.dirtyRect.width,
            height: gpuResult.dirtyRect.height
        )
        let before = undoSnapshot()
        let existing = currentPixelData(for: plan.layerIndex)
        let adjustedOutput: Data
        let nextHandle: MetalBufferHandle?
        if store.snapshot.layers[plan.layerIndex].alphaLocked {
            if let sourceHandle = gpuResult.gpuBufferHandle {
                guard let alphaPreservedHandle = gpuServices.preservingExistingAlphaBufferHandle(
                    sourceHandle: sourceHandle,
                    existingHandle: nil,
                    existingPixelData: existing,
                    width: store.snapshot.canvasWidth,
                    height: store.snapshot.canvasHeight
                ) else {
                    gpuServices.release(sourceHandle)
                    return .failure(.gpu(.kernelFailed(operation: "applyCommittedStrokeAlphaPreserve")))
                }
                adjustedOutput = existing
                nextHandle = alphaPreservedHandle
                gpuServices.release(sourceHandle)
            } else {
                let committedOutput = gpuResult.rectPixelData ?? Data()
                guard committedOutput.count == rgbaByteCount else {
                    return .failure(.gpu(.invalidPayloadSize(
                        operation: "applyCommittedStrokeMaterialization",
                        expected: rgbaByteCount,
                        actual: committedOutput.count
                    )))
                }
                adjustedOutput = preserveExistingAlphaIfNeeded(
                    committedOutput,
                    existing: existing,
                    isAlphaLocked: true
                )
                nextHandle = nil
            }
        } else if let handle = gpuResult.gpuBufferHandle {
            adjustedOutput = existing
            nextHandle = handle
        } else {
            let committedOutput = gpuResult.rectPixelData ?? Data()
            guard committedOutput.count == rgbaByteCount else {
                return .failure(.gpu(.invalidPayloadSize(
                    operation: "applyCommittedStrokeMaterialization",
                    expected: rgbaByteCount,
                    actual: committedOutput.count
                )))
            }
            adjustedOutput = committedOutput
            nextHandle = nil
        }
        store.snapshot.layers[plan.layerIndex].textLayer = nil
        setLayerPixelState(index: plan.layerIndex, pixelData: adjustedOutput, gpuBufferHandle: nextHandle)
        invalidateThumbnail(for: plan.layerIndex)
        recordMutation(
            before: before,
            timelapseEvent: .stroke(layerIndex: .unchecked(plan.layerIndex), brush: plan.brush, samples: plan.samples),
            changedLayerIndex: plan.layerIndex,
            dirtyRect: dirtyRect
        )
        return .success(())
    }

    func makeBlurPlan(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        layerIndex: Int,
        captureTimelapse: Bool
    ) -> Result<RuntimeBlurPlan, DocumentMutationFailure> {
        guard !samples.isEmpty else { return .failure(.emptyInput) }
        if let failure = validateEditableLayer(layerIndex) { return .failure(failure) }
        let baseline = currentBlurStroke?.baseline ?? undoSnapshot()
        let source = layerSourceForGpuPlan(index: layerIndex)
        currentBlurStroke = (
            baseline: baseline,
            layerIndex: layerIndex,
            brush: brush,
            samples: (currentBlurStroke?.samples ?? []) + samples
        )
        return .success(
            RuntimeBlurPlan(
                layerIndex: layerIndex,
                revision: store.snapshot.revision,
                canvasWidth: store.snapshot.canvasWidth,
                canvasHeight: store.snapshot.canvasHeight,
                pixelData: source.pixelData,
                sourceBufferHandle: source.bufferHandle,
                retainedResource: source.retainedResource,
                samples: samples,
                brush: brush,
                captureTimelapse: captureTimelapse,
                gpuServices: gpuServices
            )
        )
    }

    func blurPayload(for plan: RuntimeBlurPlan) -> DocumentLayerMutationPayload? {
        plan.gpuServices.blurPixels(
            pixelData: plan.pixelData,
            sourceBufferHandle: plan.sourceBufferHandle,
            canvasWidth: plan.canvasWidth,
            canvasHeight: plan.canvasHeight,
            samples: plan.samples,
            brush: plan.brush
        )
    }

    func applyBlurPlan(
        _ plan: RuntimeBlurPlan,
        payload: DocumentLayerMutationPayload
    ) -> DocumentMutationResult {
        guard store.snapshot.revision == plan.revision,
              store.snapshot.canvasWidth == plan.canvasWidth,
              store.snapshot.canvasHeight == plan.canvasHeight else {
            gpuServices.release(payload.gpuBufferHandle)
            return .failure(.gpu(.staleSnapshot(operation: "blurStroke")))
        }
        if let failure = validateEditableLayer(plan.layerIndex) {
            gpuServices.release(payload.gpuBufferHandle)
            return .failure(failure)
        }
        let current = currentPixelData(for: plan.layerIndex)
        let nextPixelData: Data
        let nextHandle: MetalBufferHandle?
        if store.snapshot.layers[plan.layerIndex].alphaLocked {
            nextPixelData = preserveExistingAlphaIfNeeded(
                materializedPixelData(from: payload, existing: current),
                existing: current,
                isAlphaLocked: true
            )
            nextHandle = nil
            gpuServices.release(payload.gpuBufferHandle)
        } else if let handle = payload.gpuBufferHandle {
            nextPixelData = current
            nextHandle = handle
        } else {
            nextPixelData = materializedPixelData(from: payload, existing: current)
            nextHandle = nil
        }
        setLayerPixelState(
            index: plan.layerIndex,
            pixelData: nextPixelData,
            gpuBufferHandle: nextHandle
        )
        store.snapshot.layers[plan.layerIndex].textLayer = nil
        invalidateThumbnail(for: plan.layerIndex)
        captureDirtyUpdate(rect: payload.dirtyRect)
        if plan.captureTimelapse {
            captureTimelapseFrame()
        }
        return .success(())
    }

    func currentStrokeCommitPlan() -> Result<RuntimeStrokeCommitPlan?, DocumentMutationFailure> {
        guard let currentStroke else { return .success(nil) }
        return makeStrokeCommitPlan(
            samples: currentStroke.samples,
            brush: currentStroke.brush,
            layerIndex: currentStroke.layerIndex
        ).map(Optional.some)
    }

    func clearCurrentStroke() {
        currentStroke = nil
    }

    func release(_ handle: MetalBufferHandle?) {
        gpuServices.release(handle)
    }

    func duplicateLayer(index: Int, name: String) -> DocumentIndexedMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        let before = undoSnapshot()
        var layer = store.snapshot.layers[index]
        layer.pixelData = currentPixelData(for: index)
        layer.name = name
        let duplicatedIndex = index + 1
        store.snapshot.layers.insert(layer, at: duplicatedIndex)
        remapFoldersAfterInsertion(at: duplicatedIndex)
        store.snapshot.activeLayerIndex = duplicatedIndex
        materializeGpuBackedLayerPixels()
        releaseLayerBufferHandles()
        recordMutation(before: before, timelapseEvent: .duplicateLayer(index: .unchecked(index), name: name))
        return .success(duplicatedIndex)
    }

    func deleteLayer(index: Int) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        guard store.snapshot.layers.count > 1 else { return .failure(.bridgeMutationFailed("deleteLayer")) }
        let before = undoSnapshot()
        deleteLayerUnchecked(index: index)
        recordMutation(before: before, timelapseEvent: .deleteLayer(index: .unchecked(index)))
        return .success(())
    }

    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        if let failure = validateLayer(destinationIndex) { return .failure(failure) }
        guard index != destinationIndex else { return .success(()) }
        let before = undoSnapshot()
        materializeGpuBackedLayerPixels()
        let layer = store.snapshot.layers.remove(at: index)
        store.snapshot.layers.insert(layer, at: destinationIndex)
        remapFoldersAfterMove(from: index, to: destinationIndex)
        if store.snapshot.activeLayerIndex == index {
            store.snapshot.activeLayerIndex = destinationIndex
        }
        invalidateAllThumbnails()
        releaseLayerBufferHandles()
        recordMutation(before: before, timelapseEvent: .moveLayer(index: .unchecked(index), destinationIndex: .unchecked(destinationIndex)))
        return .success(())
    }

    func createFolder(name: String, layerIndex: Int) -> DocumentIndexedMutationResult {
        guard layerIndex < 0 || store.snapshot.layers.indices.contains(layerIndex) else {
            return .failure(.invalidLayerIndex(layerIndex))
        }
        let before = undoSnapshot()
        let id = store.snapshot.nextFolderID
        store.snapshot.nextFolderID += 1
        store.snapshot.folders.append(
            SwiftDocumentFolderRecord(
                id: id,
                name: name,
                visible: true,
                expanded: true,
                anchorLayerIndex: layerIndex >= 0 ? layerIndex : nil
            )
        )
        recordMutation(
            before: before,
            timelapseEvent: .createFolder(folderID: .unchecked(id), name: name, anchorLayerIndex: layerIndex >= 0 ? .unchecked(layerIndex) : nil)
        )
        return .success(id)
    }

    func deleteFolder(folderID: Int) -> DocumentMutationResult {
        guard let folderIndex = store.snapshot.folders.firstIndex(where: { $0.id == folderID }) else {
            return .failure(.invalidFolderID(folderID))
        }
        let before = undoSnapshot()
        store.snapshot.folders.remove(at: folderIndex)
        for index in store.snapshot.layers.indices where store.snapshot.layers[index].folderID == folderID {
            store.snapshot.layers[index].folderID = nil
        }
        recordMutation(before: before, timelapseEvent: .deleteFolder(folderID: .unchecked(folderID)))
        return .success(())
    }

    func setFolderVisibility(folderID: Int, isVisible: Bool) -> DocumentMutationResult {
        guard let folderIndex = store.snapshot.folders.firstIndex(where: { $0.id == folderID }) else {
            return .failure(.invalidFolderID(folderID))
        }
        let before = undoSnapshot()
        store.snapshot.folders[folderIndex].visible = isVisible
        recordMutation(before: before, timelapseEvent: .setFolderVisibility(folderID: .unchecked(folderID), isVisible: isVisible))
        return .success(())
    }

    func setFolderName(folderID: Int, name: String) -> DocumentMutationResult {
        guard let folderIndex = store.snapshot.folders.firstIndex(where: { $0.id == folderID }) else {
            return .failure(.invalidFolderID(folderID))
        }
        let before = undoSnapshot()
        store.snapshot.folders[folderIndex].name = name
        recordMutation(before: before, timelapseEvent: .setFolderName(folderID: .unchecked(folderID), name: name))
        return .success(())
    }

    func setFolderExpanded(folderID: Int, isExpanded: Bool) -> DocumentMutationResult {
        guard let folderIndex = store.snapshot.folders.firstIndex(where: { $0.id == folderID }) else {
            return .failure(.invalidFolderID(folderID))
        }
        let before = undoSnapshot()
        store.snapshot.folders[folderIndex].expanded = isExpanded
        recordMutation(before: before, timelapseEvent: .setFolderExpanded(folderID: .unchecked(folderID), isExpanded: isExpanded))
        return .success(())
    }

    func assignLayerToFolder(index: Int, folderID: Int) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        if folderID >= 0, !store.snapshot.folders.contains(where: { $0.id == folderID }) {
            return .failure(.invalidFolderID(folderID))
        }
        let before = undoSnapshot()
        store.snapshot.layers[index].folderID = folderID >= 0 ? folderID : nil
        recordMutation(before: before, timelapseEvent: .assignLayerToFolder(index: .unchecked(index), folderID: folderID >= 0 ? .unchecked(folderID) : nil))
        return .success(())
    }

    func setLayerLocked(index: Int, isLocked: Bool) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        let before = undoSnapshot()
        store.snapshot.layers[index].locked = isLocked
        recordMutation(before: before, timelapseEvent: .setLayerLocked(index: .unchecked(index), isLocked: isLocked))
        return .success(())
    }

    func setLayerAlphaLocked(index: Int, isAlphaLocked: Bool) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        let before = undoSnapshot()
        store.snapshot.layers[index].alphaLocked = isAlphaLocked
        recordMutation(before: before, timelapseEvent: .setLayerAlphaLocked(index: .unchecked(index), isAlphaLocked: isAlphaLocked))
        return .success(())
    }

    func setLayerClipped(index: Int, isClipped: Bool) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        let before = undoSnapshot()
        store.snapshot.layers[index].clipped = isClipped
        recordMutation(before: before, timelapseEvent: .setLayerClipped(index: .unchecked(index), isClipped: isClipped))
        return .success(())
    }

    func setLayerOpacity(index: Int, opacity: Double) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        guard (0...1).contains(opacity) else { return .failure(.invalidOpacity(opacity)) }
        let before = undoSnapshot()
        store.snapshot.layers[index].opacity = opacity
        recordMutation(before: before, timelapseEvent: .setLayerOpacity(index: .unchecked(index), opacity: opacity))
        return .success(())
    }

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        let before = undoSnapshot()
        store.snapshot.layers[index].blendMode = blendMode
        recordMutation(before: before, timelapseEvent: .setLayerBlendMode(index: .unchecked(index), blendMode: blendMode))
        return .success(())
    }

    func mergeLayerDown(index: Int) -> DocumentMutationResult {
        guard index > 0 else { return .failure(.invalidLayerIndex(index)) }
        if let failure = validateEditableLayer(index) { return .failure(failure) }
        if let failure = validateEditableLayer(index - 1) { return .failure(failure) }
        var upper = store.snapshot.layers[index]
        upper.pixelData = currentPixelData(for: index)
        var lower = store.snapshot.layers[index - 1]
        lower.pixelData = currentPixelData(for: index - 1)
        guard let merged = gpuServices.mergeLayers(
            lowerPixelData: lower.pixelData,
            upperPixelData: upper.pixelData,
            upperMaskData: upper.maskData,
            canvasWidth: store.snapshot.canvasWidth,
            canvasHeight: store.snapshot.canvasHeight,
            upperOpacity: Float(upper.opacity),
            upperBlendMode: upper.blendMode
        ) else {
            return .failure(.bridgeMutationFailed("mergeLayerDown"))
        }
        let before = undoSnapshot()
        setLayerPixelState(
            index: index - 1,
            pixelData: preserveExistingAlphaIfNeeded(
                merged,
                existing: lower.pixelData,
                isAlphaLocked: lower.alphaLocked
            ),
            gpuBufferHandle: nil
        )
        store.snapshot.layers[index - 1].textLayer = nil
        deleteLayerUnchecked(index: index)
        recordMutation(before: before, timelapseEvent: .mergeLayerDown(index: .unchecked(index)))
        return .success(())
    }

    func textLayerData(index: Int) -> TextLayerData? {
        guard store.snapshot.layers.indices.contains(index) else { return nil }
        return store.snapshot.layers[index].textLayer
    }

    func setTextLayer(index: Int, textLayer: TextLayerData) -> DocumentMutationResult {
        guard !textLayer.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyInput)
        }
        if let failure = validateEditableLayer(index) { return .failure(failure) }
        guard let payload = gpuServices.rasterizeTextLayer(textLayer, canvasSize: canvasSize) else {
            return .failure(.bridgeMutationFailed("setTextLayer"))
        }
        return applyTextLayerMutationPayload(index: index, textLayer: textLayer, payload: payload)
    }

    func clearTextLayerData(index: Int) {
        guard store.snapshot.layers.indices.contains(index) else { return }
        store.snapshot.layers[index].textLayer = nil
    }

    func beginStroke(sample: StylusSample, brush: BrushRuntimeSettings) {
        currentStroke = (layerIndex: store.snapshot.activeLayerIndex, brush: brush, samples: [sample])
    }

    func appendStroke(sample: StylusSample) {
        currentStroke?.samples.append(sample)
    }

    func endStroke() -> DocumentMutationResult {
        switch currentStrokeCommitPlan() {
        case let .failure(failure):
            return .failure(failure)
        case .success(nil):
            return .success(())
        case let .success(plan?):
            guard let result = strokeCommitResult(for: plan) else {
                return .failure(.bridgeMutationFailed("applyCommittedStroke"))
            }
            let mutationResult = applyStrokeCommitPlan(plan, gpuResult: result)
            if case .success = mutationResult {
                clearCurrentStroke()
            }
            return mutationResult
        }
    }

    func cancelStroke() {
        currentStroke = nil
    }

    func blur(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, captureTimelapse: Bool) -> DocumentMutationResult {
        switch makeBlurPlan(samples: samples, brush: brush, layerIndex: layerIndex, captureTimelapse: captureTimelapse) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let payload = blurPayload(for: plan) else {
                return .failure(.bridgeMutationFailed("blurStroke"))
            }
            return applyBlurPlan(plan, payload: payload)
        }
    }

    func endBlurStroke() -> DocumentMutationResult {
        guard let currentBlurStroke,
              let baseline = currentBlurStroke.baseline
        else {
            return .failure(.bridgeMutationFailed("endBlurStrokeMissingBaseline"))
        }
        guard store.snapshot.layers.indices.contains(currentBlurStroke.layerIndex) else {
            return .failure(.invalidLayerIndex(currentBlurStroke.layerIndex))
        }
        recordMutation(
            before: baseline,
            timelapseEvent: nil,
            changedLayerIndex: currentBlurStroke.layerIndex,
            dirtyRect: fullCanvasRect()
        )
        timelapseRecorder.record(
            .blurStroke(
                layerIndex: .unchecked(currentBlurStroke.layerIndex),
                brush: currentBlurStroke.brush,
                samples: currentBlurStroke.samples
            ),
            in: store
        )
        self.currentBlurStroke = nil
        return .success(())
    }

    func fill(sample: StylusSample, brush: BrushRuntimeSettings) -> DocumentMutationResult {
        switch makeFillPlan(sample: sample, brush: brush) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let payload = fillPayload(for: plan) else {
                return .failure(.bridgeMutationFailed("fill"))
            }
            return applyFillPlan(plan, payload: payload)
        }
    }

    func applyGpuStrokeSurface(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int) -> DocumentMutationResult {
        switch makeStrokeCommitPlan(samples: samples, brush: brush, layerIndex: layerIndex) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let result = strokeCommitResult(for: plan) else {
                return .failure(.bridgeMutationFailed("applyCommittedStroke"))
            }
            return applyStrokeCommitPlan(plan, gpuResult: result)
        }
    }

    func saveProject(to url: URL, paperStyle: CanvasPaperStyle) throws {
        try projectSaveSnapshot(paperStyle: paperStyle).write(
            to: url,
            fileClient: services.fileIO,
            uuidClient: services.ids
        )
    }

    func projectSaveSnapshot(paperStyle: CanvasPaperStyle) -> SwiftDocumentProjectSaveSnapshot {
        SwiftDocumentProjectSaveSnapshot(snapshot: materializedSnapshot(), paperStyle: paperStyle)
    }

    static func compositeSurface(
        forMaterializedSnapshot snapshot: SwiftDocumentStoreSnapshot,
        gpuServices: DocumentRuntimeGpuServices
    ) -> DocumentCompositeSurface {
        let metalSnapshot = materializedMetalSnapshot(for: snapshot)
        if let gpuComposite = gpuServices.compositeDocumentSurface(snapshot: metalSnapshot) {
            return gpuComposite
        }
        logger.error("GPU composite failed for snapshot revision \(snapshot.revision, privacy: .public)")
        return DocumentCompositeSurface(
            unsafeUncheckedWidth: snapshot.canvasWidth,
            height: snapshot.canvasHeight,
            pixelData: Data(count: snapshot.canvasWidth * snapshot.canvasHeight * 4)
        )
    }

    static func compositeExportSurface(
        forMaterializedSnapshot snapshot: SwiftDocumentStoreSnapshot,
        paperStyle: CanvasPaperStyle,
        gpuServices: DocumentRuntimeGpuServices
    ) -> DocumentCompositeSurface? {
        let surface = compositeSurface(forMaterializedSnapshot: snapshot, gpuServices: gpuServices)
        guard let pixelData = gpuServices.compositedPaperPreviewRGBA(
            pixelData: surface.pixelData,
            width: surface.width,
            height: surface.height,
            paperStyle: paperStyle
        ) else {
            return nil
        }
        return DocumentCompositeSurface(
            unsafeUncheckedWidth: surface.width,
            height: surface.height,
            pixelData: pixelData
        )
    }

    static func compositePNGData(
        forMaterializedSnapshot snapshot: SwiftDocumentStoreSnapshot,
        paperStyle: CanvasPaperStyle,
        gpuServices: DocumentRuntimeGpuServices
    ) -> Data? {
        compositeExportSurface(
            forMaterializedSnapshot: snapshot,
            paperStyle: paperStyle,
            gpuServices: gpuServices
        ).flatMap(DocumentRasterImageService.pngData(from:))
    }

    private static func materializedMetalSnapshot(
        for snapshot: SwiftDocumentStoreSnapshot
    ) -> MetalDocumentSnapshot {
        MetalDocumentSnapshot.unsafeUnchecked(
            width: snapshot.canvasWidth,
            height: snapshot.canvasHeight,
            revision: snapshot.revision,
            compositePixelData: Data(),
            layers: snapshot.layers.enumerated().map { index, layer in
                MetalLayerSnapshot.unsafeUnchecked(
                    index: index,
                    opacity: Float(layer.opacity),
                    visible: layer.visible && (layer.folderID == nil || (snapshot.folders.first(where: { $0.id == layer.folderID })?.visible ?? true)),
                    isClipped: layer.clipped,
                    blendMode: layer.blendMode,
                    thumbnailSurface: nil,
                    thumbnailData: nil,
                    gpuBufferHandle: nil,
                    pixelData: layer.pixelData
                )
            }
        )
    }
}

struct SwiftDocumentProjectSaveSnapshot: Sendable {
    var snapshot: SwiftDocumentStoreSnapshot
    var paperStyle: CanvasPaperStyle

    func write(to url: URL, fileClient: FileClient, uuidClient: UUIDClient) throws {
        let persistenceService = PaintDocumentPersistenceService(fileClient: fileClient, uuidClient: uuidClient)
        let stagedURL = try persistenceService.createStagedProjectDirectory(
            for: url,
            id: uuidClient.generate()
        )
        defer {
            try? persistenceService.cleanupStagedProjectDirectory(stagedURL)
        }
        try writeProjectContents(to: stagedURL, persistenceService: persistenceService, fileClient: fileClient)
        try persistenceService.validateProjectPackage(at: stagedURL)
        try persistenceService.publishStagedProjectDirectory(stagedURL, to: url)
    }

    private func writeProjectContents(
        to url: URL,
        persistenceService: PaintDocumentPersistenceService,
        fileClient: FileClient
    ) throws {
        let directories = try persistenceService.createProjectSubdirectories(
            in: url,
            usesOperationTimelapsePersistence: snapshot.timelapseUsesOperationPersistence
        )

        for index in snapshot.layers.indices {
            let filename = String(format: "layer-%04d.rgba", index)
            try persistenceService.writeAtomic(
                snapshot.layers[index].pixelData,
                to: directories.layersDirectory.appendingPathComponent(filename, isDirectory: false)
            )
            if let maskData = snapshot.layers[index].maskData {
                let maskFilename = String(format: "layer-mask-%04d.mask", index)
                try persistenceService.writeAtomic(
                    maskData,
                    to: directories.layersDirectory.appendingPathComponent(maskFilename, isDirectory: false)
                )
            }
        }

        if !snapshot.timelapseUsesOperationPersistence {
            for (index, frame) in snapshot.timelapseFrames.enumerated() {
                let relativeFilename = String(format: "frame-%06d.jpg", index)
                try persistenceService.replaceItemIfNeeded(
                    at: directories.timelapseDirectory.appendingPathComponent(relativeFilename, isDirectory: false),
                    with: frame.imageURL
                )
            }
        }

        let storedOperations = snapshot.timelapseUsesOperationPersistence
            ? try snapshot.timelapseEvents.enumerated().map {
                try $0.element.storedRepresentation(
                    index: $0.offset,
                    dataDirectory: directories.timelapseDataDirectory,
                    fileClient: fileClient
                )
            }
            : []

        let document = StoredPrimoDocument(
            version: 5,
            canvasWidth: snapshot.canvasWidth,
            canvasHeight: snapshot.canvasHeight,
            activeLayerIndex: DocumentLayerIndex.unchecked(snapshot.activeLayerIndex),
            paperStyle: StoredPrimoDocument.PaperStyle(
                red: Double(paperStyle.red),
                green: Double(paperStyle.green),
                blue: Double(paperStyle.blue),
                alpha: Double(paperStyle.alpha),
                isTransparent: paperStyle.isTransparent
            ),
            layers: snapshot.layers.enumerated().map { index, layer in
                StoredPrimoDocument.Layer(
                    index: DocumentLayerIndex.unchecked(index),
                    name: layer.name,
                    visible: layer.visible,
                    locked: layer.locked,
                    alphaLocked: layer.alphaLocked,
                    clipped: layer.clipped,
                    opacity: layer.opacity,
                    blendMode: layer.blendMode.rawValue,
                    folderID: layer.folderID.map { DocumentFolderID.unchecked($0) },
                    textLayer: layer.textLayer,
                    pixelFilename: String(format: "Layers/layer-%04d.rgba", index),
                    maskFilename: layer.maskData == nil ? nil : String(format: "Layers/layer-mask-%04d.mask", index)
                )
            },
            folders: snapshot.folders.map {
                StoredPrimoDocument.Folder(
                    id: DocumentFolderID.unchecked($0.id),
                    name: $0.name,
                    visible: $0.visible,
                    expanded: $0.expanded,
                    anchorLayerIndex: $0.anchorLayerIndex.map { DocumentLayerIndex.unchecked($0) }
                )
            },
            timelapseFrames: snapshot.timelapseUsesOperationPersistence ? [] : snapshot.timelapseFrames.map {
                StoredPrimoDocument.TimelapseFrame(
                    filename: "Timelapse/\($0.imageURL.lastPathComponent)",
                    width: Double($0.size.width),
                    height: Double($0.size.height)
                )
            },
            timelapseOperations: storedOperations
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifest = try encoder.encode(document)
        try persistenceService.writeAtomic(manifest, to: url.appendingPathComponent("manifest.json", isDirectory: false))
    }
}

extension SwiftDocumentRuntime {
    static func loadProject(
        from url: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live,
        gpuServices: DocumentRuntimeGpuServices
    ) throws -> SwiftDocumentRuntime {
        let runtime = SwiftDocumentRuntime(
            width: 1,
            height: 1,
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient,
            gpuServices: gpuServices
        )
        let manifestURL = url.appendingPathComponent("manifest.json", isDirectory: false)
        let manifestData = try fileClient.readData(manifestURL)
        let document = try JSONDecoder().decode(StoredPrimoDocument.self, from: manifestData)
        guard document.canvasWidth > 0, document.canvasHeight > 0, !document.layers.isEmpty else {
            throw PrimoDocumentError.invalidDocument
        }

        let sortedLayers = document.layers.sorted { $0.index.rawValue < $1.index.rawValue }
        let expectedLayerBytes = document.canvasWidth * document.canvasHeight * 4
        let expectedMaskBytes = document.canvasWidth * document.canvasHeight
        let layers = try sortedLayers.map { layer -> SwiftDocumentLayerRecord in
            let pixelData = try fileClient.readData(url.appendingPathComponent(layer.pixelFilename, isDirectory: false))
            guard pixelData.count == expectedLayerBytes else { throw PrimoDocumentError.invalidDocument }
            let maskData: Data?
            if let maskFilename = layer.maskFilename {
                let loadedMaskData = try fileClient.readData(url.appendingPathComponent(maskFilename, isDirectory: false))
                guard loadedMaskData.count == expectedMaskBytes else { throw PrimoDocumentError.invalidDocument }
                maskData = loadedMaskData
            } else {
                maskData = nil
            }
            return SwiftDocumentLayerRecord(
                name: layer.name,
                visible: layer.visible,
                locked: layer.locked,
                alphaLocked: layer.alphaLocked,
                clipped: layer.clipped,
                opacity: layer.opacity,
                blendMode: LayerBlendMode(rawValue: layer.blendMode) ?? .normal,
                folderID: layer.folderID?.rawValue,
                textLayer: layer.textLayer,
                pixelData: pixelData,
                maskData: maskData
            )
        }
        let folders = document.folders.map {
            SwiftDocumentFolderRecord(
                id: $0.id.rawValue,
                name: $0.name,
                visible: $0.visible,
                expanded: $0.expanded,
                anchorLayerIndex: $0.anchorLayerIndex?.rawValue
            )
        }
        let timelapseEvents = try document.timelapseOperations.map {
            try TimelapseOperation(stored: $0, baseURL: url, fileClient: fileClient)
        }
        let timelapseFrames: [TimelapseFrame]
        if timelapseEvents.isEmpty {
            let frameDirectory = runtime.services.timelapse.frameStore.makeDirectoryURL()
            try fileClient.createDirectory(frameDirectory, true)
            timelapseFrames = try document.timelapseFrames.enumerated().map { index, frame in
                let sourceURL = url.appendingPathComponent(frame.filename, isDirectory: false)
                let destinationURL = runtime.services.timelapse.frameStore.makeFrameURL(in: frameDirectory, frameID: index)
                try runtime.services.persistence.projectStore.replaceItemIfNeeded(at: destinationURL, with: sourceURL)
                return TimelapseFrame(
                    imageURL: destinationURL,
                    size: CGSize(width: frame.width, height: frame.height)
                )
            }
        } else {
            timelapseFrames = []
        }
        runtime.store.restore(
            SwiftDocumentStoreSnapshot(
                canvasWidth: document.canvasWidth,
                canvasHeight: document.canvasHeight,
                activeLayerIndex: min(max(document.activeLayerIndex.rawValue, 0), layers.count - 1),
                paperStyle: CanvasPaperStyle(
                    red: Float(document.paperStyle.red),
                    green: Float(document.paperStyle.green),
                    blue: Float(document.paperStyle.blue),
                    alpha: Float(document.paperStyle.alpha),
                    isTransparent: document.paperStyle.isTransparent
                ),
                revision: 0,
                nextFolderID: (folders.map { $0.id }.max() ?? 0) + 1,
                layers: layers,
                folders: folders,
                thumbnailCache: [:],
                timelapseFrames: timelapseFrames,
                timelapseEvents: timelapseEvents,
                timelapseUsesOperationPersistence: !timelapseEvents.isEmpty
            )
        )
        runtime.thumbnailSurfaceCache.removeAll(keepingCapacity: true)
        return runtime
    }

    func setPaperStyle(_ style: CanvasPaperStyle) {
        let before = undoSnapshot()
        store.snapshot.paperStyle = style
        recordMutation(before: before, timelapseEvent: TimelapseOperation.setPaperStyle(style))
    }

    func newCanvas(width: Int, height: Int) {
        let newRuntime = SwiftDocumentRuntime(
            width: width,
            height: height,
            fileClient: services.fileIO,
            dateClient: services.clock,
            uuidClient: services.ids,
            gpuServices: gpuServices
        )
        store.restore(newRuntime.store.snapshot)
        thumbnailSurfaceCache.removeAll(keepingCapacity: true)
        undoPolicy.clear()
        currentStroke = nil
        currentBlurStroke = nil
        captureDirtyUpdate()
    }

    func compositePNGData(paperStyle: CanvasPaperStyle) -> Data? {
        compositeExportSurface(paperStyle: paperStyle).flatMap(DocumentRasterImageService.pngData(from:))
    }

    func compositeExportSurface(paperStyle: CanvasPaperStyle) -> DocumentCompositeSurface? {
        let surface = compositeSurface()
        guard let pixelData = gpuServices.compositedPaperPreviewRGBA(
            pixelData: surface.pixelData,
            width: surface.width,
            height: surface.height,
            paperStyle: paperStyle
        ) else {
            return nil
        }
        return DocumentCompositeSurface(
            unsafeUncheckedWidth: surface.width,
            height: surface.height,
            pixelData: pixelData
        )
    }

    func timelapseCapture() -> TimelapseCapture? {
        let previewSurface = makeTimelapseThumbnailSurface()
        let preview = previewSurface.flatMap { DocumentRasterImageService.jpegData(from: $0) }
        if store.snapshot.timelapseUsesOperationPersistence, !store.snapshot.timelapseEvents.isEmpty {
            return TimelapseCapture(
                canvasSize: canvasSize,
                paperStyle: store.snapshot.paperStyle,
                previewSurface: previewSurface,
                previewImageData: preview,
                source: .operations(store.snapshot.timelapseEvents),
                framesPerSecond: 24
            )
        }
        guard store.snapshot.timelapseFrames.count >= 2 else { return nil }
        return TimelapseCapture(
            canvasSize: canvasSize,
            paperStyle: store.snapshot.paperStyle,
            previewSurface: previewSurface,
            previewImageData: preview,
            source: .frames(store.snapshot.timelapseFrames),
            framesPerSecond: 24
        )
    }

    func timelapseCompositeSurface() -> DocumentCompositeSurface? {
        compositeExportSurface(paperStyle: store.snapshot.paperStyle)
    }

    func replayTimelapseOperation(_ operation: TimelapseOperation, folderIDMap: inout [DocumentFolderID: Int]) {
        switch operation {
        case let .stroke(layerIndex, brush, samples):
            _ = setActiveLayer(index: layerIndex.rawValue)
            _ = applyGpuStrokeSurface(samples: samples, brush: brush, layerIndex: layerIndex.rawValue)
        case let .blurStroke(layerIndex, brush, samples):
            _ = blur(samples: samples, brush: brush, layerIndex: layerIndex.rawValue, captureTimelapse: false)
            _ = endBlurStroke()
        case let .fill(layerIndex, brush, sample):
            _ = setActiveLayer(index: layerIndex.rawValue)
            _ = fill(sample: sample, brush: brush)
        case .undo:
            _ = undo()
        case .redo:
            _ = redo()
        case let .addLayer(name):
            _ = addLayer(name: name)
        case let .duplicateLayer(index, name):
            _ = duplicateLayer(index: index.rawValue, name: name)
        case let .deleteLayer(index):
            _ = deleteLayer(index: index.rawValue)
        case let .moveLayer(index, destinationIndex):
            _ = moveLayer(from: index.rawValue, to: destinationIndex.rawValue)
        case let .mergeLayerDown(index):
            _ = mergeLayerDown(index: index.rawValue)
        case let .createFolder(folderID, name, anchorLayerIndex):
            let resolved = (try? createFolder(name: name, layerIndex: anchorLayerIndex?.rawValue ?? -1).get()) ?? -1
            folderIDMap[folderID] = resolved
        case let .deleteFolder(folderID):
            if let resolved = folderIDMap[folderID] { _ = deleteFolder(folderID: resolved) }
        case let .setFolderVisibility(folderID, isVisible):
            if let resolved = folderIDMap[folderID] { _ = setFolderVisibility(folderID: resolved, isVisible: isVisible) }
        case let .setFolderName(folderID, name):
            if let resolved = folderIDMap[folderID] { _ = setFolderName(folderID: resolved, name: name) }
        case let .setFolderExpanded(folderID, isExpanded):
            if let resolved = folderIDMap[folderID] { _ = setFolderExpanded(folderID: resolved, isExpanded: isExpanded) }
        case let .assignLayerToFolder(index, folderID):
            let resolvedFolderID = folderID.flatMap { folderIDMap[$0] } ?? -1
            _ = assignLayerToFolder(index: index.rawValue, folderID: resolvedFolderID)
        case let .setLayerName(index, name):
            _ = setLayerName(index: index.rawValue, name: name)
        case let .setLayerVisibility(index, isVisible):
            _ = setLayerVisibility(index: index.rawValue, isVisible: isVisible)
        case let .setLayerLocked(index, isLocked):
            _ = setLayerLocked(index: index.rawValue, isLocked: isLocked)
        case let .setLayerAlphaLocked(index, isAlphaLocked):
            _ = setLayerAlphaLocked(index: index.rawValue, isAlphaLocked: isAlphaLocked)
        case let .setLayerClipped(index, isClipped):
            _ = setLayerClipped(index: index.rawValue, isClipped: isClipped)
        case let .setLayerOpacity(index, opacity):
            _ = setLayerOpacity(index: index.rawValue, opacity: opacity)
        case let .setLayerBlendMode(index, blendMode):
            _ = setLayerBlendMode(index: index.rawValue, blendMode: blendMode)
        case let .replaceLayerPixels(index, data):
            _ = replaceLayerPixelsUnchecked(index: index.rawValue, data: data, timelapseEvent: nil)
        case let .replaceLayerMask(index, data):
            _ = replaceLayerMask(index: index.rawValue, data: data)
        case let .clearLayerMask(index):
            _ = clearLayerMask(index: index.rawValue)
        case let .applyLayerMask(index):
            _ = applyLayerMask(index: index.rawValue)
        case let .clearLayer(index):
            _ = clearLayer(index: index.rawValue)
        case let .setPaperStyle(style):
            setPaperStyle(style)
        }
    }

    private var canvasSize: CGSize {
        CGSize(width: store.snapshot.canvasWidth, height: store.snapshot.canvasHeight)
    }

    private var rgbaByteCount: Int {
        store.snapshot.canvasWidth * store.snapshot.canvasHeight * 4
    }

    private func validateLayer(_ index: Int) -> DocumentMutationFailure? {
        store.snapshot.layers.indices.contains(index) ? nil : .invalidLayerIndex(index)
    }

    private func validateEditableLayer(_ index: Int) -> DocumentMutationFailure? {
        if let failure = validateLayer(index) { return failure }
        return store.snapshot.layers[index].locked ? .layerLocked(index) : nil
    }

    private func deleteLayerUnchecked(index: Int) {
        materializeGpuBackedLayerPixels()
        store.snapshot.layers.remove(at: index)
        remapFoldersAfterDeletion(of: index)
        store.snapshot.activeLayerIndex = min(store.snapshot.activeLayerIndex, store.snapshot.layers.count - 1)
        invalidateAllThumbnails()
        releaseLayerBufferHandles()
    }

    private func replaceLayerPixelsUnchecked(index: Int, data: Data, timelapseEvent: TimelapseOperation?) -> DocumentMutationResult {
        guard data.count == rgbaByteCount else {
            return .failure(.gpu(.invalidPayloadSize(
                operation: "replaceLayerPixels",
                expected: rgbaByteCount,
                actual: data.count
            )))
        }
        let before = undoSnapshot()
        let adjusted = preserveExistingAlphaIfNeeded(
            data,
            existing: currentPixelData(for: index),
            isAlphaLocked: store.snapshot.layers[index].alphaLocked
        )
        setLayerPixelState(index: index, pixelData: adjusted, gpuBufferHandle: nil)
        store.snapshot.layers[index].textLayer = nil
        invalidateThumbnail(for: index)
        recordMutation(
            before: before,
            timelapseEvent: timelapseEvent,
            changedLayerIndex: index,
            dirtyRect: fullCanvasRect()
        )
        return .success(())
    }

    private func applyLayerMutationPayload(
        index: Int,
        payload: DocumentLayerMutationPayload,
        timelapseEvent: TimelapseOperation?,
        recordsFinalLayerPixels: Bool = false
    ) -> DocumentMutationResult {
        guard payload.canvasWidth == store.snapshot.canvasWidth,
              payload.canvasHeight == store.snapshot.canvasHeight else {
            return .failure(.gpu(.invalidPayloadSize(
                operation: "applyLayerMutation",
                expected: rgbaByteCount,
                actual: payload.fullPixelData?.count ?? payload.rectPixelData.count
            )))
        }
        guard DocumentLayerMutationPayload(
            validatingCanvasWidth: payload.canvasWidth,
            canvasHeight: payload.canvasHeight,
            dirtyRect: payload.dirtyRect,
            gpuBufferHandle: payload.gpuBufferHandle,
            rectPixelData: payload.rectPixelData,
            fullPixelData: payload.fullPixelData
        ) != nil else {
            return .failure(.gpu(.invalidPayloadSize(
                operation: "applyLayerMutation",
                expected: rgbaByteCount,
                actual: payload.fullPixelData?.count ?? payload.rectPixelData.count
            )))
        }
        let before = undoSnapshot()
        let existing = currentPixelData(for: index)
        let shouldMaterialize = store.snapshot.layers[index].alphaLocked || recordsFinalLayerPixels
        let adjusted: Data
        let nextHandle: MetalBufferHandle?
        if shouldMaterialize {
            let materialized = materializedPixelData(from: payload, existing: existing)
            adjusted = preserveExistingAlphaIfNeeded(
                materialized,
                existing: existing,
                isAlphaLocked: store.snapshot.layers[index].alphaLocked
            )
            nextHandle = nil
        } else if let handle = payload.gpuBufferHandle {
            adjusted = existing
            nextHandle = handle
        } else {
            adjusted = materializedPixelData(from: payload, existing: existing)
            nextHandle = nil
        }
        setLayerPixelState(index: index, pixelData: adjusted, gpuBufferHandle: nextHandle)
        if nextHandle != payload.gpuBufferHandle {
            gpuServices.release(payload.gpuBufferHandle)
        }
        store.snapshot.layers[index].textLayer = nil
        invalidateThumbnail(for: index)
        let finalTimelapseEvent = recordsFinalLayerPixels
            ? TimelapseOperation.replaceLayerPixels(index: .unchecked(index), data: adjusted)
            : timelapseEvent
        recordMutation(
            before: before,
            timelapseEvent: finalTimelapseEvent,
            changedLayerIndex: index,
            dirtyRect: payload.dirtyRect
        )
        return .success(())
    }

    private func applyTextLayerMutationPayload(
        index: Int,
        textLayer: TextLayerData,
        payload: DocumentLayerMutationPayload
    ) -> DocumentMutationResult {
        guard payload.canvasWidth == store.snapshot.canvasWidth,
              payload.canvasHeight == store.snapshot.canvasHeight else {
            return .failure(.gpu(.invalidPayloadSize(
                operation: "applyTextLayerMutation",
                expected: rgbaByteCount,
                actual: payload.fullPixelData?.count ?? payload.rectPixelData.count
            )))
        }
        guard DocumentLayerMutationPayload(
            validatingCanvasWidth: payload.canvasWidth,
            canvasHeight: payload.canvasHeight,
            dirtyRect: payload.dirtyRect,
            gpuBufferHandle: payload.gpuBufferHandle,
            rectPixelData: payload.rectPixelData,
            fullPixelData: payload.fullPixelData
        ) != nil else {
            return .failure(.gpu(.invalidPayloadSize(
                operation: "applyTextLayerMutation",
                expected: rgbaByteCount,
                actual: payload.fullPixelData?.count ?? payload.rectPixelData.count
            )))
        }
        let before = undoSnapshot()
        setLayerPixelState(
            index: index,
            pixelData: materializedPixelData(from: payload, existing: currentPixelData(for: index)),
            gpuBufferHandle: payload.gpuBufferHandle
        )
        store.snapshot.layers[index].textLayer = textLayer
        invalidateThumbnail(for: index)
        recordMutation(
            before: before,
            timelapseEvent: .replaceLayerPixels(index: .unchecked(index), data: payload.fullPixelData ?? currentPixelData(for: index)),
            changedLayerIndex: index,
            dirtyRect: payload.dirtyRect
        )
        return .success(())
    }

    private func materializedPixelData(from payload: DocumentLayerMutationPayload, existing: Data) -> Data {
        if let handle = payload.gpuBufferHandle,
           let gpuPixelData = gpuServices.materializedPixelData(for: handle),
           gpuPixelData.count == rgbaByteCount {
            return gpuPixelData
        }
        if let fullPixelData = payload.fullPixelData, fullPixelData.count == rgbaByteCount {
            return fullPixelData
        }
        guard payload.rectPixelData.count == payload.dirtyRect.width * payload.dirtyRect.height * 4,
              existing.count == rgbaByteCount else {
            return existing
        }
        var output = existing
        output.withUnsafeMutableBytes { destinationBytes in
            payload.rectPixelData.withUnsafeBytes { sourceBytes in
                guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else { return }
                for row in 0..<payload.dirtyRect.height {
                    let destOffset = (((payload.dirtyRect.originY + row) * store.snapshot.canvasWidth) + payload.dirtyRect.originX) * 4
                    let srcOffset = row * payload.dirtyRect.width * 4
                    memcpy(destination + destOffset, source + srcOffset, payload.dirtyRect.width * 4)
                }
            }
        }
        return output
    }

    private func setLayerPixelState(index: Int, pixelData: Data, gpuBufferHandle: MetalBufferHandle?) {
        gpuLayerStorage.setLayerPixelState(
            index: index,
            pixelData: pixelData,
            gpuBufferHandle: gpuBufferHandle,
            in: store,
            services: gpuServices
        )
    }

    private func releaseLayerBufferHandles() {
        gpuLayerStorage.releaseLayerBufferHandles(services: gpuServices)
    }

    private func currentPixelData(for index: Int) -> Data {
        gpuLayerStorage.currentPixelData(
            for: index,
            in: store.snapshot,
            rgbaByteCount: rgbaByteCount,
            services: gpuServices
        )
    }

    private func layerSourceForGpuPlan(index: Int) -> (
        pixelData: Data,
        bufferHandle: MetalBufferHandle?,
        retainedResource: GpuResourceLease?
    ) {
        gpuLayerStorage.layerSourceForGpuPlan(
            index: index,
            snapshot: store.snapshot,
            services: gpuServices
        )
    }

    private func recordMutation(
        before: SwiftDocumentStoreSnapshot,
        timelapseEvent: TimelapseOperation?,
        changedLayerIndex: Int? = nil,
        dirtyRect: LayerPixelRect? = nil
    ) {
        let after = changedLayerIndex != nil && dirtyRect != nil ? undoSnapshot() : before
        let stats = undoPolicy.recordMutation(
            before: before,
            after: after,
            changedLayerIndex: changedLayerIndex,
            dirtyRect: dirtyRect
        )
        logUndoHistoryStats(stats, reason: "recordMutation")
        timelapseRecorder.record(timelapseEvent, marksOperationPersistence: true, in: store)
        store.snapshot.revision += 1
        captureDirtyUpdate(rect: dirtyRect)
    }

    private func fullCanvasRect() -> LayerPixelRect {
        LayerPixelRect.unsafeUnchecked(originX: 0,
            originY: 0,
            width: store.snapshot.canvasWidth,
            height: store.snapshot.canvasHeight
        )
    }

    private func logUndoHistoryStats(_ stats: UndoSnapshotPolicy.DebugStats, reason: String) {
        #if DEBUG
        Self.logger.debug(
            "Undo history \(reason, privacy: .public): bytes=\(stats.retainedBytes, privacy: .public) undo=\(stats.undoCount, privacy: .public) redo=\(stats.redoCount, privacy: .public) evicted=\(stats.evictedCount, privacy: .public) droppedOversized=\(stats.droppedOversizedCount, privacy: .public)"
        )
        #endif
    }

    private func captureDirtyUpdate(rect: LayerPixelRect? = nil) {
        let rect = rect ?? LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: store.snapshot.canvasWidth, height: store.snapshot.canvasHeight)
        let snapshot = makeMetalSnapshot(for: store.snapshot, includeCompositePixelData: false)
        if let dirtyUpdate = gpuServices.compositedIncrementalUpdate(
            snapshot: snapshot,
            dirtyRect: (rect.originX, rect.originY, rect.width, rect.height)
        ) {
            setPendingDirtyUpdate(dirtyUpdate)
            return
        }
        let composite = compositePixelDataForSnapshot(store.snapshot)
        let pixelData = crop(pixelData: composite, width: store.snapshot.canvasWidth, rect: rect)
        setPendingDirtyUpdate(IncrementalLayerUpdate.unsafeUnchecked(
            layerIndex: -1,
            originX: rect.originX,
            originY: rect.originY,
            width: rect.width,
            height: rect.height,
            pixelData: pixelData
        ))
    }

    private func setPendingDirtyUpdate(_ update: IncrementalLayerUpdate) {
        if let previous = pendingDirtyUpdate?.gpuBufferHandle,
           previous != update.gpuBufferHandle {
            gpuServices.release(previous)
        }
        pendingDirtyUpdate = update
    }

    private func compositeSurfaceForSnapshot(_ snapshot: SwiftDocumentStoreSnapshot) -> DocumentCompositeSurface {
        let metalSnapshot = makeMetalSnapshot(for: snapshot, includeCompositePixelData: false)
        if let gpuComposite = gpuServices.compositeDocumentSurface(snapshot: metalSnapshot) {
            return gpuComposite
        }
        Self.logger.error("GPU composite failed for snapshot revision \(snapshot.revision, privacy: .public)")
        return DocumentCompositeSurface(
            unsafeUncheckedWidth: snapshot.canvasWidth,
            height: snapshot.canvasHeight,
            pixelData: Data(count: snapshot.canvasWidth * snapshot.canvasHeight * 4)
        )
    }

    private func compositePixelDataForSnapshot(_ snapshot: SwiftDocumentStoreSnapshot) -> Data {
        compositeSurfaceForSnapshot(snapshot).pixelData
    }

    private func crop(pixelData: Data, width: Int, rect: LayerPixelRect) -> Data {
        guard rect.width > 0, rect.height > 0 else { return Data() }
        var output = Data(count: rect.width * rect.height * 4)
        output.withUnsafeMutableBytes { destinationBytes in
            pixelData.withUnsafeBytes { sourceBytes in
                guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else { return }
                for row in 0..<rect.height {
                    let srcOffset = ((rect.originY + row) * width + rect.originX) * 4
                    let dstOffset = row * rect.width * 4
                    memcpy(destination + dstOffset, source + srcOffset, rect.width * 4)
                }
            }
        }
        return output
    }

    private func makeRenderSnapshot() -> MetalDocumentSnapshot? {
        let baseSnapshot = makeMetalSnapshot(for: store.snapshot, includeCompositePixelData: false)
        let compositeHandle = gpuServices.compositeDocumentBufferHandle(snapshot: baseSnapshot)
        let composite = compositeHandle == nil ? compositeSurface() : nil
        return MetalDocumentSnapshot.unsafeUnchecked(
            width: baseSnapshot.width,
            height: baseSnapshot.height,
            revision: baseSnapshot.revision,
            compositeBufferHandle: compositeHandle,
            compositePixelData: composite?.pixelData ?? Data(),
            layers: baseSnapshot.layers.enumerated().map { index, layer in
                MetalLayerSnapshot.unsafeUnchecked(
                    index: layer.index,
                    opacity: layer.opacity,
                    visible: layer.visible,
                    isClipped: layer.isClipped,
                    blendMode: layer.blendMode,
                    thumbnailSurface: cachedLayerThumbnailSurface(index: index),
                    thumbnailData: nil,
                    gpuBufferHandle: layer.gpuBufferHandle,
                    pixelData: layer.pixelData
                )
            }
        )
    }

    private func makeMetalSnapshot(
        for snapshot: SwiftDocumentStoreSnapshot,
        includeCompositePixelData: Bool
    ) -> MetalDocumentSnapshot {
        MetalDocumentSnapshot.unsafeUnchecked(
            width: snapshot.canvasWidth,
            height: snapshot.canvasHeight,
            revision: snapshot.revision,
            compositePixelData: includeCompositePixelData ? compositePixelDataForSnapshot(snapshot) : Data(),
            layers: snapshot.layers.enumerated().map { index, layer in
                MetalLayerSnapshot.unsafeUnchecked(
                    index: index,
                    opacity: Float(layer.opacity),
                    visible: layer.visible && (layer.folderID == nil || (snapshot.folders.first(where: { $0.id == layer.folderID })?.visible ?? true)),
                    isClipped: layer.clipped,
                    blendMode: layer.blendMode,
                    thumbnailSurface: nil,
                    thumbnailData: nil,
                    gpuBufferHandle: gpuLayerStorage.handle(for: index),
                    pixelData: layer.pixelData
                )
            }
        )
    }

    private func buildLayerRows() -> [LayerRowModel] {
        store.snapshot.layers.enumerated().map { index, layer in
            LayerRowModel(
                index: index,
                name: layer.name,
                visible: layer.visible,
                opacity: layer.opacity,
                isLocked: layer.locked,
                isAlphaLocked: layer.alphaLocked,
                isClipped: layer.clipped,
                blendMode: layer.blendMode,
                folderID: layer.folderID,
                hasMask: layer.maskData != nil,
                isTextLayer: layer.textLayer != nil,
                textLayer: layer.textLayer
            )
        }.reversed()
    }

    private func buildSidebarRows() -> [LayerSidebarRowModel] {
        let layerRows = buildLayerRows()
        let layerRowsByIndex = Dictionary(uniqueKeysWithValues: layerRows.map { ($0.index, $0) })
        let orderedFolders = store.snapshot.folders.map { folder in
            LayerFolderModel(
                id: folder.id,
                name: folder.name,
                visible: folder.visible,
                isExpanded: folder.expanded,
                anchorLayerIndex: folder.anchorLayerIndex,
                childLayerIndices: store.snapshot.layers.enumerated().compactMap { index, layer in
                    layer.folderID == folder.id ? index : nil
                }.sorted(by: >)
            )
        }
        var emittedFolderIDs = Set<Int>()
        var rows: [LayerSidebarRowModel] = []
        for layer in layerRows {
            for folder in orderedFolders where folder.anchorLayerIndex == layer.index && !emittedFolderIDs.contains(folder.id) {
                rows.append(.folder(folder))
                emittedFolderIDs.insert(folder.id)
                if folder.isExpanded {
                    for childIndex in folder.childLayerIndices {
                        if let child = layerRowsByIndex[childIndex] {
                            rows.append(.layer(child, depth: 1))
                        }
                    }
                }
            }
            if let folderID = layer.folderID {
                if !orderedFolders.contains(where: { $0.id == folderID }) {
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

    private func cachedLayerThumbnailSurface(index: Int) -> DocumentCompositeSurface? {
        if let cached = thumbnailSurfaceCache[index] {
            return cached
        }
        guard store.snapshot.layers.indices.contains(index) else { return nil }
        let targetSize = timelapseFrameSize(for: canvasSize, maxDimension: 96)
        let targetWidth = max(Int(targetSize.width.rounded()), 1)
        let targetHeight = max(Int(targetSize.height.rounded()), 1)
        guard let scaled = gpuServices.scaledPixelData(
            currentPixelData(for: index),
            sourceWidth: store.snapshot.canvasWidth,
            sourceHeight: store.snapshot.canvasHeight,
            targetWidth: targetWidth,
            targetHeight: targetHeight
        ) else {
            return nil
        }
        let surface = DocumentCompositeSurface(
            unsafeUncheckedWidth: targetWidth,
            height: targetHeight,
            pixelData: scaled
        )
        thumbnailSurfaceCache[index] = surface
        return surface
    }

    private func invalidateThumbnail(for index: Int) {
        store.snapshot.thumbnailCache[index] = nil
        thumbnailSurfaceCache[index] = nil
    }

    private func invalidateAllThumbnails() {
        store.snapshot.thumbnailCache.removeAll(keepingCapacity: true)
        thumbnailSurfaceCache.removeAll(keepingCapacity: true)
    }

    private func timelapseFrameSize(for canvasSize: CGSize, maxDimension: CGFloat) -> CGSize {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return CGSize(width: maxDimension, height: maxDimension)
        }
        let scale = min(maxDimension / canvasSize.width, maxDimension / canvasSize.height, 1.0)
        return CGSize(width: max(2, Int((canvasSize.width * scale).rounded())), height: max(2, Int((canvasSize.height * scale).rounded())))
    }

    private func makeTimelapseThumbnailSurface() -> DocumentCompositeSurface? {
        guard let source = timelapseCompositeSurface() else { return nil }
        let targetSize = timelapseFrameSize(for: canvasSize, maxDimension: 512)
        guard let scaled = gpuServices.scaledPixelData(
            source.pixelData,
            sourceWidth: source.width,
            sourceHeight: source.height,
            targetWidth: max(Int(targetSize.width.rounded()), 1),
            targetHeight: max(Int(targetSize.height.rounded()), 1)
        ) else {
            return nil
        }
        return DocumentCompositeSurface(
            unsafeUncheckedWidth: max(Int(targetSize.width.rounded()), 1),
            height: max(Int(targetSize.height.rounded()), 1),
            pixelData: scaled
        )
    }

    private func captureTimelapseFrame() {
        guard let source = makeTimelapseThumbnailSurface(),
              let jpegData = DocumentRasterImageService.jpegData(from: source) else { return }
        let frameURL = services.timelapse.frameStore.makeFrameURL(
            in: services.timelapse.frameStore.makeDirectoryURL(),
            frameID: store.snapshot.timelapseFrames.count
        )
        do {
            try services.timelapse.frameStore.persistFrameData(jpegData, to: frameURL)
            store.snapshot.timelapseFrames.append(TimelapseFrame(imageURL: frameURL, size: CGSize(width: source.width, height: source.height)))
            store.snapshot.timelapseUsesOperationPersistence = false
        } catch {
            Self.logger.error("Failed to persist timelapse frame: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Legacy helper retained for deprecated replay/export conveniences.
    func cgImage(from pixelData: Data, width: Int, height: Int) -> CGImage? {
        guard pixelData.count == width * height * 4 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: pixelData as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private func remapFoldersAfterInsertion(at insertedIndex: Int) {
        for index in store.snapshot.folders.indices {
            if let anchor = store.snapshot.folders[index].anchorLayerIndex, anchor >= insertedIndex {
                store.snapshot.folders[index].anchorLayerIndex = anchor + 1
            }
        }
    }

    private func remapFoldersAfterDeletion(of deletedIndex: Int) {
        for index in store.snapshot.folders.indices {
            if let anchor = store.snapshot.folders[index].anchorLayerIndex {
                if anchor == deletedIndex {
                    store.snapshot.folders[index].anchorLayerIndex = nil
                } else if anchor > deletedIndex {
                    store.snapshot.folders[index].anchorLayerIndex = anchor - 1
                }
            }
        }
    }

    private func remapFoldersAfterMove(from sourceIndex: Int, to destinationIndex: Int) {
        for index in store.snapshot.folders.indices {
            guard let anchor = store.snapshot.folders[index].anchorLayerIndex else { continue }
            if anchor == sourceIndex {
                store.snapshot.folders[index].anchorLayerIndex = destinationIndex
            } else if sourceIndex < destinationIndex, anchor > sourceIndex, anchor <= destinationIndex {
                store.snapshot.folders[index].anchorLayerIndex = anchor - 1
            } else if sourceIndex > destinationIndex, anchor >= destinationIndex, anchor < sourceIndex {
                store.snapshot.folders[index].anchorLayerIndex = anchor + 1
            }
        }
    }

    private func preserveExistingAlphaIfNeeded(_ source: Data, existing: Data, isAlphaLocked: Bool) -> Data {
        isAlphaLocked ? preserveExistingAlpha(source: source, existing: existing) : source
    }

    private func preserveExistingAlpha(source: Data, existing: Data) -> Data {
        guard source.count == existing.count, source.count.isMultiple(of: 4) else { return source }
        var output = [UInt8](source)
        existing.withUnsafeBytes { existingBytes in
            guard let existingBase = existingBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for offset in stride(from: 0, to: output.count, by: 4) {
                output[offset + 3] = existingBase[offset + 3]
            }
        }
        return Data(output)
    }
}
