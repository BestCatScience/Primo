import CoreGraphics
import Foundation
import UIKit

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
        let previewData = makeTimelapseThumbnail()?.jpegData(compressionQuality: 0.72)
        if timelapseUsesOperationPersistence, !timelapseEventsSnapshot.isEmpty {
            return TimelapseCapture(
                canvasSize: bridgeCanvasSize,
                paperStyle: paperStyleValue,
                previewImageData: previewData,
                source: .operations(timelapseEventsSnapshot),
                framesPerSecond: 24
            )
        }

        guard timelapseFramesSnapshot.count >= 2 else { return nil }
        return TimelapseCapture(
            canvasSize: bridgeCanvasSize,
            paperStyle: paperStyleValue,
            previewImageData: previewData,
            source: .frames(timelapseFramesSnapshot),
            framesPerSecond: 24
        )
    }

    func timelapseCompositeImage() -> UIImage? {
        renderedCompositeImage(paperStyle: paperStyleValue)
    }
}
