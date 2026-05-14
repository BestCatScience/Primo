import AVFoundation
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts

public struct TimelapseExportProgress: Equatable, Sendable {
    public var progress: Double
    public var previewSurface: DocumentCompositeSurface?
    public var previewImageData: Data?

    public init(
        progress: Double,
        previewSurface: DocumentCompositeSurface? = nil,
        previewImageData: Data?
    ) {
        self.progress = progress
        self.previewSurface = previewSurface
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
    case cancelled
}

public enum TimelapseExportService {
    private static let maxExportFrameCount = 90000
    private static let progressPreviewInterval: TimeInterval = 0.25
    private static let progressPreviewStep = 0.01

    public static func exportVideo(
        from capture: TimelapseCapture,
        to directory: URL,
        progress: ((TimelapseExportProgress) -> Void)? = nil
    ) throws -> TimelapseExportResult {
        try exportVideo(
            from: capture,
            to: directory,
            fileClient: .live,
            dateClient: .live,
            progress: progress
        )
    }

    public static func exportVideo(
        from capture: TimelapseCapture,
        to directory: URL,
        fileClient: FileClient,
        dateClient: DateClient,
        progress: ((TimelapseExportProgress) -> Void)? = nil
    ) throws -> TimelapseExportResult {
        try checkCancellation()
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
            targetSize = videoDimensions(for: capture, exportFrames: exportFrames, fileClient: fileClient)
            totalFrameCount = exportFrames.count + holdFrameCount
        case let .operations(operations):
            let exportOperations = sampledOperations(from: operations)
            guard exportOperations.count >= 2 else {
                throw TimelapseExportError.insufficientFrames
            }
            targetSize = videoDimensions(for: capture, exportFrames: [], fileClient: fileClient)
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
                fileClient: fileClient,
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
        try checkCancellation()
        let semaphore = DispatchSemaphore(value: 0)
        var completionError: Error?
        writer.finishWriting {
            completionError = writer.error
            semaphore.signal()
        }
        while semaphore.wait(timeout: .now() + 0.05) == .timedOut {
            try checkCancellation()
        }

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
        fileClient: FileClient,
        input: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        pixelBufferPool: CVPixelBufferPool,
        frameDuration: CMTime,
        holdFrameCount: Int,
        totalFrameCount: Int,
        progress: ((TimelapseExportProgress) -> Void)?
    ) throws {
        var progressGate = ProgressPreviewGate()
        for (index, frameURL) in frameURLs.enumerated() {
            try checkCancellation()
            guard let surface = decodedSurface(from: frameURL, fileClient: fileClient) else {
                throw TimelapseExportError.invalidFrameData
            }
            try appendRenderedSurface(
                surface,
                at: index,
                targetSize: targetSize,
                input: input,
                adaptor: adaptor,
                pixelBufferPool: pixelBufferPool,
                frameDuration: frameDuration
            )
            emitProgressIfNeeded(
                progress: progress,
                gate: &progressGate,
                completed: index + 1,
                total: totalFrameCount,
                surface: surface
            )
        }

        guard let finalFrameURL = frameURLs.last,
              let finalSurface = decodedSurface(from: finalFrameURL, fileClient: fileClient) else {
            throw TimelapseExportError.invalidFrameData
        }

        for holdIndex in 1...holdFrameCount {
            try checkCancellation()
            try appendRenderedSurface(
                finalSurface,
                at: frameURLs.count - 1 + holdIndex,
                targetSize: targetSize,
                input: input,
                adaptor: adaptor,
                pixelBufferPool: pixelBufferPool,
                frameDuration: frameDuration
            )
            emitProgressIfNeeded(
                progress: progress,
                gate: &progressGate,
                completed: frameURLs.count + holdIndex,
                total: totalFrameCount,
                surface: finalSurface
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
        var progressGate = ProgressPreviewGate()
        let replayService = DocumentTimelapseReplayService(
            canvasSize: capture.canvasSize,
            fileClient: fileClient
        )
        var finalSurface: DocumentCompositeSurface?

        for (index, operation) in operations.enumerated() {
            try checkCancellation()
            guard let surface = replayService.replaySurface(operation) else {
                throw TimelapseExportError.exportFailed
            }
            finalSurface = surface
            try appendRenderedSurface(
                surface,
                at: index,
                targetSize: targetSize,
                input: input,
                adaptor: adaptor,
                pixelBufferPool: pixelBufferPool,
                frameDuration: frameDuration
            )
            emitProgressIfNeeded(
                progress: progress,
                gate: &progressGate,
                completed: index + 1,
                total: totalFrameCount,
                surface: surface
            )
        }

        guard let finalSurface else {
            throw TimelapseExportError.insufficientFrames
        }

        for holdIndex in 1...holdFrameCount {
            try checkCancellation()
            try appendRenderedSurface(
                finalSurface,
                at: operations.count - 1 + holdIndex,
                targetSize: targetSize,
                input: input,
                adaptor: adaptor,
                pixelBufferPool: pixelBufferPool,
                frameDuration: frameDuration
            )
            emitProgressIfNeeded(
                progress: progress,
                gate: &progressGate,
                completed: operations.count + holdIndex,
                total: totalFrameCount,
                surface: finalSurface
            )
        }
    }

    private static func appendRenderedSurface(
        _ surface: DocumentCompositeSurface,
        at index: Int,
        targetSize: CGSize,
        input: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        pixelBufferPool: CVPixelBufferPool,
        frameDuration: CMTime
    ) throws {
        while !input.isReadyForMoreMediaData {
            try checkCancellation()
            Thread.sleep(forTimeInterval: 0.002)
        }

        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer) == kCVReturnSuccess,
              let pixelBuffer else {
            throw TimelapseExportError.exportFailed
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard writeSurface(surface, into: pixelBuffer, targetSize: targetSize) else {
            throw TimelapseExportError.exportFailed
        }

        let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))
        guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            throw TimelapseExportError.exportFailed
        }
    }

    private static func decodedSurface(from url: URL, fileClient: FileClient) -> DocumentCompositeSurface? {
        guard let data = try? fileClient.readData(url),
              let decoded = DocumentRasterImageService.decodedImage(fromEncodedData: data) else {
            return nil
        }
        return DocumentCompositeSurface(
            validatingWidth: decoded.width,
            height: decoded.height,
            pixelData: decoded.pixelData
        )
    }

    private static func makePreviewData(surface: DocumentCompositeSurface) -> Data? {
        DocumentRasterImageService.jpegData(from: surface, compressionQuality: 0.7)
    }

    private static func videoDimensions(
        for capture: TimelapseCapture,
        exportFrames: [TimelapseFrame],
        fileClient: FileClient
    ) -> CGSize {
        let rawSize: CGSize
        if let firstFrame = exportFrames.first,
           let surface = decodedSurface(from: firstFrame.imageURL, fileClient: fileClient) {
            rawSize = CGSize(width: surface.width, height: surface.height)
        } else {
            rawSize = capture.canvasSize
        }
        return downscaledVideoDimensions(rawSize)
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

    private struct ProgressPreviewGate {
        var lastPreviewDate = Date.distantPast
        var lastPreviewProgress = 0.0
    }

    private static func emitProgressIfNeeded(
        progress: ((TimelapseExportProgress) -> Void)?,
        gate: inout ProgressPreviewGate,
        completed: Int,
        total: Int,
        surface: DocumentCompositeSurface
    ) {
        guard let progress else { return }
        let fraction = min(max(Double(completed) / Double(max(total, 1)), 0), 1)
        let now = Date()
        let shouldIncludePreview =
            now.timeIntervalSince(gate.lastPreviewDate) >= progressPreviewInterval ||
            fraction - gate.lastPreviewProgress >= progressPreviewStep ||
            completed == total
        if shouldIncludePreview {
            gate.lastPreviewDate = now
            gate.lastPreviewProgress = fraction
            progress(
                TimelapseExportProgress(
                    progress: fraction,
                    previewSurface: surface,
                    previewImageData: makePreviewData(surface: surface)
                )
            )
        } else {
            progress(
                TimelapseExportProgress(
                    progress: fraction,
                    previewSurface: nil,
                    previewImageData: nil
                )
            )
        }
    }

    private static func downscaledVideoDimensions(_ size: CGSize) -> CGSize {
        let width = max(size.width.rounded(), 1)
        let height = max(size.height.rounded(), 1)
        let largest = max(width, height)
        guard largest > CGFloat(CanvasSizePolicy.maxVideoDimension) else {
            return CGSize(width: width, height: height)
        }
        let scale = CGFloat(CanvasSizePolicy.maxVideoDimension) / largest
        return CGSize(
            width: max((width * scale).rounded(), 1),
            height: max((height * scale).rounded(), 1)
        )
    }

    private static func checkCancellation() throws {
        if Task.isCancelled {
            throw TimelapseExportError.cancelled
        }
    }

    static func writeSurface(
        _ surface: DocumentCompositeSurface,
        into pixelBuffer: CVPixelBuffer,
        targetSize: CGSize
    ) -> Bool {
        guard surface.pixelData.count == surface.width * surface.height * 4 else { return false }
        guard
            let destinationBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        else {
            return false
        }

        let targetWidth = max(Int(targetSize.width.rounded()), 1)
        let targetHeight = max(Int(targetSize.height.rounded()), 1)
        guard surface.width == targetWidth, surface.height == targetHeight else {
            return false
        }

        let sourceBytesPerRow = surface.width * 4
        let destinationBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let totalByteCount = destinationBytesPerRow * targetHeight
        memset(destinationBaseAddress, 0, totalByteCount)

        surface.pixelData.withUnsafeBytes { sourceBytes in
            guard let sourceBaseAddress = sourceBytes.baseAddress else { return }
            if destinationBytesPerRow == sourceBytesPerRow {
                memcpy(destinationBaseAddress, sourceBaseAddress, sourceBytesPerRow * surface.height)
                return
            }
            for row in 0..<surface.height {
                let sourceOffset = row * sourceBytesPerRow
                let destinationOffset = row * destinationBytesPerRow
                memcpy(
                    destinationBaseAddress.advanced(by: destinationOffset),
                    sourceBaseAddress.advanced(by: sourceOffset),
                    sourceBytesPerRow
                )
            }
        }
        return true
    }
}
