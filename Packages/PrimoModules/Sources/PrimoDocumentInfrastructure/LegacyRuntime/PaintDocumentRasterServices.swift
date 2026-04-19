struct PaintDocumentCanvasSize: Equatable {
    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        self.width = max(width, 1)
        self.height = max(height, 1)
    }

    var rgbaByteCount: Int {
        width * height * 4
    }

    var maskByteCount: Int {
        width * height
    }
}
