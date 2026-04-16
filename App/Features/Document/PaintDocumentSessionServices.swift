import Foundation

struct PaintDocumentSessionServices {
    let fileIO: FileClient
    let clock: DateClient
    let ids: UUIDClient
    let persistence: PaintDocumentPersistenceService
    let timelapse: PaintDocumentTimelapseService
    let editingLifecycle: PaintDocumentEditingLifecycleService

    init(
        fileClient: FileClient,
        dateClient: DateClient,
        uuidClient: UUIDClient
    ) {
        self.fileIO = fileClient
        self.clock = dateClient
        self.ids = uuidClient
        self.persistence = PaintDocumentPersistenceService(fileClient: fileClient)
        self.timelapse = PaintDocumentTimelapseService(fileClient: fileClient, uuidClient: uuidClient)
        self.editingLifecycle = PaintDocumentEditingLifecycleService()
    }
}

enum PaintDocumentThumbnailInvalidation {
    case none
    case layer(Int)
    case all
}

struct PaintDocumentLifecycleMutation {
    let thumbnailInvalidation: PaintDocumentThumbnailInvalidation
    let timelapseEvents: [TimelapseOperation]
    let shouldCaptureTimelapseFrame: Bool

    static let none = PaintDocumentLifecycleMutation(
        thumbnailInvalidation: .none,
        timelapseEvents: [],
        shouldCaptureTimelapseFrame: false
    )
}

struct PaintDocumentEditingLifecycleService {
    func mutation(
        recording events: [TimelapseOperation] = [],
        invalidating thumbnails: PaintDocumentThumbnailInvalidation = .none,
        captureFrame: Bool = true
    ) -> PaintDocumentLifecycleMutation {
        PaintDocumentLifecycleMutation(
            thumbnailInvalidation: thumbnails,
            timelapseEvents: events,
            shouldCaptureTimelapseFrame: captureFrame
        )
    }

    func mutation(
        recording event: TimelapseOperation,
        invalidating thumbnails: PaintDocumentThumbnailInvalidation = .none,
        captureFrame: Bool = true
    ) -> PaintDocumentLifecycleMutation {
        mutation(recording: [event], invalidating: thumbnails, captureFrame: captureFrame)
    }

    func resetStrokeState(
        activeLayerIndex: inout Int?,
        activeBrush: inout BrushRuntimeSettings?,
        activeSamples: inout [StylusSample]
    ) {
        activeLayerIndex = nil
        activeBrush = nil
        activeSamples.removeAll(keepingCapacity: true)
    }

    func resetBlurStrokeState(
        activeLayerIndex: inout Int?,
        activeBrush: inout BrushRuntimeSettings?,
        activeSamples: inout [StylusSample],
        blurStrokeHasCapturedHistory: inout Bool
    ) {
        activeLayerIndex = nil
        activeBrush = nil
        activeSamples.removeAll(keepingCapacity: true)
        blurStrokeHasCapturedHistory = false
    }

    func resetActiveEditingState(
        activeStrokeLayerIndex: inout Int?,
        activeStrokeBrush: inout BrushRuntimeSettings?,
        activeStrokeSamples: inout [StylusSample],
        activeBlurStrokeLayerIndex: inout Int?,
        activeBlurStrokeBrush: inout BrushRuntimeSettings?,
        activeBlurStrokeSamples: inout [StylusSample],
        blurStrokeHasCapturedHistory: inout Bool
    ) {
        resetStrokeState(
            activeLayerIndex: &activeStrokeLayerIndex,
            activeBrush: &activeStrokeBrush,
            activeSamples: &activeStrokeSamples
        )
        resetBlurStrokeState(
            activeLayerIndex: &activeBlurStrokeLayerIndex,
            activeBrush: &activeBlurStrokeBrush,
            activeSamples: &activeBlurStrokeSamples,
            blurStrokeHasCapturedHistory: &blurStrokeHasCapturedHistory
        )
    }
}

struct PaintDocumentPersistenceService {
    let fileClient: FileClient

    func prepareProjectDirectory(at url: URL) throws {
        if fileClient.fileExists(url.path) {
            try fileClient.removeItem(url)
        }
        try fileClient.createDirectory(url, true)
    }

    func createProjectSubdirectories(
        in projectURL: URL,
        usesOperationTimelapsePersistence: Bool
    ) throws -> (layersDirectory: URL, timelapseDirectory: URL, timelapseDataDirectory: URL) {
        let layersDirectory = projectURL.appendingPathComponent("Layers", isDirectory: true)
        let timelapseDirectory = projectURL.appendingPathComponent("Timelapse", isDirectory: true)
        let timelapseDataDirectory = projectURL.appendingPathComponent("TimelapseData", isDirectory: true)
        try fileClient.createDirectory(layersDirectory, true)
        if usesOperationTimelapsePersistence {
            try fileClient.createDirectory(timelapseDataDirectory, true)
        } else {
            try fileClient.createDirectory(timelapseDirectory, true)
        }
        return (layersDirectory, timelapseDirectory, timelapseDataDirectory)
    }

    func writeAtomic(_ data: Data, to url: URL) throws {
        try fileClient.writeData(data, url, Data.WritingOptions.atomic)
    }

    func loadData(from url: URL) throws -> Data {
        try fileClient.readData(url)
    }

    func replaceItemIfNeeded(at destinationURL: URL, with sourceURL: URL) throws {
        if fileClient.fileExists(destinationURL.path) {
            try fileClient.removeItem(destinationURL)
        }
        try fileClient.copyItem(sourceURL, destinationURL)
    }
}

struct PaintDocumentTimelapseService {
    let fileClient: FileClient
    let uuidClient: UUIDClient

    func makeDirectoryURL() -> URL {
        fileClient.temporaryDirectory()
            .appendingPathComponent("primo-timelapse", isDirectory: true)
            .appendingPathComponent(uuidClient.generate().uuidString, isDirectory: true)
    }

    func makeFrameURL(in directoryURL: URL, frameID: Int) -> URL {
        directoryURL.appendingPathComponent(String(format: "frame-%06d.jpg", frameID), isDirectory: false)
    }

    func persistFrameData(_ data: Data, to url: URL) throws {
        try fileClient.writeData(data, url, Data.WritingOptions.atomic)
    }

    func removeFrame(at url: URL) throws {
        try fileClient.removeItem(url)
    }

    func removeDirectory(at url: URL) throws {
        try fileClient.removeItem(url)
    }
}
