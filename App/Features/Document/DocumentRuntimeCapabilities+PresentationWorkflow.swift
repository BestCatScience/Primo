import PrimoCanvasPresentationDomain
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime

protocol PresentationReadable: Sendable {
    func lightweightPresentation() -> Result<PaintDocumentPresentation, DocumentMutationFailure>
    func presentation() -> Result<PaintDocumentPresentation, DocumentMutationFailure>
}

protocol DirtyRefreshRequesting: Sendable {
    func setPaperStyle(_ paperStyle: CanvasPaperStyle)
    func prewarmDrawingResources()
}

protocol WorkspaceSnapshotRendering: Sendable {
    var exportGateway: DocumentExportGateway { get }
    var renderingWorkflow: DocumentRenderingWorkflow { get }
}

typealias PresentationWorkflowAccess = PresentationReadable & DirtyRefreshRequesting & WorkspaceSnapshotRendering
