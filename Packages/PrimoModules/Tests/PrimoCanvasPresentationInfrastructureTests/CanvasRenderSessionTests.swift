import Foundation
import PrimoCanvasPresentationInfrastructure
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import Testing

@Suite
struct CanvasRenderSessionTests {
    @Test
    func releasesReplacedIncrementalHandlesOnce() {
        let released = ReleasedHandles()
        let session = CanvasRenderSession(
            lifetime: GpuResourceLifetime { handle in
                released.append(handle.buffer)
            }
        )
        let first = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)
        let second = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)

        session.retainResources(for: update(handle: first))
        session.retainResources(for: update(handle: first))
        #expect(released.values.isEmpty)

        session.retainResources(for: update(handle: second))
        #expect(released.values == [first])

        session.reset()
        #expect(released.values == [first, second])
    }

    private func update(handle: MetalBufferHandle?) -> RenderFrameUpdate {
        RenderFrameUpdate(
            snapshot: nil,
            activeLayerIndex: 0,
            incrementalUpdate: handle.map {
                IncrementalLayerUpdate(
                    layerIndex: 0,
                    originX: 0,
                    originY: 0,
                    width: 4,
                    height: 4,
                    gpuBufferHandle: $0,
                    pixelData: Data()
                )
            },
            documentSize: .zero,
            viewportOffset: .zero,
            zoomScale: 1,
            paperStyle: .default,
            previewResetNonce: 0
        )
    }
}

private final class ReleasedHandles: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [MetalBufferHandle] = []

    var values: [MetalBufferHandle] {
        lock.withLock { storage }
    }

    func append(_ handle: MetalBufferHandle) {
        lock.withLock {
            storage.append(handle)
        }
    }
}
