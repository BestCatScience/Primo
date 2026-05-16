import CoreGraphics
import CoreVideo
import Foundation
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import Testing
@testable import PrimoDocumentEngineInfrastructure
import PrimoDocumentRuntimeLive

struct TimelapseExportServiceTests {
    @Test
    func timelapseReplayServiceUsesInjectedGpuServicesForCompositeSurface() {
        let surface = DocumentCompositeSurface(
            unsafeUncheckedWidth: 2,
            height: 2,
            pixelData: Data(repeating: 0x7f, count: 16)
        )
        let gpuServices = RecordingTimelapseGpuServices(surface: surface)
        let replayService = DocumentTimelapseReplayService(
            canvasSize: CGSize(width: 2, height: 2),
            gpuServices: gpuServices.services()
        )
        let callsBeforeReplay = gpuServices.compositeSurfaceCallCount

        let replayedSurface = replayService.replaySurface(.setPaperStyle(.default))

        #expect(replayedSurface == surface)
        #expect(gpuServices.compositeSurfaceCallCount > callsBeforeReplay)
    }

    @Test
    func timelapseReplayConstructionRequiresInjectedGpuServices() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let engineLiveURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift"
        )
        let exportServiceURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/TimelapseExportService.swift"
        )
        let engineLive = try String(contentsOf: engineLiveURL, encoding: .utf8)
        let exportService = try String(contentsOf: exportServiceURL, encoding: .utf8)

        #expect(engineLive.contains("package final class DocumentTimelapseReplayService"))
        #expect(engineLive.contains("init(\n        canvasSize: CGSize,"))
        #expect(engineLive.contains("gpuServices: DocumentRuntimeGpuServices"))
        #expect(!engineLive.contains("public convenience init(\n        canvasSize: CGSize,"))
        #expect(engineLive.contains("gpuServices: gpuServices"))
        #expect(exportService.contains("gpuServices: DocumentRuntimeGpuServicesFactory.live()"))
        #expect(exportService.contains("gpuServices: DocumentRuntimeGpuServices"))
        #expect(exportService.contains("gpuServices: gpuServices"))
    }

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
            unsafeUncheckedWidth: 3,
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

private final class RecordingTimelapseGpuServices: @unchecked Sendable {
    private let lock = NSLock()
    private let surface: DocumentCompositeSurface
    private var compositeSurfaceCalls = 0

    init(surface: DocumentCompositeSurface) {
        self.surface = surface
    }

    var compositeSurfaceCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return compositeSurfaceCalls
    }

    func services() -> DocumentRuntimeGpuServices {
        DocumentRuntimeGpuServices(
            release: { _ in },
            retain: { _ in false },
            _materializedPixelData: { _ in nil },
            _scaledPixelData: { data, _, _, _, _ in data },
            _scaledMaskData: { data, _, _, _, _ in data },
            _translatedPixelData: { data, _, _, _, _, _, _ in data },
            _translatedMaskData: { data, _, _, _, _, _, _ in data },
            _applyLayerMask: { pixelData, _, _, _ in pixelData },
            _processLayer: { _, _, _, _ in nil },
            _mergeLayers: { lower, _, _, _, _, _, _ in lower },
            _rasterizeTextLayer: { _, _ in nil },
            _blurPixels: { _, _, _, _, _, _ in nil },
            _fillPixels: { _, _, _, _, _, _ in nil },
            _commitStrokeMutation: { _, _, _, _, _, _, _, _ in nil },
            _preservingExistingAlphaBufferHandle: { sourceHandle, _, _, _, _ in sourceHandle },
            _compositedPaperPreviewRGBA: { pixelData, _, _, _ in pixelData },
            _compositedIncrementalUpdate: { _, _ in nil },
            _compositeDocumentSurface: { _ in
                self.lock.lock()
                self.compositeSurfaceCalls += 1
                self.lock.unlock()
                return self.surface
            },
            _compositeDocumentBufferHandle: { _ in nil }
        )
    }
}
