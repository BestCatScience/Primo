import CoreGraphics
import Foundation
import UIKit

extension PaintDocumentSession {
    func setPaperStyle(_ style: CanvasPaperStyle) {
        guard sessionState.presentation.paperStyle != style else { return }
        sessionState.presentation.setPaperStyle(style)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setPaperStyle(style),
                captureFrame: false
            )
        )
    }

    func timelapseCapture() -> TimelapseCapture? {
        let previewData = makeTimelapseThumbnail()?.jpegData(compressionQuality: 0.72)
        if sessionState.timelapse.usesOperationPersistence, !sessionState.timelapse.events.isEmpty {
            return TimelapseCapture(
                canvasSize: CGSize(width: bridge.width, height: bridge.height),
                paperStyle: sessionState.presentation.paperStyle,
                previewImageData: previewData,
                source: .operations(sessionState.timelapse.events),
                framesPerSecond: 24
            )
        }

        guard sessionState.timelapse.frames.count >= 2 else { return nil }
        return TimelapseCapture(
            canvasSize: CGSize(width: bridge.width, height: bridge.height),
            paperStyle: sessionState.presentation.paperStyle,
            previewImageData: previewData,
            source: .frames(sessionState.timelapse.frames),
            framesPerSecond: 24
        )
    }

    func timelapseCompositeImage() -> UIImage? {
        renderedCompositeImage(paperStyle: sessionState.presentation.paperStyle)
    }
}
