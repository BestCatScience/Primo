import Foundation

struct PaintDocumentSessionServices {
    let fileIO: FileClient
    let clock: DateClient
    let ids: UUIDClient
    let persistence: PaintDocumentPersistenceService
    let timelapse: PaintDocumentTimelapseService
    let editingLifecycle: PaintDocumentEditingLifecycleService
    let bridge: PaintDocumentBridgeService
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
        self.editingLifecycle = PaintDocumentEditingLifecycleService()
        self.bridge = PaintDocumentBridgeService()
        self.geometry = PaintDocumentGeometryService()
        self.blur = PaintDocumentBlurService()
    }
}
