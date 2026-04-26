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
            renderState: nil,
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
    func appendedPreviewUsesPreviousPreviewSurfaceForIncrementalBrush() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let baseSnapshot = makeSnapshot(layerIndex: 0, revision: 14)
        let previousHandle = MetalBufferHandle(width: 2, height: 2, bytesPerRow: 8)
        let context = makeContext(layerIndex: 0)
        let previous = stylusSample(x: 2, y: 2)
        let appended = [stylusSample(x: 3, y: 3), stylusSample(x: 4, y: 4)]
        let fullSamples = [stylusSample(x: 0, y: 0), previous] + appended
        let renderState = StrokeSessionRenderState(
            baseRevision: 14,
            layerIndex: 0,
            surfaceHandle: previousHandle,
            dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2),
            isApproximatePreview: false,
            previewBrush: context.previewBrush,
            sampleCount: 2,
            supportsIncrementalContinuation: true
        )

        _ = try #require(useCase.resolveAppended(
            activeStrokeBaseSnapshot: baseSnapshot,
            renderSnapshot: nil,
            renderState: renderState,
            samples: appended,
            fullSamples: fullSamples,
            context: context,
            usesResponsiveOilPreview: false
        ))

        #expect(planner.requests.count == 1)
        #expect(planner.requests[0].baseLayer.gpuHandle?.buffer == previousHandle)
        #expect(planner.requests[0].samples == [previous] + appended)
    }

    @Test
    func appendedPreviewFallsBackWhenIncrementalBrushContextDoesNotMatch() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let baseSnapshot = makeSnapshot(layerIndex: 0, revision: 14)
        let previousHandle = MetalBufferHandle(width: 2, height: 2, bytesPerRow: 8)
        var previousBrush = brushSettings()
        previousBrush.radius = 3
        let context = makeContext(layerIndex: 0)
        let appended = [stylusSample(x: 3, y: 3), stylusSample(x: 4, y: 4)]
        let fullSamples = [stylusSample(x: 0, y: 0), stylusSample(x: 2, y: 2)] + appended
        let renderState = StrokeSessionRenderState(
            baseRevision: 14,
            layerIndex: 0,
            surfaceHandle: previousHandle,
            dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2),
            isApproximatePreview: false,
            previewBrush: previousBrush,
            sampleCount: 2,
            supportsIncrementalContinuation: true
        )

        _ = try #require(useCase.resolveAppended(
            activeStrokeBaseSnapshot: baseSnapshot,
            renderSnapshot: nil,
            renderState: renderState,
            samples: appended,
            fullSamples: fullSamples,
            context: context,
            usesResponsiveOilPreview: false
        ))

        #expect(planner.requests.count == 1)
        #expect(planner.requests[0].baseLayer.gpuHandle?.buffer == baseSnapshot.layers[0].gpuBufferHandle)
        #expect(planner.requests[0].samples == fullSamples)
    }

    @Test
    func appendedPreviewFallsBackWhenLayerIsAlphaLocked() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let baseSnapshot = makeSnapshot(layerIndex: 0, revision: 14)
        let previousHandle = MetalBufferHandle(width: 2, height: 2, bytesPerRow: 8)
        let context = makeContext(layerIndex: 0, isAlphaLocked: true)
        let appended = [stylusSample(x: 3, y: 3), stylusSample(x: 4, y: 4)]
        let fullSamples = [stylusSample(x: 0, y: 0), stylusSample(x: 2, y: 2)] + appended
        let renderState = StrokeSessionRenderState(
            baseRevision: 14,
            layerIndex: 0,
            surfaceHandle: previousHandle,
            dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2),
            isApproximatePreview: false,
            previewBrush: context.previewBrush,
            sampleCount: 2,
            supportsIncrementalContinuation: true
        )

        _ = try #require(useCase.resolveAppended(
            activeStrokeBaseSnapshot: baseSnapshot,
            renderSnapshot: nil,
            renderState: renderState,
            samples: appended,
            fullSamples: fullSamples,
            context: context,
            usesResponsiveOilPreview: false
        ))

        #expect(planner.requests.count == 1)
        #expect(planner.requests[0].baseLayer.gpuHandle?.buffer == baseSnapshot.layers[0].gpuBufferHandle)
        #expect(planner.requests[0].samples == fullSamples)
    }

    @Test
    func responsiveOilAppendedPreviewUsesPreviousPreviewSurfaceAndIncrementalSamples() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let baseSnapshot = makeSnapshot(layerIndex: 0, revision: 14)
        let previousHandle = MetalBufferHandle(width: 2, height: 2, bytesPerRow: 8)
        let renderState = StrokeSessionRenderState(
            baseRevision: 14,
            layerIndex: 0,
            surfaceHandle: previousHandle,
            dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2),
            isApproximatePreview: true
        )
        let previous = stylusSample(x: 2, y: 2)
        let appended = [stylusSample(x: 3, y: 3), stylusSample(x: 4, y: 4)]
        let fullSamples = [stylusSample(x: 0, y: 0), previous] + appended

        _ = try #require(useCase.resolveAppended(
            activeStrokeBaseSnapshot: baseSnapshot,
            renderSnapshot: nil,
            renderState: renderState,
            samples: appended,
            fullSamples: fullSamples,
            context: makeContext(layerIndex: 0),
            usesResponsiveOilPreview: true
        ))

        #expect(planner.requests.count == 1)
        #expect(planner.requests[0].baseLayer.gpuHandle?.buffer == previousHandle)
        #expect(planner.requests[0].samples == [previous] + appended)
        #expect(planner.requests[0].usesResponsiveOilPreview)
    }

    @Test
    func highFidelityOilAppendedPreviewKeepsFullSamples() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let baseSnapshot = makeSnapshot(layerIndex: 0, revision: 14)
        let previousHandle = MetalBufferHandle(width: 2, height: 2, bytesPerRow: 8)
        let renderState = StrokeSessionRenderState(
            baseRevision: 14,
            layerIndex: 0,
            surfaceHandle: previousHandle,
            dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2),
            isApproximatePreview: true
        )
        let appended = [stylusSample(x: 3, y: 3), stylusSample(x: 4, y: 4)]
        let fullSamples = [stylusSample(x: 0, y: 0), stylusSample(x: 2, y: 2)] + appended

        _ = try #require(useCase.resolveAppended(
            activeStrokeBaseSnapshot: baseSnapshot,
            renderSnapshot: nil,
            renderState: renderState,
            samples: appended,
            fullSamples: fullSamples,
            context: makeContext(layerIndex: 0),
            usesResponsiveOilPreview: false
        ))

        #expect(planner.requests.count == 1)
        #expect(planner.requests[0].baseLayer.gpuHandle?.buffer == baseSnapshot.layers[0].gpuBufferHandle)
        #expect(planner.requests[0].samples == fullSamples)
    }

    @Test
    func responsiveOilPreviewRequestSizeDoesNotGrowWithLongCircularStroke() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let baseSnapshot = makeSnapshot(layerIndex: 0, revision: 21)
        var renderState = StrokeSessionRenderState(
            baseRevision: 21,
            layerIndex: 0,
            surfaceHandle: MetalBufferHandle(width: 2, height: 2, bytesPerRow: 8),
            dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2),
            isApproximatePreview: true
        )
        var fullSamples: [StylusSample] = []
        let batchSize = 8

        for index in 0..<128 {
            let appended = (0..<batchSize).map { offset -> StylusSample in
                let sampleIndex = index * batchSize + offset
                let angle = Double(sampleIndex) * 0.08
                return stylusSample(
                    x: CGFloat(cos(angle) + 1),
                    y: CGFloat(sin(angle) + 1)
                )
            }
            fullSamples.append(contentsOf: appended)
            let resolution = try #require(useCase.resolveAppended(
                activeStrokeBaseSnapshot: baseSnapshot,
                renderSnapshot: nil,
                renderState: renderState,
                samples: appended,
                fullSamples: fullSamples,
                context: makeContext(layerIndex: 0),
                usesResponsiveOilPreview: true
            ))
            renderState = StrokeSessionRenderState(
                baseRevision: resolution.result.baseSnapshot.revision,
                layerIndex: resolution.result.surface?.layerIndex ?? 0,
                surfaceHandle: try #require(resolution.result.surface?.handle.buffer),
                dirtyRect: try #require(resolution.result.dirtyRect),
                isApproximatePreview: resolution.result.isApproximatePreview
            )
        }

        #expect(fullSamples.count > 1_000)
        #expect(planner.requests.allSatisfy { $0.samples.count <= batchSize + 1 })
    }

    @Test
    func incrementalPreviewRequestSizeDoesNotGrowWithLongCircularStroke() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let baseSnapshot = makeSnapshot(layerIndex: 0, revision: 21)
        let context = makeContext(layerIndex: 0)
        var renderState = StrokeSessionRenderState(
            baseRevision: 21,
            layerIndex: 0,
            surfaceHandle: MetalBufferHandle(width: 2, height: 2, bytesPerRow: 8),
            dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2),
            isApproximatePreview: false,
            previewBrush: context.previewBrush,
            sampleCount: 0,
            supportsIncrementalContinuation: true
        )
        var fullSamples: [StylusSample] = []
        let batchSize = 8

        for index in 0..<128 {
            let appended = (0..<batchSize).map { offset -> StylusSample in
                let sampleIndex = index * batchSize + offset
                let angle = Double(sampleIndex) * 0.08
                return stylusSample(
                    x: CGFloat(cos(angle) + 1),
                    y: CGFloat(sin(angle) + 1)
                )
            }
            fullSamples.append(contentsOf: appended)
            let resolution = try #require(useCase.resolveAppended(
                activeStrokeBaseSnapshot: baseSnapshot,
                renderSnapshot: nil,
                renderState: renderState,
                samples: appended,
                fullSamples: fullSamples,
                context: context,
                usesResponsiveOilPreview: false
            ))
            renderState = StrokeSessionRenderState(
                baseRevision: resolution.result.baseSnapshot.revision,
                layerIndex: resolution.result.surface?.layerIndex ?? 0,
                surfaceHandle: try #require(resolution.result.surface?.handle.buffer),
                dirtyRect: try #require(resolution.result.dirtyRect),
                isApproximatePreview: resolution.result.isApproximatePreview,
                previewBrush: resolution.previewBrush,
                sampleCount: resolution.sampleCount,
                supportsIncrementalContinuation: resolution.supportsIncrementalContinuation
            )
        }

        #expect(fullSamples.count > 1_000)
        #expect(planner.requests.allSatisfy { $0.samples.count <= batchSize + 1 })
    }

    @Test
    func appendedPreviewCapturesRenderSnapshotWhenNoStrokeBaseExists() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let renderSnapshot = makeSnapshot(layerIndex: 0, revision: 42)

        let resolution = try #require(useCase.resolveAppended(
            activeStrokeBaseSnapshot: nil,
            renderSnapshot: renderSnapshot,
            renderState: nil,
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

        let result = try #require(useCase.makeCommittedSurface(
            snapshot: snapshot,
            samples: [sample],
            context: makeContext(layerIndex: 3, isAlphaLocked: true)
        ))

        #expect(result.surface.layerIndex == 3)
        #expect(result.surface.handle.buffer.width == 2)
        #expect(result.dirtyRegion == GpuSurfaceRegion(originX: 0, originY: 0, width: 2, height: 2))
        #expect(renderer.requests.count == 1)
        #expect(renderer.requests[0].activeLayerIndex == 3)
        #expect(renderer.requests[0].samples == [sample])
        #expect(renderer.requests[0].preserveAlphaLockedPixels)
    }

    @Test
    func strokeSessionTrimsDuplicateSamplesAndTracksPreviewSurface() throws {
        let snapshot = makeSnapshot(layerIndex: 1, revision: 11)
        let handle = MetalBufferHandle(width: 2, height: 2, bytesPerRow: 8)
        var session = StrokeSessionState()

        session.applyPreview(
            baseSnapshot: snapshot,
            surface: GpuLayerSurface(
                layerIndex: 1,
                width: 2,
                height: 2,
                handle: GpuSurfaceHandle(buffer: handle)
            ),
            dirtyRegion: GpuSurfaceRegion(originX: 0, originY: 1, width: 2, height: 1),
            isApproximatePreview: true,
            incrementalUpdate: nil,
            previewBrush: brushSettings(),
            sampleCount: 4,
            supportsIncrementalContinuation: true
        )
        session.markCommittedPointCount(2)

        #expect(session.baseSnapshot?.revision == 11)
        #expect(session.renderState?.surfaceHandle == handle)
        #expect(session.renderState?.dirtyRect == LayerPixelRect(originX: 0, originY: 1, width: 2, height: 1))
        #expect(session.renderState?.isApproximatePreview == true)
        #expect(session.renderState?.sampleCount == 4)
        #expect(session.renderState?.supportsIncrementalContinuation == true)
        #expect(session.hasCommittedPoints)
    }

    @Test
    func strokeSessionResetKeepsCommittedCountSeparateFromPreviewReset() {
        var session = StrokeSessionState(
            baseSnapshot: makeSnapshot(layerIndex: 0),
            committedPointCount: 4
        )

        session.resetPreview()
        #expect(session.baseSnapshot == nil)
        #expect(session.committedPointCount == 4)

        session.resetInteraction()
        #expect(session.committedPointCount == 0)
    }

    @Test
    func strokeSessionUseCaseRerendersExactCommitFromFullSamples() throws {
        let planner = RecordingPreviewPlanner()
        let renderer = RecordingCommitRenderer()
        let useCase = DocumentStrokeSessionUseCase(
            preview: DocumentStrokePreviewUseCase(planner: planner),
            commit: DocumentStrokeCommitUseCase(renderer: renderer),
            resetInteractiveStrokeState: {}
        )
        let snapshot = makeSnapshot(layerIndex: 0)
        let preview = try #require(useCase.execute(
            .begin(
                sample: stylusSample(x: 1, y: 1),
                baseSnapshot: snapshot,
                context: makeContext(layerIndex: 0),
                usesResponsiveOilPreview: false
            )
        ).previewMutation)

        let renderState = StrokeSessionRenderState(
            baseRevision: preview.baseSnapshot.revision,
            layerIndex: preview.surface.layerIndex,
            surfaceHandle: preview.surface.handle.buffer,
            dirtyRect: preview.dirtyRegion.layerPixelRect,
            isApproximatePreview: false
        )
        let commit = try #require(useCase.execute(
            .finish(
                renderState: renderState,
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                samples: [stylusSample(x: 1, y: 1), stylusSample(x: 8, y: 8)],
                context: makeContext(layerIndex: 0),
                allowsApproximatePreviewCommit: false,
                refreshViaDirtyPresentation: true
            )
        ).commitMutation)

        #expect(commit.surface.handle.buffer != preview.surface.handle.buffer)
        #expect(renderer.requests.count == 1)
        #expect(renderer.requests[0].samples == [stylusSample(x: 1, y: 1), stylusSample(x: 8, y: 8)])
    }

    @Test
    func strokeSessionUseCaseCanCommitApproximatePreviewSurface() throws {
        let planner = RecordingPreviewPlanner()
        let renderer = RecordingCommitRenderer()
        let useCase = DocumentStrokeSessionUseCase(
            preview: DocumentStrokePreviewUseCase(planner: planner),
            commit: DocumentStrokeCommitUseCase(renderer: renderer),
            resetInteractiveStrokeState: {}
        )
        let snapshot = makeSnapshot(layerIndex: 0)
        let preview = try #require(useCase.execute(
            .begin(
                sample: stylusSample(x: 1, y: 1),
                baseSnapshot: snapshot,
                context: makeContext(layerIndex: 0),
                usesResponsiveOilPreview: true
            )
        ).previewMutation)

        let renderState = StrokeSessionRenderState(
            baseRevision: preview.baseSnapshot.revision,
            layerIndex: preview.surface.layerIndex,
            surfaceHandle: preview.surface.handle.buffer,
            dirtyRect: preview.dirtyRegion.layerPixelRect,
            isApproximatePreview: true
        )
        let commit = try #require(useCase.execute(
            .finish(
                renderState: renderState,
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                samples: [stylusSample(x: 1, y: 1)],
                context: makeContext(layerIndex: 0),
                allowsApproximatePreviewCommit: true,
                refreshViaDirtyPresentation: true
            )
        ).commitMutation)

        #expect(commit.surface.handle.buffer == preview.surface.handle.buffer)
        #expect(renderer.requests.isEmpty)
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
            surface: GpuLayerSurface(
                layerIndex: request.activeLayerIndex,
                width: request.snapshot.width,
                height: request.snapshot.height,
                handle: GpuSurfaceHandle(buffer: MetalBufferHandle(width: request.snapshot.width, height: request.snapshot.height, bytesPerRow: request.snapshot.width * 4))
            ),
            dirtyRegion: GpuSurfaceRegion(originX: 1, originY: 1, width: 2, height: 2),
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

    func makeCommittedSurface(_ request: StrokeCommitRequest) -> StrokeCommitResult? {
        lock.withLock {
            storage.append(request)
        }
        return StrokeCommitResult(
            surface: GpuLayerSurface(
                layerIndex: request.activeLayerIndex,
                width: request.snapshot.width,
                height: request.snapshot.height,
                handle: GpuSurfaceHandle(buffer: MetalBufferHandle(width: request.snapshot.width, height: request.snapshot.height, bytesPerRow: request.snapshot.width * 4))
            ),
            dirtyRegion: GpuSurfaceRegion(originX: 0, originY: 0, width: request.snapshot.width, height: request.snapshot.height)
        )
    }
}

private extension GpuStrokeSessionOutcome {
    var previewMutation: GpuPreviewMutation? {
        guard case let .preview(mutation) = self else { return nil }
        return mutation
    }

    var commitMutation: GpuCommitMutation? {
        guard case let .commit(mutation) = self else { return nil }
        return mutation
    }
}
