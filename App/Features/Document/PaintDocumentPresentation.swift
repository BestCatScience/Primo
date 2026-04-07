import CoreGraphics
import Foundation

struct PaintDocumentPresentation: Equatable, Sendable {
    var canvasSize: CGSize
    var activeLayerIndex: Int
    var layerRows: [LayerRowModel]
    var layerSidebarRows: [LayerSidebarRowModel]
    var renderSnapshot: MetalDocumentSnapshot?
}

struct LoadedPaintProject: Equatable, Sendable {
    var presentation: PaintDocumentPresentation
    var paperStyle: CanvasPaperStyle
}
