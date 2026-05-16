import CoreGraphics
import Foundation
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime

struct DocumentPresentationWorkflowAccess: PresentationWorkflowAccess {
    private let presentationRuntime: DocumentPresentationRuntime
    private let persistenceRuntime: DocumentPersistenceRuntime
    private let exportRuntime: DocumentExportRuntime

    init(
        presentationRuntime: DocumentPresentationRuntime,
        persistenceRuntime: DocumentPersistenceRuntime,
        exportRuntime: DocumentExportRuntime
    ) {
        self.presentationRuntime = presentationRuntime
        self.persistenceRuntime = persistenceRuntime
        self.exportRuntime = exportRuntime
    }

    func lightweightPresentation() -> Result<PaintDocumentPresentation, DocumentMutationFailure> {
        presentationRuntime.lightweightPresentation()
    }

    func presentation() -> Result<PaintDocumentPresentation, DocumentMutationFailure> {
        presentationRuntime.presentation()
    }

    func setPaperStyle(_ paperStyle: CanvasPaperStyle) {
        _ = persistenceRuntime.setPaperStyle(paperStyle)
    }

    func prewarmDrawingResources() {
        _ = persistenceRuntime.prewarmDrawingResources()
    }

    var exportGateway: DocumentExportGateway {
        exportRuntime.gateway
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }
}

extension PresentationReadable {
    var presentationReader: DocumentPresentationReader {
        DocumentPresentationReader(
            lightweightPresentation: lightweightPresentation,
            presentation: presentation
        )
    }
}
