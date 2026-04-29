import Foundation
import PrimoCanvasPresentationInfrastructure
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import Testing

@Suite
struct CanvasRenderSessionTests {
    @Test
    func keepsSingleFrameHandleUntilReset() {
        let released = ReleasedHandles()
        let session = CanvasRenderSession(
            lifetime: GpuResourceLifetime { handle in
                released.append(handle.buffer)
            }
        )
        let first = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)

        session.retainResources(for: update(handle: first))
        #expect(released.values.isEmpty)

        session.reset()
        #expect(released.values == [first])
    }

    @Test
    func duplicateRenderReleasesIncrementalHandleOnceOnReset() {
        let released = ReleasedHandles()
        let session = CanvasRenderSession(
            lifetime: GpuResourceLifetime { handle in
                released.append(handle.buffer)
            }
        )
        let first = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)

        session.retainResources(for: update(handle: first))
        session.retainResources(for: update(handle: first))
        #expect(released.values.isEmpty)

        session.reset()
        session.reset()
        #expect(released.values == [first])
    }

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
        session.retainResources(for: update(handle: second))
        #expect(released.values == [first])

        session.reset()
        #expect(released.values == [first, second])
    }

    @Test
    func releasesCurrentIncrementalHandleOnceOnDeinit() {
        let released = ReleasedHandles()
        let first = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)

        do {
            let session = CanvasRenderSession(
                lifetime: GpuResourceLifetime { handle in
                    released.append(handle.buffer)
                }
            )
            session.retainResources(for: update(handle: first))
            #expect(released.values.isEmpty)
        }

        #expect(released.values == [first])
    }

    @Test
    func canvasViewDoesNotReleaseIncrementalHandlesDirectly() throws {
        let source = try String(
            contentsOf: primoMetalCanvasViewSourceURL(),
            encoding: .utf8
        )
        let applyBody = try #require(source.methodBody(named: "applyIncrementalUpdate"))

        #expect(!applyBody.contains("MetalResourceStore()"))
        #expect(!applyBody.contains(".release("))
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

    private func primoMetalCanvasViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PrimoDocumentMetalRuntimeInfrastructure/PrimoMetalCanvasView.swift")
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

private extension String {
    func methodBody(named name: String) -> String? {
        guard let range = range(of: "func \(name)") else { return nil }
        guard let openingBrace = self[range.lowerBound...].firstIndex(of: "{") else { return nil }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            let character = self[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}
