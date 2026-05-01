import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoCanvasPresentationDomain
import PrimoCanvasPresentationInfrastructure
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRenderingInfrastructure
import PrimoDocumentStrokeApplication
import PrimoDocumentStrokeInfrastructure
import PrimoDocumentMetalStrokeInfrastructure

private final class DocumentRuntimePresentationBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private let currentPresentation: @Sendable () -> PaintDocumentPresentation
    private var continuations: [UUID: AsyncStream<PaintDocumentPresentation>.Continuation] = [:]

    init(currentPresentation: @escaping @Sendable () -> PaintDocumentPresentation) {
        self.currentPresentation = currentPresentation
    }

    func stream() -> AsyncStream<PaintDocumentPresentation> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            lock.unlock()
            continuation.yield(currentPresentation())
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id)
            }
        }
    }

    func publishLatest() {
        publish(currentPresentation())
    }

    private func publish(_ presentation: PaintDocumentPresentation) {
        lock.lock()
        let activeContinuations = Array(continuations.values)
        lock.unlock()
        for continuation in activeContinuations {
            continuation.yield(presentation)
        }
    }

    private func removeContinuation(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}

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

    package init(_ infrastructure: PrimoDocumentEngineInfrastructure.DocumentRuntimeComposition) {
        self.init(
            queryGateway: infrastructure.queryGateway,
            renderGateway: infrastructure.renderGateway,
            dirtyUpdateQueue: infrastructure.dirtyUpdateQueue,
            mutationGateway: infrastructure.mutationGateway,
            strokeGateway: infrastructure.strokeGateway,
            historyGateway: infrastructure.historyGateway,
            persistenceGateway: infrastructure.persistenceGateway,
            exportGateway: infrastructure.exportGateway,
            textLayerGateway: infrastructure.textLayerGateway,
            layerEffectsGateway: infrastructure.layerEffectsGateway,
            editingGateway: infrastructure.editingGateway,
            strokeSessionUseCase: infrastructure.strokeSessionUseCase,
            canvasPreviewOperations: infrastructure.canvasPreviewOperations,
            selectionMaskOperations: infrastructure.selectionMaskOperations,
            layerTransformOperations: infrastructure.layerTransformOperations,
            renderingOperations: infrastructure.renderingOperations,
            surfaceHandleReleaser: infrastructure.surfaceHandleReleaser
        )
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

package enum DocumentRuntimeCompositionFactory {
    package static func live(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentRuntimeComposition {
        DocumentRuntimeComposition(
            PrimoDocumentEngineInfrastructure.DocumentRuntimeCompositionFactory.live(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
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
    case create(width: Int, height: Int)
    case resize(width: Int, height: Int)
    case resizeExtent(width: Int, height: Int)
    case initializeImported(ImportedCanvasRequest, layerName: String)
    case compositeSurface
    case setPaperStyle(CanvasPaperStyle)
}

public enum DocumentLayerCommand: Sendable {
    case edit(DocumentEditingRequest)
    case mergeLayerDown(Int)
    case setTextLayer(index: Int, TextLayerData)
    case applyProcessing(index: Int, LayerProcessingRequest)
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
    case none
}

public struct DocumentPresentationReader: Sendable {
    private let lightweightPresentationHandler: @Sendable () -> PaintDocumentPresentation
    private let presentationHandler: @Sendable () -> PaintDocumentPresentation

    public init(
        lightweightPresentation: @escaping @Sendable () -> PaintDocumentPresentation,
        presentation: @escaping @Sendable () -> PaintDocumentPresentation
    ) {
        self.lightweightPresentationHandler = lightweightPresentation
        self.presentationHandler = presentation
    }

    public func lightweightPresentation() -> PaintDocumentPresentation {
        lightweightPresentationHandler()
    }

    public func presentation() -> PaintDocumentPresentation {
        presentationHandler()
    }
}

public struct DocumentTextLayerService: Sendable {
    private let textLayerDataHandler: @Sendable (Int) -> TextLayerData?
    private let setTextLayerHandler: @Sendable (Int, TextLayerData) -> DocumentMutationResult
    private let clearTextLayerDataHandler: @Sendable (Int) -> Void

    public init(
        textLayerData: @escaping @Sendable (Int) -> TextLayerData?,
        setTextLayer: @escaping @Sendable (Int, TextLayerData) -> DocumentMutationResult,
        clearTextLayerData: @escaping @Sendable (Int) -> Void
    ) {
        self.textLayerDataHandler = textLayerData
        self.setTextLayerHandler = setTextLayer
        self.clearTextLayerDataHandler = clearTextLayerData
    }

    public func textLayerData(_ index: Int) -> TextLayerData? {
        textLayerDataHandler(index)
    }

    public func setTextLayer(_ index: Int, _ textLayer: TextLayerData) -> DocumentMutationResult {
        setTextLayerHandler(index, textLayer)
    }

    public func clearTextLayerData(_ index: Int) {
        clearTextLayerDataHandler(index)
    }
}

public struct DocumentPersistenceClient: Sendable {
    private let saveProjectHandler: @Sendable (URL, CanvasPaperStyle) throws -> Void
    private let loadProjectHandler: @Sendable (URL) throws -> LoadedPaintProject
    private let setPaperStyleHandler: @Sendable (CanvasPaperStyle) -> Void
    private let newCanvasHandler: @Sendable (Int, Int) -> Void
    private let prewarmDrawingResourcesHandler: @Sendable () -> Void

    public init(
        saveProject: @escaping @Sendable (URL, CanvasPaperStyle) throws -> Void,
        loadProject: @escaping @Sendable (URL) throws -> LoadedPaintProject,
        setPaperStyle: @escaping @Sendable (CanvasPaperStyle) -> Void,
        newCanvas: @escaping @Sendable (Int, Int) -> Void,
        prewarmDrawingResources: @escaping @Sendable () -> Void
    ) {
        self.saveProjectHandler = saveProject
        self.loadProjectHandler = loadProject
        self.setPaperStyleHandler = setPaperStyle
        self.newCanvasHandler = newCanvas
        self.prewarmDrawingResourcesHandler = prewarmDrawingResources
    }

    public func saveProject(_ url: URL, _ paperStyle: CanvasPaperStyle) throws {
        try saveProjectHandler(url, paperStyle)
    }

    public func loadProject(_ url: URL) throws -> LoadedPaintProject {
        try loadProjectHandler(url)
    }

    public func setPaperStyle(_ paperStyle: CanvasPaperStyle) {
        setPaperStyleHandler(paperStyle)
    }

    public func newCanvas(_ width: Int, _ height: Int) {
        newCanvasHandler(width, height)
    }

    public func prewarmDrawingResources() {
        prewarmDrawingResourcesHandler()
    }
}

public struct DocumentExportClient: Sendable {
    private let compositeSurfaceHandler: @Sendable (CanvasPaperStyle) -> DocumentCompositeSurface?
    private let compositePNGDataHandler: @Sendable (CanvasPaperStyle) -> Data?
    private let timelapseCaptureHandler: @Sendable () -> TimelapseCapture?

    public init(
        compositeSurface: @escaping @Sendable (CanvasPaperStyle) -> DocumentCompositeSurface?,
        compositePNGData: @escaping @Sendable (CanvasPaperStyle) -> Data?,
        timelapseCapture: @escaping @Sendable () -> TimelapseCapture?
    ) {
        self.compositeSurfaceHandler = compositeSurface
        self.compositePNGDataHandler = compositePNGData
        self.timelapseCaptureHandler = timelapseCapture
    }

    public func compositeSurface(_ paperStyle: CanvasPaperStyle) -> DocumentCompositeSurface? {
        compositeSurfaceHandler(paperStyle)
    }

    public func compositePNGData(_ paperStyle: CanvasPaperStyle) -> Data? {
        compositePNGDataHandler(paperStyle)
    }

    public func timelapseCapture() -> TimelapseCapture? {
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

    public init(
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

    package init(gpuOperations: DocumentGpuOperationGateway) {
        self.init(
            operations: gpuOperations.renderingOperations
        )
    }

    public func compositedPaperPreviewRGBA(
        _ pixelData: Data,
        _ width: Int,
        _ height: Int,
        _ paperStyle: CanvasPaperStyle
    ) -> DocumentRenderingResult<Data> {
        compositedPaperPreviewRGBAHandler(pixelData, width, height, paperStyle)
    }

    public func compositedPreviewPixelData(
        _ snapshot: MetalDocumentSnapshot,
        _ activeLayerIndex: Int,
        _ adjustedActiveLayerPixels: Data
    ) -> DocumentRenderingResult<Data> {
        compositedPreviewPixelDataHandler(snapshot, activeLayerIndex, adjustedActiveLayerPixels)
    }

    public func processedLayerPixelData(
        _ source: Data,
        _ width: Int,
        _ height: Int,
        _ request: LayerProcessingRequest
    ) -> DocumentRenderingResult<Data> {
        processedLayerPixelDataHandler(source, width, height, request)
    }

    public func alphaMask(_ pixelData: Data, _ width: Int, _ height: Int) -> DocumentRenderingResult<[UInt8]> {
        alphaMaskHandler(pixelData, width, height)
    }

    public func croppedSelectionMask(_ mask: [UInt8], _ width: Int, _ height: Int) -> DocumentCroppedSelectionMask? {
        croppedSelectionMaskHandler(mask, width, height)
    }

    public func scaledPixelData(_ source: Data, _ width: Int, _ height: Int, _ targetWidth: Int, _ targetHeight: Int) -> DocumentRenderingResult<Data> {
        scaledPixelDataHandler(source, width, height, targetWidth, targetHeight)
    }

    public func translatedPixelData(
        _ source: Data,
        _ width: Int,
        _ height: Int,
        _ targetWidth: Int,
        _ targetHeight: Int,
        _ offsetX: Int,
        _ offsetY: Int
    ) -> DocumentRenderingResult<Data> {
        translatedPixelDataHandler(source, width, height, targetWidth, targetHeight, offsetX, offsetY)
    }

}

public struct DocumentRuntime: Sendable {
    private let executeHandler: @Sendable (DocumentCommand) async -> DocumentCommandOutcome
    private let observePresentationHandler: @Sendable () -> AsyncStream<PaintDocumentPresentation>

    public let canvasCommands: DocumentCanvasCommandService
    public let layerCommands: DocumentLayerCommandService
    public let strokeCommands: DocumentStrokeCommandService
    public let canvasStrokeInteractionService: CanvasStrokeInteractionService
    public let historyCommands: DocumentHistoryCommandService
    public let mutationWorkflow: DocumentMutationWorkflowService
    public let contentService: DocumentContentService
    public let canvasEditingWorkflow: CanvasEditingWorkflowService
    public let selectionWorkflow: SelectionWorkflowService
    public let canvasPreviewRenderer: any CanvasPreviewRendering
    public let layerTransformProcessor: any LayerTransformProcessing
    public let selectionMaskProcessor: any SelectionMaskProcessing
    public let canvasPresentationEnvironment: CanvasPresentationEnvironment
    public let presentationReader: DocumentPresentationReader
    public let renderingWorkflow: DocumentRenderingWorkflow
    public let textLayerService: DocumentTextLayerService
    public let exportClient: DocumentExportClient
    public let persistenceClient: DocumentPersistenceClient

    public init(
        execute: @escaping @Sendable (DocumentCommand) async -> DocumentCommandOutcome,
        observePresentation: @escaping @Sendable () -> AsyncStream<PaintDocumentPresentation>,
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
        layerTransformProcessor: any LayerTransformProcessing,
        selectionMaskProcessor: any SelectionMaskProcessing,
        canvasPresentationEnvironment: CanvasPresentationEnvironment,
        presentationReader: DocumentPresentationReader,
        renderingWorkflow: DocumentRenderingWorkflow,
        textLayerService: DocumentTextLayerService,
        exportClient: DocumentExportClient,
        persistenceClient: DocumentPersistenceClient
    ) {
        self.executeHandler = execute
        self.observePresentationHandler = observePresentation
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
        self.layerTransformProcessor = layerTransformProcessor
        self.selectionMaskProcessor = selectionMaskProcessor
        self.canvasPresentationEnvironment = canvasPresentationEnvironment
        self.presentationReader = presentationReader
        self.renderingWorkflow = renderingWorkflow
        self.textLayerService = textLayerService
        self.exportClient = exportClient
        self.persistenceClient = persistenceClient
    }

    public func execute(_ command: DocumentCommand) async -> DocumentCommandOutcome {
        await executeHandler(command)
    }

    public func observePresentation() -> AsyncStream<PaintDocumentPresentation> {
        observePresentationHandler()
    }

    package init(composition: DocumentRuntimeComposition) {
        let canvasCommands = DocumentCanvasCommandService(
            queryGateway: composition.queryGateway,
            renderGateway: composition.renderGateway,
            mutationGateway: composition.mutationGateway,
            persistenceGateway: composition.persistenceGateway
        )
        let layerCommands = DocumentLayerCommandService(mutationGateway: composition.mutationGateway)
        let strokeCommands = DocumentStrokeCommandService(strokeGateway: composition.strokeGateway)
        let canvasStrokeInteractionService = CanvasStrokeInteractionService(
            sessionUseCase: composition.strokeSessionUseCase,
            releasePreviewLease: composition.surfaceHandleReleaser.releaseSurfaceLease
        )
        let historyCommands = DocumentHistoryCommandService(historyGateway: composition.historyGateway)
        let mutationWorkflow = DocumentMutationWorkflowService(
            documentEditingGateway: composition.editingGateway,
            documentLayerEffectsGateway: composition.layerEffectsGateway,
            documentMutationGateway: composition.mutationGateway,
            textLayerGateway: composition.textLayerGateway
        )
        let contentService = DocumentContentService(
            documentQueryGateway: composition.queryGateway,
            documentRenderGateway: composition.renderGateway,
            documentMutationGateway: composition.mutationGateway,
            textLayerGateway: composition.textLayerGateway
        )
        let canvasPreviewRenderer = GpuCanvasPreviewRenderer(operations: composition.canvasPreviewOperations)
        let layerTransformProcessor = GpuLayerTransformProcessor(
            layerTransformOperations: composition.layerTransformOperations,
            selectionOperations: composition.selectionMaskOperations
        )
        let selectionMaskProcessor = GpuCanvasPreviewRenderer(operations: composition.canvasPreviewOperations)
        let canvasEditingWorkflow = CanvasEditingWorkflowService(
            documentContentService: contentService,
            layerTransformProcessor: layerTransformProcessor
        )
        let selectionWorkflow = SelectionWorkflowService(operations: composition.selectionMaskOperations)
        let canvasPresentationEnvironment = CanvasPresentationEnvironment(
            previewRenderer: canvasPreviewRenderer,
            eyedropperSampler: GpuCanvasEyedropperSampler(),
            selectionProcessor: selectionMaskProcessor
        )
        let presentationReader = DocumentPresentationReader(
            lightweightPresentation: composition.queryGateway.lightweightPresentation,
            presentation: composition.queryGateway.presentation
        )
        let renderingWorkflow = DocumentRenderingWorkflow(operations: composition.renderingOperations)
        let textLayerService = DocumentTextLayerService(
            textLayerData: composition.textLayerGateway.textLayerData,
            setTextLayer: composition.textLayerGateway.setTextLayer,
            clearTextLayerData: composition.textLayerGateway.clearTextLayerData
        )
        let persistenceClient = DocumentPersistenceClient(
            saveProject: composition.persistenceGateway.saveProject,
            loadProject: composition.persistenceGateway.loadProject,
            setPaperStyle: composition.persistenceGateway.setPaperStyle,
            newCanvas: composition.persistenceGateway.newCanvas,
            prewarmDrawingResources: composition.persistenceGateway.prewarmDrawingResources
        )
        let exportClient = DocumentExportClient(
            compositeSurface: composition.exportGateway.compositeSurface,
            compositePNGData: composition.exportGateway.compositePNGData,
            timelapseCapture: composition.exportGateway.timelapseCapture
        )
        let presentationBroadcaster = DocumentRuntimePresentationBroadcaster {
            composition.queryGateway.lightweightPresentation()
        }
        let mutationOutcome: @Sendable (
            Result<DocumentMutationSuccess, DocumentMutationFailure>
        ) -> DocumentCommandOutcome = { result in
            if case .success = result {
                presentationBroadcaster.publishLatest()
            }
            return .mutation(result)
        }

        let executeClosure: @Sendable (DocumentCommand) async -> DocumentCommandOutcome = { command in
            switch command {
            case let .presentation(request):
                switch request {
                case .lightweight:
                    return .presentation(composition.queryGateway.lightweightPresentation())
                case .full, .current:
                    return .presentation(composition.queryGateway.presentation())
                }
            case let .canvas(command):
                switch command {
                case let .create(width, height):
                    return mutationOutcome(canvasCommands.createCanvas(width, height).map { .completed })
                case let .resize(width, height):
                    return mutationOutcome(canvasCommands.resizeCanvas(width, height).map { .completed })
                case let .resizeExtent(width, height):
                    return mutationOutcome(canvasCommands.resizeCanvasExtent(width, height).map { .completed })
                case let .initializeImported(request, layerName):
                    return mutationOutcome(canvasCommands.initializeImportedCanvas(request, layerName).map { .completed })
                case .compositeSurface:
                    return .compositeSurface(canvasCommands.compositeSurface())
                case let .setPaperStyle(style):
                    composition.persistenceGateway.setPaperStyle(style)
                    presentationBroadcaster.publishLatest()
                    return .none
                }
            case let .layer(command):
                switch command {
                case let .edit(request):
                    return mutationOutcome(
                        composition.editingGateway.execute(request)
                            .map { _ in .completed }
                    )
                case let .mergeLayerDown(index):
                    return mutationOutcome(composition.layerEffectsGateway.mergeLayerDown(index).map { .completed })
                case let .setTextLayer(index, textLayer):
                    return mutationOutcome(composition.textLayerGateway.setTextLayer(index, textLayer).map { .completed })
                case let .applyProcessing(index, request):
                    return mutationOutcome(composition.mutationGateway.applyLayerProcessing(index, request).map { .completed })
                }
            case let .stroke(command):
                switch command {
                case let .begin(sample, settings):
                    composition.strokeGateway.beginStroke(sample, settings)
                    return .none
                case let .append(sample):
                    composition.strokeGateway.appendStroke(sample)
                    return .none
                case .end:
                    return mutationOutcome(composition.strokeGateway.endStroke().map { .completed })
                case .cancel:
                    composition.strokeGateway.cancelStroke()
                    return .none
                case let .fill(sample, settings):
                    return mutationOutcome(composition.strokeGateway.fill(sample, settings).map { .completed })
                }
            case let .history(command):
                switch command {
                case .state:
                    return .history(
                        DocumentHistoryState(
                            canUndo: composition.historyGateway.canUndo(),
                            canRedo: composition.historyGateway.canRedo()
                        )
                    )
                case .undo:
                    return mutationOutcome(composition.historyGateway.undo().map { .completed })
                case .redo:
                    return mutationOutcome(composition.historyGateway.redo().map { .completed })
                }
            }
        }

        self.init(
            execute: executeClosure,
            observePresentation: {
                presentationBroadcaster.stream()
            },
            canvasCommands: canvasCommands,
            layerCommands: layerCommands,
            strokeCommands: strokeCommands,
            canvasStrokeInteractionService: canvasStrokeInteractionService,
            historyCommands: historyCommands,
            mutationWorkflow: mutationWorkflow,
            contentService: contentService,
            canvasEditingWorkflow: canvasEditingWorkflow,
            selectionWorkflow: selectionWorkflow,
            canvasPreviewRenderer: canvasPreviewRenderer,
            layerTransformProcessor: layerTransformProcessor,
            selectionMaskProcessor: selectionMaskProcessor,
            canvasPresentationEnvironment: canvasPresentationEnvironment,
            presentationReader: presentationReader,
            renderingWorkflow: renderingWorkflow,
            textLayerService: textLayerService,
            exportClient: exportClient,
            persistenceClient: persistenceClient
        )
    }
}

public enum DocumentRuntimeFactory {
    public static func live(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentRuntime {
        DocumentRuntime(
            composition: DocumentRuntimeCompositionFactory.live(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
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

    init(_ infrastructure: PrimoDocumentEngineInfrastructure.DocumentProjectPreview) {
        self.init(
            canvasSize: infrastructure.canvasSize,
            layerCount: infrastructure.layerCount,
            previewSurface: infrastructure.previewSurface
        )
    }
}

public enum DocumentProjectPreviewLoader {
    public static func loadPreview(
        from url: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) throws -> DocumentProjectPreview {
        try DocumentProjectPreview(
            PrimoDocumentEngineInfrastructure.DocumentProjectPreviewLoader.loadPreview(
                from: url,
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
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

    init(_ infrastructure: PrimoDocumentEngineInfrastructure.TimelapseExportProgress) {
        self.init(
            progress: infrastructure.progress,
            previewSurface: infrastructure.previewSurface,
            previewImageData: infrastructure.previewImageData
        )
    }
}

public struct TimelapseExportResult: Equatable, Sendable {
    public var url: URL

    public init(url: URL) {
        self.url = url
    }

    init(_ infrastructure: PrimoDocumentEngineInfrastructure.TimelapseExportResult) {
        self.init(url: infrastructure.url)
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
    public static func exportVideo(
        from capture: TimelapseCapture,
        to directory: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        progress: ((TimelapseExportProgress) -> Void)? = nil
    ) throws -> TimelapseExportResult {
        do {
            return try TimelapseExportResult(
                PrimoDocumentEngineInfrastructure.TimelapseExportService.exportVideo(
                    from: capture,
                    to: directory,
                    fileClient: fileClient,
                    dateClient: dateClient,
                    progress: progress.map { callback in
                        { callback(TimelapseExportProgress($0)) }
                    }
                )
            )
        } catch let error as PrimoDocumentEngineInfrastructure.TimelapseExportError {
            throw TimelapseExportError(error)
        } catch {
            throw error
        }
    }
}

private extension TimelapseExportError {
    init(_ infrastructure: PrimoDocumentEngineInfrastructure.TimelapseExportError) {
        switch infrastructure {
        case .insufficientFrames:
            self = .insufficientFrames
        case .cannotAddWriterInput:
            self = .cannotAddWriterInput
        case .failedToStartWriting:
            self = .failedToStartWriting
        case .invalidFrameData:
            self = .invalidFrameData
        case .exportFailed:
            self = .exportFailed
        case .cancelled:
            self = .cancelled
        }
    }
}

public struct GpuCanvasPreviewRenderer: CanvasPreviewRendering, SelectionMaskProcessing {
    private let renderer: PrimoDocumentRenderingInfrastructure.GpuCanvasPreviewRenderer

    public init() {
        self.init(operations: DocumentGpuOperationGatewayFactory.live().canvasPreviewRenderingOperations)
    }

    package init(operations: DocumentCanvasPreviewRenderingOperations) {
        self.renderer = PrimoDocumentRenderingInfrastructure.GpuCanvasPreviewRenderer(operations: operations)
    }

    package init(gpuOperations: DocumentGpuOperationGateway) {
        self.init(operations: gpuOperations.canvasPreviewRenderingOperations)
    }

    public func eyedropperLoupeSurface(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> DocumentCompositeSurface? {
        renderer.eyedropperLoupeSurface(
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

    public func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        renderer.selectionOverlaySurface(maskData: maskData, width: width, height: height)
    }

    public func compositePreviewImageData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        renderer.compositePreviewImageData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    public func paperCompositeSurface(
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle
    ) -> DocumentCompositeSurface? {
        renderer.paperCompositeSurface(pixelData: pixelData, width: width, height: height, paperStyle: paperStyle)
    }

    public func shapePreviewSurface(
        stroke: Stroke,
        style: PreviewStrokeStyle,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        renderer.shapePreviewSurface(stroke: stroke, style: style, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
    }

    public func transformedTextPreviewSurface(
        textLayer: TextLayerData,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        renderer.transformedTextPreviewSurface(textLayer: textLayer, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
    }

    public func transformedTextLayoutRect(textLayer: TextLayerData, canvasSize: CGSize) -> CGRect? {
        renderer.transformedTextLayoutRect(textLayer: textLayer, canvasSize: canvasSize)
    }
}

public struct GpuCanvasEyedropperSampler: CanvasEyedropperSampling {
    private let sampler = PrimoDocumentRenderingInfrastructure.GpuCanvasEyedropperSampler()

    public init() {}

    public func sampledColor(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        source: EyedropperSamplingSource,
        point: CGPoint,
        paperStyle: CanvasPaperStyle
    ) -> SampledColor? {
        sampler.sampledColor(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            source: source,
            point: point,
            paperStyle: paperStyle
        )
    }
}

public struct GpuLayerTransformProcessor: LayerTransformProcessing {
    private let processor: PrimoDocumentRenderingInfrastructure.GpuLayerTransformProcessor

    public init() {
        let gpuOperations = DocumentGpuOperationGatewayFactory.live()
        self.init(
            layerTransformOperations: gpuOperations.layerTransformOperations,
            selectionOperations: gpuOperations.selectionMaskOperations
        )
    }

    package init(
        layerTransformOperations: DocumentLayerTransformOperations,
        selectionOperations: DocumentSelectionMaskOperations
    ) {
        self.processor = PrimoDocumentRenderingInfrastructure.GpuLayerTransformProcessor(
            layerTransformOperations: layerTransformOperations,
            selectionOperations: selectionOperations
        )
    }

    package init(gpuOperations: DocumentGpuOperationGateway) {
        self.init(
            layerTransformOperations: gpuOperations.layerTransformOperations,
            selectionOperations: gpuOperations.selectionMaskOperations
        )
    }

    public func transformedLayerPixels(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets
    ) -> Data? {
        processor.transformedLayerPixels(
            source: source,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
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
        processor.transformedSelection(
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

    public func transformationBounds(
        selection: CanvasSelection?,
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> CGRect? {
        processor.transformationBounds(
            selection: selection,
            pixelData: pixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
    }
}

public enum BrushStrokeKernel {
    public static func taperScale(progress: CGFloat, taperIn: CGFloat, taperOut: CGFloat) -> CGFloat {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.taperScale(
            progress: progress,
            taperIn: taperIn,
            taperOut: taperOut
        )
    }

    public static func taperScale(progress: Double, taperIn: Double, taperOut: Double) -> Double {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.taperScale(
            progress: progress,
            taperIn: taperIn,
            taperOut: taperOut
        )
    }

    public static func resolvedRadius(
        for sample: StylusSample,
        progress: CGFloat,
        brush: BrushRuntimeSettings
    ) -> CGFloat {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.resolvedRadius(
            for: sample,
            progress: progress,
            brush: brush
        )
    }

    public static func previewStampAlpha(
        pressure: Double,
        opacityJitter: Double,
        opacity: Double,
        flow: Double,
        hardness: Double,
        opacityPressureSensitivity: Double,
        flowPressureSensitivity: Double,
        hasCustomTip: Bool
    ) -> Double {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.previewStampAlpha(
            pressure: pressure,
            opacityJitter: opacityJitter,
            opacity: opacity,
            flow: flow,
            hardness: hardness,
            opacityPressureSensitivity: opacityPressureSensitivity,
            flowPressureSensitivity: flowPressureSensitivity,
            hasCustomTip: hasCustomTip
        )
    }

    public static func noise(x: CGFloat, y: CGFloat) -> CGFloat {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.noise(x: x, y: y)
    }
}

public enum GpuRenderingSupport {
    public static func shouldUseIncrementalPreviewUpdate(for brush: BrushRuntimeSettings) -> Bool {
        PrimoDocumentMetalStrokeInfrastructure.GpuRenderingSupport.shouldUseIncrementalPreviewUpdate(for: brush)
    }

    public static func shouldUseGpuOnlyResponsivePreview(for brush: BrushRuntimeSettings) -> Bool {
        PrimoDocumentMetalStrokeInfrastructure.GpuRenderingSupport.shouldUseGpuOnlyResponsivePreview(for: brush)
    }

    public static func responsivePreviewBrush(from brush: BrushRuntimeSettings) -> BrushRuntimeSettings {
        PrimoDocumentMetalStrokeInfrastructure.GpuRenderingSupport.responsivePreviewBrush(from: brush)
    }
}

public enum PrimoMetalSurfaceFiltering: Sendable {
    case linear
    case nearest
}

private extension PrimoDocumentMetalRuntimeInfrastructure.PrimoMetalSurfaceFiltering {
    init(_ filtering: PrimoMetalSurfaceFiltering) {
        switch filtering {
        case .linear:
            self = .linear
        case .nearest:
            self = .nearest
        }
    }
}

#if canImport(UIKit)
import UIKit

@MainActor
public final class CanvasPresentationContainerView: UIView {
    private let content: PrimoCanvasPresentationInfrastructure.CanvasPresentationContainerView

    public var documentSize: CGSize {
        get { content.documentSize }
        set { content.documentSize = newValue }
    }

    public var actionSink: CanvasPresentationActionSink? {
        get { content.actionSink }
        set { content.actionSink = newValue }
    }

    public init(environment: CanvasPresentationEnvironment) {
        self.content = PrimoCanvasPresentationInfrastructure.CanvasPresentationContainerView(environment: environment)
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = true
        addSubview(content)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds
    }

    public func update(_ state: CanvasPresentationState) {
        content.update(state)
    }
}

@MainActor
public final class CanvasPixelSurfaceView: UIView {
    private let content = PrimoCanvasPresentationInfrastructure.CanvasPixelSurfaceView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        addSubview(content)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds
    }

    public func update(
        surface: DocumentCompositeSurface?,
        opacity: CGFloat = 1.0,
        filtering: PrimoMetalSurfaceFiltering = .linear
    ) {
        content.update(
            surface: surface,
            opacity: opacity,
            filtering: PrimoDocumentMetalRuntimeInfrastructure.PrimoMetalSurfaceFiltering(filtering)
        )
        isHidden = surface == nil
    }
}

#endif
