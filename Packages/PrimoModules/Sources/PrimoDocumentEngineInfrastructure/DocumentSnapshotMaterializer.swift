import Foundation
import os
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts

enum DocumentSnapshotMaterializer {
    static func compositeSurface(
        forMaterializedSnapshot snapshot: SwiftDocumentStoreSnapshot,
        gpuServices: DocumentRuntimeGpuServices,
        logger: Logger
    ) -> DocumentCompositeSurface {
        let metalSnapshot = materializedMetalSnapshot(for: snapshot)
        if let gpuComposite = gpuServices.compositeDocumentSurface(snapshot: metalSnapshot) {
            return gpuComposite
        }
        logger.error("GPU composite failed for snapshot revision \(snapshot.revision, privacy: .public)")
        return DocumentCompositeSurface(
            unsafeUncheckedWidth: snapshot.canvasWidth,
            height: snapshot.canvasHeight,
            pixelData: Data(count: snapshot.canvasWidth * snapshot.canvasHeight * 4)
        )
    }

    static func compositeExportSurface(
        forMaterializedSnapshot snapshot: SwiftDocumentStoreSnapshot,
        paperStyle: CanvasPaperStyle,
        gpuServices: DocumentRuntimeGpuServices,
        logger: Logger
    ) -> DocumentCompositeSurface? {
        let surface = compositeSurface(forMaterializedSnapshot: snapshot, gpuServices: gpuServices, logger: logger)
        guard let pixelData = gpuServices.compositedPaperPreviewRGBA(
            pixelData: surface.pixelData,
            width: surface.width,
            height: surface.height,
            paperStyle: paperStyle
        ) else {
            return nil
        }
        return DocumentCompositeSurface(
            unsafeUncheckedWidth: surface.width,
            height: surface.height,
            pixelData: pixelData
        )
    }

    static func compositePNGData(
        forMaterializedSnapshot snapshot: SwiftDocumentStoreSnapshot,
        paperStyle: CanvasPaperStyle,
        gpuServices: DocumentRuntimeGpuServices,
        logger: Logger
    ) -> Data? {
        compositeExportSurface(
            forMaterializedSnapshot: snapshot,
            paperStyle: paperStyle,
            gpuServices: gpuServices,
            logger: logger
        ).flatMap(DocumentRasterImageService.pngData(from:))
    }

    static func materializedMetalSnapshot(
        for snapshot: SwiftDocumentStoreSnapshot
    ) -> MetalDocumentSnapshot {
        MetalDocumentSnapshot.unsafeUnchecked(
            width: snapshot.canvasWidth,
            height: snapshot.canvasHeight,
            revision: snapshot.revision,
            compositePixelData: Data(),
            layers: snapshot.layers.enumerated().map { index, layer in
                MetalLayerSnapshot.unsafeUnchecked(
                    index: index,
                    opacity: Float(layer.opacity),
                    visible: layer.visible && (layer.folderID == nil || (snapshot.folders.first(where: { $0.id == layer.folderID })?.visible ?? true)),
                    isClipped: layer.clipped,
                    blendMode: layer.blendMode,
                    thumbnailSurface: nil,
                    thumbnailData: nil,
                    gpuBufferHandle: nil,
                    pixelData: layer.pixelData
                )
            }
        )
    }
}
