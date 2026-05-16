import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoCanvasPresentationDomain
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentStrokeApplication


package struct DocumentRuntimeComposition: Sendable {
    package let queryGateway: DocumentQueryGateway
    package let renderGateway: DocumentRenderGateway
    package let dirtyUpdateQueue: DocumentDirtyUpdateQueue
    package let mutationGateway: DocumentMutationGateway
    package let strokeGateway: StrokeInputGateway
    package let historyGateway: DocumentHistoryGateway
    package let persistenceGateway: DocumentPersistenceGateway
    package let exportGateway: DocumentExportGateway
    package let textLayerGateway: TextLayerGateway
    package let layerEffectsGateway: DocumentLayerEffectsGateway
    package let editingGateway: DocumentEditingGateway
    package let strokeSessionUseCase: DocumentStrokeSessionUseCase
    package let canvasPreviewOperations: DocumentCanvasPreviewRenderingOperations
    package let selectionMaskOperations: DocumentSelectionMaskOperations
    package let layerTransformOperations: DocumentLayerTransformOperations
    package let renderingOperations: DocumentRenderingOperations
    package let surfaceHandleReleaser: DocumentSurfaceHandleReleaser

    package init(
        queryGateway: DocumentQueryGateway,
        renderGateway: DocumentRenderGateway,
        dirtyUpdateQueue: DocumentDirtyUpdateQueue,
        mutationGateway: DocumentMutationGateway,
        strokeGateway: StrokeInputGateway,
        historyGateway: DocumentHistoryGateway,
        persistenceGateway: DocumentPersistenceGateway,
        exportGateway: DocumentExportGateway,
        textLayerGateway: TextLayerGateway,
        layerEffectsGateway: DocumentLayerEffectsGateway,
        editingGateway: DocumentEditingGateway,
        strokeSessionUseCase: DocumentStrokeSessionUseCase,
        canvasPreviewOperations: DocumentCanvasPreviewRenderingOperations,
        selectionMaskOperations: DocumentSelectionMaskOperations,
        layerTransformOperations: DocumentLayerTransformOperations,
        renderingOperations: DocumentRenderingOperations,
        surfaceHandleReleaser: DocumentSurfaceHandleReleaser
    ) {
        self.queryGateway = queryGateway
        self.renderGateway = renderGateway
        self.dirtyUpdateQueue = dirtyUpdateQueue
        self.mutationGateway = mutationGateway
        self.strokeGateway = strokeGateway
        self.historyGateway = historyGateway
        self.persistenceGateway = persistenceGateway
        self.exportGateway = exportGateway
        self.textLayerGateway = textLayerGateway
        self.layerEffectsGateway = layerEffectsGateway
        self.editingGateway = editingGateway
        self.strokeSessionUseCase = strokeSessionUseCase
        self.canvasPreviewOperations = canvasPreviewOperations
        self.selectionMaskOperations = selectionMaskOperations
        self.layerTransformOperations = layerTransformOperations
        self.renderingOperations = renderingOperations
        self.surfaceHandleReleaser = surfaceHandleReleaser
    }


    package func withOverrides(
        queryGateway: DocumentQueryGateway? = nil,
        renderGateway: DocumentRenderGateway? = nil,
        dirtyUpdateQueue: DocumentDirtyUpdateQueue? = nil,
        mutationGateway: DocumentMutationGateway? = nil,
        strokeGateway: StrokeInputGateway? = nil,
        historyGateway: DocumentHistoryGateway? = nil,
        persistenceGateway: DocumentPersistenceGateway? = nil,
        exportGateway: DocumentExportGateway? = nil,
        textLayerGateway: TextLayerGateway? = nil,
        layerEffectsGateway: DocumentLayerEffectsGateway? = nil,
        editingGateway: DocumentEditingGateway? = nil,
        strokeSessionUseCase: DocumentStrokeSessionUseCase? = nil,
        canvasPreviewOperations: DocumentCanvasPreviewRenderingOperations? = nil,
        selectionMaskOperations: DocumentSelectionMaskOperations? = nil,
        layerTransformOperations: DocumentLayerTransformOperations? = nil,
        renderingOperations: DocumentRenderingOperations? = nil,
        surfaceHandleReleaser: DocumentSurfaceHandleReleaser? = nil
    ) -> DocumentRuntimeComposition {
        DocumentRuntimeComposition(
            queryGateway: queryGateway ?? self.queryGateway,
            renderGateway: renderGateway ?? self.renderGateway,
            dirtyUpdateQueue: dirtyUpdateQueue ?? self.dirtyUpdateQueue,
            mutationGateway: mutationGateway ?? self.mutationGateway,
            strokeGateway: strokeGateway ?? self.strokeGateway,
            historyGateway: historyGateway ?? self.historyGateway,
            persistenceGateway: persistenceGateway ?? self.persistenceGateway,
            exportGateway: exportGateway ?? self.exportGateway,
            textLayerGateway: textLayerGateway ?? self.textLayerGateway,
            layerEffectsGateway: layerEffectsGateway ?? self.layerEffectsGateway,
            editingGateway: editingGateway ?? self.editingGateway,
            strokeSessionUseCase: strokeSessionUseCase ?? self.strokeSessionUseCase,
            canvasPreviewOperations: canvasPreviewOperations ?? self.canvasPreviewOperations,
            selectionMaskOperations: selectionMaskOperations ?? self.selectionMaskOperations,
            layerTransformOperations: layerTransformOperations ?? self.layerTransformOperations,
            renderingOperations: renderingOperations ?? self.renderingOperations,
            surfaceHandleReleaser: surfaceHandleReleaser ?? self.surfaceHandleReleaser
        )
    }
}

public enum DocumentMutationSuccess: Equatable, Sendable {
    case completed
    case indexed(Int)
}

public struct DocumentHistoryState: Equatable, Sendable {
    public let canUndo: Bool
    public let canRedo: Bool

    public init(canUndo: Bool, canRedo: Bool) {
        self.canUndo = canUndo
        self.canRedo = canRedo
    }
}

public enum DocumentPresentationRequest: Equatable, Sendable {
    case lightweight
    case full
    case current
}

public enum DocumentCanvasCommand: Sendable {
    case createSized(ValidCanvasSize)
    case resizeSized(ValidCanvasSize)
    case resizeExtentSized(ValidCanvasSize)
    case initializeImported(ImportedCanvasRequest, layerName: String)
    case compositeSurface
    case setPaperStyle(CanvasPaperStyle)
}

public enum DocumentLayerCommand: Sendable {
    case edit(DocumentEditingRequest)
    case mergeExistingLayerDown(ExistingLayerIndex)
    case setEditableTextLayer(index: EditableLayerIndex, TextLayerData)
    case applyEditableProcessing(index: EditableLayerIndex, LayerProcessingRequest)
}

public enum DocumentStrokeCommand: Sendable {
    case begin(StylusSample, BrushRuntimeSettings)
    case append(StylusSample)
    case end
    case cancel
    case fill(StylusSample, BrushRuntimeSettings)
}

public enum DocumentHistoryCommand: Equatable, Sendable {
    case state
    case undo
    case redo
}

public enum DocumentCommand: Sendable {
    case presentation(DocumentPresentationRequest)
    case canvas(DocumentCanvasCommand)
    case layer(DocumentLayerCommand)
    case stroke(DocumentStrokeCommand)
    case history(DocumentHistoryCommand)
}

public enum DocumentCommandOutcome: Sendable {
    case mutation(Result<DocumentMutationSuccess, DocumentMutationFailure>)
    case presentation(PaintDocumentPresentation)
    case compositeSurface(DocumentCompositeSurface)
    case history(DocumentHistoryState)
    case failure(DocumentMutationFailure)
    case none
}

public struct DocumentPresentationReader: Sendable {
    private let lightweightPresentationHandler: @Sendable () -> Result<PaintDocumentPresentation, DocumentMutationFailure>
    private let presentationHandler: @Sendable () -> Result<PaintDocumentPresentation, DocumentMutationFailure>

    public init(
        lightweightPresentation: @escaping @Sendable () -> Result<PaintDocumentPresentation, DocumentMutationFailure>,
        presentation: @escaping @Sendable () -> Result<PaintDocumentPresentation, DocumentMutationFailure>
    ) {
        self.lightweightPresentationHandler = lightweightPresentation
        self.presentationHandler = presentation
    }

    public func lightweightPresentation() -> Result<PaintDocumentPresentation, DocumentMutationFailure> {
        lightweightPresentationHandler()
    }

    public func presentation() -> Result<PaintDocumentPresentation, DocumentMutationFailure> {
        presentationHandler()
    }
}

public struct DocumentTextLayerService: Sendable {
    private let textLayerDataHandler: @Sendable (ExistingLayerIndex) -> Result<TextLayerData?, DocumentMutationFailure>
    private let setTextLayerHandler: @Sendable (EditableLayerIndex, TextLayerData) -> DocumentMutationResult
    private let clearTextLayerDataHandler: @Sendable (EditableLayerIndex) -> DocumentMutationResult

    public init(
        textLayerData: @escaping @Sendable (ExistingLayerIndex) -> Result<TextLayerData?, DocumentMutationFailure>,
        setTextLayer: @escaping @Sendable (EditableLayerIndex, TextLayerData) -> DocumentMutationResult,
        clearTextLayerData: @escaping @Sendable (EditableLayerIndex) -> DocumentMutationResult
    ) {
        self.textLayerDataHandler = textLayerData
        self.setTextLayerHandler = setTextLayer
        self.clearTextLayerDataHandler = clearTextLayerData
    }

    public func textLayerData(_ index: ExistingLayerIndex) -> Result<TextLayerData?, DocumentMutationFailure> {
        textLayerDataHandler(index)
    }

    public func setTextLayer(_ index: EditableLayerIndex, _ textLayer: TextLayerData) -> DocumentMutationResult {
        setTextLayerHandler(index, textLayer)
    }

    public func clearTextLayerData(_ index: EditableLayerIndex) -> DocumentMutationResult {
        clearTextLayerDataHandler(index)
    }
}

public struct DocumentPersistenceClient: Sendable {
    private let saveProjectHandler: @Sendable (URL, CanvasPaperStyle) throws -> Void
    private let loadProjectHandler: @Sendable (URL) throws -> LoadedPaintProject
    private let setPaperStyleHandler: @Sendable (CanvasPaperStyle) -> DocumentMutationResult
    private let newCanvasHandler: @Sendable (Int, Int) -> DocumentMutationResult
    private let prewarmDrawingResourcesHandler: @Sendable () -> DocumentMutationResult

    public init(
        saveProject: @escaping @Sendable (URL, CanvasPaperStyle) throws -> Void,
        loadProject: @escaping @Sendable (URL) throws -> LoadedPaintProject,
        setPaperStyle: @escaping @Sendable (CanvasPaperStyle) -> DocumentMutationResult,
        newCanvas: @escaping @Sendable (ValidCanvasSize) -> DocumentMutationResult,
        prewarmDrawingResources: @escaping @Sendable () -> DocumentMutationResult
    ) {
        self.saveProjectHandler = saveProject
        self.loadProjectHandler = loadProject
        self.setPaperStyleHandler = setPaperStyle
        self.newCanvasHandler = { width, height in
            guard let size = ValidCanvasSize(width, height) else {
                return .failure(.invalidCanvasSize(width: width, height: height))
            }
            return newCanvas(size)
        }
        self.prewarmDrawingResourcesHandler = prewarmDrawingResources
    }

    package init(
        saveProject: @escaping @Sendable (URL, CanvasPaperStyle) throws -> Void,
        loadProject: @escaping @Sendable (URL) throws -> LoadedPaintProject,
        setPaperStyle: @escaping @Sendable (CanvasPaperStyle) -> DocumentMutationResult,
        rawNewCanvas: @escaping @Sendable (Int, Int) -> DocumentMutationResult,
        prewarmDrawingResources: @escaping @Sendable () -> DocumentMutationResult
    ) {
        self.saveProjectHandler = saveProject
        self.loadProjectHandler = loadProject
        self.setPaperStyleHandler = setPaperStyle
        self.newCanvasHandler = rawNewCanvas
        self.prewarmDrawingResourcesHandler = prewarmDrawingResources
    }

    public func saveProject(_ url: URL, _ paperStyle: CanvasPaperStyle) throws {
        try saveProjectHandler(url, paperStyle)
    }

    public func loadProject(_ url: URL) throws -> LoadedPaintProject {
        try loadProjectHandler(url)
    }

    public func setPaperStyle(_ paperStyle: CanvasPaperStyle) -> DocumentMutationResult {
        setPaperStyleHandler(paperStyle)
    }

    public func newCanvas(_ size: ValidCanvasSize) -> DocumentMutationResult {
        newCanvasHandler(size.width, size.height)
    }

    package func newCanvas(_ width: Int, _ height: Int) -> DocumentMutationResult {
        newCanvasHandler(width, height)
    }

    public func prewarmDrawingResources() -> DocumentMutationResult {
        prewarmDrawingResourcesHandler()
    }
}

public struct DocumentExportClient: Sendable {
    private let compositeSurfaceHandler: @Sendable (CanvasPaperStyle) -> Result<DocumentCompositeSurface?, DocumentMutationFailure>
    private let compositePNGDataHandler: @Sendable (CanvasPaperStyle) -> Result<Data?, DocumentMutationFailure>
    private let timelapseCaptureHandler: @Sendable () -> Result<TimelapseCapture?, DocumentMutationFailure>

    public init(
        compositeSurface: @escaping @Sendable (CanvasPaperStyle) -> Result<DocumentCompositeSurface?, DocumentMutationFailure>,
        compositePNGData: @escaping @Sendable (CanvasPaperStyle) -> Result<Data?, DocumentMutationFailure>,
        timelapseCapture: @escaping @Sendable () -> Result<TimelapseCapture?, DocumentMutationFailure>
    ) {
        self.compositeSurfaceHandler = compositeSurface
        self.compositePNGDataHandler = compositePNGData
        self.timelapseCaptureHandler = timelapseCapture
    }

    public func compositeSurface(_ paperStyle: CanvasPaperStyle) -> Result<DocumentCompositeSurface?, DocumentMutationFailure> {
        compositeSurfaceHandler(paperStyle)
    }

    public func compositePNGData(_ paperStyle: CanvasPaperStyle) -> Result<Data?, DocumentMutationFailure> {
        compositePNGDataHandler(paperStyle)
    }

    public func timelapseCapture() -> Result<TimelapseCapture?, DocumentMutationFailure> {
        timelapseCaptureHandler()
    }
}

public struct DocumentRenderingWorkflow: Sendable {
    private let compositedPaperPreviewRGBAHandler: @Sendable (Data, Int, Int, CanvasPaperStyle) -> DocumentRenderingResult<Data>
    private let compositedPreviewPixelDataHandler: @Sendable (MetalDocumentSnapshot, Int, Data) -> DocumentRenderingResult<Data>
    private let processedLayerPixelDataHandler: @Sendable (Data, Int, Int, LayerProcessingRequest) -> DocumentRenderingResult<Data>
    private let alphaMaskHandler: @Sendable (Data, Int, Int) -> DocumentRenderingResult<[UInt8]>
    private let croppedSelectionMaskHandler: @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?
    private let scaledPixelDataHandler: @Sendable (Data, Int, Int, Int, Int) -> DocumentRenderingResult<Data>
    private let translatedPixelDataHandler: @Sendable (Data, Int, Int, Int, Int, Int, Int) -> DocumentRenderingResult<Data>

    package init(
        compositedPaperPreviewRGBA: @escaping @Sendable (Data, Int, Int, CanvasPaperStyle) -> DocumentRenderingResult<Data>,
        compositedPreviewPixelData: @escaping @Sendable (MetalDocumentSnapshot, Int, Data) -> DocumentRenderingResult<Data>,
        processedLayerPixelData: @escaping @Sendable (Data, Int, Int, LayerProcessingRequest) -> DocumentRenderingResult<Data>,
        alphaMask: @escaping @Sendable (Data, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        croppedSelectionMask: @escaping @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?,
        scaledPixelData: @escaping @Sendable (Data, Int, Int, Int, Int) -> DocumentRenderingResult<Data>,
        translatedPixelData: @escaping @Sendable (Data, Int, Int, Int, Int, Int, Int) -> DocumentRenderingResult<Data>
    ) {
        self.compositedPaperPreviewRGBAHandler = compositedPaperPreviewRGBA
        self.compositedPreviewPixelDataHandler = compositedPreviewPixelData
        self.processedLayerPixelDataHandler = processedLayerPixelData
        self.alphaMaskHandler = alphaMask
        self.croppedSelectionMaskHandler = croppedSelectionMask
        self.scaledPixelDataHandler = scaledPixelData
        self.translatedPixelDataHandler = translatedPixelData
    }

    public init(operations: DocumentRenderingOperations) {
        self.init(
            compositedPaperPreviewRGBA: operations.compositedPaperPreviewRGBA,
            compositedPreviewPixelData: operations.compositedPreviewPixelData,
            processedLayerPixelData: operations.processedLayerPixelData,
            alphaMask: operations.alphaMask,
            croppedSelectionMask: operations.croppedSelectionMask,
            scaledPixelData: operations.scaledPixelData,
            translatedPixelData: operations.translatedPixelData
        )
    }

    public func compositedPaperPreviewRGBA(
        _ surface: RgbaSurface,
        _ paperStyle: CanvasPaperStyle
    ) -> DocumentRenderingResult<Data> {
        compositedPaperPreviewRGBAHandler(surface.data, surface.width, surface.height, paperStyle)
    }

    public func compositedPreviewPixelData(
        _ snapshot: MetalDocumentSnapshot,
        activeLayerIndex: ExistingLayerIndex,
        adjustedActiveLayerPixels: RgbaSurface
    ) -> DocumentRenderingResult<Data> {
        compositedPreviewPixelDataHandler(snapshot, activeLayerIndex.rawValue, adjustedActiveLayerPixels.data)
    }

    public func processedLayerPixelData(
        _ source: RgbaSurface,
        _ request: LayerProcessingRequest
    ) -> DocumentRenderingResult<Data> {
        processedLayerPixelDataHandler(source.data, source.width, source.height, request)
    }

    public func alphaMask(_ surface: RgbaSurface) -> DocumentRenderingResult<[UInt8]> {
        alphaMaskHandler(surface.data, surface.width, surface.height)
    }

    public func croppedSelectionMask(_ mask: MaskSurface) -> DocumentCroppedSelectionMask? {
        croppedSelectionMaskHandler(Array(mask.data), mask.width, mask.height)
    }

    public func scaledPixelData(_ source: RgbaSurface, targetGeometry: PixelGeometry) -> DocumentRenderingResult<Data> {
        scaledPixelDataHandler(source.data, source.width, source.height, targetGeometry.width, targetGeometry.height)
    }

    public func translatedPixelData(
        _ source: RgbaSurface,
        targetGeometry: PixelGeometry,
        offsetX: Int,
        offsetY: Int
    ) -> DocumentRenderingResult<Data> {
        translatedPixelDataHandler(source.data, source.width, source.height, targetGeometry.width, targetGeometry.height, offsetX, offsetY)
    }

}



package struct DocumentRuntimeServices: Sendable {
    package let canvasCommands: DocumentCanvasCommandService
    package let layerCommands: DocumentLayerCommandService
    package let strokeCommands: DocumentStrokeCommandService
    package let canvasStrokeInteractionService: CanvasStrokeInteractionService
    package let historyCommands: DocumentHistoryCommandService
    package let mutationWorkflow: DocumentMutationWorkflowService
    package let contentService: DocumentContentService
    package let canvasEditingWorkflow: CanvasEditingWorkflowService
    package let selectionWorkflow: SelectionWorkflowService
    package let canvasPreviewRenderer: any CanvasPreviewRendering
    package let canvasEyedropperSampler: any CanvasEyedropperSampling
    package let layerTransformProcessor: any LayerTransformProcessing
    package let selectionMaskProcessor: any SelectionMaskProcessing
    package let canvasPresentationEnvironment: CanvasPresentationEnvironment
    package let presentationReader: DocumentPresentationReader
    package let renderingWorkflow: DocumentRenderingWorkflow
    package let textLayerService: DocumentTextLayerService
    package let exportClient: DocumentExportClient
    package let persistenceClient: DocumentPersistenceClient

    package init(
        canvasCommands: DocumentCanvasCommandService,
        layerCommands: DocumentLayerCommandService,
        strokeCommands: DocumentStrokeCommandService,
        canvasStrokeInteractionService: CanvasStrokeInteractionService,
        historyCommands: DocumentHistoryCommandService,
        mutationWorkflow: DocumentMutationWorkflowService,
        contentService: DocumentContentService,
        canvasEditingWorkflow: CanvasEditingWorkflowService,
        selectionWorkflow: SelectionWorkflowService,
        canvasPreviewRenderer: any CanvasPreviewRendering,
        canvasEyedropperSampler: any CanvasEyedropperSampling,
        layerTransformProcessor: any LayerTransformProcessing,
        selectionMaskProcessor: any SelectionMaskProcessing,
        canvasPresentationEnvironment: CanvasPresentationEnvironment,
        presentationReader: DocumentPresentationReader,
        renderingWorkflow: DocumentRenderingWorkflow,
        textLayerService: DocumentTextLayerService,
        exportClient: DocumentExportClient,
        persistenceClient: DocumentPersistenceClient
    ) {
        self.canvasCommands = canvasCommands
        self.layerCommands = layerCommands
        self.strokeCommands = strokeCommands
        self.canvasStrokeInteractionService = canvasStrokeInteractionService
        self.historyCommands = historyCommands
        self.mutationWorkflow = mutationWorkflow
        self.contentService = contentService
        self.canvasEditingWorkflow = canvasEditingWorkflow
        self.selectionWorkflow = selectionWorkflow
        self.canvasPreviewRenderer = canvasPreviewRenderer
        self.canvasEyedropperSampler = canvasEyedropperSampler
        self.layerTransformProcessor = layerTransformProcessor
        self.selectionMaskProcessor = selectionMaskProcessor
        self.canvasPresentationEnvironment = canvasPresentationEnvironment
        self.presentationReader = presentationReader
        self.renderingWorkflow = renderingWorkflow
        self.textLayerService = textLayerService
        self.exportClient = exportClient
        self.persistenceClient = persistenceClient
    }
}


public struct DocumentPresentationRuntime: Sendable {
    private let presentationReader: DocumentPresentationReader
    private let renderingPipeline: DocumentRenderingWorkflow

    public init(
        lightweightPresentation: @escaping @Sendable () -> Result<PaintDocumentPresentation, DocumentMutationFailure>,
        presentation: @escaping @Sendable () -> Result<PaintDocumentPresentation, DocumentMutationFailure>,
        renderingWorkflow: DocumentRenderingWorkflow
    ) {
        self.presentationReader = DocumentPresentationReader(
            lightweightPresentation: lightweightPresentation,
            presentation: presentation
        )
        self.renderingPipeline = renderingWorkflow
    }

    package init(services: DocumentRuntimeServices) {
        self.presentationReader = services.presentationReader
        self.renderingPipeline = services.renderingWorkflow
    }

    public func lightweightPresentation() -> Result<PaintDocumentPresentation, DocumentMutationFailure> {
        presentationReader.lightweightPresentation()
    }

    public func presentation() -> Result<PaintDocumentPresentation, DocumentMutationFailure> {
        presentationReader.presentation()
    }

    public var renderingWorkflow: DocumentRenderingWorkflow {
        renderingPipeline
    }

    public func compositedPaperPreviewRGBA(
        _ surface: RgbaSurface,
        _ paperStyle: CanvasPaperStyle
    ) -> DocumentRenderingResult<Data> {
        renderingPipeline.compositedPaperPreviewRGBA(surface, paperStyle)
    }

    public func compositedPreviewPixelData(
        _ snapshot: MetalDocumentSnapshot,
        activeLayerIndex: ExistingLayerIndex,
        adjustedActiveLayerPixels: RgbaSurface
    ) -> DocumentRenderingResult<Data> {
        renderingPipeline.compositedPreviewPixelData(
            snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    public func processedLayerPixelData(
        _ source: RgbaSurface,
        _ request: LayerProcessingRequest
    ) -> DocumentRenderingResult<Data> {
        renderingPipeline.processedLayerPixelData(source, request)
    }

    public func alphaMask(_ surface: RgbaSurface) -> DocumentRenderingResult<[UInt8]> {
        renderingPipeline.alphaMask(surface)
    }

    public func croppedSelectionMask(_ mask: MaskSurface) -> DocumentCroppedSelectionMask? {
        renderingPipeline.croppedSelectionMask(mask)
    }

    public func scaledPixelData(_ source: RgbaSurface, targetGeometry: PixelGeometry) -> DocumentRenderingResult<Data> {
        renderingPipeline.scaledPixelData(source, targetGeometry: targetGeometry)
    }

    public func translatedPixelData(
        _ source: RgbaSurface,
        targetGeometry: PixelGeometry,
        offsetX: Int,
        offsetY: Int
    ) -> DocumentRenderingResult<Data> {
        renderingPipeline.translatedPixelData(source, targetGeometry: targetGeometry, offsetX: offsetX, offsetY: offsetY)
    }

}

public struct CanvasMutationRuntime: Sendable {
    private let canvasCommands: DocumentCanvasCommandService
    private let historyCommands: DocumentHistoryCommandService

    public init(
        canvasCommands: DocumentCanvasCommandService,
        historyCommands: DocumentHistoryCommandService
    ) {
        self.canvasCommands = canvasCommands
        self.historyCommands = historyCommands
    }

    package init(services: DocumentRuntimeServices) {
        self.canvasCommands = services.canvasCommands
        self.historyCommands = services.historyCommands
    }

    public func createCanvas(_ size: ValidCanvasSize) -> DocumentMutationResult {
        canvasCommands.createCanvas(size.width, size.height)
    }

    package func createCanvas(_ width: Int, _ height: Int) -> DocumentMutationResult {
        canvasCommands.createCanvas(width, height)
    }

    public func resizeCanvas(_ size: ValidCanvasSize) -> DocumentMutationResult {
        canvasCommands.resizeCanvas(size.width, size.height)
    }

    package func resizeCanvas(_ width: Int, _ height: Int) -> DocumentMutationResult {
        canvasCommands.resizeCanvas(width, height)
    }

    public func resizeCanvasExtent(_ size: ValidCanvasSize) -> DocumentMutationResult {
        canvasCommands.resizeCanvasExtent(size.width, size.height)
    }

    package func resizeCanvasExtent(_ width: Int, _ height: Int) -> DocumentMutationResult {
        canvasCommands.resizeCanvasExtent(width, height)
    }

    public func initializeImportedCanvas(_ request: ImportedCanvasRequest, _ layerName: String) -> DocumentMutationResult {
        canvasCommands.initializeImportedCanvas(request, layerName)
    }

    public func compositeSurface() -> Result<DocumentCompositeSurface, DocumentMutationFailure> {
        canvasCommands.compositeSurface()
    }

    public func undo() -> DocumentMutationResult {
        historyCommands.undo()
    }

    public func redo() -> DocumentMutationResult {
        historyCommands.redo()
    }

    public func trimHistoryForMemoryPressure() {
        historyCommands.trimForMemoryPressure()
    }

    public func trimForMemoryPressure() {
        historyCommands.trimForMemoryPressure()
    }
}

public struct LayerEditingRuntime: Sendable {
    private let layerCommands: DocumentLayerCommandService
    private let mutationWorkflow: DocumentMutationWorkflowService
    private let contentService: DocumentContentService
    private let textLayerService: DocumentTextLayerService
    private let selectionWorkflow: SelectionWorkflowService
    private let canvasStrokeInteractionService: CanvasStrokeInteractionService
    private let layerTransformProcessor: any LayerTransformProcessing
    private let canvasEditingWorkflow: CanvasEditingWorkflowService

    public init(
        layerCommands: DocumentLayerCommandService,
        mutationWorkflow: DocumentMutationWorkflowService,
        contentService: DocumentContentService,
        textLayerService: DocumentTextLayerService,
        selectionWorkflow: SelectionWorkflowService,
        canvasStrokeInteractionService: CanvasStrokeInteractionService,
        layerTransformProcessor: any LayerTransformProcessing,
        canvasEditingWorkflow: CanvasEditingWorkflowService
    ) {
        self.layerCommands = layerCommands
        self.mutationWorkflow = mutationWorkflow
        self.contentService = contentService
        self.textLayerService = textLayerService
        self.selectionWorkflow = selectionWorkflow
        self.canvasStrokeInteractionService = canvasStrokeInteractionService
        self.layerTransformProcessor = layerTransformProcessor
        self.canvasEditingWorkflow = canvasEditingWorkflow
    }

    package init(services: DocumentRuntimeServices) {
        self.layerCommands = services.layerCommands
        self.mutationWorkflow = services.mutationWorkflow
        self.contentService = services.contentService
        self.textLayerService = services.textLayerService
        self.selectionWorkflow = services.selectionWorkflow
        self.canvasStrokeInteractionService = services.canvasStrokeInteractionService
        self.layerTransformProcessor = services.layerTransformProcessor
        self.canvasEditingWorkflow = services.canvasEditingWorkflow
    }

    public func addLayer(named name: String) -> DocumentIndexedMutationResult { mutationWorkflow.addLayer(named: name) }
    public func createFolder(named name: String, afterLayerAt anchorLayerIndex: LayerAnchorIndex) -> DocumentIndexedMutationResult { mutationWorkflow.createFolder(named: name, afterLayerAt: anchorLayerIndex) }
    public func deleteFolder(_ folderID: ExistingFolderID) -> DocumentMutationResult { mutationWorkflow.deleteFolder(folderID) }
    public func deleteLayer(_ index: ExistingLayerIndex) -> DocumentMutationResult { mutationWorkflow.deleteLayer(index) }
    public func duplicateLayer(_ index: ExistingLayerIndex, named duplicateName: String) -> DocumentIndexedMutationResult { mutationWorkflow.duplicateLayer(index, named: duplicateName) }
    public func moveLayer(_ index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex) -> DocumentMutationResult { mutationWorkflow.moveLayer(index, to: destinationIndex) }
    public func assignLayer(_ index: ExistingLayerIndex, toFolder folderID: ExistingFolderID?) -> DocumentMutationResult { mutationWorkflow.assignLayer(index, toFolder: folderID) }
    public func mergeLayerDown(_ index: ExistingLayerIndex) -> DocumentMutationResult { mutationWorkflow.mergeLayerDown(index) }
    public func setLayerVisibility(_ index: ExistingLayerIndex, visible: Bool) -> DocumentMutationResult { mutationWorkflow.setLayerVisibility(index, visible: visible) }
    public func setActiveLayer(_ index: ExistingLayerIndex) -> DocumentMutationResult { mutationWorkflow.setActiveLayer(index) }
    public func setLayerOpacity(_ index: ExistingLayerIndex, opacity: UnitInterval) -> DocumentMutationResult { mutationWorkflow.setLayerOpacity(index, opacity: opacity) }
    public func setLayerLocked(_ index: ExistingLayerIndex, isLocked: Bool) -> DocumentMutationResult { mutationWorkflow.setLayerLocked(index, isLocked: isLocked) }
    public func setLayerAlphaLocked(_ index: ExistingLayerIndex, isAlphaLocked: Bool) -> DocumentMutationResult { mutationWorkflow.setLayerAlphaLocked(index, isAlphaLocked: isAlphaLocked) }
    public func setLayerClipped(_ index: ExistingLayerIndex, isClipped: Bool) -> DocumentMutationResult { mutationWorkflow.setLayerClipped(index, isClipped: isClipped) }
    public func setFolderExpanded(_ folderID: ExistingFolderID, isExpanded: Bool) -> DocumentMutationResult { mutationWorkflow.setFolderExpanded(folderID, isExpanded: isExpanded) }
    public func setFolderVisibility(_ folderID: ExistingFolderID, visible: Bool) -> DocumentMutationResult { mutationWorkflow.setFolderVisibility(folderID, visible: visible) }
    public func setFolderName(_ folderID: ExistingFolderID, name: String) -> DocumentMutationResult { mutationWorkflow.setFolderName(folderID, name: name) }
    public func setLayerBlendMode(_ index: ExistingLayerIndex, blendMode: LayerBlendMode) -> DocumentMutationResult { mutationWorkflow.setLayerBlendMode(index, blendMode: blendMode) }
    public func setLayerName(_ index: ExistingLayerIndex, name: String) -> DocumentMutationResult { mutationWorkflow.setLayerName(index, name: name) }
    public func applyLayerProcessing(_ index: EditableLayerIndex, request: LayerProcessingRequest) -> DocumentMutationResult { mutationWorkflow.applyLayerProcessing(index, request: request) }
    public func setTextLayer(_ index: EditableLayerIndex, textLayer: TextLayerData) -> DocumentMutationResult { mutationWorkflow.setTextLayer(index, textLayer: textLayer) }
    public func clearLayer(_ index: EditableLayerIndex) -> DocumentMutationResult { mutationWorkflow.clearLayer(index) }
    public func replaceLayerMask(_ index: EditableLayerIndex, mask: LayerMaskData) -> DocumentMutationResult { mutationWorkflow.replaceLayerMask(index, mask: mask) }
    public func clearLayerMask(_ index: EditableLayerIndex) -> DocumentMutationResult { mutationWorkflow.clearLayerMask(index) }
    public func applyLayerMask(_ index: EditableLayerIndex) -> DocumentMutationResult { mutationWorkflow.applyLayerMask(index) }

    public func pixelDataForLayer(_ index: ExistingLayerIndex) -> Result<LayerPixelData, DocumentMutationFailure> { contentService.pixelDataForLayer(index) }
    public func replaceLayerPixels(_ command: LayerPixelReplacementCommand) -> DocumentMutationResult { contentService.replaceLayerPixels(command) }
    public func applyPixels(_ pixelData: LayerPixelData, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> { contentService.applyPixels(pixelData, to: target) }
    public func applyTextLayer(_ textLayer: TextLayerData, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> { contentService.applyTextLayer(textLayer, to: target) }
    public func replaceLayerPixelsInRect(_ index: EditableLayerIndex, _ rect: LayerPixelRect, _ pixelData: LayerPixelData) -> DocumentMutationResult { layerCommands.replaceLayerPixelsInRect(index.rawValue, rect, pixelData.rgba) }
    public func textLayerData(_ index: ExistingLayerIndex) -> Result<TextLayerData?, DocumentMutationFailure> { textLayerService.textLayerData(index) }
    public func clearTextLayerData(_ index: EditableLayerIndex) -> DocumentMutationResult { textLayerService.clearTextLayerData(index) }
    public func execute(_ command: CanvasEditingCommand, state context: CanvasEditingContext) -> CanvasEditingOutcome { canvasEditingWorkflow.execute(command, state: context) }
    public func executeCanvasEditing(_ command: CanvasEditingCommand, state context: CanvasEditingContext) -> CanvasEditingOutcome { canvasEditingWorkflow.execute(command, state: context) }
    public func revealLayerForEditing(_ index: ExistingLayerIndex) -> DocumentMutationResult { layerCommands.revealLayerForEditing(index.rawValue) }
    public func ensureLayerVisible(_ index: ExistingLayerIndex) -> DocumentMutationResult { layerCommands.ensureLayerVisible(index.rawValue) }
    public func applyLayerSurfaceMutation(_ index: EditableLayerIndex, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult { layerCommands.applyLayerSurfaceMutation(index.rawValue, payload) }
    public func applyLayerMutation(_ index: EditableLayerIndex, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult { layerCommands.applyLayerMutation(index.rawValue, payload) }
    public func applyTextLayerMutation(_ index: EditableLayerIndex, _ textLayer: TextLayerData, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult { layerCommands.applyTextLayerMutation(index.rawValue, textLayer, payload) }
    public func discardPreviewLease(_ lease: StrokePreviewLease) { canvasStrokeInteractionService.discardPreviewLease(lease) }
    public func transformedLayerPixels(
        source: RgbaSurface,
        selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets
    ) -> Data? {
        layerTransformProcessor.transformedLayerPixels(
            source: source,
            selection: selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets
        )
    }

    public func transformedSelection(
        _ selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets,
        canvasSize: CGSize
    ) -> CanvasSelection? {
        layerTransformProcessor.transformedSelection(
            selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets,
            canvasSize: canvasSize
        )
    }

    public func transformationBounds(selection: CanvasSelection?, surface: RgbaSurface) -> CGRect? {
        layerTransformProcessor.transformationBounds(
            selection: selection,
            surface: surface
        )
    }

    public func combinedSelection(existing: CanvasSelection?, incoming: CanvasSelection?, mode: SelectionCombineMode, canvasSize: CGSize) -> CanvasSelection? { selectionWorkflow.combinedSelection(existing: existing, incoming: incoming, mode: mode, canvasSize: canvasSize) }
    public func makeRectangleSelection(from startPoint: CGPoint, to endPoint: CGPoint, canvasSize: CGSize) -> CanvasSelection? { selectionWorkflow.makeRectangleSelection(from: startPoint, to: endPoint, canvasSize: canvasSize) }
    public func expandedMask(from selection: CanvasSelection, canvasGeometry: PixelGeometry) -> MaskSurface? { selectionWorkflow.expandedMask(from: selection, canvasGeometry: canvasGeometry) }
    public func adjustedSelection(_ selection: CanvasSelection?, canvasSize: CGSize, expansion: Int, isInverted: Bool) -> CanvasSelection? { selectionWorkflow.adjustedSelection(selection, canvasSize: canvasSize, expansion: expansion, isInverted: isInverted) }
    public func invertedSelection(_ selection: CanvasSelection?, canvasSize: CGSize, mode: SelectionToolMode) -> CanvasSelection? { selectionWorkflow.invertedSelection(selection, canvasSize: canvasSize, mode: mode) }
    public func featheredSelection(_ selection: CanvasSelection?, canvasSize: CGSize, radius: Int) -> CanvasSelection? { selectionWorkflow.featheredSelection(selection, canvasSize: canvasSize, radius: radius) }
    public func makeLassoSelection(from points: [CGPoint], canvasSize: CGSize) -> CanvasSelection? { selectionWorkflow.makeLassoSelection(from: points, canvasSize: canvasSize) }
    public func makeAutoSelection(at point: CGPoint, snapshot: MetalDocumentSnapshot?, layerIndex: ExistingLayerIndex, thresholdMode: FillThresholdMode, opacityTolerance: Double, colorTolerance: Double, expansion: Int) -> CanvasSelection? { selectionWorkflow.makeAutoSelection(at: point, snapshot: snapshot, layerIndex: layerIndex, thresholdMode: thresholdMode, opacityTolerance: opacityTolerance, colorTolerance: colorTolerance, expansion: expansion) }
    public func makeColorRangeSelection(request: ColorRangeSelectionRequest, snapshot: MetalDocumentSnapshot?, activeLayerIndex: ExistingLayerIndex, mode: SelectionToolMode) -> CanvasSelection? { selectionWorkflow.makeColorRangeSelection(request: request, snapshot: snapshot, activeLayerIndex: activeLayerIndex, mode: mode) }
    public func expandedSelectionMask(_ source: MaskSurface, expansion: Int) -> MaskSurface { selectionWorkflow.expandedSelectionMask(source, expansion: expansion) }
    public func contractedSelectionMask(_ source: MaskSurface, contraction: Int) -> MaskSurface { selectionWorkflow.contractedSelectionMask(source, contraction: contraction) }
    public func featheredSelectionMask(_ source: MaskSurface, radius: Int) -> MaskSurface { selectionWorkflow.featheredSelectionMask(source, radius: radius) }
    public func invertedSelectionMask(_ source: MaskSurface) -> MaskSurface { selectionWorkflow.invertedSelectionMask(source) }
    public func croppedSelection(from source: MaskSurface, mode: SelectionToolMode) -> CanvasSelection? { selectionWorkflow.croppedSelection(from: source, mode: mode) }
    public func closedPolygon(_ points: [CGPoint], canvasSize: CGSize) -> [CGPoint] { selectionWorkflow.closedPolygon(points, canvasSize: canvasSize) }
}

package struct CanvasStrokeRuntime: Sendable {
    private let strokeCommands: DocumentStrokeCommandService
    private let canvasStrokeInteractionService: CanvasStrokeInteractionService

    package init(
        strokeCommands: DocumentStrokeCommandService,
        canvasStrokeInteractionService: CanvasStrokeInteractionService
    ) {
        self.strokeCommands = strokeCommands
        self.canvasStrokeInteractionService = canvasStrokeInteractionService
    }

    package init(services: DocumentRuntimeServices) {
        self.strokeCommands = services.strokeCommands
        self.canvasStrokeInteractionService = services.canvasStrokeInteractionService
    }

    public func beginStroke(_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult { strokeCommands.beginStroke(sample, brush) }
    public func appendStroke(_ sample: StylusSample) -> DocumentMutationResult { strokeCommands.appendStroke(sample) }
    public func endStroke() -> DocumentMutationResult { strokeCommands.endStroke() }
    public func cancelStroke() -> DocumentMutationResult { strokeCommands.cancelStroke() }
    public func applyGpuStrokeSurface(_ samples: [StylusSample], _ brush: BrushRuntimeSettings, layerIndex: EditableLayerIndex) -> DocumentMutationResult { strokeCommands.applyGpuStrokeSurface(samples, brush, layerIndex.rawValue) }
    public func blurStroke(_ samples: [StylusSample], _ brush: BrushRuntimeSettings, layerIndex: EditableLayerIndex, clearSelectionAfterBlur: Bool) -> DocumentMutationResult { strokeCommands.blurStroke(samples, brush, layerIndex.rawValue, clearSelectionAfterBlur) }
    public func endBlurStroke() -> DocumentMutationResult { strokeCommands.endBlurStroke() }
    public func cancelBlurStroke() -> DocumentMutationResult { strokeCommands.cancelBlurStroke() }
    public func fill(_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult { strokeCommands.fill(sample, brush) }
    public func cancel() -> GpuStrokeSessionOutcome { canvasStrokeInteractionService.cancel() }
    public func cancelPreview() -> GpuStrokeSessionOutcome { canvasStrokeInteractionService.cancel() }
    public func discardPreviewLease(_ lease: StrokePreviewLease) { canvasStrokeInteractionService.discardPreviewLease(lease) }
    public func beginPreview(sample: StylusSample, baseSnapshot: MetalDocumentSnapshot?, context: DocumentStrokeContext, usesResponsivePreview: Bool) -> GpuStrokeSessionOutcome { canvasStrokeInteractionService.beginPreview(sample: sample, baseSnapshot: baseSnapshot, context: context, usesResponsivePreview: usesResponsivePreview) }
    public func appendPreview(baseSnapshot: MetalDocumentSnapshot?, renderSnapshot: MetalDocumentSnapshot?, renderState: StrokeSessionRenderState?, samples: [StylusSample], fullSamples: [StylusSample], context: DocumentStrokeContext, usesResponsivePreview: Bool) -> GpuStrokeSessionOutcome { canvasStrokeInteractionService.appendPreview(baseSnapshot: baseSnapshot, renderSnapshot: renderSnapshot, renderState: renderState, samples: samples, fullSamples: fullSamples, context: context, usesResponsivePreview: usesResponsivePreview) }
    public func finish(renderState: StrokeSessionRenderState?, baseSnapshot: MetalDocumentSnapshot?, renderSnapshot: MetalDocumentSnapshot?, samples: [StylusSample], context: DocumentStrokeContext, allowsApproximatePreviewCommit: Bool, refreshViaDirtyPresentation: Bool) -> GpuStrokeSessionOutcome { canvasStrokeInteractionService.finish(renderState: renderState, baseSnapshot: baseSnapshot, renderSnapshot: renderSnapshot, samples: samples, context: context, allowsApproximatePreviewCommit: allowsApproximatePreviewCommit, refreshViaDirtyPresentation: refreshViaDirtyPresentation) }
    public func finishPreview(renderState: StrokeSessionRenderState?, baseSnapshot: MetalDocumentSnapshot?, renderSnapshot: MetalDocumentSnapshot?, samples: [StylusSample], context: DocumentStrokeContext, allowsApproximatePreviewCommit: Bool, refreshViaDirtyPresentation: Bool) -> GpuStrokeSessionOutcome { canvasStrokeInteractionService.finish(renderState: renderState, baseSnapshot: baseSnapshot, renderSnapshot: renderSnapshot, samples: samples, context: context, allowsApproximatePreviewCommit: allowsApproximatePreviewCommit, refreshViaDirtyPresentation: refreshViaDirtyPresentation) }
    public func previewLease(for mutation: GpuCommitMutation) -> StrokePreviewLease {
        StrokePreviewLease(surfaceHandle: mutation.surface.handle.buffer)
    }
}

public struct StrokeEditingRuntime: Sendable {
    private let strokeRuntime: CanvasStrokeRuntime

    public init(
        strokeCommands: DocumentStrokeCommandService,
        canvasStrokeInteractionService: CanvasStrokeInteractionService
    ) {
        self.strokeRuntime = CanvasStrokeRuntime(
            strokeCommands: strokeCommands,
            canvasStrokeInteractionService: canvasStrokeInteractionService
        )
    }

    package init(strokeRuntime: CanvasStrokeRuntime) {
        self.strokeRuntime = strokeRuntime
    }

    public func beginStroke(_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult {
        strokeRuntime.beginStroke(sample, brush)
    }

    public func appendStroke(_ sample: StylusSample) -> DocumentMutationResult {
        strokeRuntime.appendStroke(sample)
    }

    public func endStroke() -> DocumentMutationResult {
        strokeRuntime.endStroke()
    }

    public func cancelStroke() -> DocumentMutationResult {
        strokeRuntime.cancelStroke()
    }

    public func applyGpuStrokeSurface(_ samples: [StylusSample], _ brush: BrushRuntimeSettings, layerIndex: EditableLayerIndex) -> DocumentMutationResult {
        strokeRuntime.applyGpuStrokeSurface(samples, brush, layerIndex: layerIndex)
    }

    public func blurStroke(_ samples: [StylusSample], _ brush: BrushRuntimeSettings, layerIndex: EditableLayerIndex, clearSelectionAfterBlur: Bool) -> DocumentMutationResult {
        strokeRuntime.blurStroke(samples, brush, layerIndex: layerIndex, clearSelectionAfterBlur: clearSelectionAfterBlur)
    }

    public func endBlurStroke() -> DocumentMutationResult {
        strokeRuntime.endBlurStroke()
    }

    public func cancelBlurStroke() -> DocumentMutationResult {
        strokeRuntime.cancelBlurStroke()
    }

    public func fill(_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult {
        strokeRuntime.fill(sample, brush)
    }

    public func cancel() -> GpuStrokeSessionOutcome {
        strokeRuntime.cancel()
    }

    public func cancelPreview() -> GpuStrokeSessionOutcome {
        strokeRuntime.cancelPreview()
    }

    public func discardPreviewLease(_ lease: StrokePreviewLease) {
        strokeRuntime.discardPreviewLease(lease)
    }

    public func beginPreview(
        sample: StylusSample,
        baseSnapshot: MetalDocumentSnapshot?,
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome {
        strokeRuntime.beginPreview(
            sample: sample,
            baseSnapshot: baseSnapshot,
            context: context,
            usesResponsivePreview: usesResponsivePreview
        )
    }

    public func appendPreview(
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        renderState: StrokeSessionRenderState?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome {
        strokeRuntime.appendPreview(
            baseSnapshot: baseSnapshot,
            renderSnapshot: renderSnapshot,
            renderState: renderState,
            samples: samples,
            fullSamples: fullSamples,
            context: context,
            usesResponsivePreview: usesResponsivePreview
        )
    }

    public func finish(
        renderState: StrokeSessionRenderState?,
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        samples: [StylusSample],
        context: DocumentStrokeContext,
        allowsApproximatePreviewCommit: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> GpuStrokeSessionOutcome {
        strokeRuntime.finish(
            renderState: renderState,
            baseSnapshot: baseSnapshot,
            renderSnapshot: renderSnapshot,
            samples: samples,
            context: context,
            allowsApproximatePreviewCommit: allowsApproximatePreviewCommit,
            refreshViaDirtyPresentation: refreshViaDirtyPresentation
        )
    }

    public func finishPreview(
        renderState: StrokeSessionRenderState?,
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        samples: [StylusSample],
        context: DocumentStrokeContext,
        allowsApproximatePreviewCommit: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> GpuStrokeSessionOutcome {
        strokeRuntime.finishPreview(
            renderState: renderState,
            baseSnapshot: baseSnapshot,
            renderSnapshot: renderSnapshot,
            samples: samples,
            context: context,
            allowsApproximatePreviewCommit: allowsApproximatePreviewCommit,
            refreshViaDirtyPresentation: refreshViaDirtyPresentation
        )
    }

    public func previewLease(for mutation: GpuCommitMutation) -> StrokePreviewLease {
        strokeRuntime.previewLease(for: mutation)
    }
}

public struct DocumentPersistenceRuntime: Sendable {
    private let persistenceClient: DocumentPersistenceClient

    public init(persistenceClient: DocumentPersistenceClient) {
        self.persistenceClient = persistenceClient
    }

    package init(services: DocumentRuntimeServices) {
        self.persistenceClient = services.persistenceClient
    }

    public func saveProject(_ url: URL, _ paperStyle: CanvasPaperStyle) throws { try persistenceClient.saveProject(url, paperStyle) }
    public func loadProject(_ url: URL) throws -> LoadedPaintProject { try persistenceClient.loadProject(url) }
    public func setPaperStyle(_ paperStyle: CanvasPaperStyle) -> DocumentMutationResult { persistenceClient.setPaperStyle(paperStyle) }
    public func newCanvas(_ size: ValidCanvasSize) -> DocumentMutationResult { persistenceClient.newCanvas(size) }
    package func newCanvas(_ width: Int, _ height: Int) -> DocumentMutationResult { persistenceClient.newCanvas(width, height) }
    public func prewarmDrawingResources() -> DocumentMutationResult { persistenceClient.prewarmDrawingResources() }
}

public struct DocumentExportRuntime: Sendable {
    private let exportClient: DocumentExportClient

    public init(exportClient: DocumentExportClient) {
        self.exportClient = exportClient
    }

    package init(services: DocumentRuntimeServices) {
        self.exportClient = services.exportClient
    }

    public func compositeSurface(_ paperStyle: CanvasPaperStyle) -> Result<DocumentCompositeSurface?, DocumentMutationFailure> { exportClient.compositeSurface(paperStyle) }
    public func compositePNGData(_ paperStyle: CanvasPaperStyle) -> Result<Data?, DocumentMutationFailure> { exportClient.compositePNGData(paperStyle) }
    public func timelapseCapture() -> Result<TimelapseCapture?, DocumentMutationFailure> { exportClient.timelapseCapture() }
}

public struct CanvasPreviewRuntime: Sendable {
    private let canvasPreviewRenderer: any CanvasPreviewRendering
    private let canvasEyedropperSampler: any CanvasEyedropperSampling
    private let selectionMaskProcessor: any SelectionMaskProcessing
    private let canvasPresentationEnvironment: CanvasPresentationEnvironment

    public init(
        canvasPreviewRenderer: any CanvasPreviewRendering,
        canvasEyedropperSampler: any CanvasEyedropperSampling,
        selectionMaskProcessor: any SelectionMaskProcessing,
        canvasPresentationEnvironment: CanvasPresentationEnvironment
    ) {
        self.canvasPreviewRenderer = canvasPreviewRenderer
        self.canvasEyedropperSampler = canvasEyedropperSampler
        self.selectionMaskProcessor = selectionMaskProcessor
        self.canvasPresentationEnvironment = canvasPresentationEnvironment
    }

    package init(services: DocumentRuntimeServices) {
        self.canvasPreviewRenderer = services.canvasPreviewRenderer
        self.canvasEyedropperSampler = services.canvasEyedropperSampler
        self.selectionMaskProcessor = services.selectionMaskProcessor
        self.canvasPresentationEnvironment = services.canvasPresentationEnvironment
    }

    public func compositePreviewImageData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: ExistingLayerIndex,
        adjustedActiveLayerPixels: RgbaSurface
    ) -> Data? {
        canvasPreviewRenderer.compositePreviewImageData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex.rawValue,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels.data
        )
    }

    package func compositePreviewImageData(snapshot: MetalDocumentSnapshot, activeLayerIndex: Int, adjustedActiveLayerPixels: Data) -> Data? {
        canvasPreviewRenderer.compositePreviewImageData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    public func eyedropperLoupeSurface(
        source: RgbaSurface,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> DocumentCompositeSurface? {
        canvasPreviewRenderer.eyedropperLoupeSurface(
            sourcePixelData: source.data,
            canvasWidth: source.width,
            canvasHeight: source.height,
            centerX: centerX,
            centerY: centerY,
            gridSize: gridSize,
            paperStyle: paperStyle,
            blendWithPaper: blendWithPaper
        )
    }

    package func eyedropperLoupeSurface(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> DocumentCompositeSurface? {
        canvasPreviewRenderer.eyedropperLoupeSurface(
            sourcePixelData: sourcePixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            centerX: centerX,
            centerY: centerY,
            gridSize: gridSize,
            paperStyle: paperStyle,
            blendWithPaper: blendWithPaper
        )
    }

    public func paperCompositeSurface(_ surface: RgbaSurface, paperStyle: CanvasPaperStyle) -> DocumentCompositeSurface? {
        canvasPreviewRenderer.paperCompositeSurface(pixelData: surface.data, width: surface.width, height: surface.height, paperStyle: paperStyle)
    }

    package func paperCompositeSurface(pixelData: Data, width: Int, height: Int, paperStyle: CanvasPaperStyle) -> DocumentCompositeSurface? {
        canvasPreviewRenderer.paperCompositeSurface(pixelData: pixelData, width: width, height: height, paperStyle: paperStyle)
    }

    public func shapePreviewSurface(stroke: Stroke, style: PreviewStrokeStyle, canvasGeometry: PixelGeometry) -> DocumentCompositeSurface? {
        canvasPreviewRenderer.shapePreviewSurface(stroke: stroke, style: style, canvasWidth: canvasGeometry.width, canvasHeight: canvasGeometry.height)
    }

    public func transformedTextPreviewSurface(textLayer: TextLayerData, canvasGeometry: PixelGeometry) -> DocumentCompositeSurface? {
        canvasPreviewRenderer.transformedTextPreviewSurface(textLayer: textLayer, canvasWidth: canvasGeometry.width, canvasHeight: canvasGeometry.height)
    }

    public func transformedTextLayoutRect(textLayer: TextLayerData, canvasSize: CGSize) -> CGRect? {
        canvasPreviewRenderer.transformedTextLayoutRect(textLayer: textLayer, canvasSize: canvasSize)
    }

    public func sampledColor(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: ExistingLayerIndex,
        source: EyedropperSamplingSource,
        point: CGPoint,
        paperStyle: CanvasPaperStyle
    ) -> SampledColor? {
        canvasEyedropperSampler.sampledColor(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex.rawValue,
            source: source,
            point: point,
            paperStyle: paperStyle
        )
    }

    public func selectionOverlaySurface(_ mask: MaskSurface) -> DocumentCompositeSurface? {
        selectionMaskProcessor.selectionOverlaySurface(maskData: mask.data, width: mask.width, height: mask.height)
    }

    package func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        selectionMaskProcessor.selectionOverlaySurface(maskData: maskData, width: width, height: height)
    }

    public func presentationEnvironment() -> CanvasPresentationEnvironment {
        canvasPresentationEnvironment
    }
}

public struct DocumentApplicationRuntime: Sendable {
    private let presentation: DocumentPresentationRuntime
    private let canvasMutation: CanvasMutationRuntime
    private let strokeEditing: StrokeEditingRuntime
    private let layerEditing: LayerEditingRuntime
    private let persistence: DocumentPersistenceRuntime
    private let export: DocumentExportRuntime
    private let preview: CanvasPreviewRuntime

    public var workflows: DocumentApplicationWorkflowRuntime {
        DocumentApplicationWorkflowRuntime(
            presentation: presentation,
            canvasMutation: canvasMutation,
            strokeEditing: strokeEditing,
            layerEditing: layerEditing,
            persistence: persistence,
            export: export,
            preview: preview
        )
    }

    public init(
        presentation: DocumentPresentationRuntime,
        canvasMutation: CanvasMutationRuntime,
        strokeEditing: StrokeEditingRuntime,
        layerEditing: LayerEditingRuntime,
        persistence: DocumentPersistenceRuntime,
        export: DocumentExportRuntime,
        preview: CanvasPreviewRuntime
    ) {
        self.presentation = presentation
        self.canvasMutation = canvasMutation
        self.strokeEditing = strokeEditing
        self.layerEditing = layerEditing
        self.persistence = persistence
        self.export = export
        self.preview = preview
    }

}

public struct DocumentApplicationWorkflowRuntime: Sendable {
    public let presentation: DocumentPresentationRuntime
    public let canvasMutation: CanvasMutationRuntime
    public let strokeEditing: StrokeEditingRuntime
    public let layerEditing: LayerEditingRuntime
    public let persistence: DocumentPersistenceRuntime
    public let export: DocumentExportRuntime
    public let preview: CanvasPreviewRuntime

    public init(
        presentation: DocumentPresentationRuntime,
        canvasMutation: CanvasMutationRuntime,
        strokeEditing: StrokeEditingRuntime,
        layerEditing: LayerEditingRuntime,
        persistence: DocumentPersistenceRuntime,
        export: DocumentExportRuntime,
        preview: CanvasPreviewRuntime
    ) {
        self.presentation = presentation
        self.canvasMutation = canvasMutation
        self.strokeEditing = strokeEditing
        self.layerEditing = layerEditing
        self.persistence = persistence
        self.export = export
        self.preview = preview
    }
}

public struct DocumentRuntime: Sendable {
    private let executeHandler: @Sendable (DocumentCommand) async -> DocumentCommandOutcome
    private let observePresentationHandler: @Sendable () -> AsyncStream<PaintDocumentPresentation>

    public init(
        execute: @escaping @Sendable (DocumentCommand) async -> DocumentCommandOutcome,
        observePresentation: @escaping @Sendable () -> AsyncStream<PaintDocumentPresentation>
    ) {
        self.executeHandler = execute
        self.observePresentationHandler = observePresentation
    }

    public func execute(_ command: DocumentCommand) async -> DocumentCommandOutcome {
        await executeHandler(command)
    }

    public func observePresentation() -> AsyncStream<PaintDocumentPresentation> {
        observePresentationHandler()
    }

}



public struct DocumentProjectPreview: Equatable, Sendable {
    public let canvasSize: CGSize
    public let layerCount: Int
    public let previewSurface: DocumentCompositeSurface?

    public init(
        canvasSize: CGSize,
        layerCount: Int,
        previewSurface: DocumentCompositeSurface?
    ) {
        self.canvasSize = canvasSize
        self.layerCount = layerCount
        self.previewSurface = previewSurface
    }

}

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
