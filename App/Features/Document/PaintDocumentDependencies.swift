import ComposableArchitecture
import PrimoDocumentApplication
import PrimoDocumentPersistenceContracts
import PrimoDocumentRuntime
import PrimoWorkspaceApplication

private enum DocumentApplicationEnvironmentKey: DependencyKey {
    static var liveValue: DocumentApplicationEnvironment {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient

        return DocumentApplicationEnvironment(
            workflows: DocumentApplicationRuntimeFactory.liveWorkflows(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }
}

struct DocumentApplicationEnvironment: Sendable {
    let presentationWorkflowAccess: any PresentationWorkflowAccess
    let canvasMutationCapability: DocumentCanvasMutationCapability
    let layerMutationCapability: DocumentLayerMutationCapability
    let layerWorkflowEnvironment: LayerWorkflowEnvironment
    let canvasStrokeWorkflowAccess: any CanvasStrokeWorkflowAccess
    let exportCapability: DocumentExportCapability
    let persistenceCapability: DocumentPersistenceCapability
    let previewRenderingCapability: DocumentPreviewRenderingCapability

    init(workflows runtime: DocumentApplicationWorkflowRuntime) {
        let presentationWorkflowAccess = DocumentPresentationWorkflowAccess(
            presentationRuntime: runtime.presentation,
            persistenceRuntime: runtime.persistence,
            exportRuntime: runtime.export
        )
        self.presentationWorkflowAccess = presentationWorkflowAccess
        self.canvasMutationCapability = DocumentCanvasMutationCapability(
            canvasMutationRuntime: runtime.canvasMutation,
            presentationRuntime: runtime.presentation,
            persistenceRuntime: runtime.persistence
        )
        self.layerMutationCapability = DocumentLayerMutationCapability(
            layerEditingRuntime: runtime.layerEditing,
            presentationRuntime: runtime.presentation
        )
        self.layerWorkflowEnvironment = LayerWorkflowEnvironment(
            layerEditingRuntime: runtime.layerEditing,
            presentationRuntime: runtime.presentation,
            strokeRuntime: runtime.strokeEditing
        )
        self.canvasStrokeWorkflowAccess = DocumentCanvasStrokeWorkflowAccess(
            strokeRuntime: runtime.strokeEditing,
            layerEditingRuntime: runtime.layerEditing,
            presentationAccess: presentationWorkflowAccess
        )
        self.exportCapability = DocumentExportCapability(exportRuntime: runtime.export)
        self.persistenceCapability = DocumentPersistenceCapability(persistenceRuntime: runtime.persistence)
        self.previewRenderingCapability = DocumentPreviewRenderingCapability(previewRuntime: runtime.preview)
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

    var presentationWorkflowAccess: any PresentationWorkflowAccess {
        documentApplicationEnvironment.presentationWorkflowAccess
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

    var canvasStrokeWorkflowAccess: any CanvasStrokeWorkflowAccess {
        documentApplicationEnvironment.canvasStrokeWorkflowAccess
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

    var workspaceApplicationWorkflowService: WorkspaceApplicationWorkflowService {
        get { self[WorkspaceApplicationWorkflowServiceKey.self] }
        set { self[WorkspaceApplicationWorkflowServiceKey.self] = newValue }
    }
}
