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
/// The engine deliberately uses this lock-backed box instead of the actor box
/// below because most gateway APIs are synchronous and heavy GPU work is planned
/// under the lock, executed outside it, then applied under the lock again.
/// Keep `Runtime` mutations inside `withRuntime` / `replaceRuntime`; move this
/// boundary to an actor only if the gateway surface becomes async end-to-end.
package final class LockedDocumentRuntimeBox<Runtime>: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var isExecuting = false
    private var runtime: Runtime

    package init(runtime: Runtime) {
        self.runtime = runtime
    }

    package func withRuntime<T>(
        _ body: (Runtime) throws -> T
    ) rethrows -> T {
        lock.lock()
        precondition(!isExecuting, "Reentrant document runtime access")
        isExecuting = true
        defer {
            isExecuting = false
            lock.unlock()
        }
        return try body(runtime)
    }

    package func replaceRuntime(with newRuntime: Runtime) {
        lock.lock()
        precondition(!isExecuting, "Reentrant document runtime access")
        isExecuting = true
        defer {
            isExecuting = false
            lock.unlock()
        }
        runtime = newRuntime
    }
}

public actor DocumentRuntimeBox<Runtime> where Runtime: Sendable {
    private var runtime: Runtime

    public init(runtime: Runtime) {
        self.runtime = runtime
    }

    public func withRuntime<T: Sendable>(
        _ body: @Sendable (Runtime) throws -> T
    ) async rethrows -> T {
        try body(runtime)
    }

    public func replaceRuntime(with newRuntime: Runtime) {
        runtime = newRuntime
    }
}
