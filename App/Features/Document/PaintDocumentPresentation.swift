import CoreGraphics
import Foundation

struct PaintDocumentPresentation: Equatable, Sendable {
    var canvasSize: CGSize
    var activeLayerIndex: Int
    var layerRows: [LayerRowModel]
    var renderSnapshot: MetalDocumentSnapshot?
}
