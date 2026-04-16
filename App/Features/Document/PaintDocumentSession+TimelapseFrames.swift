import CoreGraphics
import Foundation
import UIKit

extension PaintDocumentSession {
    func captureTimelapseFrame() {
        guard let sourceImage = makeTimelapseThumbnail() else { return }
        appendTimelapseFrame(image: sourceImage)
    }

    func makeTimelapseThumbnail() -> UIImage? {
        guard let sourceImage = renderedCompositeImage(paperStyle: paperStyleValue) else { return nil }
        let targetSize = timelapseFrameSize(
            for: bridgeCanvasSize,
            maxDimension: 512
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func appendTimelapseFrame(image: UIImage) {
        guard let jpegData = image.jpegData(compressionQuality: 0.72) else { return }
        let frameURL = reserveNextTimelapseFrameURL()
        do {
            try timelapseService.persistFrameData(jpegData, to: frameURL)
        } catch {
            Self.logger.error("Failed to persist timelapse frame: \(error.localizedDescription, privacy: .public)")
            return
        }

        let frame = TimelapseFrame(imageURL: frameURL, size: image.size)
        if let removed = appendStoredTimelapseFrame(frame) {
            try? timelapseService.removeFrame(at: removed.imageURL)
        }
    }

    static func makeTimelapseDirectoryURL(fileClient: FileClient, uuidClient: UUIDClient) -> URL {
        fileClient.temporaryDirectory()
            .appendingPathComponent("primo-timelapse", isDirectory: true)
            .appendingPathComponent(uuidClient.generate().uuidString, isDirectory: true)
    }

    func timelapseFrameSize(for canvasSize: CGSize, maxDimension: CGFloat) -> CGSize {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return CGSize(width: maxDimension, height: maxDimension)
        }
        let scale = min(maxDimension / canvasSize.width, maxDimension / canvasSize.height, 1.0)
        let width = max(2, Int((canvasSize.width * scale).rounded()))
        let height = max(2, Int((canvasSize.height * scale).rounded()))
        return CGSize(width: width, height: height)
    }

    func renderedCompositeImage(paperStyle: CanvasPaperStyle) -> UIImage? {
        guard let imageRef = bridgeCompositeImageRef() else { return nil }
        let compositeImage = UIImage(cgImage: imageRef)
        let size = bridgeCanvasSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !paperStyle.isTransparent
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            if !paperStyle.isTransparent {
                UIColor(
                    red: CGFloat(paperStyle.red),
                    green: CGFloat(paperStyle.green),
                    blue: CGFloat(paperStyle.blue),
                    alpha: CGFloat(paperStyle.alpha)
                ).setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            compositeImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func cachedLayerThumbnailData(index: Int) -> Data? {
        if let cached = cachedThumbnailData(for: index) {
            return cached
        }
        let thumbnail = makeLayerThumbnailData(index: index)
        storeThumbnailData(thumbnail, for: index)
        return thumbnail
    }

    func makeLayerThumbnailData(index: Int) -> Data? {
        guard let imageRef = bridgeImageRefForLayer(index: index) else { return nil }
        let sourceImage = UIImage(cgImage: imageRef)
        let targetSize = timelapseFrameSize(
            for: bridgeCanvasSize,
            maxDimension: 96
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let thumbnail = renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return thumbnail.pngData()
    }

    func resetTimelapseHistory() {
        for frame in resetStoredTimelapseHistory() {
            try? timelapseService.removeFrame(at: frame.imageURL)
        }
    }

    func invalidateThumbnailCache(for index: Int? = nil) {
        invalidateStoredThumbnailCache(for: index)
    }
}
