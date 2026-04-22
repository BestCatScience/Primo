import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentEngineInfrastructure
import Testing

struct TimelapseExportServiceTests {
    @Test
    func exportVideoRejectsFrameCapturesWithFewerThanTwoFrames() {
        let capture = TimelapseCapture(
            canvasSize: CGSize(width: 64, height: 64),
            paperStyle: .default,
            previewImageData: nil,
            source: .frames([
                TimelapseFrame(
                    imageURL: URL(fileURLWithPath: "/tmp/frame-1.png"),
                    size: CGSize(width: 64, height: 64)
                )
            ]),
            framesPerSecond: 12
        )

        #expect(throws: TimelapseExportError.insufficientFrames) {
            try TimelapseExportService.exportVideo(
                from: capture,
                to: URL(fileURLWithPath: "/tmp/timelapse-export-tests")
            )
        }
    }

    @Test
    func exportVideoRejectsOperationCapturesWithFewerThanTwoOperations() {
        let capture = TimelapseCapture(
            canvasSize: CGSize(width: 64, height: 64),
            paperStyle: .default,
            previewImageData: nil,
            source: .operations([.undo]),
            framesPerSecond: 24
        )

        #expect(throws: TimelapseExportError.insufficientFrames) {
            try TimelapseExportService.exportVideo(
                from: capture,
                to: URL(fileURLWithPath: "/tmp/timelapse-export-tests")
            )
        }
    }
}
