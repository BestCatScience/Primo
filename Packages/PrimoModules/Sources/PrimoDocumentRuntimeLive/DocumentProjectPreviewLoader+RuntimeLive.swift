import Foundation
import PrimoCoreTypes
import PrimoDocumentEngineInfrastructure
import PrimoDocumentRuntime
import PrimoSystemClients

public enum DocumentProjectPreviewLoader {
    public static func loadPreview(
        from url: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) throws -> PrimoDocumentRuntime.DocumentProjectPreview {
        try PrimoDocumentRuntime.DocumentProjectPreview(
            PrimoDocumentEngineInfrastructure.DocumentProjectPreviewLoader.loadPreview(
                from: url,
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }
}

private extension PrimoDocumentRuntime.DocumentProjectPreview {
    init(_ infrastructure: PrimoDocumentEngineInfrastructure.DocumentProjectPreview) {
        self.init(
            canvasSize: infrastructure.canvasSize,
            layerCount: infrastructure.layerCount,
            previewSurface: infrastructure.previewSurface
        )
    }
}
