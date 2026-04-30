import Foundation
import Metal
import PrimoDocumentContracts
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentMetalSurfaceInfrastructure
import PrimoDocumentPresentationContracts
import Testing

@Suite
struct MetalSurfaceResourceGatewayTests {
    @Test
    func materializesFullSurfaceAndRegionThroughGateway() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let rawBytes: [UInt8] = [
            1, 2, 3, 4,     5, 6, 7, 8,
            9, 10, 11, 12,  13, 14, 15, 16,
        ]
        let bytes = Data(rawBytes)
        let buffer = try #require(device.makeBuffer(bytes: rawBytes, length: rawBytes.count, options: .storageModeShared))
        let client = PrimoMetalDocumentProcessingClient()
        let store = MetalResourceStore(client: client)
        let handle = store.makeBufferHandle(width: 2, height: 2, bytesPerRow: 8, buffer: buffer)
        let gateway = MetalSurfaceResourceGateway(resourceStore: store, processingClient: client)

        let full = try #require(gateway.materializedSurface(
            MaterializedSurfaceRequest(handle: GpuSurfaceHandle(buffer: handle))
        ))
        let region = try #require(gateway.materializedSurface(
            MaterializedSurfaceRequest(
                handle: GpuSurfaceHandle(buffer: handle),
                region: GpuSurfaceRegion(originX: 1, originY: 0, width: 1, height: 2)
            )
        ))

        #expect(full.width == 2)
        #expect(full.height == 2)
        #expect(full.pixelData == bytes)
        #expect(region.width == 1)
        #expect(region.height == 2)
        #expect(region.pixelData == Data([5, 6, 7, 8, 13, 14, 15, 16]))

        gateway.release(GpuSurfaceHandle(buffer: handle))
        #expect(gateway.materializedSurface(MaterializedSurfaceRequest(handle: GpuSurfaceHandle(buffer: handle))) == nil)
    }

    @Test
    func retainThenReleaseKeepsBufferUntilFinalRelease() throws {
        let (store, handle, bytes) = try makeBufferedStore()

        #expect(store.retain(handle))
        store.release(handle)
        #expect(store.materializedPixelData(for: handle) == bytes)

        store.release(handle)
        #expect(store.materializedPixelData(for: handle) == nil)
    }

    @Test
    func staleRetainDoesNotCreatePhantomResource() throws {
        let client = PrimoMetalDocumentProcessingClient()
        let store = MetalResourceStore(client: client)
        let stale = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)

        #expect(!store.retain(stale))
        store.release(stale)
        #expect(store.materializedPixelData(for: stale) == nil)
    }

    @Test
    func releaseAfterPreviewAndRuntimeShareDoesNotDropBufferEarly() throws {
        let (store, handle, bytes) = try makeBufferedStore()

        #expect(store.retain(handle))

        store.release(handle)
        #expect(store.materializedPixelData(for: handle) == bytes)

        store.release(handle)
        #expect(store.materializedPixelData(for: handle) == nil)
    }

    private func makeBufferedStore() throws -> (
        store: MetalResourceStore,
        handle: MetalBufferHandle,
        bytes: Data
    ) {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let rawBytes: [UInt8] = [
            1, 2, 3, 4,     5, 6, 7, 8,
            9, 10, 11, 12,  13, 14, 15, 16,
        ]
        let bytes = Data(rawBytes)
        let buffer = try #require(device.makeBuffer(bytes: rawBytes, length: rawBytes.count, options: .storageModeShared))
        let client = PrimoMetalDocumentProcessingClient()
        let store = MetalResourceStore(client: client)
        let handle = store.makeBufferHandle(width: 2, height: 2, bytesPerRow: 8, buffer: buffer)
        return (store, handle, bytes)
    }
}
