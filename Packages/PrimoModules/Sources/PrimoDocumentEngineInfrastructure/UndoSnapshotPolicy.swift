import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts

struct UndoSnapshotPolicy: Sendable {
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
    // Rect deltas intentionally capture the layer metadata produced by the same
    // mutation. Pixel operations can clear text layers or materialize GPU state,
    // while independent metadata edits are recorded as separate snapshot entries.
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
        guard let geometry = snapshot.pixelGeometry,
              snapshot.layers[layerIndex].replacePixelData(patchedPixels, geometry: geometry) else {
            return nil
        }
        return snapshot
    }
}

private struct LayerUndoMetadata: Sendable {
    var name: String
    var visible: Bool
    var locked: Bool
    var alphaLocked: Bool
    var clipped: Bool
    var opacity: DocumentLayerOpacity
    var blendMode: LayerBlendMode
    var folderID: Int?
    var textLayer: TextLayerData?

    init(layer: SwiftDocumentLayerRecord) {
        name = layer.name
        visible = layer.visible
        locked = layer.locked
        alphaLocked = layer.alphaLocked
        clipped = layer.clipped
        guard let layerOpacity = layer.validatedOpacity() else {
            preconditionFailure("LayerUndoMetadata cannot capture invalid layer opacity")
        }
        opacity = layerOpacity
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
        layer.setOpacity(opacity.rawValue)
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
