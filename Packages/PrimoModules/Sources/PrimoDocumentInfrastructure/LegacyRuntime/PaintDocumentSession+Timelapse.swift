import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func setPaperStyle(_ style: CanvasPaperStyle) {
        guard paperStyleValue != style else { return }
        setStoredPaperStyle(style)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setPaperStyle(style),
                captureFrame: false
            )
        )
    }

    func timelapseCapture() -> TimelapseCapture? {
        let previewData = makeTimelapseThumbnail().flatMap { DocumentImageCodec.jpegData(from: $0) }
        if timelapseUsesOperationPersistence, !timelapseEventsSnapshot.isEmpty {
            return TimelapseCapture(
                canvasSize: documentGateway.queries.canvasSize,
                paperStyle: paperStyleValue,
                previewImageData: previewData,
                source: .operations(timelapseEventsSnapshot),
                framesPerSecond: 24
            )
        }

        guard timelapseFramesSnapshot.count >= 2 else { return nil }
        return TimelapseCapture(
            canvasSize: documentGateway.queries.canvasSize,
            paperStyle: paperStyleValue,
            previewImageData: previewData,
            source: .frames(timelapseFramesSnapshot),
            framesPerSecond: 24
        )
    }

    func timelapseCompositeImage() -> CGImage? {
        renderedCompositeImage(paperStyle: paperStyleValue)
    }
}
