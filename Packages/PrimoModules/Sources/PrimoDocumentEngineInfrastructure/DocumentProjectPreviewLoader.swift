import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts

public struct DocumentProjectPreview: Equatable, Sendable {
    public let canvasSize: CGSize
    public let layerCount: Int
    public let previewSurface: DocumentCompositeSurface?

    public init(
        canvasSize: CGSize,
        layerCount: Int,
        previewSurface: DocumentCompositeSurface?
    ) {
        self.canvasSize = canvasSize
        self.layerCount = layerCount
        self.previewSurface = previewSurface
    }
}

public enum DocumentProjectPreviewLoader {
    public static func loadPreview(
        from url: URL,
        fileClient: PrimoCoreTypes.FileClient = .live,
        dateClient: PrimoCoreTypes.DateClient = .live,
        uuidClient: PrimoCoreTypes.UUIDClient = .live
    ) throws -> DocumentProjectPreview {
        let runtime = try SwiftDocumentRuntime.loadProject(
            from: url,
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient,
            gpuServices: DocumentRuntimeGpuServicesFactory.live()
        )
        let presentation = runtime.lightweightPresentation()
        return DocumentProjectPreview(
            canvasSize: presentation.canvasSize,
            layerCount: presentation.layerRows.count,
            previewSurface: runtime.compositeExportSurface(paperStyle: runtime.currentPaperStyle)
        )
    }
}
