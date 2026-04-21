import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentRuntimeInfrastructure

typealias DocumentMutationResult = PrimoDocumentContracts.DocumentMutationResult
typealias DocumentIndexedMutationResult = PrimoDocumentContracts.DocumentIndexedMutationResult
typealias DocumentMutationFailure = PrimoDocumentContracts.DocumentMutationFailure
typealias DocumentQueryGateway = PrimoDocumentContracts.DocumentQueryGateway
typealias DocumentMutationGateway = PrimoDocumentContracts.DocumentMutationGateway
typealias StrokeInputGateway = PrimoDocumentContracts.StrokeInputGateway
typealias DocumentHistoryGateway = PrimoDocumentContracts.DocumentHistoryGateway
typealias DocumentPersistenceGateway = PrimoDocumentContracts.DocumentPersistenceGateway
typealias DocumentExportGateway = PrimoDocumentContracts.DocumentExportGateway
typealias TextLayerGateway = PrimoDocumentContracts.TextLayerGateway
typealias LayerPixelRect = PrimoDocumentContracts.LayerPixelRect

struct PaintDocumentClient: Sendable {
    var lightweightPresentation: @Sendable () -> PaintDocumentPresentation
    var presentation: @Sendable () -> PaintDocumentPresentation
    var compositePixelData: @Sendable () -> Data
    var prewarmDrawingResources: @Sendable () -> Void
    var compositePNGData: @Sendable (CanvasPaperStyle) -> Data?
    var timelapseCapture: @Sendable () -> TimelapseCapture?
    var saveProject: @Sendable (URL, CanvasPaperStyle) throws -> Void
    var loadProject: @Sendable (URL) throws -> LoadedPaintProject
    var setPaperStyle: @Sendable (CanvasPaperStyle) -> Void
    var newCanvas: @Sendable (Int, Int) -> Void
    var resizeCanvas: @Sendable (Int, Int) -> DocumentMutationResult
    var resizeCanvasExtent: @Sendable (Int, Int) -> DocumentMutationResult
    var beginStroke: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    var appendStroke: @Sendable (StylusSample) -> Void
    var endStroke: @Sendable () -> Void
    var cancelStroke: @Sendable () -> Void
    var blurStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult
    var endBlurStroke: @Sendable () -> Void
    var fill: @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult
    var canUndo: @Sendable () -> Bool
    var canRedo: @Sendable () -> Bool
    var undo: @Sendable () -> DocumentMutationResult
    var redo: @Sendable () -> DocumentMutationResult
    var addLayer: @Sendable (String) -> DocumentIndexedMutationResult
    var duplicateLayer: @Sendable (Int, String) -> DocumentIndexedMutationResult
    var deleteLayer: @Sendable (Int) -> DocumentMutationResult
    var moveLayer: @Sendable (Int, Int) -> DocumentMutationResult
    var createFolder: @Sendable (String, Int) -> DocumentIndexedMutationResult
    var deleteFolder: @Sendable (Int) -> DocumentMutationResult
    var setFolderVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    var setFolderName: @Sendable (Int, String) -> DocumentMutationResult
    var setFolderExpanded: @Sendable (Int, Bool) -> DocumentMutationResult
    var assignLayerToFolder: @Sendable (Int, Int) -> DocumentMutationResult
    var setActiveLayer: @Sendable (Int) -> DocumentMutationResult
    var setLayerName: @Sendable (Int, String) -> DocumentMutationResult
    var setLayerVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    var setLayerLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    var setLayerAlphaLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    var setLayerClipped: @Sendable (Int, Bool) -> DocumentMutationResult
    var revealLayerForEditing: @Sendable (Int) -> DocumentMutationResult
    var setLayerOpacity: @Sendable (Int, Double) -> DocumentMutationResult
    var setLayerBlendMode: @Sendable (Int, LayerBlendMode) -> DocumentMutationResult
    var mergeLayerDown: @Sendable (Int) -> DocumentMutationResult
    var textLayerData: @Sendable (Int) -> TextLayerData?
    var setTextLayer: @Sendable (Int, TextLayerData) -> DocumentMutationResult
    var clearTextLayerData: @Sendable (Int) -> Void
    var applyLayerProcessing: @Sendable (Int, LayerProcessingRequest) -> DocumentMutationResult
    var applySoftwareStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult
    var pixelDataForLayer: @Sendable (Int) -> Data
    var replaceLayerPixels: @Sendable (Int, Data) -> DocumentMutationResult
    var replaceLayerPixelsInRect: @Sendable (Int, LayerPixelRect, Data) -> DocumentMutationResult
    var replaceLayerMask: @Sendable (Int, Data) -> DocumentMutationResult
    var clearLayerMask: @Sendable (Int) -> DocumentMutationResult
    var applyLayerMask: @Sendable (Int) -> DocumentMutationResult
    var clearLayer: @Sendable (Int) -> DocumentMutationResult
    var consumeDirtyUpdate: @Sendable () -> IncrementalLayerUpdate?

    static func live(
        fileClient: FileClient,
        dateClient: DateClient,
        uuidClient: UUIDClient
    ) -> PaintDocumentClient {
        let runtime = DocumentRuntimeFactory.live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
        return PaintDocumentClient(
            lightweightPresentation: runtime.queryGateway.lightweightPresentation,
            presentation: runtime.queryGateway.presentation,
            compositePixelData: runtime.queryGateway.compositePixelData,
            prewarmDrawingResources: runtime.persistenceGateway.prewarmDrawingResources,
            compositePNGData: runtime.exportGateway.compositePNGData,
            timelapseCapture: runtime.exportGateway.timelapseCapture,
            saveProject: runtime.persistenceGateway.saveProject,
            loadProject: runtime.persistenceGateway.loadProject,
            setPaperStyle: runtime.persistenceGateway.setPaperStyle,
            newCanvas: runtime.persistenceGateway.newCanvas,
            resizeCanvas: runtime.mutationGateway.resizeCanvas,
            resizeCanvasExtent: runtime.mutationGateway.resizeCanvasExtent,
            beginStroke: runtime.strokeGateway.beginStroke,
            appendStroke: runtime.strokeGateway.appendStroke,
            endStroke: runtime.strokeGateway.endStroke,
            cancelStroke: runtime.strokeGateway.cancelStroke,
            blurStroke: runtime.strokeGateway.blurStroke,
            endBlurStroke: runtime.strokeGateway.endBlurStroke,
            fill: runtime.strokeGateway.fill,
            canUndo: runtime.historyGateway.canUndo,
            canRedo: runtime.historyGateway.canRedo,
            undo: runtime.historyGateway.undo,
            redo: runtime.historyGateway.redo,
            addLayer: runtime.mutationGateway.addLayer,
            duplicateLayer: runtime.duplicateLayer,
            deleteLayer: runtime.mutationGateway.deleteLayer,
            moveLayer: runtime.moveLayer,
            createFolder: runtime.createFolder,
            deleteFolder: runtime.deleteFolder,
            setFolderVisibility: runtime.setFolderVisibility,
            setFolderName: runtime.setFolderName,
            setFolderExpanded: runtime.setFolderExpanded,
            assignLayerToFolder: runtime.assignLayerToFolder,
            setActiveLayer: runtime.mutationGateway.setActiveLayer,
            setLayerName: runtime.mutationGateway.setLayerName,
            setLayerVisibility: runtime.mutationGateway.setLayerVisibility,
            setLayerLocked: runtime.setLayerLocked,
            setLayerAlphaLocked: runtime.setLayerAlphaLocked,
            setLayerClipped: runtime.setLayerClipped,
            revealLayerForEditing: runtime.mutationGateway.revealLayerForEditing,
            setLayerOpacity: runtime.setLayerOpacity,
            setLayerBlendMode: runtime.setLayerBlendMode,
            mergeLayerDown: runtime.mergeLayerDown,
            textLayerData: runtime.textLayerGateway.textLayerData,
            setTextLayer: runtime.textLayerGateway.setTextLayer,
            clearTextLayerData: runtime.textLayerGateway.clearTextLayerData,
            applyLayerProcessing: runtime.mutationGateway.applyLayerProcessing,
            applySoftwareStroke: runtime.strokeGateway.applySoftwareStroke,
            pixelDataForLayer: runtime.queryGateway.pixelDataForLayer,
            replaceLayerPixels: runtime.mutationGateway.replaceLayerPixels,
            replaceLayerPixelsInRect: runtime.mutationGateway.replaceLayerPixelsInRect,
            replaceLayerMask: runtime.mutationGateway.replaceLayerMask,
            clearLayerMask: runtime.mutationGateway.clearLayerMask,
            applyLayerMask: runtime.mutationGateway.applyLayerMask,
            clearLayer: runtime.mutationGateway.clearLayer,
            consumeDirtyUpdate: runtime.queryGateway.consumeDirtyUpdate
        )
    }
}

struct DocumentLayerClient: Sendable {
    let addLayer: @Sendable (String) -> DocumentIndexedMutationResult
    let duplicateLayer: @Sendable (Int, String) -> DocumentIndexedMutationResult
    let deleteLayer: @Sendable (Int) -> DocumentMutationResult
    let moveLayer: @Sendable (Int, Int) -> DocumentMutationResult
    let createFolder: @Sendable (String, Int) -> DocumentIndexedMutationResult
    let deleteFolder: @Sendable (Int) -> DocumentMutationResult
    let setFolderVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    let setFolderName: @Sendable (Int, String) -> DocumentMutationResult
    let setFolderExpanded: @Sendable (Int, Bool) -> DocumentMutationResult
    let assignLayerToFolder: @Sendable (Int, Int) -> DocumentMutationResult
    let setActiveLayer: @Sendable (Int) -> DocumentMutationResult
    let setLayerName: @Sendable (Int, String) -> DocumentMutationResult
    let setLayerVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    let setLayerLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    let setLayerAlphaLocked: @Sendable (Int, Bool) -> DocumentMutationResult
    let setLayerClipped: @Sendable (Int, Bool) -> DocumentMutationResult
    let revealLayerForEditing: @Sendable (Int) -> DocumentMutationResult
    let setLayerOpacity: @Sendable (Int, Double) -> DocumentMutationResult
    let setLayerBlendMode: @Sendable (Int, LayerBlendMode) -> DocumentMutationResult
    let mergeLayerDown: @Sendable (Int) -> DocumentMutationResult
    let textLayerData: @Sendable (Int) -> TextLayerData?
    let setTextLayer: @Sendable (Int, TextLayerData) -> DocumentMutationResult
    let clearTextLayerData: @Sendable (Int) -> Void
    let replaceLayerPixels: @Sendable (Int, Data) -> DocumentMutationResult
    let replaceLayerPixelsInRect: @Sendable (Int, LayerPixelRect, Data) -> DocumentMutationResult
    let replaceLayerMask: @Sendable (Int, Data) -> DocumentMutationResult
    let clearLayerMask: @Sendable (Int) -> DocumentMutationResult
    let applyLayerMask: @Sendable (Int) -> DocumentMutationResult
    let clearLayer: @Sendable (Int) -> DocumentMutationResult

    init(paintDocumentClient: PaintDocumentClient) {
        self.addLayer = paintDocumentClient.addLayer
        self.duplicateLayer = paintDocumentClient.duplicateLayer
        self.deleteLayer = paintDocumentClient.deleteLayer
        self.moveLayer = paintDocumentClient.moveLayer
        self.createFolder = paintDocumentClient.createFolder
        self.deleteFolder = paintDocumentClient.deleteFolder
        self.setFolderVisibility = paintDocumentClient.setFolderVisibility
        self.setFolderName = paintDocumentClient.setFolderName
        self.setFolderExpanded = paintDocumentClient.setFolderExpanded
        self.assignLayerToFolder = paintDocumentClient.assignLayerToFolder
        self.setActiveLayer = paintDocumentClient.setActiveLayer
        self.setLayerName = paintDocumentClient.setLayerName
        self.setLayerVisibility = paintDocumentClient.setLayerVisibility
        self.setLayerLocked = paintDocumentClient.setLayerLocked
        self.setLayerAlphaLocked = paintDocumentClient.setLayerAlphaLocked
        self.setLayerClipped = paintDocumentClient.setLayerClipped
        self.revealLayerForEditing = paintDocumentClient.revealLayerForEditing
        self.setLayerOpacity = paintDocumentClient.setLayerOpacity
        self.setLayerBlendMode = paintDocumentClient.setLayerBlendMode
        self.mergeLayerDown = paintDocumentClient.mergeLayerDown
        self.textLayerData = paintDocumentClient.textLayerData
        self.setTextLayer = paintDocumentClient.setTextLayer
        self.clearTextLayerData = paintDocumentClient.clearTextLayerData
        self.replaceLayerPixels = paintDocumentClient.replaceLayerPixels
        self.replaceLayerPixelsInRect = paintDocumentClient.replaceLayerPixelsInRect
        self.replaceLayerMask = paintDocumentClient.replaceLayerMask
        self.clearLayerMask = paintDocumentClient.clearLayerMask
        self.applyLayerMask = paintDocumentClient.applyLayerMask
        self.clearLayer = paintDocumentClient.clearLayer
    }
}

private enum PaintDocumentClientKey: DependencyKey {
    static var liveValue: PaintDocumentClient {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient
        return .live(fileClient: fileClient, dateClient: dateClient, uuidClient: uuidClient)
    }
}

extension DependencyValues {
    var paintDocumentClient: PaintDocumentClient {
        get { self[PaintDocumentClientKey.self] }
        set { self[PaintDocumentClientKey.self] = newValue }
    }

    var documentQueryGateway: DocumentQueryGateway {
        get { self[DocumentQueryGatewayKey.self] }
        set { self[DocumentQueryGatewayKey.self] = newValue }
    }

    var documentMutationGateway: DocumentMutationGateway {
        get { self[DocumentMutationGatewayKey.self] }
        set { self[DocumentMutationGatewayKey.self] = newValue }
    }

    var strokeInputGateway: StrokeInputGateway {
        get { self[StrokeInputGatewayKey.self] }
        set { self[StrokeInputGatewayKey.self] = newValue }
    }

    var documentHistoryGateway: DocumentHistoryGateway {
        get { self[DocumentHistoryGatewayKey.self] }
        set { self[DocumentHistoryGatewayKey.self] = newValue }
    }

    var documentPersistenceGateway: DocumentPersistenceGateway {
        get { self[DocumentPersistenceGatewayKey.self] }
        set { self[DocumentPersistenceGatewayKey.self] = newValue }
    }

    var documentExportGateway: DocumentExportGateway {
        get { self[DocumentExportGatewayKey.self] }
        set { self[DocumentExportGatewayKey.self] = newValue }
    }

    var textLayerGateway: TextLayerGateway {
        get { self[TextLayerGatewayKey.self] }
        set { self[TextLayerGatewayKey.self] = newValue }
    }
}

private enum DocumentQueryGatewayKey: DependencyKey {
    static var liveValue: DocumentQueryGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return DocumentQueryGateway(
            lightweightPresentation: paintDocumentClient.lightweightPresentation,
            presentation: paintDocumentClient.presentation,
            compositePixelData: paintDocumentClient.compositePixelData,
            pixelDataForLayer: paintDocumentClient.pixelDataForLayer,
            consumeDirtyUpdate: paintDocumentClient.consumeDirtyUpdate
        )
    }
}

private enum DocumentMutationGatewayKey: DependencyKey {
    static var liveValue: DocumentMutationGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return DocumentMutationGateway(
            resizeCanvas: paintDocumentClient.resizeCanvas,
            resizeCanvasExtent: paintDocumentClient.resizeCanvasExtent,
            addLayer: paintDocumentClient.addLayer,
            deleteLayer: paintDocumentClient.deleteLayer,
            setActiveLayer: paintDocumentClient.setActiveLayer,
            setLayerName: paintDocumentClient.setLayerName,
            setLayerVisibility: paintDocumentClient.setLayerVisibility,
            revealLayerForEditing: paintDocumentClient.revealLayerForEditing,
            replaceLayerPixels: paintDocumentClient.replaceLayerPixels,
            replaceLayerPixelsInRect: paintDocumentClient.replaceLayerPixelsInRect,
            replaceLayerMask: paintDocumentClient.replaceLayerMask,
            clearLayerMask: paintDocumentClient.clearLayerMask,
            applyLayerMask: paintDocumentClient.applyLayerMask,
            clearLayer: paintDocumentClient.clearLayer,
            applyLayerProcessing: paintDocumentClient.applyLayerProcessing
        )
    }
}

private enum StrokeInputGatewayKey: DependencyKey {
    static var liveValue: StrokeInputGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return StrokeInputGateway(
            beginStroke: paintDocumentClient.beginStroke,
            appendStroke: paintDocumentClient.appendStroke,
            endStroke: paintDocumentClient.endStroke,
            cancelStroke: paintDocumentClient.cancelStroke,
            blurStroke: paintDocumentClient.blurStroke,
            endBlurStroke: paintDocumentClient.endBlurStroke,
            fill: paintDocumentClient.fill,
            applySoftwareStroke: paintDocumentClient.applySoftwareStroke
        )
    }
}

private enum DocumentHistoryGatewayKey: DependencyKey {
    static var liveValue: DocumentHistoryGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return DocumentHistoryGateway(
            canUndo: paintDocumentClient.canUndo,
            canRedo: paintDocumentClient.canRedo,
            undo: paintDocumentClient.undo,
            redo: paintDocumentClient.redo
        )
    }
}

private enum DocumentPersistenceGatewayKey: DependencyKey {
    static var liveValue: DocumentPersistenceGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return DocumentPersistenceGateway(
            saveProject: paintDocumentClient.saveProject,
            loadProject: paintDocumentClient.loadProject,
            setPaperStyle: paintDocumentClient.setPaperStyle,
            newCanvas: paintDocumentClient.newCanvas,
            prewarmDrawingResources: paintDocumentClient.prewarmDrawingResources
        )
    }
}

private enum DocumentExportGatewayKey: DependencyKey {
    static var liveValue: DocumentExportGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return DocumentExportGateway(
            compositePNGData: paintDocumentClient.compositePNGData,
            timelapseCapture: paintDocumentClient.timelapseCapture
        )
    }
}

private enum TextLayerGatewayKey: DependencyKey {
    static var liveValue: TextLayerGateway {
        @Dependency(\.paintDocumentClient) var paintDocumentClient
        return TextLayerGateway(
            textLayerData: paintDocumentClient.textLayerData,
            setTextLayer: paintDocumentClient.setTextLayer,
            clearTextLayerData: paintDocumentClient.clearTextLayerData
        )
    }
}
