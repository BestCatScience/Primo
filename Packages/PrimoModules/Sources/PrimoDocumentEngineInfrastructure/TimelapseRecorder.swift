import CoreGraphics
import Foundation
import os
import PrimoDocumentApplication
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentTimelapseInfrastructure

struct TimelapseRecorder: Sendable {
    func record(
        _ event: TimelapseOperation?,
        marksOperationPersistence: Bool = false,
        in store: SwiftDocumentStore
    ) {
        if let event {
            if marksOperationPersistence {
                store.snapshot.timelapseUsesOperationPersistence = true
            }
            store.snapshot.timelapseEvents.append(event)
        }
    }

    func capture(
        store: SwiftDocumentStore,
        services: DocumentEngineServices,
        source: DocumentCompositeSurface?,
        canvasSize: CGSize,
        gpuServices: DocumentRuntimeGpuServices,
        frameSize: (CGSize, CGFloat) -> CGSize,
        logger: Logger
    ) {
        guard let source,
              let scaled = scaledThumbnailSurface(
                source: source,
                canvasSize: canvasSize,
                gpuServices: gpuServices,
                frameSize: frameSize
              ),
              let jpegData = DocumentRasterImageService.jpegData(from: scaled) else { return }
        let frameURL = services.timelapse.frameStore.makeFrameURL(
            in: services.timelapse.frameStore.makeDirectoryURL(),
            frameID: store.snapshot.timelapseFrames.count
        )
        do {
            try services.timelapse.frameStore.persistFrameData(jpegData, to: frameURL)
            store.snapshot.timelapseFrames.append(TimelapseFrame(imageURL: frameURL, size: CGSize(width: scaled.width, height: scaled.height)))
            store.snapshot.timelapseUsesOperationPersistence = false
        } catch {
            logger.error("Failed to persist timelapse frame: \(error.localizedDescription, privacy: .public)")
        }
    }

    func captureResult(
        store: SwiftDocumentStore,
        canvasSize: CGSize,
        previewSurface: DocumentCompositeSurface?,
        previewImageData: Data?
    ) -> TimelapseCapture? {
        if store.snapshot.timelapseUsesOperationPersistence, !store.snapshot.timelapseEvents.isEmpty {
            return TimelapseCapture(
                canvasSize: canvasSize,
                paperStyle: store.snapshot.paperStyle,
                previewSurface: previewSurface,
                previewImageData: previewImageData,
                source: .operations(store.snapshot.timelapseEvents),
                framesPerSecond: 24
            )
        }
        guard store.snapshot.timelapseFrames.count >= 2 else { return nil }
        return TimelapseCapture(
            canvasSize: canvasSize,
            paperStyle: store.snapshot.paperStyle,
            previewSurface: previewSurface,
            previewImageData: previewImageData,
            source: .frames(store.snapshot.timelapseFrames),
            framesPerSecond: 24
        )
    }

    private func scaledThumbnailSurface(
        source: DocumentCompositeSurface,
        canvasSize: CGSize,
        gpuServices: DocumentRuntimeGpuServices,
        frameSize: (CGSize, CGFloat) -> CGSize
    ) -> DocumentCompositeSurface? {
        let targetSize = frameSize(canvasSize, 512)
        guard let scaled = gpuServices.scaledPixelData(
            source.pixelData,
            sourceWidth: source.width,
            sourceHeight: source.height,
            targetWidth: max(Int(targetSize.width.rounded()), 1),
            targetHeight: max(Int(targetSize.height.rounded()), 1)
        ) else {
            return nil
        }
        return DocumentCompositeSurface(
            unsafeUncheckedWidth: max(Int(targetSize.width.rounded()), 1),
            height: max(Int(targetSize.height.rounded()), 1),
            pixelData: scaled
        )
    }
}
