import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

enum TimelapseExporter {
    private static let maxExportFrameCount = 90000

    static func exportVideo(
        from capture: TimelapseCapture,
        to directory: URL,
        progress: ((Double, URL) -> Void)? = nil
    ) throws -> URL {
        let exportFrames = sampledFrames(from: capture.frames)
        guard exportFrames.count >= 2 else {
            throw TimelapseExportError.insufficientFrames
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let outputURL = directory.appendingPathComponent(exportFilename())
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let targetSize = videoDimensions(for: capture, exportFrames: exportFrames)
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

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(capture.framesPerSecond, 1)))
        let holdFrameCount = max(capture.framesPerSecond * 2, 1)
        let totalFrameCount = exportFrames.count + holdFrameCount
        for (index, frame) in exportFrames.enumerated() {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.002)
            }

            guard let image = decodedImage(from: frame.imageURL) else {
                throw TimelapseExportError.invalidFrameData
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
                throw writer.error ?? TimelapseExportError.exportFailed
            }
            progress?(Double(index + 1) / Double(totalFrameCount), frame.imageURL)
        }

        guard let finalFrame = exportFrames.last,
              let finalImage = decodedImage(from: finalFrame.imageURL) else {
            throw TimelapseExportError.invalidFrameData
        }
        for holdIndex in 1...holdFrameCount {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.002)
            }

            var maybeBuffer: CVPixelBuffer?
            let creationStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &maybeBuffer)
            guard creationStatus == kCVReturnSuccess, let buffer = maybeBuffer else {
                throw TimelapseExportError.exportFailed
            }

            guard render(image: finalImage, into: buffer, targetSize: targetSize) else {
                throw TimelapseExportError.exportFailed
            }

            let presentationTime = CMTimeMultiply(
                frameDuration,
                multiplier: Int32(exportFrames.count - 1 + holdIndex)
            )
            guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? TimelapseExportError.exportFailed
            }
            progress?(Double(exportFrames.count + holdIndex) / Double(totalFrameCount), finalFrame.imageURL)
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

    private static func exportFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "atelierprime-timelapse-\(formatter.string(from: Date())).mp4"
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
}

enum TimelapseExportError: Error {
    case insufficientFrames
    case cannotAddWriterInput
    case failedToStartWriting
    case invalidFrameData
    case exportFailed
}
