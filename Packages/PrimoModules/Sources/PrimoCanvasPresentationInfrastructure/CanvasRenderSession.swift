import CoreGraphics
import Foundation
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure

public final class CanvasRenderSession {
    private var adoptedIncrementalHandle: GpuSurfaceHandle?
    private let lifetime: GpuResourceLifetime

    public init(
        lifetime: GpuResourceLifetime = CanvasRenderSession.sharedMetalResourceLifetime()
    ) {
        self.lifetime = lifetime
    }

    public static func sharedMetalResourceLifetime(
        resourceStore: MetalResourceStore = MetalResourceStore()
    ) -> GpuResourceLifetime {
        GpuResourceLifetime { handle in
            resourceStore.release(handle.buffer)
        }
    }

    deinit {
        lifetime.release(adoptedIncrementalHandle)
    }

    public func adoptTransferredResources(for update: RenderFrameUpdate) {
        let nextHandle = update.incrementalUpdate?.gpuBufferHandle.map(GpuSurfaceHandle.init(buffer:))
        if adoptedIncrementalHandle != nextHandle {
            lifetime.release(adoptedIncrementalHandle)
        }
        adoptedIncrementalHandle = nextHandle
    }

    public func reset() {
        lifetime.release(adoptedIncrementalHandle)
        adoptedIncrementalHandle = nil
    }
}
