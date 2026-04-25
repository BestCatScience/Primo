import CoreGraphics
import Foundation
import os
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentInfrastructure
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentPersistenceInfrastructure
import PrimoDocumentRenderingInfrastructure
import PrimoDocumentStrokeInfrastructure
import PrimoDocumentTimelapseInfrastructure

final class SwiftDocumentRuntime: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.primo.app", category: "SwiftDocumentRuntime")

    private let services: DocumentEngineServices
    private let resources: MetalResourceStore
    private let strokes: MetalStrokeExecutionService
    private let composites: MetalCompositingService
    private let layers: MetalLayerMutationService
    private let text: MetalTextService
    private let store: SwiftDocumentStore
    private var undoStack: [SwiftDocumentStoreSnapshot] = []
    private var redoStack: [SwiftDocumentStoreSnapshot] = []
    private var pendingDirtyUpdate: IncrementalLayerUpdate?
    private var currentStroke: (layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])?
    private var currentBlurStroke: (baseline: SwiftDocumentStoreSnapshot?, layerIndex: Int, brush: BrushRuntimeSettings, samples: [StylusSample])?
    private var thumbnailSurfaceCache: [Int: DocumentCompositeSurface] = [:]
    private var gpuLayerHandles: [Int: MetalBufferHandle] = [:]

    init(
        width: Int = 1152,
        height: Int = 1536,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live,
        resources: MetalResourceStore = MetalResourceStore(),
        strokes: MetalStrokeExecutionService = MetalStrokeExecutionService(),
        composites: MetalCompositingService = MetalCompositingService(),
        layers: MetalLayerMutationService = MetalLayerMutationService(),
        text: MetalTextService = MetalTextService()
    ) {
        self.services = DocumentEngineServices(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
        self.resources = resources
        self.strokes = strokes
        self.composites = composites
        self.layers = layers
        self.text = text
        self.store = SwiftDocumentStore(width: width, height: height)
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

    func canUndo() -> Bool {
        !undoStack.isEmpty
    }

    func canRedo() -> Bool {
        !redoStack.isEmpty
    }

    func undo() -> DocumentMutationResult {
        guard let previous = undoStack.popLast() else {
            return .failure(.noUndoState)
        }
        redoStack.append(store.snapshot)
        store.restore(previous)
        thumbnailSurfaceCache.removeAll(keepingCapacity: true)
        releaseLayerBufferHandles()
        store.snapshot.timelapseEvents.append(.undo)
        store.snapshot.revision += 1
        captureDirtyUpdate()
        return .success(())
    }

    func redo() -> DocumentMutationResult {
        guard let next = redoStack.popLast() else {
            return .failure(.noRedoState)
        }
        undoStack.append(store.snapshot)
        store.restore(next)
        thumbnailSurfaceCache.removeAll(keepingCapacity: true)
        releaseLayerBufferHandles()
        store.snapshot.timelapseEvents.append(.redo)
        store.snapshot.revision += 1
        captureDirtyUpdate()
        return .success(())
    }

    func resizeCanvas(width: Int, height: Int) -> DocumentMutationResult {
        guard width > 0 && height > 0 else {
            return .failure(.invalidCanvasSize(width: width, height: height))
        }
        let sourceSize = PaintDocumentCanvasSize(width: store.snapshot.canvasWidth, height: store.snapshot.canvasHeight)
        let targetSize = PaintDocumentCanvasSize(width: width, height: height)
        guard sourceSize != targetSize else { return .success(()) }
        let before = store.snapshot
        let widthScale = Double(targetSize.width) / Double(sourceSize.width)
        let heightScale = Double(targetSize.height) / Double(sourceSize.height)
        let textScale = min(widthScale, heightScale)
        for index in store.snapshot.layers.indices {
            var layer = store.snapshot.layers[index]
            guard let scaled = layers.scaledPixelData(
                layer.pixelData,
                sourceWidth: sourceSize.width,
                sourceHeight: sourceSize.height,
                targetWidth: targetSize.width,
                targetHeight: targetSize.height
            ) else {
                return .failure(.bridgeMutationFailed("resizeCanvas"))
            }
            layer.pixelData = scaled
            if let mask = layer.maskData {
                guard let scaledMask = layers.scaledMaskData(
                    mask,
                    sourceWidth: sourceSize.width,
                    sourceHeight: sourceSize.height,
                    targetWidth: targetSize.width,
                    targetHeight: targetSize.height
                ) else {
                    return .failure(.bridgeMutationFailed("resizeCanvas"))
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
            store.snapshot.layers[index] = layer
        }
        store.snapshot.canvasWidth = targetSize.width
        store.snapshot.canvasHeight = targetSize.height
        store.snapshot.thumbnailCache.removeAll()
        thumbnailSurfaceCache.removeAll(keepingCapacity: true)
        releaseLayerBufferHandles()
        recordMutation(before: before, timelapseEvent: nil)
        return .success(())
    }

    func resizeCanvasExtent(width: Int, height: Int) -> DocumentMutationResult {
        guard width > 0 && height > 0 else {
            return .failure(.invalidCanvasSize(width: width, height: height))
        }
        let sourceSize = PaintDocumentCanvasSize(width: store.snapshot.canvasWidth, height: store.snapshot.canvasHeight)
        let targetSize = PaintDocumentCanvasSize(width: width, height: height)
        guard sourceSize != targetSize else { return .success(()) }
        let before = store.snapshot
        let offsetX = (targetSize.width - sourceSize.width) / 2
        let offsetY = (targetSize.height - sourceSize.height) / 2
        for index in store.snapshot.layers.indices {
            var layer = store.snapshot.layers[index]
            guard let translated = layers.translatedPixelData(
                layer.pixelData,
                sourceWidth: sourceSize.width,
                sourceHeight: sourceSize.height,
                targetWidth: targetSize.width,
                targetHeight: targetSize.height,
                offsetX: offsetX,
                offsetY: offsetY
            ) else {
                return .failure(.bridgeMutationFailed("resizeCanvasExtent"))
            }
            layer.pixelData = translated
            if let mask = layer.maskData {
                guard let translatedMask = layers.translatedMaskData(
                    mask,
                    sourceWidth: sourceSize.width,
                    sourceHeight: sourceSize.height,
                    targetWidth: targetSize.width,
                    targetHeight: targetSize.height,
                    offsetX: offsetX,
                    offsetY: offsetY
                ) else {
                    return .failure(.bridgeMutationFailed("resizeCanvasExtent"))
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
            store.snapshot.layers[index] = layer
        }
        store.snapshot.canvasWidth = targetSize.width
        store.snapshot.canvasHeight = targetSize.height
        store.snapshot.thumbnailCache.removeAll()
        thumbnailSurfaceCache.removeAll(keepingCapacity: true)
        releaseLayerBufferHandles()
        recordMutation(before: before, timelapseEvent: nil)
        return .success(())
    }

    func addLayer(name: String) -> DocumentIndexedMutationResult {
        let before = store.snapshot
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
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        store.snapshot.layers[index].name = name
        return .success(())
    }

    func setLayerVisibility(index: Int, isVisible: Bool) -> DocumentMutationResult {
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        let before = store.snapshot
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
            return .failure(.bridgeMutationFailed("replaceLayerPixelsInRect"))
        }
        guard data.count == rect.width * rect.height * 4 else {
            return .failure(.bridgeMutationFailed("replaceLayerPixelsInRect"))
        }
        guard rect.originX >= 0,
              rect.originY >= 0,
              rect.originX + rect.width <= store.snapshot.canvasWidth,
              rect.originY + rect.height <= store.snapshot.canvasHeight
        else {
            return .failure(.bridgeMutationFailed("replaceLayerPixelsInRect"))
        }
        guard let failure = validateEditableLayer(index) else {
            let before = store.snapshot
            var output = store.snapshot.layers[index].pixelData
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
                existing: store.snapshot.layers[index].pixelData,
                isAlphaLocked: store.snapshot.layers[index].alphaLocked
            )
            setLayerPixelState(index: index, pixelData: output, gpuBufferHandle: nil)
            invalidateThumbnail(for: index)
            recordMutation(before: before, timelapseEvent: nil, dirtyRect: rect)
            return .success(())
        }
        return .failure(failure)
    }

    func applyLayerMutation(index: Int, payload: DocumentLayerMutationPayload) -> DocumentMutationResult {
        guard let failure = validateEditableLayer(index) else {
            return applyLayerMutationPayload(
                index: index,
                payload: payload,
                timelapseEvent: .replaceLayerPixels(index: .unchecked(index), data: payload.fullPixelData ?? store.snapshot.layers[index].pixelData)
            )
        }
        return .failure(failure)
    }

    func applyTextLayerMutation(index: Int, textLayer: TextLayerData, payload: DocumentLayerMutationPayload) -> DocumentMutationResult {
        guard validateEditableLayer(index) == nil else { return .failure(validateEditableLayer(index)!) }
        return applyTextLayerMutationPayload(index: index, textLayer: textLayer, payload: payload)
    }

    func replaceLayerMask(index: Int, data: Data) -> DocumentMutationResult {
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        guard !data.isEmpty else { return .failure(.emptyInput) }
        guard data.count == store.snapshot.canvasWidth * store.snapshot.canvasHeight else {
            return .failure(.bridgeMutationFailed("replaceLayerMask"))
        }
        let before = store.snapshot
        store.snapshot.layers[index].maskData = data
        invalidateThumbnail(for: index)
        recordMutation(before: before, timelapseEvent: .replaceLayerMask(index: .unchecked(index), data: data))
        return .success(())
    }

    func clearLayerMask(index: Int) -> DocumentMutationResult {
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        guard store.snapshot.layers[index].maskData != nil else { return .success(()) }
        let before = store.snapshot
        store.snapshot.layers[index].maskData = nil
        invalidateThumbnail(for: index)
        recordMutation(before: before, timelapseEvent: .clearLayerMask(index: .unchecked(index)))
        return .success(())
    }

    func applyLayerMask(index: Int) -> DocumentMutationResult {
        guard let failure = validateLayer(index) else {
            guard let mask = store.snapshot.layers[index].maskData else { return .success(()) }
            guard let maskedPixels = layers.applyLayerMask(
                pixelData: store.snapshot.layers[index].pixelData,
                maskData: mask,
                width: store.snapshot.canvasWidth,
                height: store.snapshot.canvasHeight
            ) else {
                return .failure(.bridgeMutationFailed("applyLayerMask"))
            }
            let before = store.snapshot
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
            let before = store.snapshot
            setLayerPixelState(index: index, pixelData: Data(count: rgbaByteCount), gpuBufferHandle: nil)
            invalidateThumbnail(for: index)
            recordMutation(before: before, timelapseEvent: .clearLayer(index: .unchecked(index)))
            return .success(())
        }
        return .failure(failure)
    }

    func applyLayerProcessing(index: Int, request: LayerProcessingRequest) -> DocumentMutationResult {
        guard validateEditableLayer(index) == nil else { return .failure(validateEditableLayer(index)!) }
        guard let payload = layers.processLayer(
            pixelData: store.snapshot.layers[index].pixelData,
            canvasWidth: store.snapshot.canvasWidth,
            canvasHeight: store.snapshot.canvasHeight,
            request: request
        ) else {
            return .failure(.bridgeMutationFailed("applyLayerProcessing"))
        }
        return applyLayerMutationPayload(
            index: index,
            payload: payload,
            timelapseEvent: .replaceLayerPixels(index: .unchecked(index), data: payload.fullPixelData ?? store.snapshot.layers[index].pixelData)
        )
    }

    func duplicateLayer(index: Int, name: String) -> DocumentIndexedMutationResult {
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        let before = store.snapshot
        var layer = store.snapshot.layers[index]
        layer.name = name
        let duplicatedIndex = index + 1
        store.snapshot.layers.insert(layer, at: duplicatedIndex)
        remapFoldersAfterInsertion(at: duplicatedIndex)
        store.snapshot.activeLayerIndex = duplicatedIndex
        releaseLayerBufferHandles()
        recordMutation(before: before, timelapseEvent: .duplicateLayer(index: .unchecked(index), name: name))
        return .success(duplicatedIndex)
    }

    func deleteLayer(index: Int) -> DocumentMutationResult {
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        guard store.snapshot.layers.count > 1 else { return .failure(.bridgeMutationFailed("deleteLayer")) }
        let before = store.snapshot
        store.snapshot.layers.remove(at: index)
        remapFoldersAfterDeletion(of: index)
        store.snapshot.activeLayerIndex = min(store.snapshot.activeLayerIndex, store.snapshot.layers.count - 1)
        invalidateAllThumbnails()
        releaseLayerBufferHandles()
        recordMutation(before: before, timelapseEvent: .deleteLayer(index: .unchecked(index)))
        return .success(())
    }

    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentMutationResult {
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        guard validateLayer(destinationIndex) == nil else { return .failure(validateLayer(destinationIndex)!) }
        guard index != destinationIndex else { return .success(()) }
        let before = store.snapshot
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
        let before = store.snapshot
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
        let before = store.snapshot
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
        let before = store.snapshot
        store.snapshot.folders[folderIndex].visible = isVisible
        recordMutation(before: before, timelapseEvent: .setFolderVisibility(folderID: .unchecked(folderID), isVisible: isVisible))
        return .success(())
    }

    func setFolderName(folderID: Int, name: String) -> DocumentMutationResult {
        guard let folderIndex = store.snapshot.folders.firstIndex(where: { $0.id == folderID }) else {
            return .failure(.invalidFolderID(folderID))
        }
        store.snapshot.folders[folderIndex].name = name
        return .success(())
    }

    func setFolderExpanded(folderID: Int, isExpanded: Bool) -> DocumentMutationResult {
        guard let folderIndex = store.snapshot.folders.firstIndex(where: { $0.id == folderID }) else {
            return .failure(.invalidFolderID(folderID))
        }
        store.snapshot.folders[folderIndex].expanded = isExpanded
        return .success(())
    }

    func assignLayerToFolder(index: Int, folderID: Int) -> DocumentMutationResult {
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        if folderID >= 0, !store.snapshot.folders.contains(where: { $0.id == folderID }) {
            return .failure(.invalidFolderID(folderID))
        }
        let before = store.snapshot
        store.snapshot.layers[index].folderID = folderID >= 0 ? folderID : nil
        recordMutation(before: before, timelapseEvent: .assignLayerToFolder(index: .unchecked(index), folderID: folderID >= 0 ? .unchecked(folderID) : nil))
        return .success(())
    }

    func setLayerLocked(index: Int, isLocked: Bool) -> DocumentMutationResult {
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        let before = store.snapshot
        store.snapshot.layers[index].locked = isLocked
        recordMutation(before: before, timelapseEvent: .setLayerLocked(index: .unchecked(index), isLocked: isLocked))
        return .success(())
    }

    func setLayerAlphaLocked(index: Int, isAlphaLocked: Bool) -> DocumentMutationResult {
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        let before = store.snapshot
        store.snapshot.layers[index].alphaLocked = isAlphaLocked
        recordMutation(before: before, timelapseEvent: .setLayerAlphaLocked(index: .unchecked(index), isAlphaLocked: isAlphaLocked))
        return .success(())
    }

    func setLayerClipped(index: Int, isClipped: Bool) -> DocumentMutationResult {
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        let before = store.snapshot
        store.snapshot.layers[index].clipped = isClipped
        recordMutation(before: before, timelapseEvent: .setLayerClipped(index: .unchecked(index), isClipped: isClipped))
        return .success(())
    }

    func setLayerOpacity(index: Int, opacity: Double) -> DocumentMutationResult {
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        guard (0...1).contains(opacity) else { return .failure(.invalidOpacity(opacity)) }
        let before = store.snapshot
        store.snapshot.layers[index].opacity = opacity
        recordMutation(before: before, timelapseEvent: .setLayerOpacity(index: .unchecked(index), opacity: opacity))
        return .success(())
    }

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) -> DocumentMutationResult {
        guard validateLayer(index) == nil else { return .failure(validateLayer(index)!) }
        let before = store.snapshot
        store.snapshot.layers[index].blendMode = blendMode
        recordMutation(before: before, timelapseEvent: .setLayerBlendMode(index: .unchecked(index), blendMode: blendMode))
        return .success(())
    }

    func mergeLayerDown(index: Int) -> DocumentMutationResult {
        guard index > 0 else { return .failure(.invalidLayerIndex(index)) }
        guard validateEditableLayer(index) == nil else { return .failure(validateEditableLayer(index)!) }
        guard validateEditableLayer(index - 1) == nil else { return .failure(validateEditableLayer(index - 1)!) }
        let upper = store.snapshot.layers[index]
        let lower = store.snapshot.layers[index - 1]
        guard let merged = layers.mergeLayers(
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
        let before = store.snapshot
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
        _ = deleteLayer(index: index)
        invalidateThumbnail(for: index - 1)
        recordMutation(before: before, timelapseEvent: .replaceLayerPixels(index: .unchecked(index - 1), data: merged))
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
        guard validateEditableLayer(index) == nil else { return .failure(validateEditableLayer(index)!) }
        guard let payload = text.rasterizeTextLayer(textLayer, canvasSize: canvasSize) else {
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

    func endStroke() {
        guard let currentStroke else { return }
        _ = applySoftwareStroke(samples: currentStroke.samples, brush: currentStroke.brush, layerIndex: currentStroke.layerIndex)
        self.currentStroke = nil
    }

    func cancelStroke() {
        currentStroke = nil
    }

    func blur(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, captureTimelapse: Bool) -> DocumentMutationResult {
        guard !samples.isEmpty else { return .failure(.emptyInput) }
        guard validateEditableLayer(layerIndex) == nil else { return .failure(validateEditableLayer(layerIndex)!) }
        let baseline = currentBlurStroke?.baseline ?? store.snapshot
        currentBlurStroke = (
            baseline: baseline,
            layerIndex: layerIndex,
            brush: brush,
            samples: (currentBlurStroke?.samples ?? []) + samples
        )
        guard let payload = layers.blurPixels(
            pixelData: store.snapshot.layers[layerIndex].pixelData,
            sourceBufferHandle: gpuLayerHandles[layerIndex],
            canvasWidth: store.snapshot.canvasWidth,
            canvasHeight: store.snapshot.canvasHeight,
            samples: samples,
            brush: brush
        ) else {
            return .failure(.bridgeMutationFailed("blurStroke"))
        }
        let current = store.snapshot.layers[layerIndex].pixelData
        let nextPixelData: Data
        let nextHandle: MetalBufferHandle?
        if store.snapshot.layers[layerIndex].alphaLocked {
            nextPixelData = preserveExistingAlphaIfNeeded(
                materializedPixelData(from: payload, existing: current),
                existing: current,
                isAlphaLocked: true
            )
            nextHandle = nil
            resources.release(payload.gpuBufferHandle)
        } else if let handle = payload.gpuBufferHandle {
            nextPixelData = current
            nextHandle = handle
        } else {
            nextPixelData = materializedPixelData(from: payload, existing: current)
            nextHandle = nil
        }
        setLayerPixelState(
            index: layerIndex,
            pixelData: nextPixelData,
            gpuBufferHandle: nextHandle
        )
        store.snapshot.layers[layerIndex].textLayer = nil
        invalidateThumbnail(for: layerIndex)
        captureDirtyUpdate(rect: payload.dirtyRect)
        if captureTimelapse {
            captureTimelapseFrame()
        }
        return .success(())
    }

    func endBlurStroke() {
        guard let currentBlurStroke,
              let baseline = currentBlurStroke.baseline
        else { return }
        undoStack.append(baseline)
        redoStack.removeAll(keepingCapacity: true)
        store.snapshot.timelapseEvents.append(
            .blurStroke(
                layerIndex: .unchecked(currentBlurStroke.layerIndex),
                brush: currentBlurStroke.brush,
                samples: currentBlurStroke.samples
            )
        )
        store.snapshot.revision += 1
        captureDirtyUpdate()
        self.currentBlurStroke = nil
    }

    func fill(sample: StylusSample, brush: BrushRuntimeSettings) -> DocumentMutationResult {
        let layerIndex = store.snapshot.activeLayerIndex
        guard validateEditableLayer(layerIndex) == nil else { return .failure(validateEditableLayer(layerIndex)!) }
        guard let payload = layers.fillPixels(
            pixelData: store.snapshot.layers[layerIndex].pixelData,
            sourceBufferHandle: gpuLayerHandles[layerIndex],
            canvasWidth: store.snapshot.canvasWidth,
            canvasHeight: store.snapshot.canvasHeight,
            sample: sample,
            brush: brush
        ) else {
            return .failure(.bridgeMutationFailed("fill"))
        }
        return applyLayerMutationPayload(
            index: layerIndex,
            payload: payload,
            timelapseEvent: .fill(layerIndex: .unchecked(layerIndex), brush: brush, sample: sample)
        )
    }

    func applySoftwareStroke(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int) -> DocumentMutationResult {
        guard !samples.isEmpty else { return .failure(.emptyInput) }
        guard validateEditableLayer(layerIndex) == nil else { return .failure(validateEditableLayer(layerIndex)!) }
        let gpuResult = strokes.executeStrokeMutation(
            PrimoMetalStrokeExecutionRequest(
                basePixelData: store.snapshot.layers[layerIndex].pixelData,
                baseBufferHandle: gpuLayerHandles[layerIndex],
                canvasWidth: store.snapshot.canvasWidth,
                canvasHeight: store.snapshot.canvasHeight,
                samples: samples,
                brush: brush,
                mode: .commit,
                snapshotRevision: store.snapshot.revision,
                activeLayerIndex: layerIndex
            )
        )
        guard let gpuResult else {
            return .failure(.bridgeMutationFailed("applyCommittedStroke"))
        }
        let dirtyRect = LayerPixelRect(
            originX: gpuResult.dirtyRect.originX,
            originY: gpuResult.dirtyRect.originY,
            width: gpuResult.dirtyRect.width,
            height: gpuResult.dirtyRect.height
        )
        let before = store.snapshot
        let existing = store.snapshot.layers[layerIndex].pixelData
        let adjustedOutput: Data
        let nextHandle: MetalBufferHandle?
        if store.snapshot.layers[layerIndex].alphaLocked {
            let committedOutput = gpuResult.gpuBufferHandle.flatMap {
                resources.materializedPixelData(for: $0)
            } ?? gpuResult.rectPixelData ?? Data()
            guard committedOutput.count == rgbaByteCount else {
                return .failure(.bridgeMutationFailed("applyCommittedStrokeMaterialization"))
            }
            adjustedOutput = preserveExistingAlphaIfNeeded(
                committedOutput,
                existing: existing,
                isAlphaLocked: true
            )
            nextHandle = nil
            resources.release(gpuResult.gpuBufferHandle)
        } else if let handle = gpuResult.gpuBufferHandle {
            adjustedOutput = existing
            nextHandle = handle
        } else {
            let committedOutput = gpuResult.rectPixelData ?? Data()
            guard committedOutput.count == rgbaByteCount else {
                return .failure(.bridgeMutationFailed("applyCommittedStrokeMaterialization"))
            }
            adjustedOutput = committedOutput
            nextHandle = nil
        }
        store.snapshot.layers[layerIndex].textLayer = nil
        setLayerPixelState(index: layerIndex, pixelData: adjustedOutput, gpuBufferHandle: nextHandle)
        invalidateThumbnail(for: layerIndex)
        recordMutation(
            before: before,
            timelapseEvent: .stroke(layerIndex: .unchecked(layerIndex), brush: brush, samples: samples),
            dirtyRect: dirtyRect
        )
        return .success(())
    }

    func saveProject(to url: URL, paperStyle: CanvasPaperStyle) throws {
        let persistenceService = services.persistence.projectStore
        try persistenceService.prepareProjectDirectory(at: url)
        let directories = try persistenceService.createProjectSubdirectories(
            in: url,
            usesOperationTimelapsePersistence: store.snapshot.timelapseUsesOperationPersistence
        )

        for index in store.snapshot.layers.indices {
            let filename = String(format: "layer-%04d.rgba", index)
            try persistenceService.writeAtomic(
                currentPixelData(for: index),
                to: directories.layersDirectory.appendingPathComponent(filename, isDirectory: false)
            )
            if let maskData = store.snapshot.layers[index].maskData {
                let maskFilename = String(format: "layer-mask-%04d.mask", index)
                try persistenceService.writeAtomic(
                    maskData,
                    to: directories.layersDirectory.appendingPathComponent(maskFilename, isDirectory: false)
                )
            }
        }

        if !store.snapshot.timelapseUsesOperationPersistence {
            for (index, frame) in store.snapshot.timelapseFrames.enumerated() {
                let relativeFilename = String(format: "frame-%06d.jpg", index)
                try persistenceService.replaceItemIfNeeded(
                    at: directories.timelapseDirectory.appendingPathComponent(relativeFilename, isDirectory: false),
                    with: frame.imageURL
                )
            }
        }

        let storedOperations = store.snapshot.timelapseUsesOperationPersistence
            ? try store.snapshot.timelapseEvents.enumerated().map {
                try $0.element.storedRepresentation(
                    index: $0.offset,
                    dataDirectory: directories.timelapseDataDirectory,
                    fileClient: services.fileIO
                )
            }
            : []

        let document = StoredPrimoDocument(
            version: 5,
            canvasWidth: store.snapshot.canvasWidth,
            canvasHeight: store.snapshot.canvasHeight,
            activeLayerIndex: DocumentLayerIndex.unchecked(store.snapshot.activeLayerIndex),
            paperStyle: StoredPrimoDocument.PaperStyle(
                red: Double(paperStyle.red),
                green: Double(paperStyle.green),
                blue: Double(paperStyle.blue),
                alpha: Double(paperStyle.alpha),
                isTransparent: paperStyle.isTransparent
            ),
            layers: store.snapshot.layers.enumerated().map { index, layer in
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
            folders: store.snapshot.folders.map {
                StoredPrimoDocument.Folder(
                    id: DocumentFolderID.unchecked($0.id),
                    name: $0.name,
                    visible: $0.visible,
                    expanded: $0.expanded,
                    anchorLayerIndex: $0.anchorLayerIndex.map { DocumentLayerIndex.unchecked($0) }
                )
            },
            timelapseFrames: store.snapshot.timelapseUsesOperationPersistence ? [] : store.snapshot.timelapseFrames.map {
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

    static func loadProject(
        from url: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) throws -> SwiftDocumentRuntime {
        let runtime = SwiftDocumentRuntime(
            width: 1,
            height: 1,
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
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
        let before = store.snapshot
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
            resources: resources,
            strokes: strokes,
            composites: composites,
            layers: layers,
            text: text
        )
        store.restore(newRuntime.store.snapshot)
        thumbnailSurfaceCache.removeAll(keepingCapacity: true)
        undoStack.removeAll(keepingCapacity: true)
        redoStack.removeAll(keepingCapacity: true)
        currentStroke = nil
        currentBlurStroke = nil
        captureDirtyUpdate()
    }

    func compositePNGData(paperStyle: CanvasPaperStyle) -> Data? {
        compositeExportSurface(paperStyle: paperStyle).flatMap(DocumentRasterImageService.pngData(from:))
    }

    func compositeExportSurface(paperStyle: CanvasPaperStyle) -> DocumentCompositeSurface? {
        let surface = compositeSurface()
        guard let pixelData = composites.compositedPaperPreviewRGBA(
            pixelData: surface.pixelData,
            width: surface.width,
            height: surface.height,
            paperStyle: paperStyle
        ) else {
            return nil
        }
        return DocumentCompositeSurface(width: surface.width, height: surface.height, pixelData: pixelData)
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
            _ = applySoftwareStroke(samples: samples, brush: brush, layerIndex: layerIndex.rawValue)
        case let .blurStroke(layerIndex, brush, samples):
            _ = blur(samples: samples, brush: brush, layerIndex: layerIndex.rawValue, captureTimelapse: false)
            endBlurStroke()
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
        case let .createFolder(folderID, name, anchorLayerIndex):
            let resolved = (try? createFolder(name: name, layerIndex: anchorLayerIndex?.rawValue ?? -1).get()) ?? -1
            folderIDMap[folderID] = resolved
        case let .deleteFolder(folderID):
            if let resolved = folderIDMap[folderID] { _ = deleteFolder(folderID: resolved) }
        case let .setFolderVisibility(folderID, isVisible):
            if let resolved = folderIDMap[folderID] { _ = setFolderVisibility(folderID: resolved, isVisible: isVisible) }
        case let .assignLayerToFolder(index, folderID):
            let resolvedFolderID = folderID.flatMap { folderIDMap[$0] } ?? -1
            _ = assignLayerToFolder(index: index.rawValue, folderID: resolvedFolderID)
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

    private func replaceLayerPixelsUnchecked(index: Int, data: Data, timelapseEvent: TimelapseOperation?) -> DocumentMutationResult {
        guard data.count == rgbaByteCount else {
            return .failure(.bridgeMutationFailed("replaceLayerPixels"))
        }
        let before = store.snapshot
        let adjusted = preserveExistingAlphaIfNeeded(
            data,
            existing: store.snapshot.layers[index].pixelData,
            isAlphaLocked: store.snapshot.layers[index].alphaLocked
        )
        setLayerPixelState(index: index, pixelData: adjusted, gpuBufferHandle: nil)
        store.snapshot.layers[index].textLayer = nil
        invalidateThumbnail(for: index)
        recordMutation(before: before, timelapseEvent: timelapseEvent)
        return .success(())
    }

    private func applyLayerMutationPayload(
        index: Int,
        payload: DocumentLayerMutationPayload,
        timelapseEvent: TimelapseOperation?
    ) -> DocumentMutationResult {
        guard payload.canvasWidth == store.snapshot.canvasWidth,
              payload.canvasHeight == store.snapshot.canvasHeight else {
            return .failure(.bridgeMutationFailed("applyLayerMutation"))
        }
        let before = store.snapshot
        let existing = store.snapshot.layers[index].pixelData
        let shouldMaterialize = store.snapshot.layers[index].alphaLocked || timelapseEvent?.requiresLayerPixelData == true
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
            resources.release(payload.gpuBufferHandle)
        }
        store.snapshot.layers[index].textLayer = nil
        invalidateThumbnail(for: index)
        recordMutation(
            before: before,
            timelapseEvent: timelapseEvent?.replacingLayerPixelData(with: adjusted),
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
            return .failure(.bridgeMutationFailed("applyTextLayerMutation"))
        }
        let before = store.snapshot
        setLayerPixelState(
            index: index,
            pixelData: materializedPixelData(from: payload, existing: store.snapshot.layers[index].pixelData),
            gpuBufferHandle: payload.gpuBufferHandle
        )
        store.snapshot.layers[index].textLayer = textLayer
        invalidateThumbnail(for: index)
        recordMutation(
            before: before,
            timelapseEvent: .replaceLayerPixels(index: .unchecked(index), data: payload.fullPixelData ?? store.snapshot.layers[index].pixelData),
            dirtyRect: payload.dirtyRect
        )
        return .success(())
    }

    private func materializedPixelData(from payload: DocumentLayerMutationPayload, existing: Data) -> Data {
        if let handle = payload.gpuBufferHandle,
           let gpuPixelData = resources.materializedPixelData(for: handle),
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
        let previousHandle = gpuLayerHandles[index]
        store.snapshot.layers[index].pixelData = pixelData
        if let gpuBufferHandle {
            gpuLayerHandles[index] = gpuBufferHandle
        } else {
            gpuLayerHandles.removeValue(forKey: index)
        }
        if previousHandle != gpuBufferHandle {
            resources.release(previousHandle)
        }
    }

    private func releaseLayerBufferHandles() {
        for handle in gpuLayerHandles.values {
            resources.release(handle)
        }
        gpuLayerHandles.removeAll(keepingCapacity: true)
    }

    private func currentPixelData(for index: Int) -> Data {
        guard store.snapshot.layers.indices.contains(index) else { return Data() }
        if let handle = gpuLayerHandles[index],
           let pixelData = resources.materializedPixelData(for: handle),
           pixelData.count == rgbaByteCount {
            return pixelData
        }
        return store.snapshot.layers[index].pixelData
    }

    private func recordMutation(
        before: SwiftDocumentStoreSnapshot,
        timelapseEvent: TimelapseOperation?,
        dirtyRect: LayerPixelRect? = nil
    ) {
        undoStack.append(before)
        redoStack.removeAll(keepingCapacity: true)
        if let timelapseEvent {
            store.snapshot.timelapseUsesOperationPersistence = true
            store.snapshot.timelapseEvents.append(timelapseEvent)
        }
        store.snapshot.revision += 1
        captureDirtyUpdate(rect: dirtyRect)
    }

    private func captureDirtyUpdate(rect: LayerPixelRect? = nil) {
        let rect = rect ?? LayerPixelRect(originX: 0, originY: 0, width: store.snapshot.canvasWidth, height: store.snapshot.canvasHeight)
        let snapshot = makeMetalSnapshot(for: store.snapshot, includeCompositePixelData: false)
        if let dirtyUpdate = composites.compositedIncrementalUpdate(
            snapshot: snapshot,
            dirtyRect: (rect.originX, rect.originY, rect.width, rect.height)
        ) {
            setPendingDirtyUpdate(dirtyUpdate)
            return
        }
        let composite = compositePixelDataForSnapshot(store.snapshot)
        let pixelData = crop(pixelData: composite, width: store.snapshot.canvasWidth, rect: rect)
        setPendingDirtyUpdate(IncrementalLayerUpdate(
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
            resources.release(previous)
        }
        pendingDirtyUpdate = update
    }

    private func compositeSurfaceForSnapshot(_ snapshot: SwiftDocumentStoreSnapshot) -> DocumentCompositeSurface {
        let metalSnapshot = makeMetalSnapshot(for: snapshot, includeCompositePixelData: false)
        if let gpuComposite = composites.compositeDocumentSurface(snapshot: metalSnapshot) {
            return gpuComposite
        }
        Self.logger.error("GPU composite failed for snapshot revision \(snapshot.revision, privacy: .public)")
        return DocumentCompositeSurface(
            width: snapshot.canvasWidth,
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
        let compositeHandle = composites.compositeDocumentBufferHandle(snapshot: baseSnapshot)
        let composite = compositeHandle == nil ? compositeSurface() : nil
        return MetalDocumentSnapshot(
            width: baseSnapshot.width,
            height: baseSnapshot.height,
            revision: baseSnapshot.revision,
            compositeBufferHandle: compositeHandle,
            compositePixelData: composite?.pixelData ?? Data(),
            layers: baseSnapshot.layers.enumerated().map { index, layer in
                MetalLayerSnapshot(
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
        MetalDocumentSnapshot(
            width: snapshot.canvasWidth,
            height: snapshot.canvasHeight,
            revision: snapshot.revision,
            compositePixelData: includeCompositePixelData ? compositePixelDataForSnapshot(snapshot) : Data(),
            layers: snapshot.layers.enumerated().map { index, layer in
                MetalLayerSnapshot(
                    index: index,
                    opacity: Float(layer.opacity),
                    visible: layer.visible && (layer.folderID == nil || (snapshot.folders.first(where: { $0.id == layer.folderID })?.visible ?? true)),
                    isClipped: layer.clipped,
                    blendMode: layer.blendMode,
                    thumbnailSurface: nil,
                    thumbnailData: nil,
                    gpuBufferHandle: gpuLayerHandles[index],
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
        guard let scaled = layers.scaledPixelData(
            store.snapshot.layers[index].pixelData,
            sourceWidth: store.snapshot.canvasWidth,
            sourceHeight: store.snapshot.canvasHeight,
            targetWidth: targetWidth,
            targetHeight: targetHeight
        ) else {
            return nil
        }
        let surface = DocumentCompositeSurface(
            width: targetWidth,
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
        guard let scaled = layers.scaledPixelData(
            source.pixelData,
            sourceWidth: source.width,
            sourceHeight: source.height,
            targetWidth: max(Int(targetSize.width.rounded()), 1),
            targetHeight: max(Int(targetSize.height.rounded()), 1)
        ) else {
            return nil
        }
        return DocumentCompositeSurface(
            width: max(Int(targetSize.width.rounded()), 1),
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

private extension TimelapseOperation {
    var requiresLayerPixelData: Bool {
        if case .replaceLayerPixels = self {
            return true
        }
        return false
    }

    func replacingLayerPixelData(with data: Data) -> TimelapseOperation {
        switch self {
        case let .replaceLayerPixels(index, _):
            return .replaceLayerPixels(index: index, data: data)
        default:
            return self
        }
    }
}
