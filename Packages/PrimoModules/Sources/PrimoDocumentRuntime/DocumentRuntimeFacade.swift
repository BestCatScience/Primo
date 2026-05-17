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
    private let textLayerDataHandler: @Sendable (ExistingLayerIndex) -> Result<TextLayerDataOutcome, DocumentMutationFailure>
    private let setTextLayerHandler: @Sendable (EditableLayerIndex, TextLayerData) -> DocumentMutationResult
    private let clearTextLayerDataHandler: @Sendable (EditableLayerIndex) -> DocumentMutationResult

    public init(
        textLayerData: @escaping @Sendable (ExistingLayerIndex) -> Result<TextLayerDataOutcome, DocumentMutationFailure>,
        setTextLayer: @escaping @Sendable (EditableLayerIndex, TextLayerData) -> DocumentMutationResult,
        clearTextLayerData: @escaping @Sendable (EditableLayerIndex) -> DocumentMutationResult
    ) {
        self.textLayerDataHandler = textLayerData
        self.setTextLayerHandler = setTextLayer
        self.clearTextLayerDataHandler = clearTextLayerData
    }

    package init(
        textLayerGateway: TextLayerGateway,
        documentQueryGateway: DocumentQueryGateway,
        documentEditingGateway: DocumentEditingGateway
    ) {
        self.init(
            textLayerData: { index in
                Self.requireCurrent(index, documentQueryGateway: documentQueryGateway)
                    .flatMap { textLayerGateway.textLayerData($0.rawValue) }
            },
            setTextLayer: { index, textLayer in
                Self.requireEditable(index, documentQueryGateway: documentQueryGateway)
                    .flatMap { index in
                        documentEditingGateway.execute(.content(.setTextLayer(index: index.rawValue, textLayer: textLayer)))
                            .map { _ in () }
                    }
            },
            clearTextLayerData: { index in
                Self.requireEditable(index, documentQueryGateway: documentQueryGateway)
                    .flatMap { textLayerGateway.clearTextLayerData($0.rawValue) }
            }
        )
    }

    public func textLayerData(_ index: ExistingLayerIndex) -> Result<TextLayerDataOutcome, DocumentMutationFailure> {
        textLayerDataHandler(index)
    }

    public func setTextLayer(_ index: EditableLayerIndex, _ textLayer: TextLayerData) -> DocumentMutationResult {
        setTextLayerHandler(index, textLayer)
    }

    public func clearTextLayerData(_ index: EditableLayerIndex) -> DocumentMutationResult {
        clearTextLayerDataHandler(index)
    }

    private static func requireCurrent(
        _ index: ExistingLayerIndex,
        documentQueryGateway: DocumentQueryGateway
    ) -> Result<ExistingLayerIndex, DocumentMutationFailure> {
        currentMutationContext(documentQueryGateway: documentQueryGateway).flatMap { context in
            guard index.revision == context.revision else {
                return .failure(
                    .staleLayerIndex(
                        index: index.rawValue,
                        validationRevision: index.revision,
                        currentRevision: context.revision
                    )
                )
            }
            guard let currentIndex = context.existingLayerIndex(index.rawValue) else {
                return .failure(.invalidLayerIndex(index.rawValue))
            }
            return .success(currentIndex)
        }
    }

    private static func requireEditable(
        _ index: EditableLayerIndex,
        documentQueryGateway: DocumentQueryGateway
    ) -> Result<EditableLayerIndex, DocumentMutationFailure> {
        currentMutationContext(documentQueryGateway: documentQueryGateway).flatMap { context in
            guard index.revision == context.revision else {
                return .failure(
                    .staleLayerIndex(
                        index: index.rawValue,
                        validationRevision: index.revision,
                        currentRevision: context.revision
                    )
                )
            }
            guard let currentIndex = context.editableLayerIndex(index.rawValue) else {
                if context.containsLayerIndex(index.rawValue), context.isLayerLocked(index.rawValue) {
                    return .failure(.layerLocked(index.rawValue))
                }
                return .failure(.invalidLayerIndex(index.rawValue))
            }
            return .success(currentIndex)
        }
    }

    private static func currentMutationContext(
        documentQueryGateway: DocumentQueryGateway
    ) -> Result<DocumentLayerMutationContext, DocumentMutationFailure> {
        documentQueryGateway.lightweightPresentation().map { presentation in
            DocumentLayerMutationContext(
                revision: presentation.revision,
                layerIndexes: presentation.layerRows.map(\.index),
                folderIDs: Set(presentation.layerSidebarRows.compactMap { row in
                    if case let .folder(folder) = row { return folder.id }
                    return nil
                }),
                canvasGeometry: presentation.geometry,
                isLayerLocked: { rawValue in
                    presentation.layerRows.first { $0.index == rawValue }?.isLocked == true
                }
            )
        }
    }
}

public struct DocumentPersistenceClient: Sendable {
    private let saveProjectHandler: @Sendable (WritableProjectLocation, CanvasPaperStyle) throws -> Void
    private let loadProjectHandler: @Sendable (ProjectPackageLocation) throws -> LoadedPaintProject
    private let setPaperStyleHandler: @Sendable (CanvasPaperStyle) -> DocumentMutationResult
    private let newCanvasHandler: @Sendable (Int, Int) -> DocumentMutationResult
    private let prewarmDrawingResourcesHandler: @Sendable () -> DocumentMutationResult

    public init(
        saveProject: @escaping @Sendable (WritableProjectLocation, CanvasPaperStyle) throws -> Void,
        loadProject: @escaping @Sendable (ProjectPackageLocation) throws -> LoadedPaintProject,
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
        saveProject: @escaping @Sendable (WritableProjectLocation, CanvasPaperStyle) throws -> Void,
        loadProject: @escaping @Sendable (ProjectPackageLocation) throws -> LoadedPaintProject,
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

    public func saveProject(_ location: WritableProjectLocation, _ paperStyle: CanvasPaperStyle) throws {
        try saveProjectHandler(location, paperStyle)
    }

    public func loadProject(_ packageURL: ProjectPackageLocation) throws -> LoadedPaintProject {
        try loadProjectHandler(packageURL)
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
    private let compositeSurfaceHandler: @Sendable (CanvasPaperStyle) -> Result<PreviewOutcome, DocumentMutationFailure>
    private let compositePNGDataHandler: @Sendable (CanvasPaperStyle) -> Result<PreviewDataOutcome, DocumentMutationFailure>
    private let timelapseCaptureHandler: @Sendable () -> Result<TimelapseCaptureOutcome, DocumentMutationFailure>

    public init(
        compositeSurface: @escaping @Sendable (CanvasPaperStyle) -> Result<PreviewOutcome, DocumentMutationFailure>,
        compositePNGData: @escaping @Sendable (CanvasPaperStyle) -> Result<PreviewDataOutcome, DocumentMutationFailure>,
        timelapseCapture: @escaping @Sendable () -> Result<TimelapseCaptureOutcome, DocumentMutationFailure>
    ) {
        self.compositeSurfaceHandler = compositeSurface
        self.compositePNGDataHandler = compositePNGData
        self.timelapseCaptureHandler = timelapseCapture
    }

    public func compositeSurface(_ paperStyle: CanvasPaperStyle) -> Result<PreviewOutcome, DocumentMutationFailure> {
        compositeSurfaceHandler(paperStyle)
    }

    public func compositePNGData(_ paperStyle: CanvasPaperStyle) -> Result<PreviewDataOutcome, DocumentMutationFailure> {
        compositePNGDataHandler(paperStyle)
    }

    public func timelapseCapture() -> Result<TimelapseCaptureOutcome, DocumentMutationFailure> {
        timelapseCaptureHandler()
    }
}

public struct DocumentRenderingWorkflow: Sendable {
    private let compositedPaperPreviewRGBAHandler: @Sendable (Data, Int, Int, CanvasPaperStyle) -> DocumentRenderingResult<Data>
    private let compositedPreviewPixelDataHandler: @Sendable (MetalDocumentSnapshot, ExistingLayerIndex, RgbaSurface) -> DocumentRenderingResult<Data>
    private let processedLayerPixelDataHandler: @Sendable (Data, Int, Int, LayerProcessingRequest) -> DocumentRenderingResult<Data>
    private let alphaMaskHandler: @Sendable (Data, Int, Int) -> DocumentRenderingResult<[UInt8]>
    private let croppedSelectionMaskHandler: @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?
    private let scaledPixelDataHandler: @Sendable (Data, Int, Int, Int, Int) -> DocumentRenderingResult<Data>
    private let translatedPixelDataHandler: @Sendable (Data, Int, Int, Int, Int, Int, Int) -> DocumentRenderingResult<Data>

    package init(
        compositedPaperPreviewRGBA: @escaping @Sendable (Data, Int, Int, CanvasPaperStyle) -> DocumentRenderingResult<Data>,
        compositedPreviewPixelData: @escaping @Sendable (MetalDocumentSnapshot, ExistingLayerIndex, RgbaSurface) -> DocumentRenderingResult<Data>,
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

    package init(operations: DocumentRenderingOperations) {
        self.init(
            compositedPaperPreviewRGBA: operations.compositedPaperPreviewRGBA,
            compositedPreviewPixelData: { snapshot, activeLayerIndex, adjustedActiveLayerPixels in
                operations.compositedPreviewPixelData(
                    snapshot,
                    activeLayerIndex.rawValue,
                    adjustedActiveLayerPixels.data
                )
            },
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
        compositedPreviewPixelDataHandler(snapshot, activeLayerIndex, adjustedActiveLayerPixels)
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



package struct DocumentPresentationServices: Sendable {
    package let presentationReader: DocumentPresentationReader
    package let renderingWorkflow: DocumentRenderingWorkflow

    package init(
        presentationReader: DocumentPresentationReader,
        renderingWorkflow: DocumentRenderingWorkflow
    ) {
        self.presentationReader = presentationReader
        self.renderingWorkflow = renderingWorkflow
    }
}

package struct DocumentMutationServices: Sendable {
    package let canvas: DocumentCanvasMutationServices
    package let layerStructure: DocumentLayerStructureMutationServices
    package let layerContent: DocumentLayerContentMutationServices
    package let textLayer: DocumentTextLayerMutationServices
    package let selection: DocumentSelectionMutationServices
    package let canvasEditing: DocumentCanvasEditingMutationServices
    package let stroke: DocumentStrokeMutationServices
    package let previewLease: DocumentPreviewLeaseMutationServices

    package init(
        canvas: DocumentCanvasMutationServices,
        layerStructure: DocumentLayerStructureMutationServices,
        layerContent: DocumentLayerContentMutationServices,
        textLayer: DocumentTextLayerMutationServices,
        selection: DocumentSelectionMutationServices,
        canvasEditing: DocumentCanvasEditingMutationServices,
        stroke: DocumentStrokeMutationServices,
        previewLease: DocumentPreviewLeaseMutationServices
    ) {
        self.canvas = canvas
        self.layerStructure = layerStructure
        self.layerContent = layerContent
        self.textLayer = textLayer
        self.selection = selection
        self.canvasEditing = canvasEditing
        self.stroke = stroke
        self.previewLease = previewLease
    }

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
        textLayerService: DocumentTextLayerService
    ) {
        self.init(
            canvas: DocumentCanvasMutationServices(canvasCommands: canvasCommands, historyCommands: historyCommands),
            layerStructure: DocumentLayerStructureMutationServices(
                layerCommands: layerCommands,
                mutationWorkflow: mutationWorkflow
            ),
            layerContent: DocumentLayerContentMutationServices(
                layerCommands: layerCommands,
                contentService: contentService
            ),
            textLayer: DocumentTextLayerMutationServices(
                layerCommands: layerCommands,
                mutationWorkflow: mutationWorkflow,
                contentService: contentService,
                textLayerService: textLayerService
            ),
            selection: DocumentSelectionMutationServices(selectionWorkflow: selectionWorkflow),
            canvasEditing: DocumentCanvasEditingMutationServices(canvasEditingWorkflow: canvasEditingWorkflow),
            stroke: DocumentStrokeMutationServices(
                strokeCommands: strokeCommands,
                canvasStrokeInteractionService: canvasStrokeInteractionService
            ),
            previewLease: DocumentPreviewLeaseMutationServices(
                canvasStrokeInteractionService: canvasStrokeInteractionService
            )
        )
    }
}

package struct DocumentCanvasMutationServices: Sendable {
    package let canvasCommands: DocumentCanvasCommandService
    package let historyCommands: DocumentHistoryCommandService

    package init(
        canvasCommands: DocumentCanvasCommandService,
        historyCommands: DocumentHistoryCommandService
    ) {
        self.canvasCommands = canvasCommands
        self.historyCommands = historyCommands
    }
}

package struct DocumentLayerStructureMutationServices: Sendable {
    package let layerCommands: DocumentLayerCommandService
    package let mutationWorkflow: DocumentMutationWorkflowService

    package init(
        layerCommands: DocumentLayerCommandService,
        mutationWorkflow: DocumentMutationWorkflowService
    ) {
        self.layerCommands = layerCommands
        self.mutationWorkflow = mutationWorkflow
    }
}

package struct DocumentLayerContentMutationServices: Sendable {
    package let layerCommands: DocumentLayerCommandService
    package let contentService: DocumentContentService

    package init(
        layerCommands: DocumentLayerCommandService,
        contentService: DocumentContentService
    ) {
        self.layerCommands = layerCommands
        self.contentService = contentService
    }
}

package struct DocumentTextLayerMutationServices: Sendable {
    package let layerCommands: DocumentLayerCommandService
    package let mutationWorkflow: DocumentMutationWorkflowService
    package let contentService: DocumentContentService
    package let textLayerService: DocumentTextLayerService

    package init(
        layerCommands: DocumentLayerCommandService,
        mutationWorkflow: DocumentMutationWorkflowService,
        contentService: DocumentContentService,
        textLayerService: DocumentTextLayerService
    ) {
        self.layerCommands = layerCommands
        self.mutationWorkflow = mutationWorkflow
        self.contentService = contentService
        self.textLayerService = textLayerService
    }
}

package struct DocumentSelectionMutationServices: Sendable {
    package let selectionWorkflow: SelectionWorkflowService

    package init(selectionWorkflow: SelectionWorkflowService) {
        self.selectionWorkflow = selectionWorkflow
    }
}

package struct DocumentCanvasEditingMutationServices: Sendable {
    package let canvasEditingWorkflow: CanvasEditingWorkflowService

    package init(canvasEditingWorkflow: CanvasEditingWorkflowService) {
        self.canvasEditingWorkflow = canvasEditingWorkflow
    }
}

package struct DocumentStrokeMutationServices: Sendable {
    package let strokeCommands: DocumentStrokeCommandService
    package let canvasStrokeInteractionService: CanvasStrokeInteractionService

    package init(
        strokeCommands: DocumentStrokeCommandService,
        canvasStrokeInteractionService: CanvasStrokeInteractionService
    ) {
        self.strokeCommands = strokeCommands
        self.canvasStrokeInteractionService = canvasStrokeInteractionService
    }
}

package struct DocumentPreviewLeaseMutationServices: Sendable {
    package let canvasStrokeInteractionService: CanvasStrokeInteractionService

    package init(canvasStrokeInteractionService: CanvasStrokeInteractionService) {
        self.canvasStrokeInteractionService = canvasStrokeInteractionService
    }
}

package struct DocumentPreviewServices: Sendable {
    package let canvasPreviewRenderer: any CanvasPreviewRendering
    package let canvasEyedropperSampler: any CanvasEyedropperSampling
    package let layerTransformProcessor: any LayerTransformProcessing
    package let selectionMaskProcessor: any SelectionMaskProcessing
    package let canvasPresentationEnvironment: CanvasPresentationEnvironment

    package init(
        canvasPreviewRenderer: any CanvasPreviewRendering,
        canvasEyedropperSampler: any CanvasEyedropperSampling,
        layerTransformProcessor: any LayerTransformProcessing,
        selectionMaskProcessor: any SelectionMaskProcessing,
        canvasPresentationEnvironment: CanvasPresentationEnvironment
    ) {
        self.canvasPreviewRenderer = canvasPreviewRenderer
        self.canvasEyedropperSampler = canvasEyedropperSampler
        self.layerTransformProcessor = layerTransformProcessor
        self.selectionMaskProcessor = selectionMaskProcessor
        self.canvasPresentationEnvironment = canvasPresentationEnvironment
    }
}

package struct DocumentPersistenceServices: Sendable {
    package let exportClient: DocumentExportClient
    package let persistenceClient: DocumentPersistenceClient

    package init(
        exportClient: DocumentExportClient,
        persistenceClient: DocumentPersistenceClient
    ) {
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

    package init(services: DocumentPresentationServices) {
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

    package init(services: DocumentCanvasMutationServices) {
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

public struct LayerStructureEditingRuntime: Sendable {
    private let layerCommands: DocumentLayerCommandService
    private let mutationWorkflow: DocumentMutationWorkflowService

    public init(
        layerCommands: DocumentLayerCommandService,
        mutationWorkflow: DocumentMutationWorkflowService
    ) {
        self.layerCommands = layerCommands
        self.mutationWorkflow = mutationWorkflow
    }

    package init(services: DocumentLayerStructureMutationServices) {
        self.layerCommands = services.layerCommands
        self.mutationWorkflow = services.mutationWorkflow
    }

    public func addLayer(named name: String) -> DocumentCreatedLayerMutationResult { mutationWorkflow.addLayer(named: name) }
    public func createFolder(named name: String, afterLayerAt anchorLayerIndex: LayerAnchorIndex) -> DocumentCreatedFolderMutationResult { mutationWorkflow.createFolder(named: name, afterLayerAt: anchorLayerIndex) }
    public func deleteFolder(_ folderID: ExistingFolderID) -> DocumentMutationResult { mutationWorkflow.deleteFolder(folderID) }
    public func deleteLayer(_ index: ExistingLayerIndex) -> DocumentMutationResult { mutationWorkflow.deleteLayer(index) }
    public func duplicateLayer(_ index: ExistingLayerIndex, named duplicateName: String) -> DocumentCreatedLayerMutationResult { mutationWorkflow.duplicateLayer(index, named: duplicateName) }
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
    public func clearLayer(_ index: EditableLayerIndex) -> DocumentMutationResult { mutationWorkflow.clearLayer(index) }
    public func replaceLayerMask(_ index: EditableLayerIndex, mask: LayerMaskData) -> DocumentMutationResult { mutationWorkflow.replaceLayerMask(index, mask: mask) }
    public func clearLayerMask(_ index: EditableLayerIndex) -> DocumentMutationResult { mutationWorkflow.clearLayerMask(index) }
    public func applyLayerMask(_ index: EditableLayerIndex) -> DocumentMutationResult { mutationWorkflow.applyLayerMask(index) }
    public func revealLayerForEditing(_ index: ExistingLayerIndex) -> DocumentMutationResult { layerCommands.revealLayerForEditing(index.rawValue) }
    public func ensureLayerVisible(_ index: ExistingLayerIndex) -> DocumentMutationResult { layerCommands.ensureLayerVisible(index.rawValue) }
    public func applyLayerSurfaceMutation(_ index: EditableLayerIndex, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult { layerCommands.applyLayerSurfaceMutation(index.rawValue, payload) }
}

public struct LayerContentEditingRuntime: Sendable {
    private let layerCommands: DocumentLayerCommandService
    private let contentService: DocumentContentService

    public init(
        layerCommands: DocumentLayerCommandService,
        contentService: DocumentContentService
    ) {
        self.layerCommands = layerCommands
        self.contentService = contentService
    }

    package init(services: DocumentLayerContentMutationServices) {
        self.layerCommands = services.layerCommands
        self.contentService = services.contentService
    }

    public func pixelDataForLayer(_ index: ExistingLayerIndex) -> Result<LayerPixelData, DocumentMutationFailure> { contentService.pixelDataForLayer(index) }
    public func replaceLayerPixels(_ command: LayerPixelReplacementCommand) -> DocumentMutationResult { contentService.replaceLayerPixels(command) }
    public func applyPixels(_ pixelData: LayerPixelData, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> { contentService.applyPixels(pixelData, to: target) }
    public func applyTextLayer(_ textLayer: TextLayerData, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> { contentService.applyTextLayer(textLayer, to: target) }
    public func replaceLayerPixelsInRect(_ index: EditableLayerIndex, _ rect: LayerPixelRect, _ pixelData: LayerPixelData) -> DocumentMutationResult { layerCommands.replaceLayerPixelsInRect(index.rawValue, rect, pixelData.rgba) }
    public func applyLayerMutation(_ index: EditableLayerIndex, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult { layerCommands.applyLayerMutation(index.rawValue, payload) }
}

public struct TextLayerEditingRuntime: Sendable {
    private let layerCommands: DocumentLayerCommandService
    private let mutationWorkflow: DocumentMutationWorkflowService
    private let contentService: DocumentContentService
    private let textLayerService: DocumentTextLayerService

    public init(
        layerCommands: DocumentLayerCommandService,
        mutationWorkflow: DocumentMutationWorkflowService,
        contentService: DocumentContentService,
        textLayerService: DocumentTextLayerService
    ) {
        self.layerCommands = layerCommands
        self.mutationWorkflow = mutationWorkflow
        self.contentService = contentService
        self.textLayerService = textLayerService
    }

    package init(services: DocumentTextLayerMutationServices) {
        self.layerCommands = services.layerCommands
        self.mutationWorkflow = services.mutationWorkflow
        self.contentService = services.contentService
        self.textLayerService = services.textLayerService
    }

    public func setTextLayer(_ index: EditableLayerIndex, textLayer: TextLayerData) -> DocumentMutationResult { mutationWorkflow.setTextLayer(index, textLayer: textLayer) }
    public func textLayerData(_ index: ExistingLayerIndex) -> Result<TextLayerDataOutcome, DocumentMutationFailure> { textLayerService.textLayerData(index) }
    public func clearTextLayerData(_ index: EditableLayerIndex) -> DocumentMutationResult { textLayerService.clearTextLayerData(index) }
    public func applyTextLayer(_ textLayer: TextLayerData, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> { contentService.applyTextLayer(textLayer, to: target) }
    public func applyTextLayerMutation(_ index: EditableLayerIndex, _ textLayer: TextLayerData, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult { layerCommands.applyTextLayerMutation(index.rawValue, textLayer, payload) }
}

public struct LayerSelectionEditingRuntime: Sendable {
    private let selectionWorkflow: SelectionWorkflowService

    public init(selectionWorkflow: SelectionWorkflowService) {
        self.selectionWorkflow = selectionWorkflow
    }

    package init(services: DocumentSelectionMutationServices) {
        self.selectionWorkflow = services.selectionWorkflow
    }

    public func combinedSelection(existing: CanvasSelection?, incoming: CanvasSelection?, mode: SelectionCombineMode, canvasGeometry: PixelGeometry) -> CanvasSelection? { selectionWorkflow.combinedSelection(existing: existing, incoming: incoming, mode: mode, canvasGeometry: canvasGeometry) }
    public func makeRectangleSelection(from startPoint: CGPoint, to endPoint: CGPoint, canvasGeometry: PixelGeometry) -> CanvasSelection? { selectionWorkflow.makeRectangleSelection(from: startPoint, to: endPoint, canvasGeometry: canvasGeometry) }
    public func expandedMask(from selection: CanvasSelection, canvasGeometry: PixelGeometry) -> MaskSurface? { selectionWorkflow.expandedMask(from: selection, canvasGeometry: canvasGeometry) }
    public func adjustedSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, expansion: Int, isInverted: Bool) -> CanvasSelection? { selectionWorkflow.adjustedSelection(selection, canvasGeometry: canvasGeometry, expansion: expansion, isInverted: isInverted) }
    public func invertedSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, mode: SelectionToolMode) -> CanvasSelection? { selectionWorkflow.invertedSelection(selection, canvasGeometry: canvasGeometry, mode: mode) }
    public func featheredSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, radius: Int) -> CanvasSelection? { selectionWorkflow.featheredSelection(selection, canvasGeometry: canvasGeometry, radius: radius) }
    public func makeLassoSelection(from points: [CGPoint], canvasGeometry: PixelGeometry) -> CanvasSelection? { selectionWorkflow.makeLassoSelection(from: points, canvasGeometry: canvasGeometry) }
    public func makeAutoSelection(at point: CGPoint, snapshot: MetalDocumentSnapshot?, layerIndex: ExistingLayerIndex, thresholdMode: FillThresholdMode, opacityTolerance: Double, colorTolerance: Double, expansion: Int) -> CanvasSelection? { selectionWorkflow.makeAutoSelection(at: point, snapshot: snapshot, layerIndex: layerIndex, thresholdMode: thresholdMode, opacityTolerance: opacityTolerance, colorTolerance: colorTolerance, expansion: expansion) }
    public func makeColorRangeSelection(request: ColorRangeSelectionRequest, snapshot: MetalDocumentSnapshot?, activeLayerIndex: ExistingLayerIndex, mode: SelectionToolMode) -> CanvasSelection? { selectionWorkflow.makeColorRangeSelection(request: request, snapshot: snapshot, activeLayerIndex: activeLayerIndex, mode: mode) }
    public func expandedSelectionMask(_ source: MaskSurface, expansion: Int) -> MaskSurface { selectionWorkflow.expandedSelectionMask(source, expansion: expansion) }
    public func contractedSelectionMask(_ source: MaskSurface, contraction: Int) -> MaskSurface { selectionWorkflow.contractedSelectionMask(source, contraction: contraction) }
    public func featheredSelectionMask(_ source: MaskSurface, radius: Int) -> MaskSurface { selectionWorkflow.featheredSelectionMask(source, radius: radius) }
    public func invertedSelectionMask(_ source: MaskSurface) -> MaskSurface { selectionWorkflow.invertedSelectionMask(source) }
    public func croppedSelection(from source: MaskSurface, mode: SelectionToolMode) -> CanvasSelection? { selectionWorkflow.croppedSelection(from: source, mode: mode) }
    public func closedPolygon(_ points: [CGPoint], canvasGeometry: PixelGeometry) -> [CGPoint] { selectionWorkflow.closedPolygon(points, canvasGeometry: canvasGeometry) }
}

public struct LayerTransformEditingRuntime: Sendable {
    private let layerTransformProcessor: any LayerTransformProcessing

    public init(layerTransformProcessor: any LayerTransformProcessing) {
        self.layerTransformProcessor = layerTransformProcessor
    }

    package init(services: DocumentPreviewServices) {
        self.layerTransformProcessor = services.layerTransformProcessor
    }

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
        canvasGeometry: PixelGeometry
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
            canvasGeometry: canvasGeometry
        )
    }

    public func transformationBounds(selection: CanvasSelection?, surface: RgbaSurface) -> CGRect? {
        layerTransformProcessor.transformationBounds(
            selection: selection,
            surface: surface
        )
    }
}

public struct CanvasEditingRuntime: Sendable {
    private let canvasEditingWorkflow: CanvasEditingWorkflowService

    public init(canvasEditingWorkflow: CanvasEditingWorkflowService) {
        self.canvasEditingWorkflow = canvasEditingWorkflow
    }

    package init(services: DocumentCanvasEditingMutationServices) {
        self.canvasEditingWorkflow = services.canvasEditingWorkflow
    }

    public func execute(_ command: CanvasEditingCommand, state context: CanvasEditingContext) -> CanvasEditingOutcome { canvasEditingWorkflow.execute(command, state: context) }
    public func executeCanvasEditing(_ command: CanvasEditingCommand, state context: CanvasEditingContext) -> CanvasEditingOutcome { canvasEditingWorkflow.execute(command, state: context) }
}

public struct LayerPreviewLeaseRuntime: Sendable {
    private let canvasStrokeInteractionService: CanvasStrokeInteractionService

    public init(canvasStrokeInteractionService: CanvasStrokeInteractionService) {
        self.canvasStrokeInteractionService = canvasStrokeInteractionService
    }

    package init(services: DocumentPreviewLeaseMutationServices) {
        self.canvasStrokeInteractionService = services.canvasStrokeInteractionService
    }

    public func discardPreviewLease(_ lease: StrokePreviewLease) { canvasStrokeInteractionService.discardPreviewLease(lease) }
}

public struct LayerEditingRuntime: Sendable {
    public let structure: LayerStructureEditingRuntime
    public let content: LayerContentEditingRuntime
    public let text: TextLayerEditingRuntime
    public let selection: LayerSelectionEditingRuntime
    public let transform: LayerTransformEditingRuntime
    public let canvasEditing: CanvasEditingRuntime
    public let previewLease: LayerPreviewLeaseRuntime

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
        self.structure = LayerStructureEditingRuntime(layerCommands: layerCommands, mutationWorkflow: mutationWorkflow)
        self.content = LayerContentEditingRuntime(layerCommands: layerCommands, contentService: contentService)
        self.text = TextLayerEditingRuntime(
            layerCommands: layerCommands,
            mutationWorkflow: mutationWorkflow,
            contentService: contentService,
            textLayerService: textLayerService
        )
        self.selection = LayerSelectionEditingRuntime(selectionWorkflow: selectionWorkflow)
        self.transform = LayerTransformEditingRuntime(layerTransformProcessor: layerTransformProcessor)
        self.canvasEditing = CanvasEditingRuntime(canvasEditingWorkflow: canvasEditingWorkflow)
        self.previewLease = LayerPreviewLeaseRuntime(canvasStrokeInteractionService: canvasStrokeInteractionService)
    }

    package init(
        mutationServices: DocumentMutationServices,
        previewServices: DocumentPreviewServices
    ) {
        self.structure = LayerStructureEditingRuntime(services: mutationServices.layerStructure)
        self.content = LayerContentEditingRuntime(services: mutationServices.layerContent)
        self.text = TextLayerEditingRuntime(services: mutationServices.textLayer)
        self.selection = LayerSelectionEditingRuntime(services: mutationServices.selection)
        self.transform = LayerTransformEditingRuntime(services: previewServices)
        self.canvasEditing = CanvasEditingRuntime(services: mutationServices.canvasEditing)
        self.previewLease = LayerPreviewLeaseRuntime(services: mutationServices.previewLease)
    }

    public func addLayer(named name: String) -> DocumentCreatedLayerMutationResult { structure.addLayer(named: name) }
    public func createFolder(named name: String, afterLayerAt anchorLayerIndex: LayerAnchorIndex) -> DocumentCreatedFolderMutationResult { structure.createFolder(named: name, afterLayerAt: anchorLayerIndex) }
    public func deleteFolder(_ folderID: ExistingFolderID) -> DocumentMutationResult { structure.deleteFolder(folderID) }
    public func deleteLayer(_ index: ExistingLayerIndex) -> DocumentMutationResult { structure.deleteLayer(index) }
    public func duplicateLayer(_ index: ExistingLayerIndex, named duplicateName: String) -> DocumentCreatedLayerMutationResult { structure.duplicateLayer(index, named: duplicateName) }
    public func moveLayer(_ index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex) -> DocumentMutationResult { structure.moveLayer(index, to: destinationIndex) }
    public func assignLayer(_ index: ExistingLayerIndex, toFolder folderID: ExistingFolderID?) -> DocumentMutationResult { structure.assignLayer(index, toFolder: folderID) }
    public func mergeLayerDown(_ index: ExistingLayerIndex) -> DocumentMutationResult { structure.mergeLayerDown(index) }
    public func setLayerVisibility(_ index: ExistingLayerIndex, visible: Bool) -> DocumentMutationResult { structure.setLayerVisibility(index, visible: visible) }
    public func setActiveLayer(_ index: ExistingLayerIndex) -> DocumentMutationResult { structure.setActiveLayer(index) }
    public func setLayerOpacity(_ index: ExistingLayerIndex, opacity: UnitInterval) -> DocumentMutationResult { structure.setLayerOpacity(index, opacity: opacity) }
    public func setLayerLocked(_ index: ExistingLayerIndex, isLocked: Bool) -> DocumentMutationResult { structure.setLayerLocked(index, isLocked: isLocked) }
    public func setLayerAlphaLocked(_ index: ExistingLayerIndex, isAlphaLocked: Bool) -> DocumentMutationResult { structure.setLayerAlphaLocked(index, isAlphaLocked: isAlphaLocked) }
    public func setLayerClipped(_ index: ExistingLayerIndex, isClipped: Bool) -> DocumentMutationResult { structure.setLayerClipped(index, isClipped: isClipped) }
    public func setFolderExpanded(_ folderID: ExistingFolderID, isExpanded: Bool) -> DocumentMutationResult { structure.setFolderExpanded(folderID, isExpanded: isExpanded) }
    public func setFolderVisibility(_ folderID: ExistingFolderID, visible: Bool) -> DocumentMutationResult { structure.setFolderVisibility(folderID, visible: visible) }
    public func setFolderName(_ folderID: ExistingFolderID, name: String) -> DocumentMutationResult { structure.setFolderName(folderID, name: name) }
    public func setLayerBlendMode(_ index: ExistingLayerIndex, blendMode: LayerBlendMode) -> DocumentMutationResult { structure.setLayerBlendMode(index, blendMode: blendMode) }
    public func setLayerName(_ index: ExistingLayerIndex, name: String) -> DocumentMutationResult { structure.setLayerName(index, name: name) }
    public func applyLayerProcessing(_ index: EditableLayerIndex, request: LayerProcessingRequest) -> DocumentMutationResult { structure.applyLayerProcessing(index, request: request) }
    public func setTextLayer(_ index: EditableLayerIndex, textLayer: TextLayerData) -> DocumentMutationResult { text.setTextLayer(index, textLayer: textLayer) }
    public func clearLayer(_ index: EditableLayerIndex) -> DocumentMutationResult { structure.clearLayer(index) }
    public func replaceLayerMask(_ index: EditableLayerIndex, mask: LayerMaskData) -> DocumentMutationResult { structure.replaceLayerMask(index, mask: mask) }
    public func clearLayerMask(_ index: EditableLayerIndex) -> DocumentMutationResult { structure.clearLayerMask(index) }
    public func applyLayerMask(_ index: EditableLayerIndex) -> DocumentMutationResult { structure.applyLayerMask(index) }
    public func pixelDataForLayer(_ index: ExistingLayerIndex) -> Result<LayerPixelData, DocumentMutationFailure> { content.pixelDataForLayer(index) }
    public func replaceLayerPixels(_ command: LayerPixelReplacementCommand) -> DocumentMutationResult { content.replaceLayerPixels(command) }
    public func applyPixels(_ pixelData: LayerPixelData, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> { content.applyPixels(pixelData, to: target) }
    public func applyTextLayer(_ textLayer: TextLayerData, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> { text.applyTextLayer(textLayer, to: target) }
    public func replaceLayerPixelsInRect(_ index: EditableLayerIndex, _ rect: LayerPixelRect, _ pixelData: LayerPixelData) -> DocumentMutationResult { content.replaceLayerPixelsInRect(index, rect, pixelData) }
    public func textLayerData(_ index: ExistingLayerIndex) -> Result<TextLayerDataOutcome, DocumentMutationFailure> { text.textLayerData(index) }
    public func clearTextLayerData(_ index: EditableLayerIndex) -> DocumentMutationResult { text.clearTextLayerData(index) }
    public func execute(_ command: CanvasEditingCommand, state context: CanvasEditingContext) -> CanvasEditingOutcome { canvasEditing.execute(command, state: context) }
    public func executeCanvasEditing(_ command: CanvasEditingCommand, state context: CanvasEditingContext) -> CanvasEditingOutcome { canvasEditing.executeCanvasEditing(command, state: context) }
    public func revealLayerForEditing(_ index: ExistingLayerIndex) -> DocumentMutationResult { structure.revealLayerForEditing(index) }
    public func ensureLayerVisible(_ index: ExistingLayerIndex) -> DocumentMutationResult { structure.ensureLayerVisible(index) }
    public func applyLayerSurfaceMutation(_ index: EditableLayerIndex, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult { structure.applyLayerSurfaceMutation(index, payload) }
    public func applyLayerMutation(_ index: EditableLayerIndex, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult { content.applyLayerMutation(index, payload) }
    public func applyTextLayerMutation(_ index: EditableLayerIndex, _ textLayer: TextLayerData, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult { text.applyTextLayerMutation(index, textLayer, payload) }
    public func discardPreviewLease(_ lease: StrokePreviewLease) { previewLease.discardPreviewLease(lease) }
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
        transform.transformedLayerPixels(
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
        canvasGeometry: PixelGeometry
    ) -> CanvasSelection? {
        transform.transformedSelection(
            selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets,
            canvasGeometry: canvasGeometry
        )
    }

    public func transformationBounds(selection: CanvasSelection?, surface: RgbaSurface) -> CGRect? {
        transform.transformationBounds(selection: selection, surface: surface)
    }
    public func combinedSelection(existing: CanvasSelection?, incoming: CanvasSelection?, mode: SelectionCombineMode, canvasGeometry: PixelGeometry) -> CanvasSelection? { selection.combinedSelection(existing: existing, incoming: incoming, mode: mode, canvasGeometry: canvasGeometry) }
    public func makeRectangleSelection(from startPoint: CGPoint, to endPoint: CGPoint, canvasGeometry: PixelGeometry) -> CanvasSelection? { selection.makeRectangleSelection(from: startPoint, to: endPoint, canvasGeometry: canvasGeometry) }
    public func expandedMask(from selection: CanvasSelection, canvasGeometry: PixelGeometry) -> MaskSurface? { self.selection.expandedMask(from: selection, canvasGeometry: canvasGeometry) }
    public func adjustedSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, expansion: Int, isInverted: Bool) -> CanvasSelection? { self.selection.adjustedSelection(selection, canvasGeometry: canvasGeometry, expansion: expansion, isInverted: isInverted) }
    public func invertedSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, mode: SelectionToolMode) -> CanvasSelection? { self.selection.invertedSelection(selection, canvasGeometry: canvasGeometry, mode: mode) }
    public func featheredSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, radius: Int) -> CanvasSelection? { self.selection.featheredSelection(selection, canvasGeometry: canvasGeometry, radius: radius) }
    public func makeLassoSelection(from points: [CGPoint], canvasGeometry: PixelGeometry) -> CanvasSelection? { selection.makeLassoSelection(from: points, canvasGeometry: canvasGeometry) }
    public func makeAutoSelection(at point: CGPoint, snapshot: MetalDocumentSnapshot?, layerIndex: ExistingLayerIndex, thresholdMode: FillThresholdMode, opacityTolerance: Double, colorTolerance: Double, expansion: Int) -> CanvasSelection? { selection.makeAutoSelection(at: point, snapshot: snapshot, layerIndex: layerIndex, thresholdMode: thresholdMode, opacityTolerance: opacityTolerance, colorTolerance: colorTolerance, expansion: expansion) }
    public func makeColorRangeSelection(request: ColorRangeSelectionRequest, snapshot: MetalDocumentSnapshot?, activeLayerIndex: ExistingLayerIndex, mode: SelectionToolMode) -> CanvasSelection? { selection.makeColorRangeSelection(request: request, snapshot: snapshot, activeLayerIndex: activeLayerIndex, mode: mode) }
    public func expandedSelectionMask(_ source: MaskSurface, expansion: Int) -> MaskSurface { selection.expandedSelectionMask(source, expansion: expansion) }
    public func contractedSelectionMask(_ source: MaskSurface, contraction: Int) -> MaskSurface { selection.contractedSelectionMask(source, contraction: contraction) }
    public func featheredSelectionMask(_ source: MaskSurface, radius: Int) -> MaskSurface { selection.featheredSelectionMask(source, radius: radius) }
    public func invertedSelectionMask(_ source: MaskSurface) -> MaskSurface { selection.invertedSelectionMask(source) }
    public func croppedSelection(from source: MaskSurface, mode: SelectionToolMode) -> CanvasSelection? { selection.croppedSelection(from: source, mode: mode) }
    public func closedPolygon(_ points: [CGPoint], canvasGeometry: PixelGeometry) -> [CGPoint] { selection.closedPolygon(points, canvasGeometry: canvasGeometry) }
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

    package init(services: DocumentStrokeMutationServices) {
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

    package init(services: DocumentPersistenceServices) {
        self.persistenceClient = services.persistenceClient
    }

    public func saveProject(_ location: WritableProjectLocation, _ paperStyle: CanvasPaperStyle) throws { try persistenceClient.saveProject(location, paperStyle) }
    public func loadProject(_ packageURL: ProjectPackageLocation) throws -> LoadedPaintProject { try persistenceClient.loadProject(packageURL) }
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

    package init(services: DocumentPersistenceServices) {
        self.exportClient = services.exportClient
    }

    public func compositeSurface(_ paperStyle: CanvasPaperStyle) -> Result<PreviewOutcome, DocumentMutationFailure> { exportClient.compositeSurface(paperStyle) }
    public func compositePNGData(_ paperStyle: CanvasPaperStyle) -> Result<PreviewDataOutcome, DocumentMutationFailure> { exportClient.compositePNGData(paperStyle) }
    public func timelapseCapture() -> Result<TimelapseCaptureOutcome, DocumentMutationFailure> { exportClient.timelapseCapture() }
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

    package init(services: DocumentPreviewServices) {
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
