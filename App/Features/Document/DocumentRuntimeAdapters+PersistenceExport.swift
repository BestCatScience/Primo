import Foundation
import PrimoCanvasPresentationDomain
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRuntime

struct DocumentPaperStyleAdapter: PaperStylePort {
    private let runtime: DocumentPersistenceRuntime

    init(runtime: DocumentPersistenceRuntime) {
        self.runtime = runtime
    }
}

extension DocumentPaperStyleAdapter {
    func setPaperStyle(_ paperStyle: CanvasPaperStyle) {
        _ = runtime.setPaperStyle(paperStyle)
    }
}

extension DocumentExportCapability {
    var exportGateway: DocumentExportGateway {
        exportRuntime.gateway
    }
}

extension DocumentPersistenceCapability {
    var persistenceGateway: DocumentPersistenceGateway {
        persistenceRuntime.gateway
    }
}

extension DocumentPersistenceRuntime {
    var gateway: DocumentPersistenceGateway {
        DocumentPersistenceGateway(
            saveProject: saveProject,
            loadProject: loadProject,
            setPaperStyle: setPaperStyle,
            newCanvas: { width, height in
                guard let size = ValidCanvasSize(width, height) else {
                    return .failure(.invalidCanvasSize(width: width, height: height))
                }
                return newCanvas(size)
            },
            prewarmDrawingResources: prewarmDrawingResources
        )
    }
}

extension DocumentExportRuntime {
    var gateway: DocumentExportGateway {
        DocumentExportGateway(
            compositeSurface: compositeSurface,
            compositePNGData: compositePNGData,
            timelapseCapture: timelapseCapture
        )
    }
}
