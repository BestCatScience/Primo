import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication

package extension DocumentRuntimeServices {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
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
            documentQueryGateway: composition.queryGateway,
            documentEditingGateway: composition.editingGateway,
            documentLayerEffectsGateway: composition.layerEffectsGateway
        )
        let contentService = DocumentContentService(
            documentQueryGateway: composition.queryGateway,
            documentRenderGateway: composition.renderGateway,
            documentEditingGateway: composition.editingGateway,
            documentMutationGateway: composition.mutationGateway
        )
        let canvasPreviewRenderer = GpuCanvasPreviewRenderer(operations: composition.canvasPreviewOperations)
        let canvasEyedropperSampler = GpuCanvasEyedropperSampler()
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
            eyedropperSampler: canvasEyedropperSampler,
            selectionProcessor: selectionMaskProcessor
        )
        let presentationReader = DocumentPresentationReader(
            lightweightPresentation: composition.queryGateway.lightweightPresentation,
            presentation: composition.queryGateway.presentation
        )
        let renderingWorkflow = DocumentRenderingWorkflow(operations: composition.renderingOperations)
        let textLayerService = DocumentTextLayerService(
            textLayerData: { index in composition.textLayerGateway.textLayerData(index.rawValue) },
            setTextLayer: { index, textLayer in
                composition.editingGateway.execute(.content(.setTextLayer(index: index.rawValue, textLayer: textLayer)))
                    .map { _ in () }
            },
            clearTextLayerData: { index in composition.textLayerGateway.clearTextLayerData(index.rawValue) }
        )
        let persistenceClient = DocumentPersistenceClient(
            saveProject: composition.persistenceGateway.saveProject,
            loadProject: composition.persistenceGateway.loadProject,
            setPaperStyle: composition.persistenceGateway.setPaperStyle,
            rawNewCanvas: composition.persistenceGateway.newCanvas,
            prewarmDrawingResources: composition.persistenceGateway.prewarmDrawingResources
        )
        let exportClient = DocumentExportClient(
            compositeSurface: composition.exportGateway.compositeSurface,
            compositePNGData: composition.exportGateway.compositePNGData,
            timelapseCapture: composition.exportGateway.timelapseCapture
        )
        self.init(
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
            canvasEyedropperSampler: canvasEyedropperSampler,
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

package extension DocumentApplicationRuntime {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
        let services = DocumentRuntimeServices(composition: composition)
        self.init(
            presentation: DocumentPresentationRuntime(services: services),
            canvasMutation: CanvasMutationRuntime(services: services),
            strokeEditing: StrokeEditingRuntime(strokeRuntime: CanvasStrokeRuntime(services: services)),
            layerEditing: LayerEditingRuntime(services: services),
            persistence: DocumentPersistenceRuntime(services: services),
            export: DocumentExportRuntime(services: services),
            preview: CanvasPreviewRuntime(services: services)
        )
    }
}
