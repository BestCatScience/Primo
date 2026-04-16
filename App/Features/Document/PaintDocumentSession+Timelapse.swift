import CoreGraphics
import Foundation
import UIKit

extension PaintDocumentSession {
    func setPaperStyle(_ style: CanvasPaperStyle) {
        guard paperStyle != style else { return }
        paperStyle = style
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setPaperStyle(style),
                captureFrame: false
            )
        )
    }

    func timelapseCapture() -> TimelapseCapture? {
        let previewData = makeTimelapseThumbnail()?.jpegData(compressionQuality: 0.72)
        if usesOperationTimelapsePersistence, !timelapseEvents.isEmpty {
            return TimelapseCapture(
                canvasSize: CGSize(width: bridge.width, height: bridge.height),
                paperStyle: paperStyle,
                previewImageData: previewData,
                source: .operations(timelapseEvents),
                framesPerSecond: 24
            )
        }

        guard timelapseFrames.count >= 2 else { return nil }
        return TimelapseCapture(
            canvasSize: CGSize(width: bridge.width, height: bridge.height),
            paperStyle: paperStyle,
            previewImageData: previewData,
            source: .frames(timelapseFrames),
            framesPerSecond: 24
        )
    }

    func timelapseCompositeImage() -> UIImage? {
        renderedCompositeImage(paperStyle: paperStyle)
    }
}
