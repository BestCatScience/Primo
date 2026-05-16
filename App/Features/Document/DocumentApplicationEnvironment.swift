import PrimoDocumentApplication
import PrimoDocumentRuntime

struct PresentationEnvironment: Sendable {
    let presentationWorkflowAccess: any PresentationWorkflowAccess
    let canvasMutationCapability: DocumentCanvasMutationCapability
    let layerMutationCapability: DocumentLayerMutationCapability
}

struct CanvasEditingEnvironment: Sendable {
    let strokePreviewPort: any StrokePreviewPort
    let strokeCommitPort: any StrokeCommitPort
    let layerVisibilityPort: any LayerVisibilityPort
    let layerContentPort: any LayerContentPort
    let selectionProcessingPort: any SelectionProcessingPort
    let canvasTransformPort: any CanvasTransformPort
    let canvasEditingPresentationPort: any CanvasEditingPresentationPort
    let paperStylePort: any PaperStylePort
}

struct PersistenceEnvironment: Sendable {
    let exportCapability: DocumentExportCapability
    let persistenceCapability: DocumentPersistenceCapability
    let previewRenderingCapability: DocumentPreviewRenderingCapability
}

struct DocumentApplicationEnvironment: Sendable {
    let presentationEnvironment: PresentationEnvironment
    let canvasEditingEnvironment: CanvasEditingEnvironment
    let layerWorkflowEnvironment: LayerWorkflowEnvironment
    let persistenceEnvironment: PersistenceEnvironment

    init(workflows runtime: DocumentApplicationWorkflowRuntime) {
        self.presentationEnvironment = PresentationEnvironment(workflows: runtime)
        self.canvasEditingEnvironment = CanvasEditingEnvironment(workflows: runtime)
        self.layerWorkflowEnvironment = LayerWorkflowEnvironment(workflows: runtime)
        self.persistenceEnvironment = PersistenceEnvironment(workflows: runtime)
    }
}

extension PresentationEnvironment {
    init(workflows runtime: DocumentApplicationWorkflowRuntime) {
        self.init(
            presentationWorkflowAccess: DocumentPresentationWorkflowAccess(
                presentationRuntime: runtime.presentation,
                persistenceRuntime: runtime.persistence,
                exportRuntime: runtime.export
            ),
            canvasMutationCapability: DocumentCanvasMutationCapability(
                canvasMutationRuntime: runtime.canvasMutation,
                presentationRuntime: runtime.presentation,
                persistenceRuntime: runtime.persistence
            ),
            layerMutationCapability: DocumentLayerMutationCapability(
                layerStructureRuntime: runtime.layerEditing.structure,
                layerContentRuntime: runtime.layerEditing.content,
                textLayerRuntime: runtime.layerEditing.text,
                selectionRuntime: runtime.layerEditing.selection,
                presentationRuntime: runtime.presentation
            )
        )
    }
}

extension CanvasEditingEnvironment {
    init(workflows runtime: DocumentApplicationWorkflowRuntime) {
        self.init(
            strokePreviewPort: DocumentStrokePreviewAdapter(runtime: runtime.strokeEditing),
            strokeCommitPort: DocumentStrokeCommitAdapter(runtime: runtime.strokeEditing),
            layerVisibilityPort: DocumentLayerVisibilityAdapter(runtime: runtime.layerEditing.structure),
            layerContentPort: DocumentLayerContentAdapter(runtime: runtime.layerEditing.content),
            selectionProcessingPort: DocumentSelectionProcessingAdapter(runtime: runtime.layerEditing.selection),
            canvasTransformPort: DocumentCanvasTransformAdapter(
                canvasEditingRuntime: runtime.layerEditing.canvasEditing,
                transformRuntime: runtime.layerEditing.transform
            ),
            canvasEditingPresentationPort: DocumentCanvasEditingPresentationAdapter(runtime: runtime.presentation),
            paperStylePort: DocumentPaperStyleAdapter(runtime: runtime.persistence)
        )
    }
}

extension LayerWorkflowEnvironment {
    init(workflows runtime: DocumentApplicationWorkflowRuntime) {
        self.init(
            layerStructureRuntime: runtime.layerEditing.structure,
            layerContentRuntime: runtime.layerEditing.content,
            textLayerRuntime: runtime.layerEditing.text,
            selectionRuntime: runtime.layerEditing.selection,
            presentationRuntime: runtime.presentation,
            strokeRuntime: runtime.strokeEditing
        )
    }
}

extension PersistenceEnvironment {
    init(workflows runtime: DocumentApplicationWorkflowRuntime) {
        self.init(
            exportCapability: DocumentExportCapability(exportRuntime: runtime.export),
            persistenceCapability: DocumentPersistenceCapability(persistenceRuntime: runtime.persistence),
            previewRenderingCapability: DocumentPreviewRenderingCapability(previewRuntime: runtime.preview)
        )
    }
}
