import Foundation
import PrimoCoreTypes
import PrimoDocumentPersistenceInfrastructure
import PrimoDocumentStrokeInfrastructure
import PrimoDocumentTimelapseInfrastructure

struct DocumentEngineServices {
    let fileIO: FileClient
    let clock: DateClient
    let ids: UUIDClient
    let persistence: DocumentPersistenceServices
    let timelapse: DocumentTimelapseServices
    let stroke: DocumentStrokeServices

    init(
        fileClient: FileClient,
        dateClient: DateClient,
        uuidClient: UUIDClient
    ) {
        self.fileIO = fileClient
        self.clock = dateClient
        self.ids = uuidClient
        self.persistence = DocumentPersistenceServices(fileClient: fileClient)
        self.timelapse = DocumentTimelapseServices(fileClient: fileClient, uuidClient: uuidClient)
        self.stroke = DocumentStrokeServices()
    }
}

struct DocumentPersistenceServices {
    let projectStore: PaintDocumentPersistenceService

    init(fileClient: FileClient) {
        self.projectStore = PaintDocumentPersistenceService(fileClient: fileClient)
    }
}

struct DocumentTimelapseServices {
    let frameStore: PaintDocumentTimelapseService

    init(fileClient: FileClient, uuidClient: UUIDClient) {
        self.frameStore = PaintDocumentTimelapseService(fileClient: fileClient, uuidClient: uuidClient)
    }
}

struct DocumentStrokeServices {
    let geometry: PaintDocumentGeometryService
    let blur: PaintDocumentBlurService

    init() {
        self.geometry = PaintDocumentGeometryService()
        self.blur = PaintDocumentBlurService()
    }
}
