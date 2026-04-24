import CoreGraphics
import CoreVideo
import Foundation
import PrimoDocumentContracts
import Testing
@testable import PrimoDocumentEngineInfrastructure

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

    @Test
    func writeSurfaceCopiesRowsIntoPixelBufferWithLargerStride() throws {
        let surface = DocumentCompositeSurface(
            width: 3,
            height: 2,
            pixelData: Data([
                1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
                13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24
            ])
        )

        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: 3,
            kCVPixelBufferHeightKey as String: 2,
            kCVPixelBufferBytesPerRowAlignmentKey as String: 64
        ]
        let status = CVPixelBufferCreate(
            nil,
            3,
            2,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        #expect(status == kCVReturnSuccess)
        guard let pixelBuffer else {
            Issue.record("Expected pixel buffer")
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let wrote = TimelapseExportService.writeSurface(
            surface,
            into: pixelBuffer,
            targetSize: CGSize(width: 3, height: 2)
        )

        #expect(wrote)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        #expect(bytesPerRow >= 12)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            Issue.record("Expected base address")
            return
        }
        let byteView = baseAddress.assumingMemoryBound(to: UInt8.self)
        let firstRow = Array(UnsafeBufferPointer(start: byteView, count: 12))
        let secondRow = Array(UnsafeBufferPointer(start: byteView.advanced(by: bytesPerRow), count: 12))
        #expect(firstRow == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        #expect(secondRow == [13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24])
    }
}
