import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func captureTimelapseFrame() {
        guard let sourceImage = makeTimelapseThumbnail() else { return }
        appendTimelapseFrame(image: sourceImage)
    }

    func makeTimelapseThumbnail() -> CGImage? {
        guard let sourceImage = renderedCompositeImage(paperStyle: paperStyleValue) else { return nil }
        let targetSize = timelapseFrameSize(
            for: documentGateway.queries.canvasSize,
            maxDimension: 512
        )
        return DocumentImageCodec.scaledImage(sourceImage, to: targetSize)
    }

    func appendTimelapseFrame(image: CGImage) {
        guard let jpegData = DocumentImageCodec.jpegData(from: image) else { return }
        let frameURL = reserveNextTimelapseFrameURL()
        do {
            try timelapseService.persistFrameData(jpegData, to: frameURL)
        } catch {
            Self.logger.error("Failed to persist timelapse frame: \(error.localizedDescription, privacy: .public)")
            return
        }

        let frame = TimelapseFrame(
            imageURL: frameURL,
            size: CGSize(width: image.width, height: image.height)
        )
        if let removed = appendStoredTimelapseFrame(frame) {
            do {
                // Best-effort cleanup for evicted timelapse frames.
                try timelapseService.removeFrame(at: removed.imageURL)
            } catch {
            }
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

    func renderedCompositeImage(paperStyle: CanvasPaperStyle) -> CGImage? {
        guard let imageRef = documentGateway.queries.compositeImageRef() else { return nil }
        let size = documentGateway.queries.canvasSize
        return DocumentImageCodec.compositedImage(base: imageRef, canvasSize: size, paperStyle: paperStyle)
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
        guard let imageRef = documentGateway.queries.imageRefForLayer(index: index) else { return nil }
        let targetSize = timelapseFrameSize(
            for: documentGateway.queries.canvasSize,
            maxDimension: 96
        )
        guard let thumbnail = DocumentImageCodec.scaledImage(imageRef, to: targetSize) else { return nil }
        return DocumentImageCodec.pngData(from: thumbnail)
    }

    func resetTimelapseHistory() {
        for frame in resetStoredTimelapseHistory() {
            do {
                // Best-effort cleanup for discarded timelapse frames.
                try timelapseService.removeFrame(at: frame.imageURL)
            } catch {
            }
        }
    }

    func invalidateThumbnailCache(for index: Int? = nil) {
        invalidateStoredThumbnailCache(for: index)
    }
}
