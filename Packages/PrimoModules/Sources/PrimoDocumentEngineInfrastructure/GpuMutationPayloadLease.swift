import PrimoDocumentPresentationContracts

/// @unchecked Sendable: the handle is consumed or released exactly once through a `@Sendable` release closure.
/// Concurrency test: gpuMutationPayloadLeaseSuppressesReleaseAfterTransferredOwnership
final class GpuMutationPayloadLease: @unchecked Sendable {
    private var handle: MetalBufferHandle?
    private let releaseHandle: @Sendable (MetalBufferHandle?) -> Void

    init(handle: MetalBufferHandle?, services: DocumentRuntimeGpuServices) {
        self.handle = handle
        self.releaseHandle = services.release
    }

    init(payloadLease: GpuLayerMutationPayloadLease, services: DocumentRuntimeGpuServices) {
        self.handle = payloadLease.gpuBufferHandle
        self.releaseHandle = services.release
    }

    deinit {
        releaseRemainingHandle()
    }

    var borrowedHandle: MetalBufferHandle? {
        handle
    }

    func adoptHandle() -> MetalBufferHandle? {
        let adoptedHandle = handle
        handle = nil
        return adoptedHandle
    }

    func withTransferredOwnership<Result>(_ body: () -> Result) -> Result {
        _ = adoptHandle()
        return body()
    }

    func releaseNow() {
        releaseRemainingHandle()
    }

    private func releaseRemainingHandle() {
        guard let handle else { return }
        self.handle = nil
        releaseHandle(handle)
    }
}
