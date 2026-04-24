import Foundation
import PrimoCoreTypes
import PrimoDocumentPersistenceInfrastructure
import PrimoDocumentTimelapseInfrastructure

struct DocumentEngineServices {
    let fileIO: FileClient
    let clock: DateClient
    let ids: UUIDClient
    let persistence: DocumentPersistenceServices
    let timelapse: DocumentTimelapseServices

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
