import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
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
            usesResponsivePreview: true
        ))

        #expect(resolution.baseSnapshotToCapture == nil)
        #expect(resolution.result.dirtyRect == LayerPixelRect.unsafeUnchecked(originX: 1, originY: 1, width: 2, height: 2))
        #expect(planner.requests.count == 1)
        #expect(planner.requests[0].activeLayerIndex == 2)
        #expect(planner.requests[0].baseLayer.layerIndex == 2)
        #expect(planner.requests[0].samples == [sample])
        #expect(planner.requests[0].preserveAlphaLockedPixels)
        #expect(planner.requests[0].usesResponsivePreview)
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
            usesResponsivePreview: false
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
        let previousHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let context = makeContext(layerIndex: 0)
        let previous = stylusSample(x: 2, y: 2)
        let appended = [stylusSample(x: 3, y: 3), stylusSample(x: 4, y: 4)]
        let fullSamples = [stylusSample(x: 0, y: 0), previous] + appended
        let renderState = StrokeSessionRenderState(
            baseRevision: 14,
            layerIndex: 0,
            surfaceHandle: previousHandle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
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
            usesResponsivePreview: false
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
        let previousHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        var previousBrush = brushSettings()
        previousBrush.radius = 3
        let context = makeContext(layerIndex: 0)
        let appended = [stylusSample(x: 3, y: 3), stylusSample(x: 4, y: 4)]
        let fullSamples = [stylusSample(x: 0, y: 0), stylusSample(x: 2, y: 2)] + appended
        let renderState = StrokeSessionRenderState(
            baseRevision: 14,
            layerIndex: 0,
            surfaceHandle: previousHandle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
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
            usesResponsivePreview: false
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
        let previousHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let context = makeContext(layerIndex: 0, isAlphaLocked: true)
        let appended = [stylusSample(x: 3, y: 3), stylusSample(x: 4, y: 4)]
        let fullSamples = [stylusSample(x: 0, y: 0), stylusSample(x: 2, y: 2)] + appended
        let renderState = StrokeSessionRenderState(
            baseRevision: 14,
            layerIndex: 0,
            surfaceHandle: previousHandle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
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
            usesResponsivePreview: false
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
        let previousHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let renderState = StrokeSessionRenderState(
            baseRevision: 14,
            layerIndex: 0,
            surfaceHandle: previousHandle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
            isApproximatePreview: false,
            previewBrush: makeContext(layerIndex: 0, brush: oilBrushSettings()).previewBrush,
            sampleCount: 2,
            supportsIncrementalContinuation: true
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
            context: makeContext(layerIndex: 0, brush: oilBrushSettings()),
            usesResponsivePreview: true
        ))

        #expect(planner.requests.count == 1)
        #expect(planner.requests[0].baseLayer.gpuHandle?.buffer == previousHandle)
        #expect(planner.requests[0].samples == [previous] + appended)
        #expect(planner.requests[0].usesResponsivePreview)
    }

    @Test
    func responsiveSmudgeOilAppendedPreviewUsesPreviousPreviewSurfaceAndIncrementalSamples() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let baseSnapshot = makeSnapshot(layerIndex: 0, revision: 14)
        let previousHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let context = makeContext(layerIndex: 0, brush: smudgeBrushSettings())
        let previous = stylusSample(x: 2, y: 2)
        let appended = [stylusSample(x: 3, y: 3), stylusSample(x: 4, y: 4)]
        let fullSamples = [stylusSample(x: 0, y: 0), previous] + appended
        let renderState = StrokeSessionRenderState(
            baseRevision: 14,
            layerIndex: 0,
            surfaceHandle: previousHandle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
            isApproximatePreview: false,
            previewBrush: context.previewBrush,
            sampleCount: 2,
            supportsIncrementalContinuation: false
        )

        let resolution = try #require(useCase.resolveAppended(
            activeStrokeBaseSnapshot: baseSnapshot,
            renderSnapshot: nil,
            renderState: renderState,
            samples: appended,
            fullSamples: fullSamples,
            context: context,
            usesResponsivePreview: true
        ))

        #expect(planner.requests.count == 1)
        #expect(planner.requests[0].baseLayer.gpuHandle?.buffer == previousHandle)
        #expect(planner.requests[0].samples == [previous] + appended)
        #expect(planner.requests[0].usesResponsivePreview)
        #expect(!resolution.result.isApproximatePreview)
        #expect(!resolution.supportsIncrementalContinuation)
    }

    @Test
    func highFidelityOilAppendedPreviewKeepsFullSamples() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let baseSnapshot = makeSnapshot(layerIndex: 0, revision: 14)
        let previousHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let renderState = StrokeSessionRenderState(
            baseRevision: 14,
            layerIndex: 0,
            surfaceHandle: previousHandle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
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
            usesResponsivePreview: false
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
        let context = makeContext(layerIndex: 0, brush: oilBrushSettings())
        var renderState = StrokeSessionRenderState(
            baseRevision: 21,
            layerIndex: 0,
            surfaceHandle: MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8),
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
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
                usesResponsivePreview: true
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
    func responsiveSmudgeOilPreviewRequestSizeDoesNotGrowWithLongCircularStroke() throws {
        let planner = RecordingPreviewPlanner()
        let useCase = DocumentStrokePreviewUseCase(planner: planner)
        let baseSnapshot = makeSnapshot(layerIndex: 0, revision: 21)
        let context = makeContext(layerIndex: 0, brush: smudgeBrushSettings())
        var renderState = StrokeSessionRenderState(
            baseRevision: 21,
            layerIndex: 0,
            surfaceHandle: MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8),
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
            isApproximatePreview: false,
            previewBrush: context.previewBrush,
            sampleCount: 0,
            supportsIncrementalContinuation: false
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
                usesResponsivePreview: true
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
        #expect(planner.requests.allSatisfy { $0.usesResponsivePreview })
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
            surfaceHandle: MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8),
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
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
                usesResponsivePreview: false
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
            usesResponsivePreview: false
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
        let handle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
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
            incrementalUpdate: incrementalUpdate(originX: 0, originY: 1, width: 2, height: 1),
            previewBrush: brushSettings(),
            sampleCount: 4,
            supportsIncrementalContinuation: true
        )
        session.markCommittedPointCount(2)

        #expect(session.baseSnapshot?.revision == 11)
        #expect(session.renderState?.surfaceHandle == handle)
        #expect(session.renderState?.dirtyRect == LayerPixelRect.unsafeUnchecked(originX: 0, originY: 1, width: 2, height: 1))
        #expect(session.renderState?.isApproximatePreview == true)
        #expect(session.renderState?.sampleCount == 4)
        #expect(session.renderState?.supportsIncrementalContinuation == true)
        #expect(session.hasCommittedPoints)
    }

    @Test
    func strokeSessionUnionsPreviewDirtyRectsAcrossIncrementalUpdates() throws {
        let snapshot = makeSnapshot(layerIndex: 1, revision: 11)
        let handle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let brush = brushSettings()
        let surface = GpuLayerSurface(
            layerIndex: 1,
            width: 2,
            height: 2,
            handle: GpuSurfaceHandle(buffer: handle)
        )
        var session = StrokeSessionState()

        session.applyPreview(
            baseSnapshot: snapshot,
            surface: surface,
            dirtyRegion: GpuSurfaceRegion(originX: 0, originY: 0, width: 1, height: 1),
            isApproximatePreview: false,
            incrementalUpdate: incrementalUpdate(originX: 0, originY: 0, width: 1, height: 1),
            previewBrush: brush,
            sampleCount: 1,
            supportsIncrementalContinuation: true
        )
        session.applyPreview(
            baseSnapshot: snapshot,
            surface: surface,
            dirtyRegion: GpuSurfaceRegion(originX: 1, originY: 1, width: 1, height: 1),
            isApproximatePreview: false,
            incrementalUpdate: incrementalUpdate(originX: 1, originY: 1, width: 1, height: 1),
            previewBrush: brush,
            sampleCount: 2,
            supportsIncrementalContinuation: true
        )

        #expect(session.renderState?.dirtyRect == LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2))
    }

    @Test
    func strokeSessionAppliesPreviewWithoutIncrementalUpdate() throws {
        let snapshot = makeSnapshot(layerIndex: 1, revision: 11)
        let handle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        var session = StrokeSessionState()

        session.applyPreview(
            baseSnapshot: snapshot,
            surface: GpuLayerSurface(
                layerIndex: 1,
                width: 2,
                height: 2,
                handle: GpuSurfaceHandle(buffer: handle)
            ),
            dirtyRegion: GpuSurfaceRegion(originX: 0, originY: 0, width: 2, height: 2),
            isApproximatePreview: true,
            incrementalUpdate: nil,
            previewBrush: brushSettings(),
            sampleCount: 1,
            supportsIncrementalContinuation: true
        )

        #expect(session.baseSnapshot == snapshot)
        #expect(session.renderState == StrokeSessionRenderState(
            baseRevision: 11,
            layerIndex: 1,
            surfaceHandle: handle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
            isApproximatePreview: true,
            previewBrush: brushSettings(),
            sampleCount: 1,
            supportsIncrementalContinuation: true
        ))
        #expect(session.pendingIncrementalUpdate == nil)
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
                usesResponsivePreview: false
            )
        ).previewMutation)

        let renderState = StrokeSessionRenderState(
            baseRevision: preview.baseSnapshot.revision,
            layerIndex: preview.surface.layerIndex,
            surfaceHandle: preview.surface.handle.buffer,
            dirtyRect: preview.dirtyRegion.layerPixelRect,
            isApproximatePreview: false,
            previewBrush: makeContext(layerIndex: 0).previewBrush,
            sampleCount: 1,
            supportsIncrementalContinuation: true
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

        #expect(commit.surface.handle.buffer == preview.surface.handle.buffer)
        #expect(renderer.requests.isEmpty)
    }

    @Test
    func strokeSessionUseCaseCommitsExactPreviewSurfaceWhenItMatchesFullStroke() throws {
        let planner = RecordingPreviewPlanner()
        let renderer = RecordingCommitRenderer()
        let useCase = DocumentStrokeSessionUseCase(
            preview: DocumentStrokePreviewUseCase(planner: planner),
            commit: DocumentStrokeCommitUseCase(renderer: renderer),
            resetInteractiveStrokeState: {}
        )
        let snapshot = makeSnapshot(layerIndex: 0)
        let context = makeContext(layerIndex: 0)
        let preview = try #require(useCase.execute(
            .begin(
                sample: stylusSample(x: 1, y: 1),
                baseSnapshot: snapshot,
                context: context,
                usesResponsivePreview: false
            )
        ).previewMutation)

        let renderState = StrokeSessionRenderState(
            baseRevision: preview.baseSnapshot.revision,
            layerIndex: preview.surface.layerIndex,
            surfaceHandle: preview.surface.handle.buffer,
            dirtyRect: preview.dirtyRegion.layerPixelRect,
            isApproximatePreview: false,
            previewBrush: context.previewBrush,
            sampleCount: 1,
            supportsIncrementalContinuation: true
        )
        let commit = try #require(useCase.execute(
            .finish(
                renderState: renderState,
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                samples: [stylusSample(x: 1, y: 1)],
                context: context,
                allowsApproximatePreviewCommit: false,
                refreshViaDirtyPresentation: true
            )
        ).commitMutation)

        #expect(commit.surface.handle.buffer == preview.surface.handle.buffer)
        #expect(commit.surface.pixelData == nil)
        #expect(commit.dirtyRegion == preview.dirtyRegion)
        #expect(renderer.requests.isEmpty)
    }

    @Test
    func testCommitWithMissingMaterializedPixelsDoesNotSilentlySkipPendingSnapshot() throws {
        let planner = RecordingPreviewPlanner()
        let renderer = RecordingCommitRenderer(materializedPixelData: nil)
        let useCase = DocumentStrokeSessionUseCase(
            preview: DocumentStrokePreviewUseCase(planner: planner),
            commit: DocumentStrokeCommitUseCase(renderer: renderer),
            resetInteractiveStrokeState: {}
        )
        let snapshot = makeSnapshot(layerIndex: 0)
        let context = makeContext(layerIndex: 0)
        let preview = try #require(useCase.execute(
            .begin(
                sample: stylusSample(x: 1, y: 1),
                baseSnapshot: snapshot,
                context: context,
                usesResponsivePreview: false
            )
        ).previewMutation)

        let renderState = StrokeSessionRenderState(
            baseRevision: preview.baseSnapshot.revision,
            layerIndex: preview.surface.layerIndex,
            surfaceHandle: preview.surface.handle.buffer,
            dirtyRect: preview.dirtyRegion.layerPixelRect,
            isApproximatePreview: false,
            previewBrush: context.previewBrush,
            sampleCount: 1,
            supportsIncrementalContinuation: true
        )
        let commit = try #require(useCase.execute(
            .finish(
                renderState: renderState,
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                samples: [stylusSample(x: 1, y: 1)],
                context: context,
                allowsApproximatePreviewCommit: false,
                refreshViaDirtyPresentation: true
            )
        ).commitMutation)

        #expect(commit.surface.handle.buffer == preview.surface.handle.buffer)
        #expect(commit.surface.pixelData == nil)
        #expect(renderer.requests.isEmpty)
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
                usesResponsivePreview: false
            )
        ).previewMutation)

        let renderState = StrokeSessionRenderState(
            baseRevision: preview.baseSnapshot.revision,
            layerIndex: preview.surface.layerIndex,
            surfaceHandle: preview.surface.handle.buffer,
            dirtyRect: preview.dirtyRegion.layerPixelRect,
            isApproximatePreview: true,
            previewBrush: makeContext(layerIndex: 0).previewBrush,
            sampleCount: 1,
            supportsIncrementalContinuation: false
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
        #expect(commit.surface.pixelData == nil)
        #expect(renderer.requests.isEmpty)
    }

    @Test
    func strokeSessionUseCaseCommitsResponsiveSmudgePreviewSurfaceWhenSamplesMatch() throws {
        let planner = RecordingPreviewPlanner()
        let renderer = RecordingCommitRenderer()
        let useCase = DocumentStrokeSessionUseCase(
            preview: DocumentStrokePreviewUseCase(planner: planner),
            commit: DocumentStrokeCommitUseCase(renderer: renderer),
            resetInteractiveStrokeState: {}
        )
        let snapshot = makeSnapshot(layerIndex: 0)
        let context = makeContext(layerIndex: 0, brush: smudgeBrushSettings())
        let preview = try #require(useCase.execute(
            .begin(
                sample: stylusSample(x: 1, y: 1),
                baseSnapshot: snapshot,
                context: context,
                usesResponsivePreview: true
            )
        ).previewMutation)

        #expect(!preview.isApproximatePreview)

        let renderState = StrokeSessionRenderState(
            baseRevision: preview.baseSnapshot.revision,
            layerIndex: preview.surface.layerIndex,
            surfaceHandle: preview.surface.handle.buffer,
            dirtyRect: preview.dirtyRegion.layerPixelRect,
            isApproximatePreview: preview.isApproximatePreview,
            previewBrush: context.previewBrush,
            sampleCount: 1,
            supportsIncrementalContinuation: false
        )
        let commit = try #require(useCase.execute(
            .finish(
                renderState: renderState,
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                samples: [stylusSample(x: 1, y: 1)],
                context: context,
                allowsApproximatePreviewCommit: true,
                refreshViaDirtyPresentation: true
            )
        ).commitMutation)

        #expect(commit.surface.handle.buffer == preview.surface.handle.buffer)
        #expect(commit.dirtyRegion == preview.dirtyRegion)
        #expect(commit.surface.pixelData == nil)
        #expect(renderer.requests.isEmpty)
    }

    @Test
    func strokeSessionUseCaseCommitsDisplayedSmudgePreviewWhenSampleCountDiffers() throws {
        let planner = RecordingPreviewPlanner()
        let renderer = RecordingCommitRenderer()
        let useCase = DocumentStrokeSessionUseCase(
            preview: DocumentStrokePreviewUseCase(planner: planner),
            commit: DocumentStrokeCommitUseCase(renderer: renderer),
            resetInteractiveStrokeState: {}
        )
        let snapshot = makeSnapshot(layerIndex: 0)
        let context = makeContext(layerIndex: 0, brush: smudgeBrushSettings())
        let preview = try #require(useCase.execute(
            .begin(
                sample: stylusSample(x: 1, y: 1),
                baseSnapshot: snapshot,
                context: context,
                usesResponsivePreview: true
            )
        ).previewMutation)

        let renderState = StrokeSessionRenderState(
            baseRevision: preview.baseSnapshot.revision,
            layerIndex: preview.surface.layerIndex,
            surfaceHandle: preview.surface.handle.buffer,
            dirtyRect: preview.dirtyRegion.layerPixelRect,
            isApproximatePreview: preview.isApproximatePreview,
            previewBrush: context.previewBrush,
            sampleCount: 1,
            supportsIncrementalContinuation: false
        )
        let finalSamples = [stylusSample(x: 1, y: 1), stylusSample(x: 8, y: 8)]
        let commit = try #require(useCase.execute(
            .finish(
                renderState: renderState,
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                samples: finalSamples,
                context: context,
                allowsApproximatePreviewCommit: true,
                refreshViaDirtyPresentation: true
            )
        ).commitMutation)

        #expect(commit.surface.handle.buffer == preview.surface.handle.buffer)
        #expect(renderer.requests.isEmpty)
    }

    @Test
    func strokeSessionUseCaseCommitsResponsivePreviewSurfaceForNonOilBrush() throws {
        let renderer = RecordingCommitRenderer()
        let useCase = DocumentStrokeSessionUseCase(
            preview: DocumentStrokePreviewUseCase(planner: RecordingPreviewPlanner()),
            commit: DocumentStrokeCommitUseCase(renderer: renderer),
            resetInteractiveStrokeState: {}
        )
        let snapshot = makeSnapshot(layerIndex: 0)
        let context = makeContext(layerIndex: 0, brush: brushSettings())
        let preview = try #require(useCase.execute(
            .begin(
                sample: stylusSample(x: 1, y: 1),
                baseSnapshot: snapshot,
                context: context,
                usesResponsivePreview: true
            )
        ).previewMutation)

        #expect(!preview.isApproximatePreview)

        let renderState = StrokeSessionRenderState(
            baseRevision: preview.baseSnapshot.revision,
            layerIndex: preview.surface.layerIndex,
            surfaceHandle: preview.surface.handle.buffer,
            dirtyRect: preview.dirtyRegion.layerPixelRect,
            isApproximatePreview: preview.isApproximatePreview,
            previewBrush: context.previewBrush,
            sampleCount: 1,
            supportsIncrementalContinuation: false
        )
        let commit = try #require(useCase.execute(
            .finish(
                renderState: renderState,
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                samples: [stylusSample(x: 1, y: 1)],
                context: context,
                allowsApproximatePreviewCommit: true,
                refreshViaDirtyPresentation: true
            )
        ).commitMutation)

        #expect(commit.surface.handle.buffer == preview.surface.handle.buffer)
        #expect(renderer.requests.isEmpty)
    }

    @Test
    func strokeSessionUseCaseCommitsDisplayedResponsivePreviewWhenSampleCountDiffers() throws {
        let renderer = RecordingCommitRenderer()
        let useCase = DocumentStrokeSessionUseCase(
            preview: DocumentStrokePreviewUseCase(planner: RecordingPreviewPlanner()),
            commit: DocumentStrokeCommitUseCase(renderer: renderer),
            resetInteractiveStrokeState: {}
        )
        let snapshot = makeSnapshot(layerIndex: 0)
        let context = makeContext(layerIndex: 0, brush: brushSettings())
        let preview = try #require(useCase.execute(
            .begin(
                sample: stylusSample(x: 1, y: 1),
                baseSnapshot: snapshot,
                context: context,
                usesResponsivePreview: true
            )
        ).previewMutation)

        let renderState = StrokeSessionRenderState(
            baseRevision: preview.baseSnapshot.revision,
            layerIndex: preview.surface.layerIndex,
            surfaceHandle: preview.surface.handle.buffer,
            dirtyRect: preview.dirtyRegion.layerPixelRect,
            isApproximatePreview: preview.isApproximatePreview,
            previewBrush: context.previewBrush,
            sampleCount: 1,
            supportsIncrementalContinuation: false
        )
        let finalSamples = [stylusSample(x: 1, y: 1), stylusSample(x: 8, y: 8)]
        let commit = try #require(useCase.execute(
            .finish(
                renderState: renderState,
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                samples: finalSamples,
                context: context,
                allowsApproximatePreviewCommit: true,
                refreshViaDirtyPresentation: true
            )
        ).commitMutation)

        #expect(commit.surface.handle.buffer == preview.surface.handle.buffer)
        #expect(renderer.requests.isEmpty)
    }

    @Test
    func strokeSessionUseCaseCommitsWithPreviewBrushWhenCurrentBrushChangesBeforeFinish() throws {
        let renderer = RecordingCommitRenderer()
        let useCase = DocumentStrokeSessionUseCase(
            preview: DocumentStrokePreviewUseCase(planner: RecordingPreviewPlanner()),
            commit: DocumentStrokeCommitUseCase(renderer: renderer),
            resetInteractiveStrokeState: {}
        )
        let snapshot = makeSnapshot(layerIndex: 0)
        var eraserBrush = brushSettings()
        eraserBrush.isEraser = true
        eraserBrush.red = 255
        eraserBrush.green = 255
        eraserBrush.blue = 255
        var currentBrush = brushSettings()
        currentBrush.isEraser = false
        currentBrush.red = 255
        currentBrush.green = 0
        currentBrush.blue = 0
        let changedContext = makeContext(layerIndex: 0, brush: currentBrush)
        let finalSamples = [stylusSample(x: 1, y: 1), stylusSample(x: 8, y: 8)]

        let previewHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let commit = try #require(useCase.execute(
            .finish(
                renderState: StrokeSessionRenderState(
                    baseRevision: snapshot.revision,
                    layerIndex: 0,
                    surfaceHandle: previewHandle,
                    dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
                    isApproximatePreview: false,
                    previewBrush: eraserBrush,
                    sampleCount: 1,
                    supportsIncrementalContinuation: true
                ),
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                samples: finalSamples,
                context: changedContext,
                allowsApproximatePreviewCommit: false,
                refreshViaDirtyPresentation: true
            )
        ).commitMutation)

        #expect(commit.surface.handle.buffer == previewHandle)
        #expect(renderer.requests.isEmpty)
    }

    @Test
    func commitUseCaseUsesFullBrushRatherThanPreviewBrush() throws {
        let renderer = RecordingCommitRenderer()
        let useCase = DocumentStrokeCommitUseCase(renderer: renderer)
        let snapshot = makeSnapshot(layerIndex: 0)
        let brush = smudgeBrushSettings()
        var previewBrush = brush
        previewBrush.smudgeEngineEnabled = false
        let context = DocumentStrokeContext(
            activeLayer: makeContext(layerIndex: 0).activeLayer,
            activeLayerIndex: 0,
            brush: brush,
            previewBrush: previewBrush
        )

        _ = try #require(useCase.makeCommittedSurface(
            snapshot: snapshot,
            samples: [stylusSample(x: 1, y: 1)],
            context: context
        ))

        #expect(renderer.requests.count == 1)
        #expect(renderer.requests[0].brush.smudgeEngineEnabled)
    }

    @Test
    func smudgeBrushUsesGpuOnlyResponsivePreviewButNotExactContinuation() {
        let brush = smudgeBrushSettings()

        #expect(StrokePreviewContinuationPolicy.shouldUseGpuOnlyResponsivePreview(for: brush))
        #expect(!StrokePreviewContinuationPolicy.shouldUseIncrementalPreviewUpdate(for: brush))
    }

    @Test
    func approximateSmudgePreviewCommitsDisplayedPreviewSurface() throws {
        let renderer = RecordingCommitRenderer()
        let useCase = DocumentStrokeSessionUseCase(
            preview: DocumentStrokePreviewUseCase(planner: RecordingPreviewPlanner()),
            commit: DocumentStrokeCommitUseCase(renderer: renderer),
            resetInteractiveStrokeState: {}
        )
        let snapshot = makeSnapshot(layerIndex: 0)
        let brush = smudgeBrushSettings()
        let context = makeContext(layerIndex: 0, brush: brush)
        let previewHandle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let samples = [stylusSample(x: 1, y: 1), stylusSample(x: 8, y: 8)]

        let commit = try #require(useCase.execute(
            .finish(
                renderState: StrokeSessionRenderState(
                    baseRevision: snapshot.revision,
                    layerIndex: 0,
                    surfaceHandle: previewHandle,
                    dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
                    isApproximatePreview: true,
                    previewBrush: brush,
                    sampleCount: samples.count,
                    supportsIncrementalContinuation: false
                ),
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                samples: samples,
                context: context,
                allowsApproximatePreviewCommit: true,
                refreshViaDirtyPresentation: true
            )
        ).commitMutation)

        #expect(commit.surface.handle.buffer == previewHandle)
        #expect(renderer.requests.isEmpty)
    }

    @Test
    func commitWorkflowReusesMatchingPreviewAndStagesPendingSnapshot() throws {
        let renderer = RecordingCommitRenderer()
        let snapshot = makeSnapshot(layerIndex: 0)
        let handle = MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8)
        let appliedPayloads = LockedValues<GpuLayerMutationPayload>()
        let service = DocumentStrokeCommitWorkflowService(
            layerCommands: layerCommands(
                applyLayerSurfaceMutation: { _, payload in
                    appliedPayloads.append(payload)
                    return .success(())
                }
            ),
            strokeInteraction: CanvasStrokeInteractionService(
                sessionUseCase: DocumentStrokeSessionUseCase(
                    preview: DocumentStrokePreviewUseCase(planner: RecordingPreviewPlanner()),
                    commit: DocumentStrokeCommitUseCase(renderer: renderer),
                    resetInteractiveStrokeState: {}
                )
            )
        )

        let result: StrokeCommitWorkflowResult<Int, String> = try service.resolveCommit(
            StrokeCommitWorkflowRequest(
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                renderState: StrokeSessionRenderState(
                    baseRevision: snapshot.revision,
                    layerIndex: 0,
                    surfaceHandle: handle,
                    dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 2, height: 2),
                    isApproximatePreview: false,
                    previewBrush: brushSettings(),
                    sampleCount: 1,
                    supportsIncrementalContinuation: true
                ),
                samples: [stylusSample(x: 1, y: 1)],
                context: makeContext(layerIndex: 0),
                selectionClearPolicy: .none,
                refreshViaDirtyPresentation: true
            ),
            usesResponsivePreviewCommit: false
        ).get()

        #expect(renderer.requests.isEmpty)
        #expect(appliedPayloads.values.count == 1)
        #expect(appliedPayloads.values[0].gpuBufferHandle == handle)
        #expect(result.contract.refresh == .dirty)
        #expect(result.transferredSurfaceHandle == handle)
        #expect(result.pendingCommittedSnapshot?.baseSnapshot == snapshot)
    }

    @Test
    func commitWorkflowFallsBackToRenderedCommitWhenPreviewDoesNotMatch() throws {
        let renderer = RecordingCommitRenderer()
        let snapshot = makeSnapshot(layerIndex: 0)
        let service = DocumentStrokeCommitWorkflowService(
            layerCommands: layerCommands(),
            strokeInteraction: CanvasStrokeInteractionService(
                sessionUseCase: DocumentStrokeSessionUseCase(
                    preview: DocumentStrokePreviewUseCase(planner: RecordingPreviewPlanner()),
                    commit: DocumentStrokeCommitUseCase(renderer: renderer),
                    resetInteractiveStrokeState: {}
                )
            )
        )

        let result: StrokeCommitWorkflowResult<Int, String> = try service.resolveCommit(
            StrokeCommitWorkflowRequest(
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                renderState: nil,
                samples: [stylusSample(x: 1, y: 1), stylusSample(x: 2, y: 2)],
                context: makeContext(layerIndex: 0),
                selectionClearPolicy: .none,
                refreshViaDirtyPresentation: false
            ),
            usesResponsivePreviewCommit: false
        ).get()

        #expect(renderer.requests.count == 1)
        #expect(renderer.requests[0].samples.count == 2)
        #expect(result.contract.refresh == .current)
        #expect(result.pendingCommittedSnapshot?.baseSnapshot == snapshot)
    }

    @Test
    func commitWorkflowSelectionClearEnsuresLayerAndMarksContract() throws {
        let ensuredLayerIndexes = LockedValues<Int>()
        let snapshot = makeSnapshot(layerIndex: 0)
        let service = DocumentStrokeCommitWorkflowService(
            layerCommands: layerCommands(
                ensureLayerVisible: { index in
                    ensuredLayerIndexes.append(index)
                    return .success(())
                }
            ),
            strokeInteraction: CanvasStrokeInteractionService(
                sessionUseCase: DocumentStrokeSessionUseCase(
                    preview: DocumentStrokePreviewUseCase(planner: RecordingPreviewPlanner()),
                    commit: DocumentStrokeCommitUseCase(renderer: RecordingCommitRenderer()),
                    resetInteractiveStrokeState: {}
                )
            )
        )

        let result: StrokeCommitWorkflowResult<Int, String> = try service.resolveCommit(
            StrokeCommitWorkflowRequest(
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                renderState: nil,
                samples: [stylusSample(x: 1, y: 1)],
                context: makeContext(layerIndex: 0),
                selectionClearPolicy: .clearSelection,
                refreshViaDirtyPresentation: true
            ),
            usesResponsivePreviewCommit: false
        ).get()

        #expect(ensuredLayerIndexes.values == [0])
        #expect(result.contract.canvasMutation == .clearSelection)
    }

    @Test
    func commitWorkflowPropagatesSurfaceMutationFailure() throws {
        let snapshot = makeSnapshot(layerIndex: 0)
        let service = DocumentStrokeCommitWorkflowService(
            layerCommands: layerCommands(
                applyLayerSurfaceMutation: { _, _ in .failure(.alphaLocked(0)) }
            ),
            strokeInteraction: CanvasStrokeInteractionService(
                sessionUseCase: DocumentStrokeSessionUseCase(
                    preview: DocumentStrokePreviewUseCase(planner: RecordingPreviewPlanner()),
                    commit: DocumentStrokeCommitUseCase(renderer: RecordingCommitRenderer()),
                    resetInteractiveStrokeState: {}
                )
            )
        )

        let result: Result<StrokeCommitWorkflowResult<Int, String>, DocumentMutationFailure> = service.resolveCommit(
            StrokeCommitWorkflowRequest(
                baseSnapshot: snapshot,
                renderSnapshot: nil,
                renderState: nil,
                samples: [stylusSample(x: 1, y: 1)],
                context: makeContext(layerIndex: 0),
                selectionClearPolicy: .none,
                refreshViaDirtyPresentation: true
            ),
            usesResponsivePreviewCommit: false
        )

        #expect(result.failure == .alphaLocked(0))
    }

    private func makeSnapshot(layerIndex: Int, revision: Int = 7) -> MetalDocumentSnapshot {
        MetalDocumentSnapshot.unsafeUnchecked(
            width: 2,
            height: 2,
            revision: revision,
            compositePixelData: Data(repeating: 1, count: 16),
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: layerIndex,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    gpuBufferHandle: MetalBufferHandle.unsafeUnchecked(width: 2, height: 2, bytesPerRow: 8),
                    pixelData: Data(repeating: 2, count: 16)
                )
            ]
        )
    }

    private func makeContext(
        layerIndex: Int,
        isAlphaLocked: Bool = false,
        brush: BrushRuntimeSettings? = nil
    ) -> DocumentStrokeContext {
        let brush = brush ?? brushSettings()
        return DocumentStrokeContext(
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
            brush: brush,
            previewBrush: brush
        )
    }

    private func stylusSample(x: CGFloat, y: CGFloat) -> StylusSample {
        StylusSample(point: CGPoint(x: x, y: y), pressure: 1, altitude: 0.5, azimuth: 0.25, timestamp: TimeInterval(x + y))
    }

    private func incrementalUpdate(originX: Int, originY: Int, width: Int, height: Int) -> IncrementalLayerUpdate {
        IncrementalLayerUpdate.unsafeUnchecked(
            layerIndex: -1,
            originX: originX,
            originY: originY,
            width: width,
            height: height,
            pixelData: Data(repeating: 0, count: width * height * 4)
        )
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

    private func oilBrushSettings() -> BrushRuntimeSettings {
        var brush = smudgeBrushSettings()
        brush.smudgeEngineEnabled = false
        brush.paintLoad = 0.92
        brush.smudgeRadius = 0.36
        return brush
    }

    private func smudgeBrushSettings() -> BrushRuntimeSettings {
        BrushRuntimeSettings(
            tipKind: .oil,
            radius: 10,
            opacity: 0.82,
            hardness: 0.36,
            roundness: 0.96,
            angle: 0,
            angleMode: .fixed,
            stampSpacing: 0.10,
            spacingJitter: 0,
            scatterLateral: 0,
            scatterLinear: 0,
            count: 1,
            countJitter: 0,
            angleJitter: 0,
            roundnessJitter: 0,
            textureMode: .strokeLocked,
            textureStrength: 0.10,
            flow: 0.82,
            wetness: 0.20,
            colorMixStrength: 0.24,
            paintLoad: 0.08,
            smudgeEngineEnabled: true,
            smudgeMode: .smearing,
            smudgeLength: 0.32,
            colorRate: 0.08,
            pressureSensitivity: 0.12,
            red: 46,
            green: 47,
            blue: 50
        )
    }

    private func layerCommands(
        ensureLayerVisible: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .success(()) },
        applyLayerSurfaceMutation: @escaping @Sendable (Int, GpuLayerMutationPayload) -> DocumentMutationResult = { _, _ in .success(()) }
    ) -> DocumentLayerCommandService {
        DocumentLayerCommandService(
            ensureLayerVisible: ensureLayerVisible,
            replaceLayerPixels: { _, _ in .success(()) },
            replaceLayerPixelsInRect: { _, _, _ in .success(()) },
            applyLayerSurfaceMutation: applyLayerSurfaceMutation,
            applyLayerMutation: { _, _ in .success(()) },
            applyTextLayerMutation: { _, _, _ in .success(()) },
            revealLayerForEditing: { _ in .success(()) }
        )
    }
}

private extension Result where Failure == DocumentMutationFailure {
    var failure: DocumentMutationFailure? {
        guard case let .failure(failure) = self else { return nil }
        return failure
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
                handle: GpuSurfaceHandle(buffer: MetalBufferHandle.unsafeUnchecked(width: request.snapshot.width, height: request.snapshot.height, bytesPerRow: request.snapshot.width * 4))
            ),
            dirtyRegion: GpuSurfaceRegion(originX: 1, originY: 1, width: 2, height: 2),
            incrementalUpdate: nil,
            isApproximatePreview: false
        )
    }
}

private final class LockedValues<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []

    var values: [Value] {
        lock.withLock { storage }
    }

    func append(_ value: Value) {
        lock.withLock {
            storage.append(value)
        }
    }
}

private final class RecordingCommitRenderer: StrokeCommitRendering, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [StrokeCommitRequest] = []
    private let materializedPixelData: Data?

    init(materializedPixelData: Data? = Data(repeating: 0x7F, count: 16)) {
        self.materializedPixelData = materializedPixelData
    }

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
                handle: GpuSurfaceHandle(buffer: MetalBufferHandle.unsafeUnchecked(width: request.snapshot.width, height: request.snapshot.height, bytesPerRow: request.snapshot.width * 4))
            ),
            dirtyRegion: GpuSurfaceRegion(originX: 0, originY: 0, width: request.snapshot.width, height: request.snapshot.height)
        )
    }

    func materializedPixelData(for surface: GpuLayerSurface) -> Data? {
        materializedPixelData
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

    var failure: DocumentMutationFailure? {
        guard case let .failure(failure) = self else { return nil }
        return failure
    }
}
