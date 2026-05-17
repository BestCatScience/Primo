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
import PrimoDocumentPersistenceInfrastructure
import PrimoDocumentStrokeInfrastructure
import PrimoDocumentTimelapseInfrastructure
import PrimoSystemClients

struct RuntimeLayerProcessingPlan: Sendable {
    let index: Int
    let request: LayerProcessingRequest
    let documentGeneration: UUID
    let revision: Int
    let canvasWidth: Int
    let canvasHeight: Int
    let pixelData: Data
    let gpuServices: DocumentRuntimeGpuServices
}

struct RuntimeFillPlan: Sendable {
    let layerIndex: Int
    let documentGeneration: UUID
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
    let sessionID: UUID?
    let layerIndex: Int
    let documentGeneration: UUID
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

enum RuntimeStrokeCommitPlanOutcome: Sendable {
    case commit(RuntimeStrokeCommitPlan)
    case noCurrentStroke
}

struct RuntimeBlurPlan: Sendable {
    let sessionID: UUID?
    let layerIndex: Int
    let documentGeneration: UUID
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

/// @unchecked Sendable: the retained handle is immutable after init and released exactly once in deinit through a `@Sendable` release closure.
/// Concurrency test: gpuResourceLeaseRetainsAndReleasesThroughInjectedGpuServices
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

/// @unchecked Sendable: live runtime access is serialized by `LockedDocumentRuntimeExecutor`; the runtime keeps mutable collaborators private.
/// Concurrency test: uncheckedSendableRuntimeCollaboratorsStayExecutorConfined
final class SwiftDocumentRuntime: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.primo.app", category: "SwiftDocumentRuntime")

    private let services: DocumentEngineServices
    private let gpuServices: DocumentRuntimeGpuServices
    private let store: SwiftDocumentStore
    private var undoHistory: UndoHistoryCoordinator
    private var strokeCoordinator = StrokeCommitCoordinator()
    private let presentationBuilder = DocumentPresentationBuilder()
    private let dirtyUpdatePublisher = DirtyUpdatePublisher()
    private var gpuLayerRepository = GpuLayerRepository()
    private let timelapseRecorder = TimelapseRecorder()
    private let documentGeneration = UUID()

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
        self.undoHistory = UndoHistoryCoordinator(
            maxUndoEntryCount: maxUndoEntryCount,
            maxUndoRetainedBytes: maxUndoRetainedBytes
        )
        captureDirtyUpdate()
    }

    var currentPaperStyle: CanvasPaperStyle {
        store.snapshot.paperStyle
    }

    func lightweightPresentation() -> PaintDocumentPresentation {
        presentationBuilder.lightweightPresentation(
            snapshot: store.validatedSnapshot(),
            canvasSize: canvasSize
        )
    }

    func presentation() -> PaintDocumentPresentation {
        presentationBuilder.presentation(
            snapshot: store.validatedSnapshot(),
            canvasSize: canvasSize,
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
        dirtyUpdatePublisher.consumeDirtyUpdate()
    }

    func pixelDataForLayer(index: Int) -> Result<Data, DocumentMutationFailure> {
        guard store.snapshot.layers.indices.contains(index) else { return .failure(.invalidLayerIndex(index)) }
        return .success(currentPixelData(for: index))
    }

    func materializedSnapshot() -> SwiftDocumentStoreSnapshot {
        var snapshot = store.snapshot
        guard let geometry = snapshot.pixelGeometry else {
            return snapshot
        }
        for index in snapshot.layers.indices {
            snapshot.layers[index].replacePixelData(currentPixelData(for: index), geometry: geometry)
        }
        return snapshot
    }

    private func undoSnapshot() -> SwiftDocumentStoreSnapshot {
        gpuBackedMaterializedSnapshot()
    }

    private func gpuBackedMaterializedSnapshot() -> SwiftDocumentStoreSnapshot {
        gpuLayerRepository.materializedSnapshot(
            from: store.snapshot,
            rgbaByteCount: rgbaByteCount,
            services: gpuServices
        )
    }

    private func materializeGpuBackedLayerPixels() {
        gpuLayerRepository.materializeGpuBackedLayerPixels(
            in: store,
            rgbaByteCount: rgbaByteCount,
            services: gpuServices
        )
    }

    func canUndo() -> Bool {
        undoHistory.canUndo
    }

    func canRedo() -> Bool {
        undoHistory.canRedo
    }

    func undo() -> DocumentMutationResult {
        let currentRevision = store.snapshot.revision
        let previous: SwiftDocumentStoreSnapshot
        switch undoHistory.restoreUndo(current: undoSnapshot()) {
        case let .success(snapshot):
            previous = snapshot
        case let .failure(failure):
            return .failure(failure)
        }
        guard store.restore(previous) else {
            return .failure(.inconsistentComposition(operation: "undo", reason: "invalid snapshot"))
        }
        presentationBuilder.clearThumbnailSurfaces()
        releaseLayerBufferHandles()
        timelapseRecorder.record(.undo, in: store)
        guard store.update({
            $0.revision = max(currentRevision, $0.revision) + 1
            return true
        }) else {
            return .failure(.inconsistentComposition(operation: "undo", reason: "revision update failed"))
        }
        captureDirtyUpdate()
        return .success(())
    }

    func redo() -> DocumentMutationResult {
        let currentRevision = store.snapshot.revision
        let next: SwiftDocumentStoreSnapshot
        switch undoHistory.restoreRedo(current: undoSnapshot()) {
        case let .success(snapshot):
            next = snapshot
        case let .failure(failure):
            return .failure(failure)
        }
        guard store.restore(next) else {
            return .failure(.inconsistentComposition(operation: "redo", reason: "invalid snapshot"))
        }
        presentationBuilder.clearThumbnailSurfaces()
        releaseLayerBufferHandles()
        timelapseRecorder.record(.redo, in: store)
        guard store.update({
            $0.revision = max(currentRevision, $0.revision) + 1
            return true
        }) else {
            return .failure(.inconsistentComposition(operation: "redo", reason: "revision update failed"))
        }
        captureDirtyUpdate()
        return .success(())
    }

    func trimUndoHistoryForMemoryPressure() {
        let stats = undoHistory.trimForMemoryPressure()
        logUndoHistoryStats(stats, reason: "memoryPressure")
    }

    func resizeCanvas(width: Int, height: Int) -> DocumentMutationResult {
        switch makeResizeCanvasPlan(width: width, height: height) {
        case let .failure(failure):
            return .failure(failure)
        case .success(.noResizeNeeded):
            return .success(())
        case let .success(.resize(plan)):
            guard let layers = plan.resizedLayers() else {
                return .failure(.rawAPIUnavailable(operation: "resizeCanvas"))
            }
            return applyResizeCanvasPlan(plan, layers: layers)
        }
    }

    func resizeCanvasExtent(width: Int, height: Int) -> DocumentMutationResult {
        switch makeResizeCanvasExtentPlan(width: width, height: height) {
        case let .failure(failure):
            return .failure(failure)
        case .success(.noResizeNeeded):
            return .success(())
        case let .success(.resize(plan)):
            guard let layers = plan.resizedLayers() else {
                return .failure(.rawAPIUnavailable(operation: "resizeCanvasExtent"))
            }
            return applyResizeCanvasPlan(plan, layers: layers)
        }
    }

    func makeResizeCanvasPlan(width: Int, height: Int) -> Result<RuntimeResizeCanvasPlanOutcome, DocumentMutationFailure> {
        makeResizeCanvasPlan(width: width, height: height, mode: .scale)
    }

    func makeResizeCanvasExtentPlan(width: Int, height: Int) -> Result<RuntimeResizeCanvasPlanOutcome, DocumentMutationFailure> {
        makeResizeCanvasPlan(width: width, height: height, mode: .extent)
    }

    private func makeResizeCanvasPlan(
        width: Int,
        height: Int,
        mode: RuntimeResizeCanvasPlan.Mode
    ) -> Result<RuntimeResizeCanvasPlanOutcome, DocumentMutationFailure> {
        CanvasResizeCoordinator.makeResizeCanvasPlan(
            width: width,
            height: height,
            mode: mode,
            snapshot: store.snapshot,
            beforeSnapshot: { undoSnapshot() },
            documentGeneration: documentGeneration,
            gpuServices: gpuServices
        )
    }

    func applyResizeCanvasPlan(
        _ plan: RuntimeResizeCanvasPlan,
        layers: [SwiftDocumentLayerRecord]
    ) -> DocumentMutationResult {
        let result = CanvasResizeCoordinator.applyResizeCanvasPlan(
            plan,
            layers: layers,
            documentGeneration: documentGeneration,
            store: store
        )
        guard case .success = result else {
            return result
        }
        presentationBuilder.clearThumbnailSurfaces()
        releaseLayerBufferHandles()
        recordMutation(before: plan.before, timelapseEvent: nil)
        return .success(())
    }

    func addLayer(name: String) -> DocumentCreatedLayerMutationResult {
        let before = undoSnapshot()
        guard let geometry = store.snapshot.pixelGeometry,
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
            geometry: geometry,
            pixelData: Data(count: geometry.rgbaByteCount),
            maskData: nil
              ) else {
            return .failure(.inconsistentComposition(operation: "addLayer", reason: "invalid store geometry"))
        }
        var insertedIndex: Int?
        guard store.update({ snapshot in
            snapshot.layers.append(layer)
            let index = snapshot.layers.count - 1
            snapshot.activeLayerIndex = index
            insertedIndex = index
            return true
        }), let index = insertedIndex else {
            return .failure(.rawAPIUnavailable(operation: "addLayer"))
        }
        materializeGpuBackedLayerPixels()
        releaseLayerBufferHandles()
        recordMutation(before: before, timelapseEvent: .addLayer(name: name))
        return .success(DocumentCreatedLayerIndex(index))
    }

    func setActiveLayer(index: Int) -> DocumentMutationResult {
        guard store.snapshot.layers.indices.contains(index) else {
            return .failure(.invalidLayerIndex(index))
        }
        guard store.update({
            $0.activeLayerIndex = index
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "setActiveLayer"))
        }
        return .success(())
    }

    func setLayerName(index: Int, name: String) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        let before = undoSnapshot()
        guard store.update({
            $0.layers[index].name = name
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "setLayerName"))
        }
        recordMutation(before: before, timelapseEvent: .setLayerName(index: .unchecked(index), name: name))
        return .success(())
    }

    func setLayerVisibility(index: Int, isVisible: Bool) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        guard store.snapshot.layers[index].visible != isVisible else {
            return .success(())
        }
        let before = undoSnapshot()
        guard store.update({
            $0.layers[index].visible = isVisible
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "setLayerVisibility"))
        }
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
        let payloadLease = GpuMutationPayloadLease(handle: payload.gpuBufferHandle, services: gpuServices)
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
                recordsFinalLayerPixels: layer.alphaLocked,
                incomingPayloadLease: payloadLease
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
            return .failure(.rawAPIUnavailable(operation: "replaceLayerMask"))
        }
        guard let geometry = store.snapshot.pixelGeometry,
              LayerMaskBuffer(geometry: geometry, data: data) != nil else {
            return .failure(.rawAPIUnavailable(operation: "replaceLayerMask"))
        }
        let before = undoSnapshot()
        guard store.update({
            $0.layers[index].replaceMaskData(data, geometry: geometry)
        }) else {
            return .failure(.rawAPIUnavailable(operation: "replaceLayerMask"))
        }
        invalidateThumbnail(for: index)
        recordMutation(before: before, timelapseEvent: .replaceLayerMask(index: .unchecked(index), data: data))
        return .success(())
    }

    func clearLayerMask(index: Int) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        guard store.snapshot.layers[index].maskData != nil else { return .success(()) }
        let before = undoSnapshot()
        guard let geometry = store.snapshot.pixelGeometry,
              store.update({
                  $0.layers[index].replaceMaskData(nil, geometry: geometry)
              }) else {
            return .failure(.rawAPIUnavailable(operation: "clearLayerMask"))
        }
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
            guard let geometry = store.snapshot.pixelGeometry,
                  store.update({
                      $0.layers[index].replaceMaskData(nil, geometry: geometry)
                  }) else {
                return .failure(.rawAPIUnavailable(operation: "applyLayerMask"))
            }
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
                documentGeneration: documentGeneration,
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
        let payloadLease = GpuMutationPayloadLease(handle: payload.gpuBufferHandle, services: gpuServices)
        guard store.snapshot.revision == plan.revision,
              documentGeneration == plan.documentGeneration,
              store.snapshot.canvasWidth == plan.canvasWidth,
              store.snapshot.canvasHeight == plan.canvasHeight else {
            return .failure(.gpu(.staleSnapshot(operation: "applyLayerProcessing")))
        }
        if let failure = validateEditableLayer(plan.index) {
            return .failure(failure)
        }
        return applyLayerMutationPayload(
            index: plan.index,
            payload: payload,
            timelapseEvent: nil,
            recordsFinalLayerPixels: true,
            incomingPayloadLease: payloadLease
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
                documentGeneration: documentGeneration,
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
        let payloadLease = GpuMutationPayloadLease(handle: payload.gpuBufferHandle, services: gpuServices)
        guard store.snapshot.revision == plan.revision,
              documentGeneration == plan.documentGeneration,
              store.snapshot.canvasWidth == plan.canvasWidth,
              store.snapshot.canvasHeight == plan.canvasHeight else {
            return .failure(.gpu(.staleSnapshot(operation: "fill")))
        }
        if let failure = validateEditableLayer(plan.layerIndex) {
            return .failure(failure)
        }
        return applyLayerMutationPayload(
            index: plan.layerIndex,
            payload: payload,
            timelapseEvent: .fill(layerIndex: .unchecked(plan.layerIndex), brush: plan.brush, sample: plan.sample),
            incomingPayloadLease: payloadLease
        )
    }

    func makeStrokeCommitPlan(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        layerIndex: Int,
        sessionID: UUID? = nil
    ) -> Result<RuntimeStrokeCommitPlan, DocumentMutationFailure> {
        guard !samples.isEmpty else { return .failure(.emptyInput) }
        if let failure = validateEditableLayer(layerIndex) { return .failure(failure) }
        let source = layerSourceForGpuPlan(index: layerIndex)
        return .success(
            RuntimeStrokeCommitPlan(
                sessionID: sessionID,
                layerIndex: layerIndex,
                documentGeneration: documentGeneration,
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
        let payloadLease = GpuMutationPayloadLease(handle: gpuResult.gpuBufferHandle, services: gpuServices)
        guard store.snapshot.revision == plan.revision,
              documentGeneration == plan.documentGeneration,
              store.snapshot.canvasWidth == plan.canvasWidth,
              store.snapshot.canvasHeight == plan.canvasHeight else {
            return .failure(.gpu(.staleSnapshot(operation: "applyCommittedStroke")))
        }
        if let failure = validateEditableLayer(plan.layerIndex) {
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
            if let sourceHandle = payloadLease.borrowedHandle {
                guard let alphaPreservedHandle = gpuServices.preservingExistingAlphaBufferHandle(
                    sourceHandle: sourceHandle,
                    existingHandle: nil,
                    existingPixelData: existing,
                    width: store.snapshot.canvasWidth,
                    height: store.snapshot.canvasHeight
                ) else {
                    return .failure(.gpu(.kernelFailed(operation: "applyCommittedStrokeAlphaPreserve")))
                }
                adjustedOutput = existing
                nextHandle = alphaPreservedHandle
                if alphaPreservedHandle == sourceHandle {
                    _ = payloadLease.adoptHandle()
                } else {
                    payloadLease.releaseNow()
                }
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
        } else if let handle = payloadLease.adoptHandle() {
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
        guard updateLayerTextLayer(index: plan.layerIndex, textLayer: nil) else {
            gpuServices.release(nextHandle)
            return .failure(.inconsistentComposition(operation: "applyCommittedStroke", reason: "target layer is text"))
        }
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
        let source = layerSourceForGpuPlan(index: layerIndex)
        return .success(
            RuntimeBlurPlan(
                sessionID: strokeCoordinator.blurStrokeState?.id,
                layerIndex: layerIndex,
                documentGeneration: documentGeneration,
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

    func reserveBlurSession(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        layerIndex: Int
    ) -> Result<StrokeCommitCoordinator.BlurSessionReservation, DocumentMutationFailure> {
        guard !samples.isEmpty else { return .failure(.emptyInput) }
        if let failure = validateEditableLayer(layerIndex) { return .failure(failure) }
        let baseline = strokeCoordinator.blurStrokeState?.baseline ?? undoSnapshot()
        return .success(
            strokeCoordinator.beginOrAppendBlur(
                baseline: baseline,
                layerIndex: layerIndex,
                brush: brush,
                samples: samples
            )
        )
    }

    func rollbackBlurSessionReservation(_ reservation: StrokeCommitCoordinator.BlurSessionReservation) {
        strokeCoordinator.rollbackBlurReservation(reservation)
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
        let payloadLease = GpuMutationPayloadLease(handle: payload.gpuBufferHandle, services: gpuServices)
        guard store.snapshot.revision == plan.revision,
              documentGeneration == plan.documentGeneration,
              store.snapshot.canvasWidth == plan.canvasWidth,
              store.snapshot.canvasHeight == plan.canvasHeight else {
            return .failure(.gpu(.staleSnapshot(operation: "blurStroke")))
        }
        if let sessionID = plan.sessionID, strokeCoordinator.blurStrokeState?.id != sessionID {
            return .failure(.gpu(.staleSnapshot(operation: "blurStroke")))
        }
        if let failure = validateEditableLayer(plan.layerIndex) {
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
            payloadLease.releaseNow()
        } else if let handle = payloadLease.adoptHandle() {
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
        guard updateLayerTextLayer(index: plan.layerIndex, textLayer: nil) else {
            gpuServices.release(nextHandle)
            return .failure(.inconsistentComposition(operation: "blurStroke", reason: "target layer is text"))
        }
        invalidateThumbnail(for: plan.layerIndex)
        captureDirtyUpdate(rect: payload.dirtyRect)
        if plan.captureTimelapse {
            captureTimelapseFrame()
        }
        return .success(())
    }

    func currentStrokeCommitPlan() -> Result<RuntimeStrokeCommitPlanOutcome, DocumentMutationFailure> {
        guard let currentStroke = strokeCoordinator.currentStrokePlanInput() else { return .success(.noCurrentStroke) }
        return makeStrokeCommitPlan(
            samples: currentStroke.samples,
            brush: currentStroke.brush,
            layerIndex: currentStroke.layerIndex,
            sessionID: currentStroke.id
        ).map(RuntimeStrokeCommitPlanOutcome.commit)
    }

    func clearCurrentStroke(sessionID: UUID? = nil) {
        strokeCoordinator.clearCurrentStroke(id: sessionID)
    }

    func release(_ handle: MetalBufferHandle?) {
        gpuServices.release(handle)
    }

    func duplicateLayer(index: Int, name: String) -> DocumentCreatedLayerMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        guard let geometry = store.snapshot.pixelGeometry else {
            return .failure(.inconsistentComposition(operation: "duplicateLayer", reason: "invalid store geometry"))
        }
        let before = undoSnapshot()
        var layer = store.snapshot.layers[index]
        guard layer.replacePixelData(currentPixelData(for: index), geometry: geometry) else {
            return .failure(.inconsistentComposition(operation: "duplicateLayer", reason: "invalid pixel data"))
        }
        layer.name = name
        let duplicatedIndex = index + 1
        guard store.update({
            $0.layers.insert(layer, at: duplicatedIndex)
            $0.activeLayerIndex = duplicatedIndex
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "duplicateLayer"))
        }
        remapFoldersAfterInsertion(at: duplicatedIndex)
        materializeGpuBackedLayerPixels()
        releaseLayerBufferHandles()
        recordMutation(before: before, timelapseEvent: .duplicateLayer(index: .unchecked(index), name: name))
        return .success(DocumentCreatedLayerIndex(duplicatedIndex))
    }

    func deleteLayer(index: Int) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        guard store.snapshot.layers.count > 1 else { return .failure(.rawAPIUnavailable(operation: "deleteLayer")) }
        let before = undoSnapshot()
        guard deleteLayerUnchecked(index: index) else {
            return .failure(.rawAPIUnavailable(operation: "deleteLayer"))
        }
        recordMutation(before: before, timelapseEvent: .deleteLayer(index: .unchecked(index)))
        return .success(())
    }

    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        if let failure = validateLayer(destinationIndex) { return .failure(failure) }
        guard index != destinationIndex else { return .success(()) }
        let before = undoSnapshot()
        materializeGpuBackedLayerPixels()
        let movedLayerWasActive = store.snapshot.activeLayerIndex == index
        guard store.update({ snapshot in
            let layer = snapshot.layers.remove(at: index)
            snapshot.layers.insert(layer, at: destinationIndex)
            if movedLayerWasActive {
                snapshot.activeLayerIndex = destinationIndex
            }
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "moveLayer"))
        }
        remapFoldersAfterMove(from: index, to: destinationIndex)
        invalidateAllThumbnails()
        releaseLayerBufferHandles()
        recordMutation(before: before, timelapseEvent: .moveLayer(index: .unchecked(index), destinationIndex: .unchecked(destinationIndex)))
        return .success(())
    }

    func createFolder(name: String, anchorLayerIndex: LayerAnchorIndex) -> DocumentCreatedFolderMutationResult {
        createFolder(name: name, anchorLayerIndex: anchorLayerIndex.rawValue)
    }

    private func createFolder(name: String, anchorLayerIndex: Int?) -> DocumentCreatedFolderMutationResult {
        if let anchorLayerIndex, !store.snapshot.layers.indices.contains(anchorLayerIndex) {
            return .failure(.invalidLayerIndex(anchorLayerIndex))
        }
        let before = undoSnapshot()
        let id = store.snapshot.nextFolderID
        guard store.update({
            $0.nextFolderID += 1
            $0.folders.append(
                SwiftDocumentFolderRecord(
                    id: id,
                    name: name,
                    visible: true,
                    expanded: true,
                    anchorLayerIndex: anchorLayerIndex
                )
            )
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "createFolder"))
        }
        recordMutation(
            before: before,
            timelapseEvent: .createFolder(
                folderID: .unchecked(id),
                name: name,
                anchorLayerIndex: anchorLayerIndex.map { .unchecked($0) }
            )
        )
        return .success(DocumentCreatedFolderID(id))
    }

    func deleteFolder(folderID: Int) -> DocumentMutationResult {
        guard let folderIndex = store.snapshot.folders.firstIndex(where: { $0.id == folderID }) else {
            return .failure(.invalidFolderID(folderID))
        }
        let before = undoSnapshot()
        guard store.update({ snapshot in
            snapshot.folders.remove(at: folderIndex)
            for index in snapshot.layers.indices where snapshot.layers[index].folderID == folderID {
                snapshot.layers[index].folderID = nil
            }
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "deleteFolder"))
        }
        recordMutation(before: before, timelapseEvent: .deleteFolder(folderID: .unchecked(folderID)))
        return .success(())
    }

    func setFolderVisibility(folderID: Int, isVisible: Bool) -> DocumentMutationResult {
        guard let folderIndex = store.snapshot.folders.firstIndex(where: { $0.id == folderID }) else {
            return .failure(.invalidFolderID(folderID))
        }
        let before = undoSnapshot()
        guard store.update({
            $0.folders[folderIndex].visible = isVisible
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "setFolderVisibility"))
        }
        recordMutation(before: before, timelapseEvent: .setFolderVisibility(folderID: .unchecked(folderID), isVisible: isVisible))
        return .success(())
    }

    func setFolderName(folderID: Int, name: String) -> DocumentMutationResult {
        guard let folderIndex = store.snapshot.folders.firstIndex(where: { $0.id == folderID }) else {
            return .failure(.invalidFolderID(folderID))
        }
        let before = undoSnapshot()
        guard store.update({
            $0.folders[folderIndex].name = name
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "setFolderName"))
        }
        recordMutation(before: before, timelapseEvent: .setFolderName(folderID: .unchecked(folderID), name: name))
        return .success(())
    }

    func setFolderExpanded(folderID: Int, isExpanded: Bool) -> DocumentMutationResult {
        guard let folderIndex = store.snapshot.folders.firstIndex(where: { $0.id == folderID }) else {
            return .failure(.invalidFolderID(folderID))
        }
        let before = undoSnapshot()
        guard store.update({
            $0.folders[folderIndex].expanded = isExpanded
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "setFolderExpanded"))
        }
        recordMutation(before: before, timelapseEvent: .setFolderExpanded(folderID: .unchecked(folderID), isExpanded: isExpanded))
        return .success(())
    }

    func assignLayerToFolder(index: ExistingLayerIndex, folderID: ExistingFolderID?) -> DocumentMutationResult {
        assignLayerToFolder(index: index.rawValue, folderID: folderID?.rawValue)
    }

    private func assignLayerToFolder(index: Int, folderID: Int?) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        if let folderID, !store.snapshot.folders.contains(where: { $0.id == folderID }) {
            return .failure(.invalidFolderID(folderID))
        }
        let before = undoSnapshot()
        guard store.update({
            $0.layers[index].folderID = folderID
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "assignLayerToFolder"))
        }
        recordMutation(
            before: before,
            timelapseEvent: .assignLayerToFolder(
                index: .unchecked(index),
                folderID: folderID.map { .unchecked($0) }
            )
        )
        return .success(())
    }

    func setLayerLocked(index: Int, isLocked: Bool) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        let before = undoSnapshot()
        guard store.update({
            $0.layers[index].locked = isLocked
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "setLayerLocked"))
        }
        recordMutation(before: before, timelapseEvent: .setLayerLocked(index: .unchecked(index), isLocked: isLocked))
        return .success(())
    }

    func setLayerAlphaLocked(index: Int, isAlphaLocked: Bool) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        let before = undoSnapshot()
        guard store.update({
            $0.layers[index].alphaLocked = isAlphaLocked
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "setLayerAlphaLocked"))
        }
        recordMutation(before: before, timelapseEvent: .setLayerAlphaLocked(index: .unchecked(index), isAlphaLocked: isAlphaLocked))
        return .success(())
    }

    func setLayerClipped(index: Int, isClipped: Bool) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        let before = undoSnapshot()
        guard store.update({
            $0.layers[index].clipped = isClipped
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "setLayerClipped"))
        }
        recordMutation(before: before, timelapseEvent: .setLayerClipped(index: .unchecked(index), isClipped: isClipped))
        return .success(())
    }

    func setLayerOpacity(index: Int, opacity: Double) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        guard DocumentLayerOpacity(opacity) != nil else { return .failure(.invalidOpacity(opacity)) }
        let before = undoSnapshot()
        guard store.update({
            $0.layers[index].setOpacity(opacity)
        }) else {
            return .failure(.rawAPIUnavailable(operation: "setLayerOpacity"))
        }
        recordMutation(before: before, timelapseEvent: .setLayerOpacity(index: .unchecked(index), opacity: opacity))
        return .success(())
    }

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) -> DocumentMutationResult {
        if let failure = validateLayer(index) { return .failure(failure) }
        let before = undoSnapshot()
        guard store.update({
            $0.layers[index].blendMode = blendMode
            return true
        }) else {
            return .failure(.rawAPIUnavailable(operation: "setLayerBlendMode"))
        }
        recordMutation(before: before, timelapseEvent: .setLayerBlendMode(index: .unchecked(index), blendMode: blendMode))
        return .success(())
    }

    func mergeLayerDown(index: Int) -> DocumentMutationResult {
        guard index > 0 else { return .failure(.invalidLayerIndex(index)) }
        if let failure = validateEditableLayer(index) { return .failure(failure) }
        if let failure = validateEditableLayer(index - 1) { return .failure(failure) }
        guard let geometry = store.snapshot.pixelGeometry else {
            return .failure(.inconsistentComposition(operation: "mergeLayerDown", reason: "invalid store geometry"))
        }
        var upper = store.snapshot.layers[index]
        guard upper.replacePixelData(currentPixelData(for: index), geometry: geometry) else {
            return .failure(.inconsistentComposition(operation: "mergeLayerDown", reason: "invalid upper pixels"))
        }
        var lower = store.snapshot.layers[index - 1]
        guard lower.replacePixelData(currentPixelData(for: index - 1), geometry: geometry) else {
            return .failure(.inconsistentComposition(operation: "mergeLayerDown", reason: "invalid lower pixels"))
        }
        guard let merged = gpuServices.mergeLayers(
            lowerPixelData: lower.pixelData,
            upperPixelData: upper.pixelData,
            upperMaskData: upper.maskData,
            canvasWidth: store.snapshot.canvasWidth,
            canvasHeight: store.snapshot.canvasHeight,
            upperOpacity: Float(upper.opacity),
            upperBlendMode: upper.blendMode
        ) else {
            return .failure(.rawAPIUnavailable(operation: "mergeLayerDown"))
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
        guard updateLayerTextLayer(index: index - 1, textLayer: nil),
              deleteLayerUnchecked(index: index) else {
            return .failure(.rawAPIUnavailable(operation: "mergeLayerDown"))
        }
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
            return .failure(.rawAPIUnavailable(operation: "setTextLayer"))
        }
        return applyTextLayerMutationPayload(index: index, textLayer: textLayer, payload: payload)
    }

    func clearTextLayerData(index: Int) {
        guard store.snapshot.layers.indices.contains(index) else { return }
        updateLayerTextLayer(index: index, textLayer: nil)
    }

    func beginStroke(sample: StylusSample, brush: BrushRuntimeSettings) {
        strokeCoordinator.beginStroke(layerIndex: store.snapshot.activeLayerIndex, sample: sample, brush: brush)
    }

    func appendStroke(sample: StylusSample) {
        strokeCoordinator.appendStroke(sample: sample)
    }

    func endStroke() -> DocumentMutationResult {
        switch currentStrokeCommitPlan() {
        case let .failure(failure):
            return .failure(failure)
        case .success(.noCurrentStroke):
            return .success(())
        case let .success(.commit(plan)):
            guard let result = strokeCommitResult(for: plan) else {
                return .failure(.rawAPIUnavailable(operation: "applyCommittedStroke"))
            }
            let mutationResult = applyStrokeCommitPlan(plan, gpuResult: result)
            if case .success = mutationResult {
                clearCurrentStroke()
            }
            return mutationResult
        }
    }

    func cancelStroke() {
        strokeCoordinator.cancelStroke()
    }

    func cancelBlurStroke() {
        guard let baseline = strokeCoordinator.blurStrokeState?.baseline else {
            strokeCoordinator.clearBlurStroke()
            return
        }
        let currentRevision = store.snapshot.revision
        releaseLayerBufferHandles()
        guard store.restore(baseline) else {
            strokeCoordinator.clearBlurStroke()
            return
        }
        presentationBuilder.clearThumbnailSurfaces()
        _ = store.update {
            $0.revision = max(currentRevision, $0.revision) + 1
            return true
        }
        captureDirtyUpdate()
        strokeCoordinator.clearBlurStroke()
    }

    func blur(samples: [StylusSample], brush: BrushRuntimeSettings, layerIndex: Int, captureTimelapse: Bool) -> DocumentMutationResult {
        let reservation: StrokeCommitCoordinator.BlurSessionReservation
        switch reserveBlurSession(samples: samples, brush: brush, layerIndex: layerIndex) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(success):
            reservation = success
        }
        switch makeBlurPlan(samples: samples, brush: brush, layerIndex: layerIndex, captureTimelapse: captureTimelapse) {
        case let .failure(failure):
            rollbackBlurSessionReservation(reservation)
            return .failure(failure)
        case let .success(plan):
            guard let payload = blurPayload(for: plan) else {
                rollbackBlurSessionReservation(reservation)
                return .failure(.rawAPIUnavailable(operation: "blurStroke"))
            }
            let result = applyBlurPlan(plan, payload: payload)
            if case .failure = result {
                rollbackBlurSessionReservation(reservation)
            }
            return result
        }
    }

    func endBlurStroke() -> DocumentMutationResult {
        guard let currentBlurStroke = strokeCoordinator.blurStrokeState,
              let baseline = currentBlurStroke.baseline
        else {
            return .failure(.inconsistentComposition(operation: "endBlurStroke", reason: "missing baseline"))
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
        strokeCoordinator.clearBlurStroke()
        return .success(())
    }

    func fill(sample: StylusSample, brush: BrushRuntimeSettings) -> DocumentMutationResult {
        switch makeFillPlan(sample: sample, brush: brush) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(plan):
            guard let payload = fillPayload(for: plan) else {
                return .failure(.rawAPIUnavailable(operation: "fill"))
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
                return .failure(.rawAPIUnavailable(operation: "applyCommittedStroke"))
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
        DocumentSnapshotMaterializer.compositeSurface(
            forMaterializedSnapshot: snapshot,
            gpuServices: gpuServices,
            logger: logger
        )
    }

    static func compositeExportSurface(
        forMaterializedSnapshot snapshot: SwiftDocumentStoreSnapshot,
        paperStyle: CanvasPaperStyle,
        gpuServices: DocumentRuntimeGpuServices
    ) -> DocumentCompositeSurface? {
        DocumentSnapshotMaterializer.compositeExportSurface(
            forMaterializedSnapshot: snapshot,
            paperStyle: paperStyle,
            gpuServices: gpuServices,
            logger: logger
        )
    }

    static func compositePNGData(
        forMaterializedSnapshot snapshot: SwiftDocumentStoreSnapshot,
        paperStyle: CanvasPaperStyle,
        gpuServices: DocumentRuntimeGpuServices
    ) -> Data? {
        DocumentSnapshotMaterializer.compositePNGData(
            forMaterializedSnapshot: snapshot,
            paperStyle: paperStyle,
            gpuServices: gpuServices,
            logger: logger
        )
    }

    private static func materializedMetalSnapshot(
        for snapshot: SwiftDocumentStoreSnapshot
    ) -> MetalDocumentSnapshot {
        DocumentSnapshotMaterializer.materializedMetalSnapshot(for: snapshot)
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
        guard let geometry = PixelGeometry(width: document.canvasWidth, height: document.canvasHeight),
              !document.layers.isEmpty else {
            throw PrimoDocumentError.invalidDocument
        }

        let sortedLayers = document.layers.sorted { $0.index.rawValue < $1.index.rawValue }
        let expectedLayerBytes = geometry.rgbaByteCount
        let expectedMaskBytes = geometry.maskByteCount
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
            guard let layerRecord = SwiftDocumentLayerRecord(
                name: layer.name,
                visible: layer.visible,
                locked: layer.locked,
                alphaLocked: layer.alphaLocked,
                clipped: layer.clipped,
                opacity: layer.opacity,
                blendMode: LayerBlendMode(rawValue: layer.blendMode) ?? .normal,
                folderID: layer.folderID?.rawValue,
                textLayer: layer.textLayer,
                geometry: geometry,
                pixelData: pixelData,
                maskData: maskData
                  ) else {
                throw PrimoDocumentError.invalidDocument
            }
            return layerRecord
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
        guard let loadedSnapshot = SwiftDocumentStoreSnapshot(
                canvasWidth: document.canvasWidth,
                canvasHeight: document.canvasHeight,
                activeLayerIndex: min(max(document.activeLayerIndex.rawValue, 0), layers.count - 1),
                paperStyle: CanvasPaperStyle(
                    validatingRed: Float(document.paperStyle.red),
                    green: Float(document.paperStyle.green),
                    blue: Float(document.paperStyle.blue),
                    alpha: Float(document.paperStyle.alpha),
                    isTransparent: document.paperStyle.isTransparent
                ) ?? .default,
                revision: 0,
                nextFolderID: (folders.map { $0.id }.max() ?? 0) + 1,
                layers: layers,
                folders: folders,
                thumbnailCache: [:],
                timelapseFrames: timelapseFrames,
                timelapseEvents: timelapseEvents,
                timelapseUsesOperationPersistence: !timelapseEvents.isEmpty
              ),
              runtime.store.restore(loadedSnapshot) else {
            throw PrimoDocumentError.invalidDocument
        }
        runtime.presentationBuilder.clearThumbnailSurfaces()
        return runtime
    }

    func setPaperStyle(_ style: CanvasPaperStyle) {
        let before = undoSnapshot()
        _ = store.update {
            $0.paperStyle = style
            return true
        }
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
        _ = store.update {
            $0 = newRuntime.store.snapshot
            return true
        }
        presentationBuilder.clearThumbnailSurfaces()
        undoHistory.clear()
        strokeCoordinator.clearCurrentStroke()
        strokeCoordinator.clearBlurStroke()
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
        return timelapseRecorder.captureResult(
            store: store,
            canvasSize: canvasSize,
            previewSurface: previewSurface,
            previewImageData: preview
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
            if let resolved = try? createFolder(name: name, anchorLayerIndex: anchorLayerIndex?.rawValue).get() {
                folderIDMap[folderID] = resolved.rawValue
            }
        case let .deleteFolder(folderID):
            if let resolved = folderIDMap[folderID] { _ = deleteFolder(folderID: resolved) }
        case let .setFolderVisibility(folderID, isVisible):
            if let resolved = folderIDMap[folderID] { _ = setFolderVisibility(folderID: resolved, isVisible: isVisible) }
        case let .setFolderName(folderID, name):
            if let resolved = folderIDMap[folderID] { _ = setFolderName(folderID: resolved, name: name) }
        case let .setFolderExpanded(folderID, isExpanded):
            if let resolved = folderIDMap[folderID] { _ = setFolderExpanded(folderID: resolved, isExpanded: isExpanded) }
        case let .assignLayerToFolder(index, folderID):
            let resolvedFolderID = folderID.flatMap { folderIDMap[$0] }
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

    private func deleteLayerUnchecked(index: Int) -> Bool {
        materializeGpuBackedLayerPixels()
        guard store.update({ snapshot in
            snapshot.layers.remove(at: index)
            snapshot.activeLayerIndex = min(snapshot.activeLayerIndex, snapshot.layers.count - 1)
            return true
        }) else {
            return false
        }
        remapFoldersAfterDeletion(of: index)
        invalidateAllThumbnails()
        releaseLayerBufferHandles()
        return true
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
        guard updateLayerTextLayer(index: index, textLayer: nil) else {
            return .failure(.inconsistentComposition(operation: "replaceLayerPixels", reason: "target layer is text"))
        }
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
        recordsFinalLayerPixels: Bool = false,
        incomingPayloadLease: GpuMutationPayloadLease? = nil
    ) -> DocumentMutationResult {
        let payloadLease = incomingPayloadLease ?? GpuMutationPayloadLease(handle: payload.gpuBufferHandle, services: gpuServices)
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
        } else if let handle = payloadLease.adoptHandle() {
            adjusted = existing
            nextHandle = handle
        } else {
            adjusted = materializedPixelData(from: payload, existing: existing)
            nextHandle = nil
        }
        setLayerPixelState(index: index, pixelData: adjusted, gpuBufferHandle: nextHandle)
        guard updateLayerTextLayer(index: index, textLayer: nil) else {
            return .failure(.inconsistentComposition(operation: "applyLayerMutation", reason: "target layer is text"))
        }
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
        let payloadLease = GpuMutationPayloadLease(handle: payload.gpuBufferHandle, services: gpuServices)
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
            gpuBufferHandle: payloadLease.adoptHandle()
        )
        guard updateLayerTextLayer(index: index, textLayer: textLayer) else {
            return .failure(.inconsistentComposition(operation: "applyTextLayerMutation", reason: "target layer is text"))
        }
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
        gpuLayerRepository.setLayerPixelState(
            index: index,
            pixelData: pixelData,
            gpuBufferHandle: gpuBufferHandle,
            in: store,
            services: gpuServices
        )
    }

    @discardableResult
    private func updateLayerTextLayer(index: Int, textLayer: TextLayerData?) -> Bool {
        store.update {
            guard $0.layers.indices.contains(index) else { return false }
            $0.layers[index].textLayer = textLayer
            return true
        }
    }

    private func releaseLayerBufferHandles() {
        gpuLayerRepository.releaseLayerBufferHandles(services: gpuServices)
    }

    private func currentPixelData(for index: Int) -> Data {
        gpuLayerRepository.currentPixelData(
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
        gpuLayerRepository.layerSourceForGpuPlan(
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
        let stats = undoHistory.recordMutation(
            before: before,
            after: after,
            changedLayerIndex: changedLayerIndex,
            dirtyRect: dirtyRect
        )
        logUndoHistoryStats(stats, reason: "recordMutation")
        timelapseRecorder.record(timelapseEvent, marksOperationPersistence: true, in: store)
        _ = store.update {
            $0.revision += 1
            return true
        }
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
        dirtyUpdatePublisher.captureDirtyUpdate(
            snapshot: store.snapshot,
            rect: rect,
            gpuServices: gpuServices,
            makeMetalSnapshot: { [weak self] (snapshot: SwiftDocumentStoreSnapshot, includeCompositePixelData: Bool) in
                guard let self else {
                    return MetalDocumentSnapshot.unsafeUnchecked(
                        width: snapshot.canvasWidth,
                        height: snapshot.canvasHeight,
                        revision: snapshot.revision,
                        compositePixelData: Data(),
                        layers: []
                    )
                }
                return self.makeMetalSnapshot(for: snapshot, includeCompositePixelData: includeCompositePixelData)
            },
            compositePixelData: { [weak self] snapshot in
                self?.compositePixelDataForSnapshot(snapshot) ?? Data()
            }
        )
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
        return presentationBuilder.makeRenderSnapshot(
            baseSnapshot: baseSnapshot,
            compositeHandle: compositeHandle,
            fallbackComposite: composite,
            thumbnailSurface: cachedLayerThumbnailSurface(index:)
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
                    gpuBufferHandle: gpuLayerRepository.handle(for: index),
                    pixelData: layer.pixelData
                )
            }
        )
    }

    private func buildLayerRows() -> [LayerRowModel] {
        presentationBuilder.lightweightPresentation(snapshot: store.validatedSnapshot(), canvasSize: canvasSize).layerRows
    }

    private func buildLayerRows(from snapshot: SwiftDocumentStoreSnapshot) -> [LayerRowModel] {
        presentationBuilder.lightweightPresentation(snapshot: snapshot, canvasSize: canvasSize).layerRows
    }

    private func buildSidebarRows() -> [LayerSidebarRowModel] {
        presentationBuilder.lightweightPresentation(snapshot: store.validatedSnapshot(), canvasSize: canvasSize).layerSidebarRows
    }

    private func buildSidebarRows(from snapshot: SwiftDocumentStoreSnapshot) -> [LayerSidebarRowModel] {
        presentationBuilder.lightweightPresentation(snapshot: snapshot, canvasSize: canvasSize).layerSidebarRows
    }

    private func cachedLayerThumbnailSurface(index: Int) -> DocumentCompositeSurface? {
        presentationBuilder.cachedLayerThumbnailSurface(
            index: index,
            snapshot: store.snapshot,
            canvasSize: canvasSize,
            gpuServices: gpuServices,
            currentPixelData: currentPixelData(for:)
        )
    }

    private func invalidateThumbnail(for index: Int) {
        presentationBuilder.invalidateThumbnail(for: index, in: store)
    }

    private func invalidateAllThumbnails() {
        presentationBuilder.invalidateAllThumbnails(in: store)
    }

    private func timelapseFrameSize(for canvasSize: CGSize, maxDimension: CGFloat) -> CGSize {
        presentationBuilder.timelapseFrameSize(for: canvasSize, maxDimension: maxDimension)
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
        timelapseRecorder.capture(
            store: store,
            services: services,
            source: timelapseCompositeSurface(),
            canvasSize: canvasSize,
            gpuServices: gpuServices,
            frameSize: { [weak self] canvasSize, maxDimension in
                self?.timelapseFrameSize(for: canvasSize, maxDimension: maxDimension) ?? CGSize(width: maxDimension, height: maxDimension)
            },
            logger: Self.logger
        )
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
        LayerMutationEngine.remapFoldersAfterInsertion(in: store, at: insertedIndex)
    }

    private func remapFoldersAfterDeletion(of deletedIndex: Int) {
        LayerMutationEngine.remapFoldersAfterDeletion(in: store, of: deletedIndex)
    }

    private func remapFoldersAfterMove(from sourceIndex: Int, to destinationIndex: Int) {
        LayerMutationEngine.remapFoldersAfterMove(in: store, from: sourceIndex, to: destinationIndex)
    }

    private func preserveExistingAlphaIfNeeded(_ source: Data, existing: Data, isAlphaLocked: Bool) -> Data {
        LayerMutationEngine.preserveExistingAlphaIfNeeded(source, existing: existing, isAlphaLocked: isAlphaLocked)
    }
}
