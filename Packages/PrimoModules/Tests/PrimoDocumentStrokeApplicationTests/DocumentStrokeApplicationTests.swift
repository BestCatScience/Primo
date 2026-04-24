import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentStrokeApplication
import Testing

@Suite
struct DocumentStrokeApplicationTests {
    @Test
    func initialPreviewBuildsContractRequestFromBaseSnapshot() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let snapshot = makeSnapshot(layerIndex: 2)
        let sample = stylusSample(x: 4, y: 5)
        let context = makeContext(layerIndex: 2, isAlphaLocked: true)

        let resolution = try #require(useCase.resolveInitial(
            baseSnapshot: snapshot,
            sample: sample,
            context: context,
            usesResponsiveOilPreview: true
        ))

        #expect(resolution.baseSnapshotToCapture == nil)
        #expect(resolution.result.dirtyRect == LayerPixelRect(originX: 1, originY: 1, width: 2, height: 2))
        #expect(planner.requests.count == 1)
        #expect(planner.requests[0].activeLayerIndex == 2)
        #expect(planner.requests[0].baseLayer.layerIndex == 2)
        #expect(planner.requests[0].samples == [sample])
        #expect(planner.requests[0].preserveAlphaLockedPixels)
        #expect(planner.requests[0].usesResponsiveOilPreview)
    }

    @Test
    func appendedPreviewUsesActiveBaseSnapshotAndFullSamples() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let baseSnapshot = makeSnapshot(layerIndex: 0)
        let renderSnapshot = makeSnapshot(layerIndex: 0, revision: 99)
        let samples = [stylusSample(x: 1, y: 1)]
        let fullSamples = [stylusSample(x: 1, y: 1), stylusSample(x: 8, y: 8)]

        let resolution = try #require(useCase.resolveAppended(
            activeStrokeBaseSnapshot: baseSnapshot,
            renderSnapshot: renderSnapshot,
            samples: samples,
            fullSamples: fullSamples,
            context: makeContext(layerIndex: 0),
            usesResponsiveOilPreview: false
        ))

        #expect(resolution.baseSnapshotToCapture == nil)
        #expect(planner.requests.count == 1)
        #expect(planner.requests[0].snapshot.revision == baseSnapshot.revision)
        #expect(planner.requests[0].samples == fullSamples)
    }

    @Test
    func appendedPreviewCapturesRenderSnapshotWhenNoStrokeBaseExists() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let renderSnapshot = makeSnapshot(layerIndex: 0, revision: 42)

        let resolution = try #require(useCase.resolveAppended(
            activeStrokeBaseSnapshot: nil,
            renderSnapshot: renderSnapshot,
            samples: [stylusSample(x: 1, y: 1)],
            fullSamples: [],
            context: makeContext(layerIndex: 0),
            usesResponsiveOilPreview: false
        ))

        #expect(resolution.baseSnapshotToCapture == renderSnapshot)
        #expect(planner.requests[0].snapshot.revision == 42)
    }

    @Test
    func commitUseCaseDelegatesToRendererContract() throws {
        let renderer = RecordingCommitRenderer()
        let useCase = DocumentStrokeCommitUseCase(renderer: renderer)
        let snapshot = makeSnapshot(layerIndex: 3)
        let sample = stylusSample(x: 10, y: 11)

        let result = try #require(useCase.makeCommittedPixels(
            snapshot: snapshot,
            samples: [sample],
            context: makeContext(layerIndex: 3, isAlphaLocked: true)
        ))

        #expect(result.committedPixels == Data([9, 8, 7, 6]))
        #expect(renderer.requests.count == 1)
        #expect(renderer.requests[0].activeLayerIndex == 3)
        #expect(renderer.requests[0].samples == [sample])
        #expect(renderer.requests[0].preserveAlphaLockedPixels)
    }

    private func makeSnapshot(layerIndex: Int, revision: Int = 7) -> MetalDocumentSnapshot {
        MetalDocumentSnapshot(
            width: 2,
            height: 2,
            revision: revision,
            compositePixelData: Data(repeating: 1, count: 16),
            layers: [
                MetalLayerSnapshot(
                    index: layerIndex,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    gpuBufferHandle: MetalBufferHandle(width: 2, height: 2, bytesPerRow: 8),
                    pixelData: Data(repeating: 2, count: 16)
                )
            ]
        )
    }

    private func makeContext(layerIndex: Int, isAlphaLocked: Bool = false) -> DocumentStrokeContext {
        DocumentStrokeContext(
            activeLayer: LayerRowModel(
                index: layerIndex,
                name: "Layer",
                visible: true,
                opacity: 1,
                isLocked: false,
                isAlphaLocked: isAlphaLocked,
                isClipped: false,
                blendMode: .normal,
                folderID: nil,
                hasMask: false,
                isTextLayer: false,
                textLayer: nil
            ),
            activeLayerIndex: layerIndex,
            brush: brushSettings(),
            previewBrush: brushSettings()
        )
    }

    private func stylusSample(x: CGFloat, y: CGFloat) -> StylusSample {
        StylusSample(point: CGPoint(x: x, y: y), pressure: 1, altitude: 0.5, azimuth: 0.25, timestamp: TimeInterval(x + y))
    }

    private func brushSettings() -> BrushRuntimeSettings {
        BrushRuntimeSettings(
            tipKind: .ink,
            radius: 8,
            opacity: 1,
            hardness: 1,
            roundness: 1,
            angle: 0,
            angleMode: .fixed,
            stampSpacing: 0.1,
            spacingJitter: 0,
            scatterLateral: 0,
            scatterLinear: 0,
            count: 1,
            countJitter: 0,
            angleJitter: 0,
            roundnessJitter: 0,
            textureMode: .off,
            textureStrength: 0,
            pressureSensitivity: 1,
            red: 255,
            green: 255,
            blue: 255
        )
    }
}

private final class RecordingPreviewPlanner: StrokePreviewPlanning, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [StrokePreviewRequest] = []

    var requests: [StrokePreviewRequest] {
        lock.withLock { storage }
    }

    func makePreview(_ request: StrokePreviewRequest) -> StrokePreviewResult? {
        lock.withLock {
            storage.append(request)
        }
        return StrokePreviewResult(
            baseSnapshot: request.snapshot,
            adjustedPixels: Data([1, 2, 3, 4]),
            dirtyRect: LayerPixelRect(originX: 1, originY: 1, width: 2, height: 2),
            rectPixelData: Data([5, 6, 7, 8]),
            incrementalUpdate: nil,
            isApproximatePreview: request.usesResponsiveOilPreview
        )
    }
}

private final class RecordingCommitRenderer: StrokeCommitRendering, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [StrokeCommitRequest] = []

    var requests: [StrokeCommitRequest] {
        lock.withLock { storage }
    }

    func makeCommittedPixels(_ request: StrokeCommitRequest) -> StrokeCommitResult? {
        lock.withLock {
            storage.append(request)
        }
        return StrokeCommitResult(committedPixels: Data([9, 8, 7, 6]))
    }
}
