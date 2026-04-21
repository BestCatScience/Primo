public struct PaintDocumentCanvasSize: Equatable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = max(width, 1)
        self.height = max(height, 1)
    }

    public var rgbaByteCount: Int {
        width * height * 4
    }

    public var maskByteCount: Int {
        width * height
    }
}
