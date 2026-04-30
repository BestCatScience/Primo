import CoreGraphics
import Foundation
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure

@MainActor
public final class CanvasRenderSurfaceDriver {
    private let renderSession: CanvasRenderSession
    private var lastPreviewResetNonce = 0
    public private(set) var currentActiveLayerIndex: Int = 0

    public init(renderSession: CanvasRenderSession = CanvasRenderSession()) {
        self.renderSession = renderSession
    }

    public func render(_ update: RenderFrameUpdate, into backend: PrimoMetalCanvasView) {
        renderSession.adoptTransferredResources(for: update)
        currentActiveLayerIndex = update.activeLayerIndex
        backend.currentActiveLayerIndex = update.activeLayerIndex
        backend.updateDocumentSize(update.documentSize)
        if update.previewResetNonce != lastPreviewResetNonce {
            backend.reloadSnapshot(update.snapshot)
            lastPreviewResetNonce = update.previewResetNonce
        }
        backend.update(
            snapshot: update.snapshot,
            viewportOffset: update.viewportOffset,
            zoomScale: update.zoomScale,
            paperStyle: update.paperStyle
        )
        if let incrementalUpdate = update.incrementalUpdate {
            backend.applyIncrementalUpdate(incrementalUpdate)
        }
    }

    public func reset() {
        renderSession.reset()
        lastPreviewResetNonce = 0
        currentActiveLayerIndex = 0
    }
}
