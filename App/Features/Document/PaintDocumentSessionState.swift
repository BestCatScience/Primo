import Foundation

struct PaintDocumentSessionState {
    var revision: Int = 0
    var activeStrokeLayerIndex: Int?
    var activeStrokeBrush: BrushRuntimeSettings?
    var activeStrokeSamples: [StylusSample] = []
    var timelapseFrames: [TimelapseFrame] = []
    var timelapseEvents: [TimelapseOperation] = []
    var layerThumbnailCache: [Int: Data] = [:]
    var paperStyle: CanvasPaperStyle = .default
    let timelapseDirectoryURL: URL
    var nextTimelapseFrameID: Int = 0
    var usesOperationTimelapsePersistence = true
    var activeBlurStrokeLayerIndex: Int?
    var activeBlurStrokeBrush: BrushRuntimeSettings?
    var activeBlurStrokeSamples: [StylusSample] = []
    var blurStrokeHasCapturedHistory = false
    var textLayers: [Int: TextLayerData] = [:]
}
