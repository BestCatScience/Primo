import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func textLayerData(index: Int) -> TextLayerData? {
        storedTextLayer(at: index)
    }

    func setTextLayer(index: Int, textLayer: TextLayerData) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.layer(index: index, requiresUnlocked: true)],
                applySideEffects: { session, _ in
                    session.setStoredTextLayer(textLayer, at: index)
                }
            )
        ) {
            guard !textLayer.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .failure(.emptyInput)
            }
            guard let rasterized = rasterizedTextLayerPixelData(textLayer) else {
                return .failure(.bridgeMutationFailed("setTextLayer"))
            }
            return replaceLayerPixels(
                index: index,
                data: rasterized,
                preservesTextLayerMetadata: true
            )
        }
    }

    func clearTextLayerData(index: Int) {
        removeStoredTextLayer(at: index)
    }

    func rasterizedTextLayerPixelData(_ textLayer: TextLayerData) -> Data? {
        let canvasSize = documentGateway.queries.canvasSize
        return DocumentTextRasterizer.rasterizedPixelData(for: textLayer, canvasSize: canvasSize)
    }

    static func resolvedTextLayout(
        for textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> DocumentTextRasterizer.ResolvedLayout? {
        DocumentTextRasterizer.resolvedTextLayout(for: textLayer, canvasSize: canvasSize)
    }

    static func drawTextLayer(
        _ textLayer: TextLayerData,
        resolved: DocumentTextRasterizer.ResolvedLayout,
        in context: CGContext
    ) {
        DocumentTextRasterizer.drawTextLayer(textLayer, resolved: resolved, in: context)
    }
}
