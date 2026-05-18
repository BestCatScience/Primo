import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import Testing
@testable import PrimoDocumentEngineInfrastructure

struct DocumentRuntimeCollaboratorTests {
    @Test
    func gpuLayerRepositoryReleasesReplacedHandlesAndMaterializesCurrentPixels() throws {
        let box = CollaboratorGpuBox()
        let services = box.services()
        let store = SwiftDocumentStore(width: 2, height: 2)
        var repository = GpuLayerRepository()
        let firstHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let secondHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let firstPixels = Data(repeating: 0x11, count: 16)
        let secondPixels = Data(repeating: 0x22, count: 16)
        box.setPixelData(firstPixels, for: firstHandle)
        box.setPixelData(secondPixels, for: secondHandle)

        repository.setLayerPixelState(index: 0, pixelData: firstPixels, gpuBufferHandle: firstHandle, in: store, services: services)
        repository.setLayerPixelState(index: 0, pixelData: secondPixels, gpuBufferHandle: secondHandle, in: store, services: services)

        #expect(box.releasedHandles == [firstHandle])
        let snapshot = try repository.materializedSnapshot(from: store.snapshot, rgbaByteCount: 16, services: services).get()
        #expect(snapshot.layers[0].pixelData == secondPixels)
    }

    @Test
    func gpuLayerRepositoryAppliesPixelAndTextUpdatesAtomically() throws {
        let box = CollaboratorGpuBox()
        let services = box.services()
        let store = SwiftDocumentStore(width: 2, height: 2)
        var repository = GpuLayerRepository()
        let handle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let textLayer = try #require(TextLayerData(
            validatingText: "Draft",
            positionX: 0,
            positionY: 0,
            fontPostScriptName: "Helvetica",
            fontDisplayName: "Helvetica",
            fontSize: 12,
            red: 1,
            green: 1,
            blue: 1,
            alpha: 1
        ))
        let originalPixels = store.snapshot.layers[0].pixelData
        store.update {
            $0.layers[0].textLayer = textLayer
            return true
        }

        let didApply = repository.setLayerPixelState(
            index: 0,
            pixelData: Data([0xff]),
            gpuBufferHandle: handle,
            textLayerUpdate: .set(nil),
            in: store,
            services: services
        )

        #expect(!didApply)
        #expect(store.snapshot.layers[0].pixelData == originalPixels)
        #expect(store.snapshot.layers[0].textLayer == textLayer)
        #expect(box.releasedHandles == [handle])
    }

    @Test
    func dirtyUpdatePublisherReleasesPreviousGpuHandleWhenReplacingPendingUpdate() {
        let box = CollaboratorGpuBox()
        let services = box.services()
        let publisher = DirtyUpdatePublisher()
        let store = SwiftDocumentStore(width: 2, height: 2)
        let firstHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let secondHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        box.incrementalUpdates = [
            IncrementalLayerUpdate.unsafeUnchecked(layerIndex: -1, originX: 0, originY: 0, width: 2, height: 2, gpuBufferHandle: firstHandle, pixelData: Data()),
            IncrementalLayerUpdate.unsafeUnchecked(layerIndex: -1, originX: 0, originY: 0, width: 2, height: 2, gpuBufferHandle: secondHandle, pixelData: Data()),
        ]

        publisher.captureDirtyUpdate(snapshot: store.snapshot, rect: nil, gpuServices: services, makeMetalSnapshot: CollaboratorGpuBox.metalSnapshot, compositePixelData: { _ in Data(count: 16) })
        publisher.captureDirtyUpdate(snapshot: store.snapshot, rect: nil, gpuServices: services, makeMetalSnapshot: CollaboratorGpuBox.metalSnapshot, compositePixelData: { _ in Data(count: 16) })

        #expect(box.releasedHandles == [firstHandle])
        #expect(publisher.consumeDirtyUpdate()?.gpuBufferHandle == secondHandle)
    }

    @Test
    func dirtyUpdatePublisherTransfersGpuHandleOwnershipOnConsume() {
        let box = CollaboratorGpuBox()
        let services = box.services()
        let publisher = DirtyUpdatePublisher()
        let store = SwiftDocumentStore(width: 2, height: 2)
        let handle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        box.incrementalUpdates = [
            IncrementalLayerUpdate.unsafeUnchecked(
                layerIndex: -1,
                originX: 0,
                originY: 0,
                width: 2,
                height: 2,
                gpuBufferHandle: handle,
                pixelData: Data()
            )
        ]

        publisher.captureDirtyUpdate(
            snapshot: store.snapshot,
            rect: nil,
            gpuServices: services,
            makeMetalSnapshot: CollaboratorGpuBox.metalSnapshot,
            compositePixelData: { _ in Data(count: 16) }
        )

        #expect(publisher.consumeDirtyUpdate()?.gpuBufferHandle == handle)
        #expect(publisher.consumeDirtyUpdate() == nil)
        #expect(box.releasedHandles.isEmpty)
    }

    @Test
    func presentationBuilderCachesAndInvalidatesLayerThumbnailSurfaces() {
        let box = CollaboratorGpuBox()
        let services = box.services()
        let store = SwiftDocumentStore(width: 2, height: 2)
        let builder = DocumentPresentationBuilder()
        let pixels = Data(repeating: 0x44, count: 16)

        _ = builder.cachedLayerThumbnailSurface(index: 0, snapshot: store.snapshot, canvasSize: CGSize(width: 2, height: 2), gpuServices: services) { _ in pixels }
        _ = builder.cachedLayerThumbnailSurface(index: 0, snapshot: store.snapshot, canvasSize: CGSize(width: 2, height: 2), gpuServices: services) { _ in pixels }
        #expect(box.scaledPixelCallCount == 1)

        builder.invalidateThumbnail(for: 0, in: store)
        _ = builder.cachedLayerThumbnailSurface(index: 0, snapshot: store.snapshot, canvasSize: CGSize(width: 2, height: 2), gpuServices: services) { _ in pixels }
        #expect(box.scaledPixelCallCount == 2)
    }

    @Test
    func timelapseRecorderMarksOperationPersistenceWhenRecordingEvents() {
        let store = SwiftDocumentStore(width: 2, height: 2)
        store.update {
            $0.timelapseUsesOperationPersistence = false
            return true
        }
        let recorder = TimelapseRecorder()

        recorder.record(.undo, marksOperationPersistence: true, in: store)

        #expect(store.snapshot.timelapseUsesOperationPersistence)
        #expect(store.snapshot.timelapseEvents == [.undo])
    }

    @Test
    func gpuMutationPayloadLeaseReleasesHandleWhenOwnershipIsNotTransferred() {
        let box = CollaboratorGpuBox()
        let services = box.services()
        let handle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)

        do {
            _ = GpuMutationPayloadLease(handle: handle, services: services)
        }

        #expect(box.releasedHandles == [handle])
    }

    @Test
    func gpuMutationPayloadLeaseSuppressesReleaseAfterTransferredOwnership() {
        let box = CollaboratorGpuBox()
        let services = box.services()
        let handle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        var didEnterTransferBody = false

        do {
            let lease = GpuMutationPayloadLease(handle: handle, services: services)
            lease.withTransferredOwnership {
                didEnterTransferBody = true
            }
        }

        #expect(didEnterTransferBody)
        #expect(box.releasedHandles.isEmpty)
    }

    @Test
    func applyLayerSurfaceMutationReleasesGpuPayloadHandleOnEarlyFailure() {
        let box = CollaboratorGpuBox()
        let services = box.services()
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: services)
        let handle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let payload = GpuLayerMutationPayload.unsafeUnchecked(
            canvasWidth: 3,
            canvasHeight: 2,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
            gpuBufferHandle: handle,
            fallbackPixelData: nil
        )

        let result = runtime.applyLayerSurfaceMutation(index: 0, payload: payload)

        guard case .failure = result else {
            Issue.record("Expected invalid surface payload to fail")
            return
        }
        #expect(box.releasedHandles == [handle])
    }

    @Test
    func applyLayerMutationReleasesGpuPayloadHandleWhenValidationFails() {
        let box = CollaboratorGpuBox()
        let services = box.services()
        let runtime = SwiftDocumentRuntime(width: 2, height: 2, gpuServices: services)
        let handle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let payload = DocumentLayerMutationPayload.unsafeUnchecked(
            canvasWidth: 2,
            canvasHeight: 2,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 1, originY: 0, width: 2, height: 2),
            gpuBufferHandle: handle,
            rectPixelData: Data(),
            fullPixelData: nil
        )

        let result = runtime.applyLayerMutation(index: 0, payload: payload)

        guard case .failure = result else {
            Issue.record("Expected invalid layer payload to fail")
            return
        }
        #expect(box.releasedHandles == [handle])
    }
}

private final class CollaboratorGpuBox: @unchecked Sendable {
    private let lock = NSLock()
    private var pixelDataByHandle: [MetalBufferHandle: Data] = [:]
    private var releases: [MetalBufferHandle] = []
    private var scaledCalls = 0
    var incrementalUpdates: [IncrementalLayerUpdate] = []

    var releasedHandles: [MetalBufferHandle] {
        lock.withLock { releases }
    }

    var scaledPixelCallCount: Int {
        lock.withLock { scaledCalls }
    }

    func setPixelData(_ data: Data, for handle: MetalBufferHandle) {
        lock.withLock {
            pixelDataByHandle[handle] = data
        }
    }

    func services() -> DocumentRuntimeGpuServices {
        DocumentRuntimeGpuServices(
            release: { handle in
                guard let handle else { return }
                self.lock.withLock {
                    self.releases.append(handle)
                    self.pixelDataByHandle.removeValue(forKey: handle)
                }
            },
            retain: { _ in true },
            _materializedPixelData: { handle in
                self.lock.withLock { self.pixelDataByHandle[handle] }
            },
            _scaledPixelData: { data, _, _, targetWidth, targetHeight in
                self.lock.withLock { self.scaledCalls += 1 }
                return Data(repeating: data.first ?? 0, count: targetWidth * targetHeight * 4)
            },
            _scaledMaskData: { data, _, _, _, _ in data },
            _translatedPixelData: { data, _, _, _, _, _, _ in data },
            _translatedMaskData: { data, _, _, _, _, _, _ in data },
            _applyLayerMask: { pixelData, _, _, _ in pixelData },
            _processLayer: { pixelData, width, height, _ in
                DocumentLayerMutationPayload.unsafeUnchecked(
                    canvasWidth: width,
                    canvasHeight: height,
                    dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: width, height: height),
                    gpuBufferHandle: nil,
                    rectPixelData: pixelData,
                    fullPixelData: pixelData
                )
            },
            _mergeLayers: { lower, _, _, _, _, _, _ in lower },
            _rasterizeTextLayer: { _, size in
                let width = Int(size.width)
                let height = Int(size.height)
                let pixelData = Data(count: width * height * 4)
                return DocumentLayerMutationPayload.unsafeUnchecked(
                    canvasWidth: width,
                    canvasHeight: height,
                    dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: width, height: height),
                    gpuBufferHandle: nil,
                    rectPixelData: pixelData,
                    fullPixelData: pixelData
                )
            },
            _blurPixels: { pixelData, _, width, height, _, _ in
                DocumentLayerMutationPayload.unsafeUnchecked(
                    canvasWidth: width,
                    canvasHeight: height,
                    dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: width, height: height),
                    gpuBufferHandle: nil,
                    rectPixelData: pixelData,
                    fullPixelData: pixelData
                )
            },
            _fillPixels: { pixelData, _, width, height, _, _ in
                DocumentLayerMutationPayload.unsafeUnchecked(
                    canvasWidth: width,
                    canvasHeight: height,
                    dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: width, height: height),
                    gpuBufferHandle: nil,
                    rectPixelData: pixelData,
                    fullPixelData: pixelData
                )
            },
            _commitStrokeMutation: { _, _, _, _, _, _, _, _ in nil },
            _preservingExistingAlphaBufferHandle: { sourceHandle, _, _, _, _ in sourceHandle },
            _compositedPaperPreviewRGBA: { pixelData, _, _, _ in pixelData },
            _compositedIncrementalUpdate: { _, _ in
                self.lock.withLock {
                    guard !self.incrementalUpdates.isEmpty else { return nil }
                    return self.incrementalUpdates.removeFirst()
                }
            },
            _compositeDocumentSurface: { snapshot in
                DocumentCompositeSurface(unsafeUncheckedWidth: snapshot.width, height: snapshot.height, pixelData: Data(count: snapshot.width * snapshot.height * 4))
            },
            _compositeDocumentBufferHandle: { _ in nil }
        )
    }

    static func metalSnapshot(_ snapshot: SwiftDocumentStoreSnapshot, _ includeCompositePixelData: Bool) -> MetalDocumentSnapshot {
        MetalDocumentSnapshot.unsafeUnchecked(
            width: snapshot.canvasWidth,
            height: snapshot.canvasHeight,
            revision: snapshot.revision,
            compositePixelData: includeCompositePixelData ? Data(count: snapshot.canvasWidth * snapshot.canvasHeight * 4) : Data(),
            layers: snapshot.layers.enumerated().map { index, layer in
                MetalLayerSnapshot.unsafeUnchecked(
                    index: index,
                    opacity: Float(layer.opacity),
                    visible: layer.visible,
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
