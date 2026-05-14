import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentPresentationContracts

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
    public static func loadPreview(from url: URL) throws -> DocumentProjectPreview {
        try loadPreview(
            from: url,
            fileClient: .live,
            dateClient: .live,
            uuidClient: .live
        )
    }

    public static func loadPreview(
        from url: URL,
        fileClient: PrimoCoreTypes.FileClient,
        dateClient: PrimoCoreTypes.DateClient,
        uuidClient: PrimoCoreTypes.UUIDClient
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
