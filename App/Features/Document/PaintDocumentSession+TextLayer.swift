import CoreGraphics
import Foundation
import UIKit

extension PaintDocumentSession {
    func textLayerData(index: Int) -> TextLayerData? {
        storedTextLayer(at: index)
    }

    @discardableResult
    func setTextLayer(index: Int, textLayer: TextLayerData) -> Bool {
        guard beginPixelLayerMutation(
            at: index,
            preservesTextLayerMetadata: true
        ) else { return false }
        let existingPixelData = pixelDataForLayer(index: index)
        guard !existingPixelData.isEmpty else { return false }
        guard let rasterized = rasterizedTextLayerPixelData(textLayer) else { return false }
        setStoredTextLayer(textLayer, at: index)
        return replaceLayerPixels(
            index: index,
            data: rasterized,
            preservesTextLayerMetadata: true
        )
    }

    func clearTextLayerData(index: Int) {
        removeStoredTextLayer(at: index)
    }

    func rasterizedTextLayerPixelData(_ textLayer: TextLayerData) -> Data? {
        let canvasSize = bridgeCanvasSize
        guard
            canvasSize.width > 0,
            canvasSize.height > 0,
            let resolved = Self.resolvedTextLayout(for: textLayer, canvasSize: canvasSize)
        else {
            return nil
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let image = renderer.image { context in
            Self.drawTextLayer(textLayer, resolved: resolved, in: context.cgContext)
        }

        guard let cgImage = image.cgImage else { return nil }
        return Self.pixelData(from: cgImage, size: canvasSize)
    }

    static func resolvedTextLayout(
        for textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> (drawRect: CGRect, attributes: [NSAttributedString.Key: Any])? {
        let font = UIFont(name: textLayer.fontPostScriptName, size: textLayer.fontSize)
            ?? UIFont.systemFont(ofSize: textLayer.fontSize, weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(textLayer.color),
            .paragraphStyle: paragraphStyle
        ]
        let constraintRect = CGSize(
            width: max(canvasSize.width - textLayer.position.x - 12, textLayer.fontSize),
            height: max(canvasSize.height - textLayer.position.y - 12, textLayer.fontSize * 2.0)
        )
        let measuredBounds = (textLayer.text as NSString).boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).integral
        let drawRect = CGRect(
            origin: textLayer.position,
            size: CGSize(
                width: max(measuredBounds.width, textLayer.fontSize * 0.5),
                height: max(measuredBounds.height, textLayer.fontSize * 1.2)
            )
        )
        return (drawRect, attributes)
    }

    static func drawTextLayer(
        _ textLayer: TextLayerData,
        resolved: (drawRect: CGRect, attributes: [NSAttributedString.Key: Any]),
        in context: CGContext
    ) {
        let drawRect = resolved.drawRect
        let anchor = CGPoint(x: drawRect.midX, y: drawRect.midY)
        let scale = CGFloat(min(max(textLayer.scale, 0.2), 6.0))
        context.saveGState()
        context.translateBy(x: anchor.x, y: anchor.y)
        context.rotate(by: CGFloat(textLayer.rotationDegrees * .pi / 180.0))
        context.scaleBy(x: scale, y: scale)
        let localRect = CGRect(
            x: -(drawRect.width / 2),
            y: -(drawRect.height / 2),
            width: drawRect.width,
            height: drawRect.height
        )
        (textLayer.text as NSString).draw(in: localRect, withAttributes: resolved.attributes)
        context.restoreGState()
    }
}
