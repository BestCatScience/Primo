import CoreGraphics
import Foundation
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure

public final class CanvasRenderSession {
    private var retainedIncrementalHandle: GpuSurfaceHandle?
    private let lifetime: GpuResourceLifetime

    public init(
        lifetime: GpuResourceLifetime = GpuResourceLifetime { handle in
            PrimoMetalDocumentProcessingClient.shared.releaseBufferHandle(handle.buffer)
        }
    ) {
        self.lifetime = lifetime
    }

    deinit {
        lifetime.release(retainedIncrementalHandle)
    }

    public func retainResources(for update: RenderFrameUpdate) {
        let nextHandle = update.incrementalUpdate?.gpuBufferHandle.map(GpuSurfaceHandle.init(buffer:))
        if retainedIncrementalHandle != nextHandle {
            lifetime.release(retainedIncrementalHandle)
        }
        retainedIncrementalHandle = nextHandle
    }

    public func reset() {
        lifetime.release(retainedIncrementalHandle)
        retainedIncrementalHandle = nil
    }
}
