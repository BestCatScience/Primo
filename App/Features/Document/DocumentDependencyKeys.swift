import ComposableArchitecture
import PrimoDocumentApplication
import PrimoDocumentRuntime
import PrimoDocumentRuntimeLive
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

    var strokePreviewPort: any StrokePreviewPort {
        documentApplicationEnvironment.strokePreviewPort
    }

    var strokeCommitPort: any StrokeCommitPort {
        documentApplicationEnvironment.strokeCommitPort
    }

    var layerVisibilityPort: any LayerVisibilityPort {
        documentApplicationEnvironment.layerVisibilityPort
    }

    var layerContentPort: any LayerContentPort {
        documentApplicationEnvironment.layerContentPort
    }

    var selectionProcessingPort: any SelectionProcessingPort {
        documentApplicationEnvironment.selectionProcessingPort
    }

    var canvasTransformPort: any CanvasTransformPort {
        documentApplicationEnvironment.canvasTransformPort
    }

    var canvasEditingPresentationPort: any CanvasEditingPresentationPort {
        documentApplicationEnvironment.canvasEditingPresentationPort
    }

    var paperStylePort: any PaperStylePort {
        documentApplicationEnvironment.paperStylePort
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
