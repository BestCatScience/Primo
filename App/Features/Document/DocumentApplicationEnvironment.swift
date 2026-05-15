import PrimoDocumentApplication
import PrimoDocumentRuntime

struct DocumentApplicationEnvironment: Sendable {
    let presentationWorkflowAccess: any PresentationWorkflowAccess
    let canvasMutationCapability: DocumentCanvasMutationCapability
    let layerMutationCapability: DocumentLayerMutationCapability
    let layerWorkflowEnvironment: LayerWorkflowEnvironment
    let strokePreviewPort: any StrokePreviewPort
    let strokeCommitPort: any StrokeCommitPort
    let layerVisibilityPort: any LayerVisibilityPort
    let layerContentPort: any LayerContentPort
    let selectionProcessingPort: any SelectionProcessingPort
    let canvasTransformPort: any CanvasTransformPort
    let canvasEditingPresentationPort: any CanvasEditingPresentationPort
    let paperStylePort: any PaperStylePort
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
        let canvasEditingAccess = DocumentCanvasEditingAccess(
            strokeRuntime: runtime.strokeEditing,
            layerEditingRuntime: runtime.layerEditing,
            presentationAccess: presentationWorkflowAccess
        )
        self.strokePreviewPort = canvasEditingAccess
        self.strokeCommitPort = canvasEditingAccess
        self.layerVisibilityPort = canvasEditingAccess
        self.layerContentPort = canvasEditingAccess
        self.selectionProcessingPort = canvasEditingAccess
        self.canvasTransformPort = canvasEditingAccess
        self.canvasEditingPresentationPort = canvasEditingAccess
        self.paperStylePort = canvasEditingAccess
        self.exportCapability = DocumentExportCapability(exportRuntime: runtime.export)
        self.persistenceCapability = DocumentPersistenceCapability(persistenceRuntime: runtime.persistence)
        self.previewRenderingCapability = DocumentPreviewRenderingCapability(previewRuntime: runtime.preview)
    }
}
