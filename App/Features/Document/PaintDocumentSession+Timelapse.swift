import CoreGraphics
import Foundation
import UIKit

extension PaintDocumentSession {
    func setPaperStyle(_ style: CanvasPaperStyle) {
        guard paperStyle != style else { return }
        paperStyle = style
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setPaperStyle(style),
                captureFrame: false
            )
        )
    }

    func timelapseCapture() -> TimelapseCapture? {
        let previewData = makeTimelapseThumbnail()?.jpegData(compressionQuality: 0.72)
        if usesOperationTimelapsePersistence, !timelapseEvents.isEmpty {
            return TimelapseCapture(
                canvasSize: CGSize(width: bridge.width, height: bridge.height),
                paperStyle: paperStyle,
                previewImageData: previewData,
                source: .operations(timelapseEvents),
                framesPerSecond: 24
            )
        }

        guard timelapseFrames.count >= 2 else { return nil }
        return TimelapseCapture(
            canvasSize: CGSize(width: bridge.width, height: bridge.height),
            paperStyle: paperStyle,
            previewImageData: previewData,
            source: .frames(timelapseFrames),
            framesPerSecond: 24
        )
    }

    func replayTimelapseOperation(_ operation: TimelapseOperation, folderIDMap: inout [Int: Int]) {
        switch operation {
        case let .stroke(layerIndex, brush, samples):
            guard let first = samples.first else { return }
            bridge.activeLayerIndex = layerIndex
            bridge.beginStroke(brush: makeBrushDescriptor(from: brush), point: makeStrokePoint(from: first))
            for sample in samples.dropFirst() {
                bridge.appendStroke(point: makeStrokePoint(from: sample))
            }
            bridge.endStroke()
            invalidateThumbnailCache(for: layerIndex)

        case let .blurStroke(layerIndex, brush, samples):
            applyBlurStroke(samples: samples, brush: brush, layerIndex: layerIndex)
            invalidateThumbnailCache(for: layerIndex)

        case let .fill(layerIndex, brush, sample):
            bridge.activeLayerIndex = layerIndex
            bridge.fill(at: sample.point, brush: makeBrushDescriptor(from: brush))
            invalidateThumbnailCache(for: layerIndex)

        case .undo:
            _ = bridge.undo()
            invalidateThumbnailCache()

        case .redo:
            _ = bridge.redo()
            invalidateThumbnailCache()

        case let .addLayer(name):
            bridge.activeLayerIndex = bridge.addLayer(name: name)
            invalidateThumbnailCache()

        case let .duplicateLayer(index, name):
            bridge.activeLayerIndex = bridge.duplicateLayer(at: index, name: name)
            invalidateThumbnailCache()

        case let .deleteLayer(index):
            _ = bridge.deleteLayer(at: index)
            invalidateThumbnailCache()

        case let .moveLayer(index, destinationIndex):
            _ = bridge.moveLayer(at: index, to: destinationIndex)
            invalidateThumbnailCache()

        case let .createFolder(folderID, name, anchorLayerIndex):
            let createdID = Int(bridge.createFolder(name: name, layerIndex: anchorLayerIndex ?? -1))
            folderIDMap[folderID] = createdID

        case let .deleteFolder(folderID):
            if let resolved = folderIDMap[folderID] {
                _ = bridge.deleteFolder(id: resolved)
                folderIDMap.removeValue(forKey: folderID)
            }

        case let .setFolderVisibility(folderID, isVisible):
            if let resolved = folderIDMap[folderID] {
                bridge.setFolderVisible(isVisible, folderID: resolved)
            }

        case let .assignLayerToFolder(index, folderID):
            let resolvedFolderID = folderID.flatMap { folderIDMap[$0] } ?? -1
            _ = bridge.setLayerFolder(at: index, folderID: resolvedFolderID)
            invalidateThumbnailCache()

        case let .setLayerVisibility(index, isVisible):
            bridge.setLayerVisible(isVisible, at: index)
            invalidateThumbnailCache(for: index)

        case let .setLayerLocked(index, isLocked):
            bridge.setLayerLocked(isLocked, at: index)
            invalidateThumbnailCache(for: index)

        case let .setLayerAlphaLocked(index, isAlphaLocked):
            bridge.setLayerAlphaLocked(isAlphaLocked, at: index)
            invalidateThumbnailCache(for: index)

        case let .setLayerClipped(index, isClipped):
            bridge.setLayerClipped(isClipped, at: index)
            invalidateThumbnailCache(for: index)

        case let .setLayerOpacity(index, opacity):
            bridge.setLayerOpacity(CGFloat(opacity), at: index)
            invalidateThumbnailCache(for: index)

        case let .setLayerBlendMode(index, blendMode):
            bridge.setLayerBlendMode(blendMode.rawValue, at: index)
            invalidateThumbnailCache(for: index)

        case let .replaceLayerPixels(index, data):
            bridge.replaceLayerPixels(at: index, data: data)
            invalidateThumbnailCache(for: index)

        case let .replaceLayerMask(index, data):
            bridge.replaceLayerMask(at: index, data: data)
            invalidateThumbnailCache(for: index)

        case let .clearLayerMask(index):
            bridge.clearLayerMask(at: index)
            invalidateThumbnailCache(for: index)

        case let .applyLayerMask(index):
            _ = bridge.applyLayerMask(at: index)
            invalidateThumbnailCache(for: index)

        case let .clearLayer(index):
            bridge.clearLayer(at: index)
            invalidateThumbnailCache(for: index)

        case let .setPaperStyle(style):
            paperStyle = style
        }
    }

    func timelapseCompositeImage() -> UIImage? {
        renderedCompositeImage(paperStyle: paperStyle)
    }

    func captureTimelapseFrame() {
        guard let sourceImage = makeTimelapseThumbnail() else { return }
        appendTimelapseFrame(image: sourceImage)
    }

    func makeTimelapseThumbnail() -> UIImage? {
        guard let sourceImage = renderedCompositeImage(paperStyle: paperStyle) else { return nil }
        let targetSize = timelapseFrameSize(
            for: CGSize(width: bridge.width, height: bridge.height),
            maxDimension: 512
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func appendTimelapseFrame(image: UIImage) {
        guard let jpegData = image.jpegData(compressionQuality: 0.72) else { return }
        let frameURL = timelapseService.makeFrameURL(in: timelapseDirectoryURL, frameID: nextTimelapseFrameID)
        nextTimelapseFrameID += 1
        do {
            try timelapseService.persistFrameData(jpegData, to: frameURL)
        } catch {
            Self.logger.error("Failed to persist timelapse frame: \(error.localizedDescription, privacy: .public)")
            return
        }

        let frame = TimelapseFrame(imageURL: frameURL, size: image.size)
        timelapseFrames.append(frame)
        if timelapseFrames.count > Self.maxTimelapseFrames {
            let removed = timelapseFrames.remove(at: 1)
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
        guard let imageRef = bridge.makeCompositeImage() else { return nil }
        let compositeImage = UIImage(cgImage: imageRef)
        let size = CGSize(width: bridge.width, height: bridge.height)
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
        if let cached = layerThumbnailCache[index] {
            return cached
        }
        let thumbnail = makeLayerThumbnailData(index: index)
        layerThumbnailCache[index] = thumbnail
        return thumbnail
    }

    func makeLayerThumbnailData(index: Int) -> Data? {
        guard let imageRef = bridge.makeImageForLayer(at: index) else { return nil }
        let sourceImage = UIImage(cgImage: imageRef)
        let targetSize = timelapseFrameSize(
            for: CGSize(width: bridge.width, height: bridge.height),
            maxDimension: 96
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let thumbnail = renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return thumbnail.pngData()
    }

    func resetTimelapseHistory() {
        for frame in timelapseFrames {
            try? timelapseService.removeFrame(at: frame.imageURL)
        }
        timelapseFrames.removeAll(keepingCapacity: false)
        timelapseEvents.removeAll(keepingCapacity: false)
        nextTimelapseFrameID = 0
    }

    func invalidateThumbnailCache(for index: Int? = nil) {
        if let index {
            layerThumbnailCache.removeValue(forKey: index)
        } else {
            layerThumbnailCache.removeAll(keepingCapacity: true)
        }
    }
}
