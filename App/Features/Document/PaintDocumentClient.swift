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

struct DocumentApplicationEnvironment: Sendable {
    let runtime: DocumentRuntime
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
        self.canvasEyedropperSampler = GpuCanvasEyedropperSampler()
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
        self.selectionWorkflowEnvironment = SelectionWorkflowEnvironment(workflow: runtime.selectionWorkflow)

        let persistenceClient = runtime.persistenceClient
        self.persistenceGateway = DocumentPersistenceGateway(
            saveProject: persistenceClient.saveProject,
            loadProject: persistenceClient.loadProject,
            setPaperStyle: persistenceClient.setPaperStyle,
            newCanvas: persistenceClient.newCanvas,
            prewarmDrawingResources: persistenceClient.prewarmDrawingResources
        )

        let exportClient = runtime.exportClient
        self.exportGateway = DocumentExportGateway(
            compositeSurface: exportClient.compositeSurface,
            compositePNGData: exportClient.compositePNGData,
            timelapseCapture: exportClient.timelapseCapture
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

    var documentPresentationReader: DocumentPresentationReader {
        documentApplicationEnvironment.presentationReader
    }

    var documentPersistenceGateway: DocumentPersistenceGateway {
        documentApplicationEnvironment.persistenceGateway
    }

    var documentExportGateway: DocumentExportGateway {
        documentApplicationEnvironment.exportGateway
    }

    var documentTextLayerService: DocumentTextLayerService {
        documentApplicationEnvironment.textLayerService
    }

    var canvasStrokeInteractionService: CanvasStrokeInteractionService {
        documentApplicationEnvironment.canvasStrokeInteractionService
    }

    var documentRenderingWorkflow: DocumentRenderingWorkflow {
        documentApplicationEnvironment.renderingWorkflow
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

    var documentCanvasCommandService: DocumentCanvasCommandService {
        documentApplicationEnvironment.canvasCommandService
    }

    var documentLayerCommandService: DocumentLayerCommandService {
        documentApplicationEnvironment.layerCommandService
    }

    var documentStrokeCommandService: DocumentStrokeCommandService {
        documentApplicationEnvironment.strokeCommandService
    }

    var documentHistoryCommandService: DocumentHistoryCommandService {
        documentApplicationEnvironment.historyCommandService
    }

    var documentMutationWorkflowService: DocumentMutationWorkflowService {
        documentApplicationEnvironment.mutationWorkflowService
    }

    var documentContentService: DocumentContentService {
        documentApplicationEnvironment.contentService
    }

    var canvasEditingWorkflowService: CanvasEditingWorkflowService {
        documentApplicationEnvironment.canvasEditingWorkflowService
    }

    var layerTransformProcessor: any LayerTransformProcessing {
        documentApplicationEnvironment.layerTransformProcessor
    }

    var selectionWorkflowService: SelectionWorkflowService {
        documentApplicationEnvironment.selectionWorkflowService
    }

    var selectionWorkflowEnvironment: SelectionWorkflowEnvironment {
        documentApplicationEnvironment.selectionWorkflowEnvironment
    }

    var workspaceApplicationWorkflowService: WorkspaceApplicationWorkflowService {
        get { self[WorkspaceApplicationWorkflowServiceKey.self] }
        set { self[WorkspaceApplicationWorkflowServiceKey.self] = newValue }
    }
}
