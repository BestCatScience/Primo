import Foundation
import PrimoCanvasPresentationInfrastructure
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure
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
        let first = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)

        session.adoptTransferredResources(for: update(handle: first))
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
        let first = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)

        session.adoptTransferredResources(for: update(handle: first))
        session.adoptTransferredResources(for: update(handle: first))
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
        let first = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let second = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)

        session.adoptTransferredResources(for: update(handle: first))
        session.adoptTransferredResources(for: update(handle: second))
        #expect(released.values == [first])

        session.reset()
        #expect(released.values == [first, second])
    }

    @Test
    func releasesCurrentIncrementalHandleOnceOnDeinit() {
        let released = ReleasedHandles()
        let first = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)

        do {
            let session = CanvasRenderSession(
                lifetime: GpuResourceLifetime { handle in
                    released.append(handle.buffer)
                }
            )
            session.adoptTransferredResources(for: update(handle: first))
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

    @Test
    func defaultLifetimeNamesSharedMetalResourceOwnership() throws {
        let source = try String(
            contentsOf: canvasRenderSessionSourceURL(),
            encoding: .utf8
        )

        #expect(source.contains("sharedMetalResourceLifetime"))
        #expect(source.contains("resourceStore.release(handle.buffer)"))
    }

    @Test
    func gpuBackedSnapshotWithEmptyPixelsCannotUseCPUFallback() throws {
        let geometry = try #require(PixelGeometry(width: 4, height: 4))
        let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 4,
            height: 4,
            revision: 1,
            compositeBufferHandle: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16),
            compositePixelData: Data(),
            layers: []
        )

        #expect(!PrimoMetalCanvasView.canUseCPUFallback(for: snapshot, geometry: geometry))
    }

    @Test
    func cpuBackedSnapshotWithFullPixelsCanUseCPUFallback() throws {
        let geometry = try #require(PixelGeometry(width: 4, height: 4))
        let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 4,
            height: 4,
            revision: 1,
            compositePixelData: Data(count: geometry.rgbaByteCount),
            layers: []
        )

        #expect(PrimoMetalCanvasView.canUseCPUFallback(for: snapshot, geometry: geometry))
    }

    @Test
    func previewStrokeStyleSimdColorHandlesThreeComponentColor() throws {
        let source = try String(
            contentsOf: canvasPresentationContainerViewSourceURL(),
            encoding: .utf8
        )
        let simdColorBody = try #require(source.propertyBody(named: "simdColor"))

        #expect(simdColorBody.contains("case 3:"))
        #expect(simdColorBody.contains("Float(color.alpha)"))
    }

    @Test
    func presentationViewSurfacesDeclareMainActorAffinity() throws {
        let containerSource = try String(
            contentsOf: canvasPresentationContainerViewSourceURL(),
            encoding: .utf8
        )
        let surfaceSource = try String(
            contentsOf: canvasMetalSurfaceViewsSourceURL(),
            encoding: .utf8
        )
        let loupeSource = try String(
            contentsOf: canvasEyedropperLoupeViewSourceURL(),
            encoding: .utf8
        )
        let navigationSource = try String(
            contentsOf: canvasNavigationGestureAdapterSourceURL(),
            encoding: .utf8
        )
        let selectionSource = try String(
            contentsOf: canvasSelectionOverlayViewSourceURL(),
            encoding: .utf8
        )
        let metalCanvasSource = try String(
            contentsOf: primoMetalCanvasViewSourceURL(),
            encoding: .utf8
        )

        #expect(containerSource.contains("@MainActor\npublic final class CanvasPresentationContainerView"))
        #expect(surfaceSource.contains("@MainActor\npublic final class CanvasRenderSurfaceView"))
        #expect(surfaceSource.contains("@MainActor\npublic final class CanvasPixelSurfaceView"))
        #expect(loupeSource.contains("@MainActor\nfinal class CanvasEyedropperLoupeView"))
        #expect(navigationSource.contains("@MainActor\nfinal class CanvasNavigationGestureAdapter"))
        #expect(selectionSource.contains("@MainActor\nfinal class CanvasSelectionOverlayView"))
        #expect(metalCanvasSource.contains("@MainActor\npublic final class PrimoMetalCanvasView"))
    }

    @Test
    func renderSessionKeepsGpuResourceLifetimeBackgroundCapable() throws {
        let source = try String(
            contentsOf: canvasRenderSessionSourceURL(),
            encoding: .utf8
        )

        #expect(source.contains("public final class CanvasRenderSession"))
        #expect(!source.contains("@MainActor\npublic final class CanvasRenderSession"))
        #expect(source.contains("public func adoptTransferredResources(for update: RenderFrameUpdate)"))
    }

    private func update(handle: MetalBufferHandle?) -> RenderFrameUpdate {
        RenderFrameUpdate(
            snapshot: nil,
            activeLayerIndex: 0,
            incrementalUpdate: handle.map {
                IncrementalLayerUpdate.unsafeUnchecked(
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

    private func canvasRenderSessionSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PrimoCanvasPresentationInfrastructure/CanvasRenderSession.swift")
    }

    private func canvasPresentationContainerViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PrimoCanvasPresentationInfrastructure/CanvasPresentationContainerView.swift")
    }

    private func canvasMetalSurfaceViewsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PrimoCanvasPresentationInfrastructure/CanvasMetalSurfaceViews.swift")
    }

    private func canvasEyedropperLoupeViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PrimoCanvasPresentationInfrastructure/CanvasEyedropperLoupeView.swift")
    }

    private func canvasNavigationGestureAdapterSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PrimoCanvasPresentationInfrastructure/CanvasNavigationGestureAdapter.swift")
    }

    private func canvasSelectionOverlayViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PrimoCanvasPresentationInfrastructure/CanvasSelectionOverlayView.swift")
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
        bracedBody(after: "func \(name)")
    }

    func propertyBody(named name: String) -> String? {
        bracedBody(after: "var \(name)")
    }

    private func bracedBody(after marker: String) -> String? {
        guard let range = range(of: marker) else { return nil }
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
