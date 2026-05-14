import ComposableArchitecture
import Foundation
import PrimoCanvasPresentationDomain
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentPersistenceContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication
import PrimoWorkspaceApplication

private enum DocumentRuntimeKey: DependencyKey {
    static var liveValue: DocumentRuntime {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient

        return DocumentRuntimeFactory.live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
    }
}

struct SelectionWorkflowEnvironment: Sendable {
    let workflow: SelectionWorkflowService

    init(workflow: SelectionWorkflowService) {
        self.workflow = workflow
    }
}

struct DocumentPresentationCapability: Sendable {
    let presentationReader: DocumentPresentationReader
    let persistenceGateway: DocumentPersistenceGateway
    let exportGateway: DocumentExportGateway
    let renderingWorkflow: DocumentRenderingWorkflow
}

struct PresentationRefreshEnvironment: Sendable {
    let presentationReader: DocumentPresentationReader
    let persistenceGateway: DocumentPersistenceGateway
    let exportGateway: DocumentExportGateway
    let renderingWorkflow: DocumentRenderingWorkflow
}

struct DocumentCanvasMutationCapability: Sendable {
    let canvasCommandService: DocumentCanvasCommandService
    let historyCommandService: DocumentHistoryCommandService
    let persistenceGateway: DocumentPersistenceGateway
    let presentationReader: DocumentPresentationReader
    let renderingWorkflow: DocumentRenderingWorkflow
}

struct DocumentLayerMutationCapability: Sendable {
    let contentService: DocumentContentService
    let renderingWorkflow: DocumentRenderingWorkflow
    let mutationWorkflowService: DocumentMutationWorkflowService
    let presentationReader: DocumentPresentationReader
    let textLayerService: DocumentTextLayerService
    let selectionWorkflowService: SelectionWorkflowService
}

struct LayerWorkflowEnvironment: Sendable {
    let contentService: DocumentContentService
    let renderingWorkflow: DocumentRenderingWorkflow
    let mutationWorkflowService: DocumentMutationWorkflowService
    let presentationReader: DocumentPresentationReader
    let textLayerService: DocumentTextLayerService
    let selectionWorkflowService: SelectionWorkflowService
    let canvasStrokeInteractionService: CanvasStrokeInteractionService
}

struct DocumentStrokeCapability: Sendable {
    let canvasStrokeInteractionService: CanvasStrokeInteractionService
    let renderingWorkflow: DocumentRenderingWorkflow
    let layerCommandService: DocumentLayerCommandService
    let strokeCommandService: DocumentStrokeCommandService
    let persistenceGateway: DocumentPersistenceGateway
    let presentationReader: DocumentPresentationReader
    let canvasEditingWorkflowService: CanvasEditingWorkflowService
    let contentService: DocumentContentService
    let layerTransformProcessor: any LayerTransformProcessing
    let selectionWorkflowEnvironment: SelectionWorkflowEnvironment
}

struct CanvasStrokeEnvironment: Sendable {
    let canvasStrokeInteractionService: CanvasStrokeInteractionService
    let renderingWorkflow: DocumentRenderingWorkflow
    let layerCommandService: DocumentLayerCommandService
    let strokeCommandService: DocumentStrokeCommandService
    let persistenceGateway: DocumentPersistenceGateway
    let presentationReader: DocumentPresentationReader
    let canvasEditingWorkflowService: CanvasEditingWorkflowService
    let contentService: DocumentContentService
    let layerTransformProcessor: any LayerTransformProcessing
    let selectionWorkflowEnvironment: SelectionWorkflowEnvironment
}

struct DocumentExportCapability: Sendable {
    let exportGateway: DocumentExportGateway
}

struct DocumentPersistenceCapability: Sendable {
    let persistenceGateway: DocumentPersistenceGateway
}

struct DocumentPreviewRenderingCapability: Sendable {
    let canvasPreviewRenderer: any CanvasPreviewRendering
    let canvasEyedropperSampler: any CanvasEyedropperSampling
    let selectionMaskProcessor: any SelectionMaskProcessing
    let canvasPresentationEnvironment: CanvasPresentationEnvironment
}

struct DocumentApplicationEnvironment: Sendable {
    let runtime: DocumentRuntime
    let presentationCapability: DocumentPresentationCapability
    let presentationRefreshEnvironment: PresentationRefreshEnvironment
    let canvasMutationCapability: DocumentCanvasMutationCapability
    let layerMutationCapability: DocumentLayerMutationCapability
    let layerWorkflowEnvironment: LayerWorkflowEnvironment
    let strokeCapability: DocumentStrokeCapability
    let canvasStrokeEnvironment: CanvasStrokeEnvironment
    let exportCapability: DocumentExportCapability
    let persistenceCapability: DocumentPersistenceCapability
    let previewRenderingCapability: DocumentPreviewRenderingCapability
    let presentationReader: DocumentPresentationReader
    let persistenceGateway: DocumentPersistenceGateway
    let exportGateway: DocumentExportGateway
    let textLayerService: DocumentTextLayerService
    let canvasStrokeInteractionService: CanvasStrokeInteractionService
    let renderingWorkflow: DocumentRenderingWorkflow
    let canvasPreviewRenderer: any CanvasPreviewRendering
    let canvasEyedropperSampler: any CanvasEyedropperSampling
    let selectionMaskProcessor: any SelectionMaskProcessing
    let canvasPresentationEnvironment: CanvasPresentationEnvironment
    let canvasCommandService: DocumentCanvasCommandService
    let layerCommandService: DocumentLayerCommandService
    let strokeCommandService: DocumentStrokeCommandService
    let historyCommandService: DocumentHistoryCommandService
    let mutationWorkflowService: DocumentMutationWorkflowService
    let contentService: DocumentContentService
    let canvasEditingWorkflowService: CanvasEditingWorkflowService
    let layerTransformProcessor: any LayerTransformProcessing
    let selectionWorkflowService: SelectionWorkflowService
    let selectionWorkflowEnvironment: SelectionWorkflowEnvironment

    init(runtime: DocumentRuntime) {
        self.runtime = runtime
        self.presentationReader = runtime.presentationReader
        self.textLayerService = runtime.textLayerService
        self.canvasStrokeInteractionService = runtime.canvasStrokeInteractionService
        self.renderingWorkflow = runtime.renderingWorkflow
        self.canvasPreviewRenderer = runtime.canvasPreviewRenderer
        let canvasEyedropperSampler = GpuCanvasEyedropperSampler()
        let selectionWorkflowEnvironment = SelectionWorkflowEnvironment(workflow: runtime.selectionWorkflow)

        self.canvasEyedropperSampler = canvasEyedropperSampler
        self.selectionMaskProcessor = runtime.selectionMaskProcessor
        self.canvasPresentationEnvironment = runtime.canvasPresentationEnvironment
        self.canvasCommandService = runtime.canvasCommands
        self.layerCommandService = runtime.layerCommands
        self.strokeCommandService = runtime.strokeCommands
        self.historyCommandService = runtime.historyCommands
        self.mutationWorkflowService = runtime.mutationWorkflow
        self.contentService = runtime.contentService
        self.canvasEditingWorkflowService = runtime.canvasEditingWorkflow
        self.layerTransformProcessor = runtime.layerTransformProcessor
        self.selectionWorkflowService = runtime.selectionWorkflow
        self.selectionWorkflowEnvironment = selectionWorkflowEnvironment

        let persistenceClient = runtime.persistenceClient
        let persistenceGateway = DocumentPersistenceGateway(
            saveProject: persistenceClient.saveProject,
            loadProject: persistenceClient.loadProject,
            setPaperStyle: persistenceClient.setPaperStyle,
            newCanvas: persistenceClient.newCanvas,
            prewarmDrawingResources: persistenceClient.prewarmDrawingResources
        )
        self.persistenceGateway = persistenceGateway

        let exportClient = runtime.exportClient
        let exportGateway = DocumentExportGateway(
            compositeSurface: exportClient.compositeSurface,
            compositePNGData: exportClient.compositePNGData,
            timelapseCapture: exportClient.timelapseCapture
        )
        self.exportGateway = exportGateway

        self.presentationCapability = DocumentPresentationCapability(
            presentationReader: runtime.presentationReader,
            persistenceGateway: persistenceGateway,
            exportGateway: exportGateway,
            renderingWorkflow: runtime.renderingWorkflow
        )
        self.presentationRefreshEnvironment = PresentationRefreshEnvironment(
            presentationReader: runtime.presentationReader,
            persistenceGateway: persistenceGateway,
            exportGateway: exportGateway,
            renderingWorkflow: runtime.renderingWorkflow
        )
        self.canvasMutationCapability = DocumentCanvasMutationCapability(
            canvasCommandService: runtime.canvasCommands,
            historyCommandService: runtime.historyCommands,
            persistenceGateway: persistenceGateway,
            presentationReader: runtime.presentationReader,
            renderingWorkflow: runtime.renderingWorkflow
        )
        self.layerMutationCapability = DocumentLayerMutationCapability(
            contentService: runtime.contentService,
            renderingWorkflow: runtime.renderingWorkflow,
            mutationWorkflowService: runtime.mutationWorkflow,
            presentationReader: runtime.presentationReader,
            textLayerService: runtime.textLayerService,
            selectionWorkflowService: runtime.selectionWorkflow
        )
        self.layerWorkflowEnvironment = LayerWorkflowEnvironment(
            contentService: runtime.contentService,
            renderingWorkflow: runtime.renderingWorkflow,
            mutationWorkflowService: runtime.mutationWorkflow,
            presentationReader: runtime.presentationReader,
            textLayerService: runtime.textLayerService,
            selectionWorkflowService: runtime.selectionWorkflow,
            canvasStrokeInteractionService: runtime.canvasStrokeInteractionService
        )
        self.strokeCapability = DocumentStrokeCapability(
            canvasStrokeInteractionService: runtime.canvasStrokeInteractionService,
            renderingWorkflow: runtime.renderingWorkflow,
            layerCommandService: runtime.layerCommands,
            strokeCommandService: runtime.strokeCommands,
            persistenceGateway: persistenceGateway,
            presentationReader: runtime.presentationReader,
            canvasEditingWorkflowService: runtime.canvasEditingWorkflow,
            contentService: runtime.contentService,
            layerTransformProcessor: runtime.layerTransformProcessor,
            selectionWorkflowEnvironment: selectionWorkflowEnvironment
        )
        self.canvasStrokeEnvironment = CanvasStrokeEnvironment(
            canvasStrokeInteractionService: runtime.canvasStrokeInteractionService,
            renderingWorkflow: runtime.renderingWorkflow,
            layerCommandService: runtime.layerCommands,
            strokeCommandService: runtime.strokeCommands,
            persistenceGateway: persistenceGateway,
            presentationReader: runtime.presentationReader,
            canvasEditingWorkflowService: runtime.canvasEditingWorkflow,
            contentService: runtime.contentService,
            layerTransformProcessor: runtime.layerTransformProcessor,
            selectionWorkflowEnvironment: selectionWorkflowEnvironment
        )
        self.exportCapability = DocumentExportCapability(exportGateway: exportGateway)
        self.persistenceCapability = DocumentPersistenceCapability(persistenceGateway: persistenceGateway)
        self.previewRenderingCapability = DocumentPreviewRenderingCapability(
            canvasPreviewRenderer: runtime.canvasPreviewRenderer,
            canvasEyedropperSampler: canvasEyedropperSampler,
            selectionMaskProcessor: runtime.selectionMaskProcessor,
            canvasPresentationEnvironment: runtime.canvasPresentationEnvironment
        )
    }
}

private enum DocumentApplicationEnvironmentKey: DependencyKey {
    static var liveValue: DocumentApplicationEnvironment {
        @Dependency(\.documentRuntime) var runtime
        return DocumentApplicationEnvironment(runtime: runtime)
    }
}

private enum WorkspaceApplicationWorkflowServiceKey: DependencyKey {
    static let liveValue = WorkspaceApplicationWorkflowService()
}

extension DependencyValues {
    var documentApplicationEnvironment: DocumentApplicationEnvironment {
        get { self[DocumentApplicationEnvironmentKey.self] }
        set { self[DocumentApplicationEnvironmentKey.self] = newValue }
    }

    var documentRuntime: DocumentRuntime {
        get { self[DocumentRuntimeKey.self] }
        set {
            self[DocumentRuntimeKey.self] = newValue
            documentApplicationEnvironment = DocumentApplicationEnvironment(runtime: newValue)
        }
    }

    var documentPresentationCapability: DocumentPresentationCapability {
        documentApplicationEnvironment.presentationCapability
    }

    var presentationRefreshEnvironment: PresentationRefreshEnvironment {
        documentApplicationEnvironment.presentationRefreshEnvironment
    }

    var documentCanvasMutationCapability: DocumentCanvasMutationCapability {
        documentApplicationEnvironment.canvasMutationCapability
    }

    var documentLayerMutationCapability: DocumentLayerMutationCapability {
        documentApplicationEnvironment.layerMutationCapability
    }

    var layerWorkflowEnvironment: LayerWorkflowEnvironment {
        documentApplicationEnvironment.layerWorkflowEnvironment
    }

    var documentStrokeCapability: DocumentStrokeCapability {
        documentApplicationEnvironment.strokeCapability
    }

    var canvasStrokeEnvironment: CanvasStrokeEnvironment {
        documentApplicationEnvironment.canvasStrokeEnvironment
    }

    var documentExportCapability: DocumentExportCapability {
        documentApplicationEnvironment.exportCapability
    }

    var documentPersistenceCapability: DocumentPersistenceCapability {
        documentApplicationEnvironment.persistenceCapability
    }

    var documentPreviewRenderingCapability: DocumentPreviewRenderingCapability {
        documentApplicationEnvironment.previewRenderingCapability
    }

    var canvasPreviewRenderer: any CanvasPreviewRendering {
        documentApplicationEnvironment.canvasPreviewRenderer
    }

    var canvasEyedropperSampler: any CanvasEyedropperSampling {
        documentApplicationEnvironment.canvasEyedropperSampler
    }

    var selectionMaskProcessor: any SelectionMaskProcessing {
        documentApplicationEnvironment.selectionMaskProcessor
    }

    var canvasPresentationEnvironment: CanvasPresentationEnvironment {
        documentApplicationEnvironment.canvasPresentationEnvironment
    }

    var selectionWorkflowEnvironment: SelectionWorkflowEnvironment {
        documentApplicationEnvironment.selectionWorkflowEnvironment
    }

    var workspaceApplicationWorkflowService: WorkspaceApplicationWorkflowService {
        get { self[WorkspaceApplicationWorkflowServiceKey.self] }
        set { self[WorkspaceApplicationWorkflowServiceKey.self] = newValue }
    }
}
