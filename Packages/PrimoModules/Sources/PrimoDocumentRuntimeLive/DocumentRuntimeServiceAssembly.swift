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
        self.init(
            canvas: DocumentCanvasMutationServices(composition: composition),
            layerStructure: DocumentLayerStructureMutationServices(
                composition: composition,
                mutationWorkflow: mutationWorkflow
            ),
            layerContent: DocumentLayerContentMutationServices(
                composition: composition,
                contentService: contentService
            ),
            textLayer: DocumentTextLayerMutationServices(
                composition: composition,
                mutationWorkflow: mutationWorkflow,
                contentService: contentService
            ),
            selection: DocumentSelectionMutationServices(composition: composition),
            canvasEditing: DocumentCanvasEditingMutationServices(
                contentService: contentService,
                previewServices: previewServices
            ),
            stroke: DocumentStrokeMutationServices(composition: composition),
            previewLease: DocumentPreviewLeaseMutationServices(composition: composition)
        )
    }
}

package extension DocumentCanvasMutationServices {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
        self.init(
            canvasCommands: DocumentCanvasCommandService(
                queryGateway: composition.queryGateway,
                renderGateway: composition.renderGateway,
                mutationGateway: composition.mutationGateway,
                persistenceGateway: composition.persistenceGateway
            ),
            historyCommands: DocumentHistoryCommandService(historyGateway: composition.historyGateway)
        )
    }
}

package extension DocumentLayerStructureMutationServices {
    init(
        composition: PrimoDocumentRuntime.DocumentRuntimeComposition,
        mutationWorkflow: DocumentMutationWorkflowService
    ) {
        self.init(
            layerCommands: DocumentLayerCommandService(mutationGateway: composition.mutationGateway),
            mutationWorkflow: mutationWorkflow
        )
    }
}

package extension DocumentLayerContentMutationServices {
    init(
        composition: PrimoDocumentRuntime.DocumentRuntimeComposition,
        contentService: DocumentContentService
    ) {
        self.init(
            layerCommands: DocumentLayerCommandService(mutationGateway: composition.mutationGateway),
            contentService: contentService
        )
    }
}

package extension DocumentTextLayerMutationServices {
    init(
        composition: PrimoDocumentRuntime.DocumentRuntimeComposition,
        mutationWorkflow: DocumentMutationWorkflowService,
        contentService: DocumentContentService
    ) {
        self.init(
            layerCommands: DocumentLayerCommandService(mutationGateway: composition.mutationGateway),
            mutationWorkflow: mutationWorkflow,
            contentService: contentService,
            textLayerService: DocumentTextLayerService(
                textLayerGateway: composition.textLayerGateway,
                documentQueryGateway: composition.queryGateway,
                documentEditingGateway: composition.editingGateway
            )
        )
    }
}

package extension DocumentSelectionMutationServices {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
        self.init(selectionWorkflow: SelectionWorkflowService(operations: composition.selectionMaskOperations))
    }
}

package extension DocumentCanvasEditingMutationServices {
    init(
        contentService: DocumentContentService,
        previewServices: DocumentPreviewServices
    ) {
        self.init(
            canvasEditingWorkflow: CanvasEditingWorkflowService(
                documentContentService: contentService,
                layerTransformProcessor: previewServices.layerTransformProcessor
            )
        )
    }
}

package extension DocumentStrokeMutationServices {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
        self.init(
            strokeCommands: DocumentStrokeCommandService(strokeGateway: composition.strokeGateway),
            canvasStrokeInteractionService: CanvasStrokeInteractionService(
                sessionUseCase: composition.strokeSessionUseCase,
                releasePreviewLease: composition.surfaceHandleReleaser.releaseSurfaceLease
            )
        )
    }
}

package extension DocumentPreviewLeaseMutationServices {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
        self.init(
            canvasStrokeInteractionService: CanvasStrokeInteractionService(
                sessionUseCase: composition.strokeSessionUseCase,
                releasePreviewLease: composition.surfaceHandleReleaser.releaseSurfaceLease
            )
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
            canvasMutation: CanvasMutationRuntime(services: mutationServices.canvas),
            strokeEditing: StrokeEditingRuntime(strokeRuntime: CanvasStrokeRuntime(services: mutationServices.stroke)),
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
