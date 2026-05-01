import ComposableArchitecture
import Foundation
import PrimoCanvasPresentationDomain
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
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

private enum DocumentQueryGatewayKey: DependencyKey {
    static var liveValue: DocumentQueryGateway {
        @Dependency(\.documentRuntime) var runtime
        return runtime.queryGateway
    }
}

private enum DocumentPersistenceGatewayKey: DependencyKey {
    static var liveValue: DocumentPersistenceGateway {
        @Dependency(\.documentRuntime) var runtime
        return runtime.persistenceGateway
    }
}

private enum DocumentExportGatewayKey: DependencyKey {
    static var liveValue: DocumentExportGateway {
        @Dependency(\.documentRuntime) var runtime
        return runtime.exportGateway
    }
}

private enum TextLayerGatewayKey: DependencyKey {
    static var liveValue: TextLayerGateway {
        @Dependency(\.documentRuntime) var runtime
        return runtime.textLayerGateway
    }
}

private enum DocumentGpuOperationGatewayKey: DependencyKey {
    static var liveValue: DocumentGpuOperationGateway {
        @Dependency(\.documentRuntime) var runtime
        return runtime.gpuOperationGateway
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
        self[DocumentQueryGatewayKey.self] = runtime.queryGateway
        self[DocumentPersistenceGatewayKey.self] = runtime.persistenceGateway
        self[DocumentExportGatewayKey.self] = runtime.exportGateway
        self[TextLayerGatewayKey.self] = runtime.textLayerGateway
        self[DocumentGpuOperationGatewayKey.self] = runtime.gpuOperationGateway
    }
}

extension DependencyValues {
    var documentRuntime: DocumentRuntime {
        get { self[DocumentRuntimeKey.self] }
        set { setDocumentRuntimeAndRefreshServices(newValue) }
    }

    var documentQueryGateway: DocumentQueryGateway {
        get { self[DocumentQueryGatewayKey.self] }
        set { self[DocumentQueryGatewayKey.self] = newValue }
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

    var canvasStrokeInteractionService: CanvasStrokeInteractionService {
        get { self[CanvasStrokeInteractionServiceKey.self] }
        set { self[CanvasStrokeInteractionServiceKey.self] = newValue }
    }

    var documentGpuOperationGateway: DocumentGpuOperationGateway {
        get { self[DocumentGpuOperationGatewayKey.self] }
        set { self[DocumentGpuOperationGatewayKey.self] = newValue }
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
