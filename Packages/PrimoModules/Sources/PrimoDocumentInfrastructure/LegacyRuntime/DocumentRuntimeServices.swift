import Foundation
import PrimoCoreTypes

struct DocumentRuntimeServices {
    let fileIO: FileClient
    let clock: DateClient
    let ids: UUIDClient
    let persistence: PaintDocumentPersistenceService
    let timelapse: PaintDocumentTimelapseService
    let geometry: PaintDocumentGeometryService
    let blur: PaintDocumentBlurService

    init(
        fileClient: FileClient,
        dateClient: DateClient,
        uuidClient: UUIDClient
    ) {
        self.fileIO = fileClient
        self.clock = dateClient
        self.ids = uuidClient
        self.persistence = PaintDocumentPersistenceService(fileClient: fileClient)
        self.timelapse = PaintDocumentTimelapseService(fileClient: fileClient, uuidClient: uuidClient)
        self.geometry = PaintDocumentGeometryService()
        self.blur = PaintDocumentBlurService()
    }
}
