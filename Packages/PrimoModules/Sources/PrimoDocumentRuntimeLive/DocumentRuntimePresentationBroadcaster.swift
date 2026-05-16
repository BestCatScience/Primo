import Foundation
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts

final class DocumentRuntimePresentationBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private let currentPresentation: @Sendable () -> Result<PaintDocumentPresentation, DocumentMutationFailure>
    private var continuations: [UUID: AsyncStream<PaintDocumentPresentation>.Continuation] = [:]

    init(currentPresentation: @escaping @Sendable () -> Result<PaintDocumentPresentation, DocumentMutationFailure>) {
        self.currentPresentation = currentPresentation
    }

    func stream() -> AsyncStream<PaintDocumentPresentation> {
        AsyncStream { continuation in
            let id = UUID()
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id)
            }
            lock.lock()
            continuations[id] = continuation
            lock.unlock()
            if case let .success(presentation) = currentPresentation() {
                continuation.yield(presentation)
            }
        }
    }

    func publishLatest() {
        if case let .success(presentation) = currentPresentation() {
            publish(presentation)
        }
    }

    private func publish(_ presentation: PaintDocumentPresentation) {
        lock.lock()
        let activeContinuations = Array(continuations.values)
        lock.unlock()
        for continuation in activeContinuations {
            continuation.yield(presentation)
        }
    }

    private func removeContinuation(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}
