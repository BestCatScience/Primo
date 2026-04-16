import Accelerate
import CoreGraphics
import Foundation
import os
import UIKit
import simd

final class PaintDocumentSession: @unchecked Sendable {
    static let logger = Logger(subsystem: "com.primo.app", category: "Document")
    static let maxTimelapseFrames = 20_000

    private let services: PaintDocumentSessionServices
    private var state: PaintDocumentSessionState
    var bridge: APPaintDocumentBridge

    init(
        width: Int = 1152,
        height: Int = 1536,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) {
        let clock = ContinuousClock()
        let start = clock.now
        self.services = PaintDocumentSessionServices(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
        self.bridge = APPaintDocumentBridge(width: width, height: height)
        let timelapseDirectoryURL = services.timelapse.makeDirectoryURL()
        self.state = PaintDocumentSessionState(timelapseDirectoryURL: timelapseDirectoryURL)
        try? services.fileIO.createDirectory(timelapseDirectoryURL, true)
        let duration = start.duration(to: clock.now)
        Self.logger.debug("PaintDocumentSession initialized \(width)x\(height) in \(String(describing: duration), privacy: .public)")
    }

    deinit {
        try? services.timelapse.removeDirectory(at: timelapseDirectoryURL)
    }

    var currentPaperStyle: CanvasPaperStyle {
        paperStyle
    }

    var fileClient: FileClient { services.fileIO }
    var dateClient: DateClient { services.clock }
    var uuidClient: UUIDClient { services.ids }
    var persistenceService: PaintDocumentPersistenceService { services.persistence }
    var timelapseService: PaintDocumentTimelapseService { services.timelapse }
    var editingLifecycleService: PaintDocumentEditingLifecycleService { services.editingLifecycle }
    var bridgeQueryService: PaintDocumentBridgeQueryService { services.bridge.queries }
    var bridgePixelService: PaintDocumentBridgePixelService { services.bridge.pixels }
    var bridgeDescriptorService: PaintDocumentBridgeDescriptorService { services.bridge.descriptors }
    var bridgeStrokeService: PaintDocumentBridgeStrokeService { services.bridge.strokePoints }
    var geometryService: PaintDocumentGeometryService { services.geometry }
    var blurService: PaintDocumentBlurService { services.blur }

    var timelapseDirectoryURL: URL { state.timelapseDirectoryURL }

    var timelapseFrames: [TimelapseFrame] {
        get { state.timelapseFrames }
        set { state.timelapseFrames = newValue }
    }

    var timelapseEvents: [TimelapseOperation] {
        get { state.timelapseEvents }
        set { state.timelapseEvents = newValue }
    }

    var layerThumbnailCache: [Int: Data] {
        get { state.layerThumbnailCache }
        set { state.layerThumbnailCache = newValue }
    }

    var paperStyle: CanvasPaperStyle {
        get { state.paperStyle }
        set { state.paperStyle = newValue }
    }

    var nextTimelapseFrameID: Int {
        get { state.nextTimelapseFrameID }
        set { state.nextTimelapseFrameID = newValue }
    }

    var usesOperationTimelapsePersistence: Bool {
        get { state.usesOperationTimelapsePersistence }
        set { state.usesOperationTimelapsePersistence = newValue }
    }

    var textLayers: [Int: TextLayerData] {
        get { state.textLayers }
        set { state.textLayers = newValue }
    }

    var revision: Int {
        get { state.revision }
        set { state.revision = newValue }
    }

    var activeStrokeLayerIndex: Int? {
        get { state.activeStrokeLayerIndex }
        set { state.activeStrokeLayerIndex = newValue }
    }

    var activeStrokeBrush: BrushRuntimeSettings? {
        get { state.activeStrokeBrush }
        set { state.activeStrokeBrush = newValue }
    }

    var activeStrokeSamples: [StylusSample] {
        get { state.activeStrokeSamples }
        set { state.activeStrokeSamples = newValue }
    }

    var activeBlurStrokeLayerIndex: Int? {
        get { state.activeBlurStrokeLayerIndex }
        set { state.activeBlurStrokeLayerIndex = newValue }
    }

    var activeBlurStrokeBrush: BrushRuntimeSettings? {
        get { state.activeBlurStrokeBrush }
        set { state.activeBlurStrokeBrush = newValue }
    }

    var activeBlurStrokeSamples: [StylusSample] {
        get { state.activeBlurStrokeSamples }
        set { state.activeBlurStrokeSamples = newValue }
    }

    var blurStrokeHasCapturedHistory: Bool {
        get { state.blurStrokeHasCapturedHistory }
        set { state.blurStrokeHasCapturedHistory = newValue }
    }
}
