import ComposableArchitecture
import PrimoDocumentAppSupport
import PrimoDocumentApplication
import PrimoDocumentRuntime
import PrimoWorkspaceApplication

private enum DocumentApplicationEnvironmentKey: DependencyKey {
    static var liveValue: DocumentApplicationEnvironment {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient

        return DocumentApplicationEnvironment(
            workflows: DocumentAppRuntimeSupport.liveWorkflows(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
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
        documentApplicationEnvironment.presentationEnvironment.presentationWorkflowAccess
    }

    var documentCanvasMutationCapability: DocumentCanvasMutationCapability {
        documentApplicationEnvironment.presentationEnvironment.canvasMutationCapability
    }

    var documentLayerMutationCapability: DocumentLayerMutationCapability {
        documentApplicationEnvironment.presentationEnvironment.layerMutationCapability
    }

    var layerWorkflowEnvironment: LayerWorkflowEnvironment {
        documentApplicationEnvironment.layerWorkflowEnvironment
    }

    var strokePreviewPort: any StrokePreviewPort {
        documentApplicationEnvironment.canvasEditingEnvironment.strokePreviewPort
    }

    var strokeCommitPort: any StrokeCommitPort {
        documentApplicationEnvironment.canvasEditingEnvironment.strokeCommitPort
    }

    var layerVisibilityPort: any LayerVisibilityPort {
        documentApplicationEnvironment.canvasEditingEnvironment.layerVisibilityPort
    }

    var layerContentPort: any LayerContentPort {
        documentApplicationEnvironment.canvasEditingEnvironment.layerContentPort
    }

    var selectionProcessingPort: any SelectionProcessingPort {
        documentApplicationEnvironment.canvasEditingEnvironment.selectionProcessingPort
    }

    var canvasTransformPort: any CanvasTransformPort {
        documentApplicationEnvironment.canvasEditingEnvironment.canvasTransformPort
    }

    var canvasEditingPresentationPort: any CanvasEditingPresentationPort {
        documentApplicationEnvironment.canvasEditingEnvironment.canvasEditingPresentationPort
    }

    var paperStylePort: any PaperStylePort {
        documentApplicationEnvironment.canvasEditingEnvironment.paperStylePort
    }

    var documentExportCapability: DocumentExportCapability {
        documentApplicationEnvironment.persistenceEnvironment.exportCapability
    }

    var documentPersistenceCapability: DocumentPersistenceCapability {
        documentApplicationEnvironment.persistenceEnvironment.persistenceCapability
    }

    var documentPreviewRenderingCapability: DocumentPreviewRenderingCapability {
        documentApplicationEnvironment.persistenceEnvironment.previewRenderingCapability
    }

    var workspaceApplicationWorkflowService: WorkspaceApplicationWorkflowService {
        get { self[WorkspaceApplicationWorkflowServiceKey.self] }
        set { self[WorkspaceApplicationWorkflowServiceKey.self] = newValue }
    }
}
