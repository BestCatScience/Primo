import ComposableArchitecture
import Foundation
import PrimoCanvasPresentationDomain
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
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

private enum DocumentCanvasCommandServiceKey: DependencyKey {
    static var liveValue: DocumentCanvasCommandService {
        @Dependency(\.documentRuntime) var runtime
        return runtime.canvasCommands
    }
}

private enum DocumentLayerCommandServiceKey: DependencyKey {
    static var liveValue: DocumentLayerCommandService {
        @Dependency(\.documentRuntime) var runtime
        return runtime.layerCommands
    }
}

private enum DocumentStrokeCommandServiceKey: DependencyKey {
    static var liveValue: DocumentStrokeCommandService {
        @Dependency(\.documentRuntime) var runtime
        return runtime.strokeCommands
    }
}

private enum CanvasStrokeInteractionServiceKey: DependencyKey {
    static var liveValue: CanvasStrokeInteractionService {
        @Dependency(\.documentRuntime) var runtime
        return runtime.canvasStrokeInteractionService
    }
}

private enum DocumentHistoryCommandServiceKey: DependencyKey {
    static var liveValue: DocumentHistoryCommandService {
        @Dependency(\.documentRuntime) var runtime
        return runtime.historyCommands
    }
}

private enum DocumentMutationWorkflowServiceKey: DependencyKey {
    static var liveValue: DocumentMutationWorkflowService {
        @Dependency(\.documentRuntime) var runtime
        return runtime.mutationWorkflow
    }
}

private enum DocumentContentServiceKey: DependencyKey {
    static var liveValue: DocumentContentService {
        @Dependency(\.documentRuntime) var runtime
        return runtime.contentService
    }
}

private enum CanvasEditingWorkflowServiceKey: DependencyKey {
    static var liveValue: CanvasEditingWorkflowService {
        @Dependency(\.documentRuntime) var runtime
        return runtime.canvasEditingWorkflow
    }
}

private enum SelectionWorkflowServiceKey: DependencyKey {
    static var liveValue: SelectionWorkflowService {
        @Dependency(\.documentRuntime) var runtime
        return runtime.selectionWorkflow
    }
}

private enum WorkspaceApplicationWorkflowServiceKey: DependencyKey {
    static let liveValue = WorkspaceApplicationWorkflowService()
}

private enum CanvasPreviewRendererKey: DependencyKey {
    static var liveValue: any CanvasPreviewRendering {
        @Dependency(\.documentRuntime) var runtime
        return runtime.canvasPreviewRenderer
    }
}

private enum LayerTransformProcessorKey: DependencyKey {
    static var liveValue: any LayerTransformProcessing {
        @Dependency(\.documentRuntime) var runtime
        return runtime.layerTransformProcessor
    }
}

private enum SelectionMaskProcessorKey: DependencyKey {
    static var liveValue: any SelectionMaskProcessing {
        @Dependency(\.documentRuntime) var runtime
        return runtime.selectionMaskProcessor
    }
}

private enum CanvasEyedropperSamplerKey: DependencyKey {
    static var liveValue: any CanvasEyedropperSampling {
        GpuCanvasEyedropperSampler()
    }
}

private enum CanvasPresentationEnvironmentKey: DependencyKey {
    static var liveValue: CanvasPresentationEnvironment {
        @Dependency(\.documentRuntime) var runtime
        return runtime.canvasPresentationEnvironment
    }
}

private enum DocumentPresentationReaderKey: DependencyKey {
    static var liveValue: DocumentPresentationReader {
        @Dependency(\.documentRuntime) var runtime
        return runtime.presentationReader
    }
}

private enum DocumentPersistenceGatewayKey: DependencyKey {
    static var liveValue: DocumentPersistenceGateway {
        @Dependency(\.documentRuntime) var runtime
        let client = runtime.persistenceClient
        return DocumentPersistenceGateway(
            saveProject: client.saveProject,
            loadProject: client.loadProject,
            setPaperStyle: client.setPaperStyle,
            newCanvas: client.newCanvas,
            prewarmDrawingResources: client.prewarmDrawingResources
        )
    }
}

private enum DocumentExportGatewayKey: DependencyKey {
    static var liveValue: DocumentExportGateway {
        @Dependency(\.documentRuntime) var runtime
        let client = runtime.exportClient
        return DocumentExportGateway(
            compositeSurface: client.compositeSurface,
            compositePNGData: client.compositePNGData,
            timelapseCapture: client.timelapseCapture
        )
    }
}

private enum DocumentTextLayerServiceKey: DependencyKey {
    static var liveValue: DocumentTextLayerService {
        @Dependency(\.documentRuntime) var runtime
        return runtime.textLayerService
    }
}

private enum DocumentRenderingWorkflowKey: DependencyKey {
    static var liveValue: DocumentRenderingWorkflow {
        @Dependency(\.documentRuntime) var runtime
        return runtime.renderingWorkflow
    }
}

private enum SurfaceHandleReleaserKey: DependencyKey {
    static var liveValue: any SurfaceHandleReleasing {
        @Dependency(\.documentRuntime) var runtime
        return runtime.surfaceHandleReleaser
    }
}

private extension DependencyValues {
    mutating func setDocumentRuntimeAndRefreshServices(_ runtime: DocumentRuntime) {
        self[DocumentRuntimeKey.self] = runtime
        self[DocumentCanvasCommandServiceKey.self] = runtime.canvasCommands
        self[DocumentLayerCommandServiceKey.self] = runtime.layerCommands
        self[DocumentStrokeCommandServiceKey.self] = runtime.strokeCommands
        self[CanvasStrokeInteractionServiceKey.self] = runtime.canvasStrokeInteractionService
        self[DocumentHistoryCommandServiceKey.self] = runtime.historyCommands
        self[DocumentMutationWorkflowServiceKey.self] = runtime.mutationWorkflow
        self[DocumentContentServiceKey.self] = runtime.contentService
        self[CanvasEditingWorkflowServiceKey.self] = runtime.canvasEditingWorkflow
        self[SelectionWorkflowServiceKey.self] = runtime.selectionWorkflow
        self[CanvasPreviewRendererKey.self] = runtime.canvasPreviewRenderer
        self[SelectionMaskProcessorKey.self] = runtime.selectionMaskProcessor
        self[LayerTransformProcessorKey.self] = runtime.layerTransformProcessor
        self[CanvasPresentationEnvironmentKey.self] = runtime.canvasPresentationEnvironment
        self[DocumentPresentationReaderKey.self] = runtime.presentationReader
        self[DocumentPersistenceGatewayKey.self] = DocumentPersistenceGateway(
            saveProject: runtime.persistenceClient.saveProject,
            loadProject: runtime.persistenceClient.loadProject,
            setPaperStyle: runtime.persistenceClient.setPaperStyle,
            newCanvas: runtime.persistenceClient.newCanvas,
            prewarmDrawingResources: runtime.persistenceClient.prewarmDrawingResources
        )
        self[DocumentExportGatewayKey.self] = DocumentExportGateway(
            compositeSurface: runtime.exportClient.compositeSurface,
            compositePNGData: runtime.exportClient.compositePNGData,
            timelapseCapture: runtime.exportClient.timelapseCapture
        )
        self[DocumentTextLayerServiceKey.self] = runtime.textLayerService
        self[DocumentRenderingWorkflowKey.self] = runtime.renderingWorkflow
        self[SurfaceHandleReleaserKey.self] = runtime.surfaceHandleReleaser
    }
}

extension DependencyValues {
    var documentRuntime: DocumentRuntime {
        get { self[DocumentRuntimeKey.self] }
        set { setDocumentRuntimeAndRefreshServices(newValue) }
    }

    var documentPresentationReader: DocumentPresentationReader {
        get { self[DocumentPresentationReaderKey.self] }
        set { self[DocumentPresentationReaderKey.self] = newValue }
    }

    var documentPersistenceGateway: DocumentPersistenceGateway {
        get { self[DocumentPersistenceGatewayKey.self] }
        set { self[DocumentPersistenceGatewayKey.self] = newValue }
    }

    var documentExportGateway: DocumentExportGateway {
        get { self[DocumentExportGatewayKey.self] }
        set { self[DocumentExportGatewayKey.self] = newValue }
    }

    var documentTextLayerService: DocumentTextLayerService {
        get { self[DocumentTextLayerServiceKey.self] }
        set { self[DocumentTextLayerServiceKey.self] = newValue }
    }

    var canvasStrokeInteractionService: CanvasStrokeInteractionService {
        get { self[CanvasStrokeInteractionServiceKey.self] }
        set { self[CanvasStrokeInteractionServiceKey.self] = newValue }
    }

    var documentRenderingWorkflow: DocumentRenderingWorkflow {
        get { self[DocumentRenderingWorkflowKey.self] }
        set { self[DocumentRenderingWorkflowKey.self] = newValue }
    }

    var surfaceHandleReleaser: any SurfaceHandleReleasing {
        get { self[SurfaceHandleReleaserKey.self] }
        set { self[SurfaceHandleReleaserKey.self] = newValue }
    }

    var canvasPreviewRenderer: any CanvasPreviewRendering {
        get { self[CanvasPreviewRendererKey.self] }
        set { self[CanvasPreviewRendererKey.self] = newValue }
    }

    var layerTransformProcessor: any LayerTransformProcessing {
        get { self[LayerTransformProcessorKey.self] }
        set { self[LayerTransformProcessorKey.self] = newValue }
    }

    var canvasEyedropperSampler: any CanvasEyedropperSampling {
        get { self[CanvasEyedropperSamplerKey.self] }
        set { self[CanvasEyedropperSamplerKey.self] = newValue }
    }

    var selectionMaskProcessor: any SelectionMaskProcessing {
        get { self[SelectionMaskProcessorKey.self] }
        set { self[SelectionMaskProcessorKey.self] = newValue }
    }

    var canvasPresentationEnvironment: CanvasPresentationEnvironment {
        get { self[CanvasPresentationEnvironmentKey.self] }
        set { self[CanvasPresentationEnvironmentKey.self] = newValue }
    }

    var documentCanvasCommandService: DocumentCanvasCommandService {
        get { self[DocumentCanvasCommandServiceKey.self] }
        set { self[DocumentCanvasCommandServiceKey.self] = newValue }
    }

    var documentLayerCommandService: DocumentLayerCommandService {
        get { self[DocumentLayerCommandServiceKey.self] }
        set { self[DocumentLayerCommandServiceKey.self] = newValue }
    }

    var documentStrokeCommandService: DocumentStrokeCommandService {
        get { self[DocumentStrokeCommandServiceKey.self] }
        set { self[DocumentStrokeCommandServiceKey.self] = newValue }
    }

    var documentHistoryCommandService: DocumentHistoryCommandService {
        get { self[DocumentHistoryCommandServiceKey.self] }
        set { self[DocumentHistoryCommandServiceKey.self] = newValue }
    }

    var documentMutationWorkflowService: DocumentMutationWorkflowService {
        get { self[DocumentMutationWorkflowServiceKey.self] }
        set { self[DocumentMutationWorkflowServiceKey.self] = newValue }
    }

    var documentContentService: DocumentContentService {
        get { self[DocumentContentServiceKey.self] }
        set { self[DocumentContentServiceKey.self] = newValue }
    }

    var canvasEditingWorkflowService: CanvasEditingWorkflowService {
        get { self[CanvasEditingWorkflowServiceKey.self] }
        set { self[CanvasEditingWorkflowServiceKey.self] = newValue }
    }

    var selectionWorkflowService: SelectionWorkflowService {
        get { self[SelectionWorkflowServiceKey.self] }
        set { self[SelectionWorkflowServiceKey.self] = newValue }
    }

    var workspaceApplicationWorkflowService: WorkspaceApplicationWorkflowService {
        get { self[WorkspaceApplicationWorkflowServiceKey.self] }
        set { self[WorkspaceApplicationWorkflowServiceKey.self] = newValue }
    }
}
