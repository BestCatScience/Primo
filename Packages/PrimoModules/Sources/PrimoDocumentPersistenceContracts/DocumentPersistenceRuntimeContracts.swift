import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts

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
    case mergeLayerDown(index: DocumentLayerIndex)
    case createFolder(folderID: DocumentFolderID, name: String, anchorLayerIndex: DocumentLayerIndex?)
    case deleteFolder(folderID: DocumentFolderID)
    case setFolderVisibility(folderID: DocumentFolderID, isVisible: Bool)
    case setFolderName(folderID: DocumentFolderID, name: String)
    case setFolderExpanded(folderID: DocumentFolderID, isExpanded: Bool)
    case assignLayerToFolder(index: DocumentLayerIndex, folderID: DocumentFolderID?)
    case setLayerName(index: DocumentLayerIndex, name: String)
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

public enum PreviewUnavailableReason: Equatable, Sendable {
    case generationUnavailable
}

public enum PreviewOutcome: Equatable, Sendable {
    case available(DocumentCompositeSurface)
    case unavailable(reason: PreviewUnavailableReason)

    public var surface: DocumentCompositeSurface? {
        guard case let .available(surface) = self else { return nil }
        return surface
    }
}

public enum PreviewDataUnavailableReason: Equatable, Sendable {
    case generationUnavailable
}

public enum PreviewDataOutcome: Equatable, Sendable {
    case available(Data)
    case unavailable(reason: PreviewDataUnavailableReason)

    public var data: Data? {
        guard case let .available(data) = self else { return nil }
        return data
    }
}

public enum TimelapseCaptureUnavailableReason: Equatable, Sendable {
    case noHistory
}

public enum TimelapseCaptureOutcome: Equatable, Sendable {
    case available(TimelapseCapture)
    case unavailable(reason: TimelapseCaptureUnavailableReason)

    public var capture: TimelapseCapture? {
        guard case let .available(capture) = self else { return nil }
        return capture
    }
}

public struct DocumentPersistenceGateway: Sendable {
    public let saveProject: @Sendable (URL, CanvasPaperStyle) throws -> Void
    public let loadProject: @Sendable (URL) throws -> LoadedPaintProject
    public let setPaperStyle: @Sendable (CanvasPaperStyle) -> DocumentMutationResult
    public let newCanvas: @Sendable (Int, Int) -> DocumentMutationResult
    public let prewarmDrawingResources: @Sendable () -> DocumentMutationResult

    public init(
        saveProject: @escaping @Sendable (URL, CanvasPaperStyle) throws -> Void,
        loadProject: @escaping @Sendable (URL) throws -> LoadedPaintProject,
        setPaperStyle: @escaping @Sendable (CanvasPaperStyle) -> DocumentMutationResult,
        newCanvas: @escaping @Sendable (Int, Int) -> DocumentMutationResult,
        prewarmDrawingResources: @escaping @Sendable () -> DocumentMutationResult
    ) {
        self.saveProject = saveProject
        self.loadProject = loadProject
        self.setPaperStyle = setPaperStyle
        self.newCanvas = newCanvas
        self.prewarmDrawingResources = prewarmDrawingResources
    }
}

public struct DocumentExportGateway: Sendable {
    public let compositeSurface: @Sendable (CanvasPaperStyle) -> Result<PreviewOutcome, DocumentMutationFailure>
    public let compositePNGData: @Sendable (CanvasPaperStyle) -> Result<PreviewDataOutcome, DocumentMutationFailure>
    public let timelapseCapture: @Sendable () -> Result<TimelapseCaptureOutcome, DocumentMutationFailure>

    public init(
        compositeSurface: @escaping @Sendable (CanvasPaperStyle) -> Result<PreviewOutcome, DocumentMutationFailure> = { _ in .success(.unavailable(reason: .generationUnavailable)) },
        compositePNGData: @escaping @Sendable (CanvasPaperStyle) -> Result<PreviewDataOutcome, DocumentMutationFailure>,
        timelapseCapture: @escaping @Sendable () -> Result<TimelapseCaptureOutcome, DocumentMutationFailure>
    ) {
        self.compositeSurface = compositeSurface
        self.compositePNGData = compositePNGData
        self.timelapseCapture = timelapseCapture
    }
}
