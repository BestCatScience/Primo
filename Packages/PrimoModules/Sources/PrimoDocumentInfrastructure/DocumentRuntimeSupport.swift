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

public final class LockedDocumentRuntimeBox<Runtime>: @unchecked Sendable {
    private let lock = NSLock()
    private var runtime: Runtime

    public init(runtime: Runtime) {
        self.runtime = runtime
    }

    public func withRuntime<T>(
        _ body: (Runtime) throws -> T
    ) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(runtime)
    }

    public func replaceRuntime(with newRuntime: Runtime) {
        lock.lock()
        runtime = newRuntime
        lock.unlock()
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
