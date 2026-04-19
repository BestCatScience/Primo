import CoreGraphics
import Foundation
import PrimoDocumentDomain

#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
private typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
private typealias PlatformColor = NSColor
private typealias PlatformFont = NSFont
#endif

public enum DocumentTextRasterizer {
    public struct ResolvedLayout: Sendable {
        public let drawRect: CGRect
        public let fontName: String
        public let fontSize: Double
        public let red: Double
        public let green: Double
        public let blue: Double
        public let alpha: Double

        public init(
            drawRect: CGRect,
            fontName: String,
            fontSize: Double,
            red: Double,
            green: Double,
            blue: Double,
            alpha: Double
        ) {
            self.drawRect = drawRect
            self.fontName = fontName
            self.fontSize = fontSize
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }

    public static func resolvedTextLayout(
        for textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> ResolvedLayout? {
        #if canImport(UIKit) || canImport(AppKit)
        let font = PlatformFont(name: textLayer.fontPostScriptName, size: textLayer.fontSize)
            ?? systemFont(ofSize: textLayer.fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: platformColor(for: textLayer),
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
        return ResolvedLayout(
            drawRect: drawRect,
            fontName: font.fontName,
            fontSize: font.pointSize,
            red: textLayer.red,
            green: textLayer.green,
            blue: textLayer.blue,
            alpha: textLayer.alpha
        )
        #else
        return nil
        #endif
    }

    public static func drawTextLayer(
        _ textLayer: TextLayerData,
        resolved: ResolvedLayout,
        in context: CGContext
    ) {
        #if canImport(UIKit) || canImport(AppKit)
        let font = PlatformFont(name: resolved.fontName, size: resolved.fontSize)
            ?? systemFont(ofSize: resolved.fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: PlatformColor(
                red: resolved.red,
                green: resolved.green,
                blue: resolved.blue,
                alpha: resolved.alpha
            ),
            .paragraphStyle: paragraphStyle
        ]
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
        pushGraphicsContext(context)
        (textLayer.text as NSString).draw(in: localRect, withAttributes: attributes)
        popGraphicsContext()
        context.restoreGState()
        #endif
    }

    public static func pixelData(
        from cgImage: CGImage,
        size: CGSize
    ) -> Data? {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        var data = Data(count: bytesPerRow * height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )
        let rendered = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                return false
            }
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        return rendered ? data : nil
    }

    public static func rasterizedPixelData(
        for textLayer: TextLayerData,
        canvasSize: CGSize
    ) -> Data? {
        guard
            canvasSize.width > 0,
            canvasSize.height > 0,
            let resolved = resolvedTextLayout(for: textLayer, canvasSize: canvasSize)
        else {
            return nil
        }

        let width = Int(canvasSize.width.rounded())
        let height = Int(canvasSize.height.rounded())
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        var data = Data(count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )

        let rendered = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                return false
            }
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            drawTextLayer(textLayer, resolved: resolved, in: context)
            return true
        }

        return rendered ? data : nil
    }

    #if canImport(UIKit) || canImport(AppKit)
    private static func platformColor(for textLayer: TextLayerData) -> PlatformColor {
        PlatformColor(
            red: textLayer.red,
            green: textLayer.green,
            blue: textLayer.blue,
            alpha: textLayer.alpha
        )
    }

    private static func systemFont(ofSize size: Double) -> PlatformFont {
        #if canImport(UIKit)
        return PlatformFont.systemFont(ofSize: size, weight: .regular)
        #else
        return PlatformFont.systemFont(ofSize: size)
        #endif
    }

    private static func pushGraphicsContext(_ context: CGContext) {
        #if canImport(UIKit)
        UIGraphicsPushContext(context)
        #elseif canImport(AppKit)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        #endif
    }

    private static func popGraphicsContext() {
        #if canImport(UIKit)
        UIGraphicsPopContext()
        #elseif canImport(AppKit)
        NSGraphicsContext.restoreGraphicsState()
        #endif
    }
    #endif
}
