import CoreGraphics
import Foundation

public struct DocumentProjectPreview: Equatable, Sendable {
    public let canvasSize: CGSize
    public let layerCount: Int
    public let previewImageData: Data?

    public init(
        canvasSize: CGSize,
        layerCount: Int,
        previewImageData: Data?
    ) {
        self.canvasSize = canvasSize
        self.layerCount = layerCount
        self.previewImageData = previewImageData
    }
}

/// Synchronous runtime boundary used by the live document engine.
///
/// The engine deliberately uses this lock-backed executor instead of an actor
/// because most gateway APIs are synchronous and heavy GPU work is planned
/// under the lock, executed outside it, then applied under the lock again.
/// Keep `Runtime` mutations inside the result-returning executor methods; move
/// this boundary to an actor only if the gateway surface becomes async end-to-end.
package final class LockedDocumentRuntimeExecutor<Runtime>: @unchecked Sendable {
    package static var reentrantAccessMessage: String { "Reentrant document runtime access" }

    private let lock = NSRecursiveLock()
    private var isExecuting = false
    private var runtime: Runtime

    package init(runtime: Runtime) {
        self.runtime = runtime
    }

    package func performResult<Success, Failure: Error>(
        failure: @autoclosure () -> Failure,
        _ body: (Runtime) -> Result<Success, Failure>
    ) -> Result<Success, Failure> {
        lock.lock()
        guard !isExecuting else {
            lock.unlock()
            return .failure(failure())
        }
        isExecuting = true
        defer {
            isExecuting = false
            lock.unlock()
        }
        return body(runtime)
    }

    package func performValue<Success, Failure: Error>(
        failure: @autoclosure () -> Failure,
        _ body: (Runtime) -> Success
    ) -> Result<Success, Failure> {
        performResult(failure: failure()) { runtime in
            .success(body(runtime))
        }
    }

    package func performMutation<Failure: Error>(
        failure: @autoclosure () -> Failure,
        _ body: (Runtime) -> Void
    ) -> Result<Void, Failure> {
        performResult(failure: failure()) { runtime in
            body(runtime)
            return .success(())
        }
    }

    package func performThrowing<T>(
        reentrantError: @autoclosure () -> Error,
        _ body: (Runtime) throws -> T
    ) throws -> T {
        lock.lock()
        guard !isExecuting else {
            lock.unlock()
            throw reentrantError()
        }
        isExecuting = true
        defer {
            isExecuting = false
            lock.unlock()
        }
        return try body(runtime)
    }

    package func replaceRuntimeResult<Failure: Error>(
        with newRuntime: Runtime,
        failure: @autoclosure () -> Failure
    ) -> Result<Void, Failure> {
        lock.lock()
        guard !isExecuting else {
            lock.unlock()
            return .failure(failure())
        }
        isExecuting = true
        defer {
            isExecuting = false
            lock.unlock()
        }
        runtime = newRuntime
        return .success(())
    }
}
