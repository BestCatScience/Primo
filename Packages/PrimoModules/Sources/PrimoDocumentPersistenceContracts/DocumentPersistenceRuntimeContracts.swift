import CoreGraphics
import Foundation
@_exported import PrimoBrushRuntimeContracts
import PrimoDocumentDomain
@_exported import PrimoDocumentPresentationContracts

public struct TimelapseFrame: Equatable, Sendable {
    public let imageURL: URL
    public let size: CGSize

    public init(imageURL: URL, size: CGSize) {
        self.imageURL = imageURL
        self.size = size
    }
}

public enum TimelapseOperation: Equatable, Sendable {
    case stroke(layerIndex: DocumentLayerIndex, brush: BrushRuntimeSettings, samples: [StylusSample])
    case blurStroke(layerIndex: DocumentLayerIndex, brush: BrushRuntimeSettings, samples: [StylusSample])
    case fill(layerIndex: DocumentLayerIndex, brush: BrushRuntimeSettings, sample: StylusSample)
    case undo
    case redo
    case addLayer(name: String)
    case duplicateLayer(index: DocumentLayerIndex, name: String)
    case deleteLayer(index: DocumentLayerIndex)
    case moveLayer(index: DocumentLayerIndex, destinationIndex: DocumentLayerIndex)
    case createFolder(folderID: DocumentFolderID, name: String, anchorLayerIndex: DocumentLayerIndex?)
    case deleteFolder(folderID: DocumentFolderID)
    case setFolderVisibility(folderID: DocumentFolderID, isVisible: Bool)
    case assignLayerToFolder(index: DocumentLayerIndex, folderID: DocumentFolderID?)
    case setLayerVisibility(index: DocumentLayerIndex, isVisible: Bool)
    case setLayerLocked(index: DocumentLayerIndex, isLocked: Bool)
    case setLayerAlphaLocked(index: DocumentLayerIndex, isAlphaLocked: Bool)
    case setLayerClipped(index: DocumentLayerIndex, isClipped: Bool)
    case setLayerOpacity(index: DocumentLayerIndex, opacity: Double)
    case setLayerBlendMode(index: DocumentLayerIndex, blendMode: LayerBlendMode)
    case replaceLayerPixels(index: DocumentLayerIndex, data: Data)
    case replaceLayerMask(index: DocumentLayerIndex, data: Data)
    case clearLayerMask(index: DocumentLayerIndex)
    case applyLayerMask(index: DocumentLayerIndex)
    case clearLayer(index: DocumentLayerIndex)
    case setPaperStyle(CanvasPaperStyle)
}

public enum TimelapseCaptureSource: Equatable, Sendable {
    case frames([TimelapseFrame])
    case operations([TimelapseOperation])
}

public struct TimelapseCapture: Equatable, Sendable {
    public let canvasSize: CGSize
    public let paperStyle: CanvasPaperStyle
    public let previewSurface: DocumentCompositeSurface?
    /// Legacy preview bytes retained for HUD/persistence fallback.
    public let previewImageData: Data?
    public let source: TimelapseCaptureSource
    public let framesPerSecond: Int

    public init(
        canvasSize: CGSize,
        paperStyle: CanvasPaperStyle,
        previewSurface: DocumentCompositeSurface? = nil,
        previewImageData: Data?,
        source: TimelapseCaptureSource,
        framesPerSecond: Int
    ) {
        self.canvasSize = canvasSize
        self.paperStyle = paperStyle
        self.previewSurface = previewSurface
        self.previewImageData = previewImageData
        self.source = source
        self.framesPerSecond = framesPerSecond
    }
}

public struct DocumentPersistenceGateway: Sendable {
    public var saveProject: @Sendable (URL, CanvasPaperStyle) throws -> Void
    public var loadProject: @Sendable (URL) throws -> LoadedPaintProject
    public var setPaperStyle: @Sendable (CanvasPaperStyle) -> Void
    public var newCanvas: @Sendable (Int, Int) -> Void
    public var prewarmDrawingResources: @Sendable () -> Void

    public init(
        saveProject: @escaping @Sendable (URL, CanvasPaperStyle) throws -> Void,
        loadProject: @escaping @Sendable (URL) throws -> LoadedPaintProject,
        setPaperStyle: @escaping @Sendable (CanvasPaperStyle) -> Void,
        newCanvas: @escaping @Sendable (Int, Int) -> Void,
        prewarmDrawingResources: @escaping @Sendable () -> Void
    ) {
        self.saveProject = saveProject
        self.loadProject = loadProject
        self.setPaperStyle = setPaperStyle
        self.newCanvas = newCanvas
        self.prewarmDrawingResources = prewarmDrawingResources
    }
}

public struct DocumentExportGateway: Sendable {
    public var compositeSurface: @Sendable (CanvasPaperStyle) -> DocumentCompositeSurface?
    public var compositePNGData: @Sendable (CanvasPaperStyle) -> Data?
    public var timelapseCapture: @Sendable () -> TimelapseCapture?

    public init(
        compositeSurface: @escaping @Sendable (CanvasPaperStyle) -> DocumentCompositeSurface? = { _ in nil },
        compositePNGData: @escaping @Sendable (CanvasPaperStyle) -> Data?,
        timelapseCapture: @escaping @Sendable () -> TimelapseCapture?
    ) {
        self.compositeSurface = compositeSurface
        self.compositePNGData = compositePNGData
        self.timelapseCapture = timelapseCapture
    }
}
