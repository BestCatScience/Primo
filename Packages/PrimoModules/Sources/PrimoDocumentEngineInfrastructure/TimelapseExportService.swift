import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import PrimoCoreTypes
import PrimoDocumentContracts
import UniformTypeIdentifiers

public struct TimelapseExportProgress: Equatable, Sendable {
    public var progress: Double
    public var previewImageData: Data?

    public init(progress: Double, previewImageData: Data?) {
        self.progress = progress
        self.previewImageData = previewImageData
    }
}

public struct TimelapseExportResult: Equatable, Sendable {
    public var url: URL

    public init(url: URL) {
        self.url = url
    }
}

public enum TimelapseExportError: Error {
    case insufficientFrames
    case cannotAddWriterInput
    case failedToStartWriting
    case invalidFrameData
    case exportFailed
}

public enum TimelapseExportService {
    private static let maxExportFrameCount = 90000

    public static func exportVideo(
        from capture: TimelapseCapture,
        to directory: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        progress: ((TimelapseExportProgress) -> Void)? = nil
    ) throws -> TimelapseExportResult {
        try fileClient.createDirectory(directory, true)
        let outputURL = directory.appendingPathComponent(exportFilename(date: dateClient.now()))
        if fileClient.fileExists(outputURL.path) {
            try fileClient.removeItem(outputURL)
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
                progress: progress
            )
        case let .operations(operations):
            let exportOperations = sampledOperations(from: operations)
            try appendOperationFrames(
                exportOperations,
                capture: capture,
                fileClient: fileClient,
                targetSize: targetSize,
                input: input,
                adaptor: adaptor,
                pixelBufferPool: pixelBufferPool,
                frameDuration: frameDuration,
                holdFrameCount: holdFrameCount,
                totalFrameCount: totalFrameCount,
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

        return TimelapseExportResult(url: outputURL)
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
        progress: ((TimelapseExportProgress) -> Void)?
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
            progress?(
                TimelapseExportProgress(
                    progress: Double(index + 1) / Double(totalFrameCount),
                    previewImageData: makePreviewData(image: image)
                )
            )
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
            progress?(
                TimelapseExportProgress(
                    progress: Double(frameURLs.count + holdIndex) / Double(totalFrameCount),
                    previewImageData: makePreviewData(image: finalImage)
                )
            )
        }
    }

    private static func appendOperationFrames(
        _ operations: [TimelapseOperation],
        capture: TimelapseCapture,
        fileClient: FileClient,
        targetSize: CGSize,
        input: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        pixelBufferPool: CVPixelBufferPool,
        frameDuration: CMTime,
        holdFrameCount: Int,
        totalFrameCount: Int,
        progress: ((TimelapseExportProgress) -> Void)?
    ) throws {
        let replayService = DocumentTimelapseReplayService(
            canvasSize: capture.canvasSize,
            fileClient: fileClient
        )
        var finalImage: CGImage?

        for (index, operation) in operations.enumerated() {
            guard let image = replayService.replay(operation) else {
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
            progress?(
                TimelapseExportProgress(
                    progress: Double(index + 1) / Double(totalFrameCount),
                    previewImageData: makePreviewData(image: image)
                )
            )
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
            progress?(
                TimelapseExportProgress(
                    progress: Double(operations.count + holdIndex) / Double(totalFrameCount),
                    previewImageData: makePreviewData(image: finalImage)
                )
            )
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

        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer) == kCVReturnSuccess,
              let pixelBuffer else {
            throw TimelapseExportError.exportFailed
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw TimelapseExportError.exportFailed
        }

        context.clear(CGRect(origin: .zero, size: targetSize))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: targetSize))

        let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))
        guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            throw TimelapseExportError.exportFailed
        }
    }

    private static func decodedImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func makePreviewData(image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }

    private static func videoDimensions(
        for capture: TimelapseCapture,
        exportFrames: [TimelapseFrame]
    ) -> CGSize {
        if let firstFrame = exportFrames.first,
           let image = decodedImage(from: firstFrame.imageURL) {
            return CGSize(width: image.width, height: image.height)
        }
        return capture.canvasSize
    }

    private static func sampledFrames(from frames: [TimelapseFrame]) -> [TimelapseFrame] {
        sample(items: frames)
    }

    private static func sampledOperations(from operations: [TimelapseOperation]) -> [TimelapseOperation] {
        sample(items: operations)
    }

    private static func sample<Item>(items: [Item]) -> [Item] {
        guard items.count > maxExportFrameCount else { return items }
        let step = Double(items.count - 1) / Double(maxExportFrameCount - 1)
        return (0..<maxExportFrameCount).map { index in
            let itemIndex = min(Int((Double(index) * step).rounded()), items.count - 1)
            return items[itemIndex]
        }
    }

    private static func exportFilename(date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let raw = formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
        return "timelapse-\(raw).mp4"
    }
}
