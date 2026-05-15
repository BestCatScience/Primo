import PrimoDocumentPresentationContracts

final class GpuMutationPayloadLease: @unchecked Sendable {
    private var handle: MetalBufferHandle?
    private let releaseHandle: @Sendable (MetalBufferHandle?) -> Void

    init(handle: MetalBufferHandle?, services: DocumentRuntimeGpuServices) {
        self.handle = handle
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

    func releaseNow() {
        releaseRemainingHandle()
    }

    private func releaseRemainingHandle() {
        guard let handle else { return }
        self.handle = nil
        releaseHandle(handle)
    }
}
