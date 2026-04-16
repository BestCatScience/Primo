import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UIKit

enum TimelapseExporter {
    private static let maxExportFrameCount = 90000

    static func exportVideo(
        from capture: TimelapseCapture,
        to directory: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        progress: ((Double, URL) -> Void)? = nil
    ) throws -> URL {
        try fileClient.createDirectory(directory, true)
        let outputURL = directory.appendingPathComponent(exportFilename(date: dateClient.now()))
        if fileClient.fileExists(outputURL.path) {
            try fileClient.removeItem(outputURL)
        }

        let previewURL = directory.appendingPathComponent("timelapse-preview.jpg")
        if fileClient.fileExists(previewURL.path) {
            try fileClient.removeItem(previewURL)
        }

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(capture.framesPerSecond, 1)))
        let holdFrameCount = max(capture.framesPerSecond * 2, 1)
        let targetSize: CGSize
        let totalFrameCount: Int
        switch capture.source {
        case let .frames(frames):
            let exportFrames = sampledFrames(from: frames)
            guard exportFrames.count >= 2 else {
                throw TimelapseExportError.insufficientFrames
            }
            targetSize = videoDimensions(for: capture, exportFrames: exportFrames)
            totalFrameCount = exportFrames.count + holdFrameCount
        case let .operations(operations):
            let exportOperations = sampledOperations(from: operations)
            guard exportOperations.count >= 2 else {
                throw TimelapseExportError.insufficientFrames
            }
            targetSize = videoDimensions(for: capture, exportFrames: [])
            totalFrameCount = exportOperations.count + holdFrameCount
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: targetSize.width,
            AVVideoHeightKey: targetSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 5_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(targetSize.width),
            kCVPixelBufferHeightKey as String: Int(targetSize.height),
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourceAttributes
        )

        guard writer.canAdd(input) else {
            throw TimelapseExportError.cannotAddWriterInput
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? TimelapseExportError.failedToStartWriting
        }
        writer.startSession(atSourceTime: .zero)

        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw TimelapseExportError.exportFailed
        }

        switch capture.source {
        case let .frames(frames):
            let exportFrames = sampledFrames(from: frames)
            try appendFrameImages(
                exportFrames.map(\.imageURL),
                targetSize: targetSize,
                input: input,
                adaptor: adaptor,
                pixelBufferPool: pixelBufferPool,
                frameDuration: frameDuration,
                holdFrameCount: holdFrameCount,
                totalFrameCount: totalFrameCount,
                previewURL: previewURL,
                fileClient: fileClient,
                progress: progress
            )
        case let .operations(operations):
            let exportOperations = sampledOperations(from: operations)
            try appendOperationFrames(
                exportOperations,
                capture: capture,
                targetSize: targetSize,
                input: input,
                adaptor: adaptor,
                pixelBufferPool: pixelBufferPool,
                frameDuration: frameDuration,
                holdFrameCount: holdFrameCount,
                totalFrameCount: totalFrameCount,
                previewURL: previewURL,
                fileClient: fileClient,
                progress: progress
            )
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        var completionError: Error?
        writer.finishWriting {
            completionError = writer.error
            semaphore.signal()
        }
        semaphore.wait()

        if let completionError {
            throw completionError
        }
        if writer.status != .completed {
            throw writer.error ?? TimelapseExportError.exportFailed
        }

        return outputURL
    }

    private static func appendFrameImages(
        _ frameURLs: [URL],
        targetSize: CGSize,
        input: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        pixelBufferPool: CVPixelBufferPool,
        frameDuration: CMTime,
        holdFrameCount: Int,
        totalFrameCount: Int,
        previewURL: URL,
        fileClient: FileClient,
        progress: ((Double, URL) -> Void)?
    ) throws {
        for (index, frameURL) in frameURLs.enumerated() {
            guard let image = decodedImage(from: frameURL) else {
                throw TimelapseExportError.invalidFrameData
            }
            try appendRenderedImage(
                image,
                at: index,
                targetSize: targetSize,
                input: input,
                adaptor: adaptor,
                pixelBufferPool: pixelBufferPool,
                frameDuration: frameDuration
            )
            try writePreview(image: image, to: previewURL, fileClient: fileClient)
            progress?(Double(index + 1) / Double(totalFrameCount), previewURL)
        }

        guard let finalFrameURL = frameURLs.last,
              let finalImage = decodedImage(from: finalFrameURL) else {
            throw TimelapseExportError.invalidFrameData
        }

        for holdIndex in 1...holdFrameCount {
            try appendRenderedImage(
                finalImage,
                at: frameURLs.count - 1 + holdIndex,
                targetSize: targetSize,
                input: input,
                adaptor: adaptor,
                pixelBufferPool: pixelBufferPool,
                frameDuration: frameDuration
            )
            try writePreview(image: finalImage, to: previewURL, fileClient: fileClient)
            progress?(Double(frameURLs.count + holdIndex) / Double(totalFrameCount), previewURL)
        }
    }

    private static func appendOperationFrames(
        _ operations: [TimelapseOperation],
        capture: TimelapseCapture,
        targetSize: CGSize,
        input: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        pixelBufferPool: CVPixelBufferPool,
        frameDuration: CMTime,
        holdFrameCount: Int,
        totalFrameCount: Int,
        previewURL: URL,
        fileClient: FileClient,
        progress: ((Double, URL) -> Void)?
    ) throws {
        let replaySession = PaintDocumentSession(
            width: max(Int(capture.canvasSize.width.rounded()), 1),
            height: max(Int(capture.canvasSize.height.rounded()), 1),
            fileClient: fileClient
        )
        var folderIDMap: [DocumentFolderID: Int] = [:]
        var finalImage: CGImage?

        for (index, operation) in operations.enumerated() {
            replaySession.replayTimelapseOperation(operation, folderIDMap: &folderIDMap)
            guard let image = replaySession.timelapseCompositeImage()?.cgImage else {
                throw TimelapseExportError.exportFailed
            }
            finalImage = image
            try appendRenderedImage(
                image,
                at: index,
                targetSize: targetSize,
                input: input,
                adaptor: adaptor,
                pixelBufferPool: pixelBufferPool,
                frameDuration: frameDuration
            )
            try writePreview(image: image, to: previewURL, fileClient: fileClient)
            progress?(Double(index + 1) / Double(totalFrameCount), previewURL)
        }

        guard let finalImage else {
            throw TimelapseExportError.insufficientFrames
        }

        for holdIndex in 1...holdFrameCount {
            try appendRenderedImage(
                finalImage,
                at: operations.count - 1 + holdIndex,
                targetSize: targetSize,
                input: input,
                adaptor: adaptor,
                pixelBufferPool: pixelBufferPool,
                frameDuration: frameDuration
            )
            try writePreview(image: finalImage, to: previewURL, fileClient: fileClient)
            progress?(Double(operations.count + holdIndex) / Double(totalFrameCount), previewURL)
        }
    }

    private static func appendRenderedImage(
        _ image: CGImage,
        at index: Int,
        targetSize: CGSize,
        input: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        pixelBufferPool: CVPixelBufferPool,
        frameDuration: CMTime
    ) throws {
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.002)
        }

        var maybeBuffer: CVPixelBuffer?
        let creationStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &maybeBuffer)
        guard creationStatus == kCVReturnSuccess, let buffer = maybeBuffer else {
            throw TimelapseExportError.exportFailed
        }

        guard render(image: image, into: buffer, targetSize: targetSize) else {
            throw TimelapseExportError.exportFailed
        }

        let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))
        guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
            throw TimelapseExportError.exportFailed
        }
    }

    private static func decodedImage(from url: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }

    private static func render(image: CGImage, into pixelBuffer: CVPixelBuffer, targetSize: CGSize) -> Bool {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return false
        }

        context.setFillColor(CGColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: targetSize))

        let imageRect = AVMakeRect(
            aspectRatio: CGSize(width: image.width, height: image.height),
            insideRect: CGRect(origin: .zero, size: targetSize)
        )
        context.draw(image, in: imageRect)
        return true
    }

    private static func videoDimensions(for capture: TimelapseCapture, exportFrames: [TimelapseFrame]) -> CGSize {
        let sourceSize = exportFrames.last?.size ?? capture.canvasSize
        let width = max(Int(sourceSize.width.rounded()), 2)
        let height = max(Int(sourceSize.height.rounded()), 2)
        let evenWidth = width.isMultiple(of: 2) ? width : width + 1
        let evenHeight = height.isMultiple(of: 2) ? height : height + 1
        return CGSize(width: evenWidth, height: evenHeight)
    }

    private static func exportFilename(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "primo-timelapse-\(formatter.string(from: date)).mp4"
    }

    private static func sampledFrames(from frames: [TimelapseFrame]) -> [TimelapseFrame] {
        guard frames.count > maxExportFrameCount else {
            return frames
        }

        let sampleCount = maxExportFrameCount - 1
        let stride = Double(frames.count - 1) / Double(sampleCount)
        var sampled: [TimelapseFrame] = []
        sampled.reserveCapacity(maxExportFrameCount)

        for index in 0..<sampleCount {
            let sourceIndex = min(Int((Double(index) * stride).rounded()), frames.count - 1)
            if sampled.last?.imageURL != frames[sourceIndex].imageURL {
                sampled.append(frames[sourceIndex])
            }
        }

        if sampled.last?.imageURL != frames.last?.imageURL, let last = frames.last {
            sampled.append(last)
        }

        return sampled
    }

    private static func sampledOperations(from operations: [TimelapseOperation]) -> [TimelapseOperation] {
        guard operations.count > maxExportFrameCount else {
            return operations
        }

        let sampleCount = maxExportFrameCount - 1
        let stride = Double(operations.count - 1) / Double(sampleCount)
        var sampled: [TimelapseOperation] = []
        sampled.reserveCapacity(maxExportFrameCount)

        for index in 0..<sampleCount {
            let sourceIndex = min(Int((Double(index) * stride).rounded()), operations.count - 1)
            sampled.append(operations[sourceIndex])
        }

        if sampled.count < maxExportFrameCount, let last = operations.last {
            sampled.append(last)
        } else if let last = operations.last {
            sampled[sampled.count - 1] = last
        }

        return sampled
    }

    private static func writePreview(image: CGImage, to url: URL, fileClient: FileClient) throws {
        guard let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.72) else {
            throw TimelapseExportError.exportFailed
        }
        try fileClient.writeData(data, url, .atomic)
    }
}

enum TimelapseExportError: Error {
    case insufficientFrames
    case cannotAddWriterInput
    case failedToStartWriting
    case invalidFrameData
    case exportFailed
}
