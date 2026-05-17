import PrimoCanvasPresentationDomain
import PrimoDocumentDomain
import PrimoDocumentPersistenceContracts
import PrimoDocumentRuntime

protocol PaperStylePort: Sendable {
    func setPaperStyle(_ paperStyle: CanvasPaperStyle)
}

struct DocumentExportCapability: Sendable {
    let exportRuntime: DocumentExportRuntime
}

struct DocumentPersistenceCapability: Sendable {
    let persistenceRuntime: DocumentPersistenceRuntime
}
