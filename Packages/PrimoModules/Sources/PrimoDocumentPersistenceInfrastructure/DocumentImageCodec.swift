import CoreGraphics
import Foundation
import ImageIO
import PrimoDocumentDomain
import UniformTypeIdentifiers

/// Legacy external-format codec helpers.
/// Live document rendering and mutation paths should prefer `DocumentCompositeSurface`
/// plus `DocumentRasterImageService` or Metal surface APIs instead of bridging through `CGImage`.
public enum DocumentImageCodec {
    public static func pngData(from image: CGImage) -> Data? {
        encodedData(from: image, typeIdentifier: UTType.png.identifier as CFString)
    }

    public static func jpegData(from image: CGImage, compressionQuality: CGFloat = 0.72) -> Data? {
        encodedData(
            from: image,
            typeIdentifier: UTType.jpeg.identifier as CFString,
            compressionQuality: compressionQuality
        )
    }

    public static func scaledImage(_ image: CGImage, to targetSize: CGSize, opaque: Bool = false) -> CGImage? {
        renderedImage(size: targetSize, opaque: opaque) { context in
            context.draw(image, in: CGRect(origin: .zero, size: targetSize))
        }
    }

    public static func compositedImage(
        base image: CGImage,
        canvasSize: CGSize,
        paperStyle: CanvasPaperStyle
    ) -> CGImage? {
        if paperStyle.isTransparent {
            return renderedImage(size: canvasSize, opaque: false) { context in
                context.draw(image, in: CGRect(origin: .zero, size: canvasSize))
            }
        }
        return renderedImage(size: canvasSize, opaque: true) { context in
            context.setFillColor(
                CGColor(
                    red: CGFloat(paperStyle.red),
                    green: CGFloat(paperStyle.green),
                    blue: CGFloat(paperStyle.blue),
                    alpha: CGFloat(paperStyle.alpha)
                )
            )
            context.fill(CGRect(origin: .zero, size: canvasSize))
            context.draw(image, in: CGRect(origin: .zero, size: canvasSize))
        }
    }

    private static func encodedData(
        from image: CGImage,
        typeIdentifier: CFString,
        compressionQuality: CGFloat? = nil
    ) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, typeIdentifier, 1, nil) else {
            return nil
        }
        var options: [CFString: Any] = [:]
        if let compressionQuality {
            options[kCGImageDestinationLossyCompressionQuality] = compressionQuality
        }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func renderedImage(
        size: CGSize,
        opaque: Bool,
        draw: (CGContext) -> Void
    ) -> CGImage? {
        let width = max(Int(size.width.rounded()), 1)
        let height = max(Int(size.height.rounded()), 1)
        let alphaInfo = opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: alphaInfo.rawValue).rawValue
        ) else {
            return nil
        }
        draw(context)
        return context.makeImage()
    }
}
