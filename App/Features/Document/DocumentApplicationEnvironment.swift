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
            layerStructureRuntime: runtime.layerEditing.structure,
            layerContentRuntime: runtime.layerEditing.content,
            textLayerRuntime: runtime.layerEditing.text,
            selectionRuntime: runtime.layerEditing.selection,
            presentationRuntime: runtime.presentation
        )
        self.layerWorkflowEnvironment = LayerWorkflowEnvironment(
            layerStructureRuntime: runtime.layerEditing.structure,
            layerContentRuntime: runtime.layerEditing.content,
            textLayerRuntime: runtime.layerEditing.text,
            selectionRuntime: runtime.layerEditing.selection,
            presentationRuntime: runtime.presentation,
            strokeRuntime: runtime.strokeEditing
        )
        self.strokePreviewPort = DocumentStrokePreviewAdapter(runtime: runtime.strokeEditing)
        self.strokeCommitPort = DocumentStrokeCommitAdapter(runtime: runtime.strokeEditing)
        self.layerVisibilityPort = DocumentLayerVisibilityAdapter(runtime: runtime.layerEditing.structure)
        self.layerContentPort = DocumentLayerContentAdapter(runtime: runtime.layerEditing.content)
        self.selectionProcessingPort = DocumentSelectionProcessingAdapter(runtime: runtime.layerEditing.selection)
        self.canvasTransformPort = DocumentCanvasTransformAdapter(
            canvasEditingRuntime: runtime.layerEditing.canvasEditing,
            transformRuntime: runtime.layerEditing.transform
        )
        self.canvasEditingPresentationPort = DocumentCanvasEditingPresentationAdapter(runtime: runtime.presentation)
        self.paperStylePort = DocumentPaperStyleAdapter(runtime: runtime.persistence)
        self.exportCapability = DocumentExportCapability(exportRuntime: runtime.export)
        self.persistenceCapability = DocumentPersistenceCapability(persistenceRuntime: runtime.persistence)
        self.previewRenderingCapability = DocumentPreviewRenderingCapability(previewRuntime: runtime.preview)
    }
}
