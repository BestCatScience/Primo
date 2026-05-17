import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication

package extension DocumentPresentationServices {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
        let presentationReader = DocumentPresentationReader(
            lightweightPresentation: composition.queryGateway.lightweightPresentation,
            presentation: composition.queryGateway.presentation
        )
        let renderingWorkflow = DocumentRenderingWorkflow(operations: composition.renderingOperations)
        self.init(
            presentationReader: presentationReader,
            renderingWorkflow: renderingWorkflow
        )
    }
}

package extension DocumentMutationServices {
    init(
        composition: PrimoDocumentRuntime.DocumentRuntimeComposition,
        previewServices: DocumentPreviewServices
    ) {
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
        let canvasEditingWorkflow = CanvasEditingWorkflowService(
            documentContentService: contentService,
            layerTransformProcessor: previewServices.layerTransformProcessor
        )
        let selectionWorkflow = SelectionWorkflowService(operations: composition.selectionMaskOperations)
        let textLayerService = DocumentTextLayerService(
            textLayerGateway: composition.textLayerGateway,
            documentQueryGateway: composition.queryGateway,
            documentEditingGateway: composition.editingGateway
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
            textLayerService: textLayerService
        )
    }
}

package extension DocumentPreviewServices {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
        let canvasPreviewRenderer = GpuCanvasPreviewRenderer(operations: composition.canvasPreviewOperations)
        let canvasEyedropperSampler = GpuCanvasEyedropperSampler()
        let layerTransformProcessor = GpuLayerTransformProcessor(
            layerTransformOperations: composition.layerTransformOperations,
            selectionOperations: composition.selectionMaskOperations
        )
        let selectionMaskProcessor = GpuCanvasPreviewRenderer(operations: composition.canvasPreviewOperations)
        let canvasPresentationEnvironment = CanvasPresentationEnvironment(
            previewRenderer: canvasPreviewRenderer,
            eyedropperSampler: canvasEyedropperSampler,
            selectionProcessor: selectionMaskProcessor
        )
        self.init(
            canvasPreviewRenderer: canvasPreviewRenderer,
            canvasEyedropperSampler: canvasEyedropperSampler,
            layerTransformProcessor: layerTransformProcessor,
            selectionMaskProcessor: selectionMaskProcessor,
            canvasPresentationEnvironment: canvasPresentationEnvironment
        )
    }
}

package extension DocumentPersistenceServices {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
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
            exportClient: exportClient,
            persistenceClient: persistenceClient
        )
    }
}

package extension DocumentApplicationRuntime {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
        let presentationServices = DocumentPresentationServices(composition: composition)
        let previewServices = DocumentPreviewServices(composition: composition)
        let mutationServices = DocumentMutationServices(
            composition: composition,
            previewServices: previewServices
        )
        let persistenceServices = DocumentPersistenceServices(composition: composition)
        self.init(
            presentation: DocumentPresentationRuntime(services: presentationServices),
            canvasMutation: CanvasMutationRuntime(services: mutationServices),
            strokeEditing: StrokeEditingRuntime(strokeRuntime: CanvasStrokeRuntime(services: mutationServices)),
            layerEditing: LayerEditingRuntime(
                mutationServices: mutationServices,
                previewServices: previewServices
            ),
            persistence: DocumentPersistenceRuntime(services: persistenceServices),
            export: DocumentExportRuntime(services: persistenceServices),
            preview: CanvasPreviewRuntime(services: previewServices)
        )
    }
}
