import Foundation
import ComposableArchitecture
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentEngineInfrastructure
import PrimoDocumentGPUContracts
import PrimoDocumentRenderingInfrastructure
import PrimoDocumentStrokeApplication
import XCTest
@testable import Primo

@MainActor
final class CanvasStrokeWorkflowTests: XCTestCase {
    private func makeStrokeSessionCoordinator(
        layerCommands: DocumentLayerCommandService = DocumentLayerCommandService(mutationGateway: .stub()),
        strokeInteraction: CanvasStrokeInteractionService
    ) -> DocumentFeature.CanvasStrokeSessionCoordinator {
        DocumentFeature.CanvasStrokeSessionCoordinator(
            layerCommands: layerCommands,
            strokeInteraction: strokeInteraction,
            commitWorkflow: DocumentStrokeCommitWorkflowService(
                layerCommands: layerCommands,
                strokeInteraction: strokeInteraction
            )
        )
    }

    func testDocumentGpuGatewayOverrideRefreshesDerivedGpuDependencies() {
        let oldGateway = markedGateway(1)
        let newGateway = markedGateway(9)

        let outputs = withDependencies {
            $0.documentRuntimeComposition = .stub(gpuOperationGateway: oldGateway)
            let oldPreviewRenderer = GpuCanvasPreviewRenderer(gpuOperations: oldGateway)
            let oldLayerTransformProcessor = GpuLayerTransformProcessor(gpuOperations: oldGateway)
            $0.canvasPreviewRenderer = oldPreviewRenderer
            $0.selectionMaskProcessor = oldPreviewRenderer
            $0.layerTransformProcessor = oldLayerTransformProcessor
            $0.canvasPresentationEnvironment = CanvasPresentationEnvironment(
                previewRenderer: oldPreviewRenderer,
                eyedropperSampler: $0.canvasEyedropperSampler,
                selectionProcessor: oldPreviewRenderer,
                layerTransformProcessor: oldLayerTransformProcessor
            )

            $0.documentGpuOperationGateway = newGateway
        } operation: {
            DerivedGpuDependencyProbe().outputs()
        }

        XCTAssertEqual(outputs, [
            Data([9]),
            Data(repeating: 9, count: 4),
            Data([9]),
            Data([9]),
            Data(repeating: 9, count: 4),
            Data([9]),
        ])
    }

    func testPrepareCanvasStrokeEditingReturnsTypedFailure() {
        let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: DocumentLayerCommandService(
                mutationGateway: .stub(
                    setLayerVisibility: { _, _ in .failure(.layerLocked(0)) }
                )
            ),
            strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
        )
        var state = DocumentEditingState()
        let result = coordinator.prepareEditing(
            state: &state,
            clearSelectionWithoutRefresh: { _ in }
        )

        switch result {
        case .success:
            XCTFail("Expected layer locked failure")
        case let .failure(failure):
            XCTAssertEqual(failure, .layerLocked(0))
        }
    }

    func testGpuStrokeCommitSurfacesSessionFailure() {
        let coordinator = makeStrokeSessionCoordinator(
            strokeInteraction: CanvasStrokeInteractionService(
                sessionUseCase: .stub { _ in
                    .failure(.bridgeMutationFailed("GPU stroke commit failed: missing base snapshot"))
                }
            )
        )
        var state = DocumentEditingState()
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
        let result = coordinator.resolveStrokeCommit(
            state: &state,
            samples: [.testValue()],
            context: DocumentCanvasStrokeContext(
                activeLayer: .testValue(),
                activeLayerIndex: 0,
                brush: brush,
                previewBrush: brush
            ),
            keepsSelectionCleared: false,
            refreshViaDirtyPresentation: false
        )

        switch result {
        case .committed:
            XCTFail("Expected GPU stroke commit failure")
        case let .failed(failure):
            XCTAssertEqual(failure, .bridgeMutationFailed("GPU stroke commit failed: missing base snapshot"))
        }
    }

    func testPreviewOutcomeAppliesGpuRenderState() {
        let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
            strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
        )
        var state = DocumentEditingState()
        let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 4,
            height: 4,
            revision: 12,
            compositePixelData: Data(repeating: 0, count: 64),
            layers: []
        )
        let handle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)

        coordinator.applyPreviewMutation(
            GpuPreviewMutation(
                baseSnapshot: snapshot,
                surface: GpuLayerSurface(
                    layerIndex: 0,
                    width: 4,
                    height: 4,
                    handle: GpuSurfaceHandle(buffer: handle)
                ),
                dirtyRegion: GpuSurfaceRegion(originX: 1, originY: 1, width: 2, height: 2),
                incrementalUpdate: nil,
                isApproximatePreview: true
            ),
            state: &state,
            releaseSurfaceHandle: { _ in }
        )

        XCTAssertEqual(state.canvas.strokeSession.baseSnapshot?.revision, 12)
        XCTAssertEqual(state.canvas.strokeSession.renderState?.surfaceHandle, handle)
        XCTAssertEqual(state.canvas.strokeSession.renderState?.dirtyRect, LayerPixelRect.unsafeUnchecked(originX: 1, originY: 1, width: 2, height: 2))
        XCTAssertEqual(state.canvas.strokeSession.renderState?.isApproximatePreview, true)
    }

    func testAppendStrokePreviewPassesCurrentRenderStateToSessionUseCase() {
        let expectedHandle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let recordedRenderStates = TestRecorder<StrokeSessionRenderState?>()
        let coordinator = makeStrokeSessionCoordinator(
            strokeInteraction: CanvasStrokeInteractionService(
                sessionUseCase: .stub { command in
                    if case let .append(_, _, renderState, _, _, _, _) = command {
                        recordedRenderStates.record(renderState)
                    }
                    return .failure(.bridgeMutationFailed("recorded"))
                }
            )
        )
        var state = DocumentEditingState()
        let previewBrush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
        state.canvas.strokeSession.renderState = StrokeSessionRenderState(
            baseRevision: 12,
            layerIndex: 0,
            surfaceHandle: expectedHandle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 1, originY: 1, width: 2, height: 2),
            isApproximatePreview: true,
            previewBrush: previewBrush,
            sampleCount: 32,
            supportsIncrementalContinuation: true
        )
        let result = coordinator.resolveAppendedStrokePreview(
            state: state,
            samples: [.testValue()],
            context: DocumentCanvasStrokeContext(
                activeLayer: .testValue(),
                activeLayerIndex: 0,
                brush: previewBrush,
                previewBrush: previewBrush
            )
        )

        guard case .failure = result else {
            XCTFail("Expected stubbed failure")
            return
        }
        XCTAssertEqual(recordedRenderStates.values.first.flatMap { $0 }?.surfaceHandle, expectedHandle)
        XCTAssertEqual(
            recordedRenderStates.values.first.flatMap { $0 }?.previewBrush,
            DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: DocumentEditingState())
        )
        XCTAssertEqual(recordedRenderStates.values.first.flatMap { $0 }?.sampleCount, 32)
        XCTAssertEqual(recordedRenderStates.values.first.flatMap { $0 }?.supportsIncrementalContinuation, true)
    }

    func testShapeStrokePreviewUsesStrokeSessionPreviewWithFullSamples() {
        let recordedCommands = TestRecorder<GpuStrokeSessionCommand>()
        let expectedHandle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let coordinator = makeStrokeSessionCoordinator(
            strokeInteraction: CanvasStrokeInteractionService(
                sessionUseCase: .stub { command in
                    recordedCommands.record(command)
                    return .failure(.bridgeMutationFailed("recorded"))
                }
            )
        )
        let samples = [
            StylusSample.testValue(point: CGPoint(x: 1, y: 1)),
            StylusSample.testValue(point: CGPoint(x: 3, y: 3)),
        ]
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: DocumentEditingState())
        var state = DocumentEditingState()
        state.canvas.strokeSession.renderState = StrokeSessionRenderState(
            baseRevision: 12,
            layerIndex: 0,
            surfaceHandle: expectedHandle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 4, height: 4),
            isApproximatePreview: false,
            previewBrush: brush,
            sampleCount: 1,
            supportsIncrementalContinuation: true
        )

        let result = coordinator.resolveShapeStrokePreview(
            state: state,
            samples: samples,
            context: DocumentCanvasStrokeContext(
                activeLayer: .testValue(),
                activeLayerIndex: 0,
                brush: brush,
                previewBrush: brush
            )
        )

        guard case .failure = result else {
            XCTFail("Expected stubbed failure")
            return
        }
        guard let command = recordedCommands.values.first,
              case let .append(_, _, renderState, previewSamples, fullSamples, _, _) = command
        else {
            XCTFail("Expected shape preview to use stroke session append preview")
            return
        }
        XCTAssertEqual(renderState?.surfaceHandle, expectedHandle)
        XCTAssertEqual(previewSamples, samples)
        XCTAssertEqual(fullSamples, samples)
    }

    func testShapeStrokeEndCommitsFinalSamplesAfterLivePreview() async {
        let first = StrokePoint(
            position: SIMD2<Float>(1, 1),
            pressure: 1,
            altitude: 0,
            azimuth: 0,
            timestamp: 0,
            isPredicted: false
        )
        let second = StrokePoint(
            position: SIMD2<Float>(4, 4),
            pressure: 1,
            altitude: 0,
            azimuth: 0,
            timestamp: 1,
            isPredicted: false
        )
        let stroke = Stroke(points: [first, second])
        let store = TestStore(initialState: {
            var state = CanvasFeature.State()
            state.currentTool = .shape
            state.shapePreviewIsLive = true
            state.isStrokeActive = true
            return state
        }()) {
            CanvasFeature()
        }

        await store.send(.strokeEnded(stroke)) {
            $0.isStrokeActive = false
            $0.isAwaitingCommittedRender = true
            $0.strokeSession.committedPointCount = 0
            $0.shapePreviewIsLive = false
        }
        await store.receive(.delegate(.commitStroke(stroke.points.map(\.stylusSample))))
    }

    func testBrushStrokeEndKeepsFullStrokeAvailableForFinalAppendPreview() async {
        let first = StrokePoint(
            position: SIMD2<Float>(1, 1),
            pressure: 1,
            altitude: 0,
            azimuth: 0,
            timestamp: 0,
            isPredicted: false
        )
        let second = StrokePoint(
            position: SIMD2<Float>(4, 4),
            pressure: 1,
            altitude: 0,
            azimuth: 0,
            timestamp: 1,
            isPredicted: false
        )
        let third = StrokePoint(
            position: SIMD2<Float>(8, 8),
            pressure: 1,
            altitude: 0,
            azimuth: 0,
            timestamp: 2,
            isPredicted: false
        )
        let previousStroke = Stroke(points: [first, second])
        let endedStroke = Stroke(points: [first, second, third])
        let store = TestStore(initialState: {
            var state = CanvasFeature.State()
            state.currentTool = .brush
            state.activeStroke = previousStroke
            state.isStrokeActive = true
            state.strokeSession.committedPointCount = previousStroke.points.count
            return state
        }()) {
            CanvasFeature()
        }

        await store.send(.strokeEnded(endedStroke)) {
            $0.isStrokeActive = false
            $0.isAwaitingCommittedRender = true
            $0.activeStroke = endedStroke
            $0.strokeSession.committedPointCount = 0
        }
        await store.receive(.delegate(.appendSamples([third.stylusSample])))
        await store.receive(.delegate(.endStroke(endedStroke.points.map(\.stylusSample))))
    }

    func testGpuCommitOutcomeAppliesLayerSurfaceMutation() {
        let surfaceCalls = TestRecorder<GpuLayerMutationPayload>()
        let handle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)

        let runtime = DocumentRuntimeComposition.stub(
            mutationGateway: .stub(
                applyLayerSurfaceMutation: { _, payload in
                    surfaceCalls.record(payload)
                    return .success(())
                }
            ),
            strokeSessionUseCase: .stub { _ in
                .commit(
                    GpuCommitMutation(
                        surface: GpuLayerSurface(
                            layerIndex: 0,
                            width: 4,
                            height: 4,
                            handle: GpuSurfaceHandle(buffer: handle)
                        ),
                        dirtyRegion: GpuSurfaceRegion(originX: 1, originY: 1, width: 2, height: 2),
                        refreshViaDirtyPresentation: true
                    )
                )
            }
        )
        let coordinator = makeStrokeSessionCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: runtime.mutationGateway),
            strokeInteraction: CanvasStrokeInteractionService(sessionUseCase: runtime.strokeSessionUseCase)
        )
        var state = DocumentEditingState()
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
        let result = coordinator.resolveStrokeCommit(
            state: &state,
            samples: [.testValue()],
            context: DocumentCanvasStrokeContext(
                activeLayer: .testValue(),
                activeLayerIndex: 0,
                brush: brush,
                previewBrush: brush
            ),
            keepsSelectionCleared: false,
            refreshViaDirtyPresentation: true
        )

        switch result {
        case let .committed(contract, transferredSurfaceHandle):
            XCTAssertEqual(contract, DocumentFeature.DocumentMutationContract(canvasMutation: .none, refresh: .dirty, updatesWorkspaceArtifacts: false))
            XCTAssertEqual(transferredSurfaceHandle, handle)
        case let .failed(failure):
            XCTFail("Expected committed GPU surface mutation, got \(failure)")
        }
        XCTAssertEqual(surfaceCalls.values.first?.gpuBufferHandle, handle)
        XCTAssertEqual(surfaceCalls.values.first?.dirtyRect, LayerPixelRect.unsafeUnchecked(originX: 1, originY: 1, width: 2, height: 2))
    }

    func testGpuCommitStagesPendingCommittedSnapshotForNextStrokeBase() {
        let handle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let baseComposite = Data(repeating: 0x11, count: 64)
        let committedLayerPixels = Data(repeating: 0x44, count: 64)
        let baseSnapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 4,
            height: 4,
            revision: 12,
            transferKind: .dirtyRect,
            compositeBufferHandle: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16),
            compositePixelData: baseComposite,
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    gpuBufferHandle: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16),
                    pixelData: Data(repeating: 0x22, count: 64)
                )
            ]
        )

        let runtime = DocumentRuntimeComposition.stub(
            mutationGateway: .stub(
                applyLayerSurfaceMutation: { _, _ in .success(()) }
            ),
            strokeSessionUseCase: .stub { _ in
                .commit(
                    GpuCommitMutation(
                        surface: GpuLayerSurface(
                            layerIndex: 0,
                            width: 4,
                            height: 4,
                            handle: GpuSurfaceHandle(buffer: handle),
                            pixelData: committedLayerPixels
                        ),
                        dirtyRegion: GpuSurfaceRegion(originX: 1, originY: 1, width: 1, height: 1),
                        refreshViaDirtyPresentation: true
                    )
                )
            }
        )
        let coordinator = makeStrokeSessionCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: runtime.mutationGateway),
            strokeInteraction: CanvasStrokeInteractionService(sessionUseCase: runtime.strokeSessionUseCase)
        )
        var state = DocumentEditingState()
        state.canvas.captureStrokeBaseSnapshot(baseSnapshot)
        state.canvas.applyIncrementalRenderUpdate(
            IncrementalLayerUpdate.unsafeUnchecked(
                layerIndex: -1,
                originX: 1,
                originY: 1,
                width: 1,
                height: 1,
                pixelData: Data([0x99, 0x98, 0x97, 0x96])
            )
        )
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)

        let result = coordinator.resolveStrokeCommit(
            state: &state,
            samples: [.testValue()],
            context: DocumentCanvasStrokeContext(
                activeLayer: .testValue(),
                activeLayerIndex: 0,
                brush: brush,
                previewBrush: brush
            ),
            keepsSelectionCleared: false,
            refreshViaDirtyPresentation: true
        )

        guard case .committed = result else {
            XCTFail("Expected committed GPU surface mutation")
            return
        }
        guard let pendingSnapshot = state.canvas.pendingCommittedSnapshot else {
            XCTFail("Expected pending committed snapshot")
            return
        }
        XCTAssertEqual(pendingSnapshot.revision, 13)
        XCTAssertEqual(pendingSnapshot.transferKind, .fullSnapshot)
        XCTAssertNil(pendingSnapshot.compositeBufferHandle)
        XCTAssertNil(pendingSnapshot.layers.first?.gpuBufferHandle)
        XCTAssertEqual(pendingSnapshot.layers.first?.pixelData, committedLayerPixels)
        let replacedOffset = ((1 * 4) + 1) * 4
        XCTAssertEqual(
            Array(pendingSnapshot.compositePixelData[replacedOffset..<replacedOffset + 4]),
            [0x99, 0x98, 0x97, 0x96]
        )
    }

    func testGpuCommitStagesPendingCommittedSnapshotWithAccumulatedPreviewUpdates() {
        let previewHandle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let commitHandle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let committedLayerPixels = Data(repeating: 0x55, count: 64)
        let baseSnapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 4,
            height: 4,
            revision: 12,
            compositePixelData: Data(repeating: 0x11, count: 64),
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    gpuBufferHandle: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16),
                    pixelData: Data(repeating: 0x22, count: 64)
                )
            ]
        )
        let runtime = DocumentRuntimeComposition.stub(
            mutationGateway: .stub(
                applyLayerSurfaceMutation: { _, _ in .success(()) }
            ),
            strokeSessionUseCase: .stub { _ in
                .commit(
                    GpuCommitMutation(
                        surface: GpuLayerSurface(
                            layerIndex: 0,
                            width: 4,
                            height: 4,
                            handle: GpuSurfaceHandle(buffer: commitHandle),
                            pixelData: committedLayerPixels
                        ),
                        dirtyRegion: GpuSurfaceRegion(originX: 0, originY: 0, width: 4, height: 4),
                        refreshViaDirtyPresentation: true
                    )
                )
            }
        )
        let stateCoordinator = DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: runtime.mutationGateway),
            strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
        )
        let sessionCoordinator = makeStrokeSessionCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: runtime.mutationGateway),
            strokeInteraction: CanvasStrokeInteractionService(sessionUseCase: runtime.strokeSessionUseCase)
        )
        var state = DocumentEditingState()
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)

        stateCoordinator.applyPreviewMutation(
            GpuPreviewMutation(
                baseSnapshot: baseSnapshot,
                surface: GpuLayerSurface(
                    layerIndex: 0,
                    width: 4,
                    height: 4,
                    handle: GpuSurfaceHandle(buffer: previewHandle)
                ),
                dirtyRegion: GpuSurfaceRegion(originX: 0, originY: 0, width: 1, height: 1),
                incrementalUpdate: IncrementalLayerUpdate.unsafeUnchecked(
                    layerIndex: -1,
                    originX: 0,
                    originY: 0,
                    width: 1,
                    height: 1,
                    pixelData: Data([0x01, 0x02, 0x03, 0x04])
                ),
                isApproximatePreview: false,
                previewBrush: brush,
                sampleCount: 1,
                supportsIncrementalContinuation: true
            ),
            state: &state,
            releaseSurfaceHandle: { _ in }
        )
        stateCoordinator.applyPreviewMutation(
            GpuPreviewMutation(
                baseSnapshot: baseSnapshot,
                surface: GpuLayerSurface(
                    layerIndex: 0,
                    width: 4,
                    height: 4,
                    handle: GpuSurfaceHandle(buffer: previewHandle)
                ),
                dirtyRegion: GpuSurfaceRegion(originX: 3, originY: 3, width: 1, height: 1),
                incrementalUpdate: IncrementalLayerUpdate.unsafeUnchecked(
                    layerIndex: -1,
                    originX: 3,
                    originY: 3,
                    width: 1,
                    height: 1,
                    pixelData: Data([0x91, 0x92, 0x93, 0x94])
                ),
                isApproximatePreview: false,
                previewBrush: brush,
                sampleCount: 2,
                supportsIncrementalContinuation: true
            ),
            state: &state,
            releaseSurfaceHandle: { _ in }
        )

        XCTAssertEqual(state.canvas.strokeSession.renderState?.dirtyRect, LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 4, height: 4))
        let result = sessionCoordinator.resolveStrokeCommit(
            state: &state,
            samples: [.testValue()],
            context: DocumentCanvasStrokeContext(
                activeLayer: .testValue(),
                activeLayerIndex: 0,
                brush: brush,
                previewBrush: brush
            ),
            keepsSelectionCleared: false,
            refreshViaDirtyPresentation: true
        )

        guard case .committed = result else {
            XCTFail("Expected committed GPU surface mutation")
            return
        }
        guard let pendingSnapshot = state.canvas.pendingCommittedSnapshot else {
            XCTFail("Expected pending committed snapshot")
            return
        }
        XCTAssertNil(pendingSnapshot.compositeBufferHandle)
        XCTAssertNil(pendingSnapshot.layers.first?.gpuBufferHandle)
        XCTAssertEqual(pendingSnapshot.layers.first?.pixelData, committedLayerPixels)
        XCTAssertEqual(Array(pendingSnapshot.compositePixelData[0..<4]), [0x01, 0x02, 0x03, 0x04])
        let secondOffset = ((3 * 4) + 3) * 4
        XCTAssertEqual(Array(pendingSnapshot.compositePixelData[secondOffset..<secondOffset + 4]), [0x91, 0x92, 0x93, 0x94])
    }

    func testNextStrokeCapturesPendingCommittedSnapshotBeforePresentationRefresh() {
        let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
            strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
        )
        let pendingSnapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 4,
            height: 4,
            revision: 21,
            compositePixelData: Data(repeating: 0x33, count: 64),
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    gpuBufferHandle: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16),
                    pixelData: Data(repeating: 0x44, count: 64)
                )
            ]
        )
        var state = DocumentEditingState()
        state.canvas.stagePendingCommittedSnapshot(pendingSnapshot)
        var loadedCurrentPresentation = false

        coordinator.captureBaseSnapshotIfNeeded(
            state: &state,
            ensureCurrentPresentationLoaded: { _ in
                loadedCurrentPresentation = true
            }
        )

        XCTAssertEqual(state.canvas.strokeSession.baseSnapshot, pendingSnapshot)
        XCTAssertFalse(loadedCurrentPresentation)
    }

    func testPreviewReplacementReleasesPreviousSurfaceHandle() {
        let oldHandle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let newHandle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let releasedHandles = TestRecorder<MetalBufferHandle?>()
        let gpuOperations = DocumentGpuOperationGateway.stub(
            releaseSurfaceHandle: { handle in releasedHandles.record(handle) }
        )

        do {
            let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
                layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
                strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
            )
            var state = DocumentEditingState()
            let previewBrush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
            let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
                width: 4,
                height: 4,
                revision: 12,
                compositePixelData: Data(repeating: 0, count: 64),
                layers: []
            )
            state.canvas.strokeSession.renderState = StrokeSessionRenderState(
                baseRevision: 11,
                layerIndex: 0,
                surfaceHandle: oldHandle,
                dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 4, height: 4),
                isApproximatePreview: false
            )

            coordinator.applyPreviewMutation(
                GpuPreviewMutation(
                    baseSnapshot: snapshot,
                    surface: GpuLayerSurface(
                        layerIndex: 0,
                        width: 4,
                        height: 4,
                        handle: GpuSurfaceHandle(buffer: newHandle)
                    ),
                    dirtyRegion: GpuSurfaceRegion(originX: 1, originY: 1, width: 2, height: 2),
                    incrementalUpdate: nil,
                    isApproximatePreview: false,
                    previewBrush: previewBrush,
                    sampleCount: 12,
                    supportsIncrementalContinuation: true
                ),
                state: &state,
                releaseSurfaceHandle: { handle in
                    gpuOperations.releaseSurfaceHandle(handle)
                }
            )

            XCTAssertEqual(state.canvas.strokeSession.renderState?.surfaceHandle, newHandle)
            XCTAssertEqual(state.canvas.strokeSession.renderState?.previewBrush, previewBrush)
            XCTAssertEqual(state.canvas.strokeSession.renderState?.sampleCount, 12)
            XCTAssertEqual(state.canvas.strokeSession.renderState?.supportsIncrementalContinuation, true)
        }

        XCTAssertEqual(releasedHandles.values, [oldHandle])
    }

    func testResetStrokePreviewReleasesCurrentSurfaceHandle() {
        let handle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let releasedHandles = TestRecorder<MetalBufferHandle?>()
        let gpuOperations = DocumentGpuOperationGateway.stub(
            releaseSurfaceHandle: { handle in releasedHandles.record(handle) }
        )

        let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
            strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
        )
        var state = DocumentEditingState()
        state.canvas.strokeSession.renderState = StrokeSessionRenderState(
            baseRevision: 11,
            layerIndex: 0,
            surfaceHandle: handle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 4, height: 4),
            isApproximatePreview: false
        )

        coordinator.resetPreviewState(state: &state) { handle in
            gpuOperations.releaseSurfaceHandle(handle)
        }

        XCTAssertEqual(releasedHandles.values, [handle])
    }

    func testCompletedCommitDoesNotReleaseTransferredPreviewSurfaceHandle() {
        let handle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let releasedHandles = TestRecorder<MetalBufferHandle?>()
        let gpuOperations = DocumentGpuOperationGateway.stub(
            releaseSurfaceHandle: { handle in releasedHandles.record(handle) }
        )

        let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
            strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
        )
        var state = DocumentEditingState()
        state.canvas.strokeSession.renderState = StrokeSessionRenderState(
            baseRevision: 11,
            layerIndex: 0,
            surfaceHandle: handle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 4, height: 4),
            isApproximatePreview: false
        )

        coordinator.resetPreviewState(state: &state, preserving: handle) { handle in
            gpuOperations.releaseSurfaceHandle(handle)
        }

        XCTAssertTrue(releasedHandles.values.isEmpty)
    }

    func testFillFailureRemainsTyped() {
        let sample = StylusSample.testValue()
        let service = DocumentStrokeCommandService(
            strokeGateway: .stub(
                fill: { _, _ in .failure(.invalidLayerIndex(4)) }
            )
        )
        let result = service.fill(
            sample,
            DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: DocumentEditingState())
        )

        switch result {
        case .success:
            XCTFail("Expected invalid layer failure")
        case let .failure(failure):
            XCTAssertEqual(failure, .invalidLayerIndex(4))
        }
    }

    func testLayerContentTransactionRollsBackCreatedLayerOnFailure() {
        let addLayerCalls = TestRecorder<String>()
        let deleteLayerCalls = TestRecorder<Int>()
        let setActiveLayerCalls = TestRecorder<Int>()

        let service = DocumentContentService(
            documentQueryGateway: .stub(
                presentation: .testValue(activeLayerIndex: 3)
            ),
            documentMutationGateway: .stub(
                addLayer: { name in
                    addLayerCalls.record(name)
                    return .success(7)
                },
                deleteLayer: { index in
                    deleteLayerCalls.record(index)
                    return .success(())
                },
                setActiveLayer: { index in
                    setActiveLayerCalls.record(index)
                    return .success(())
                },
                replaceLayerPixels: { _, _ in
                    .failure(.bridgeMutationFailed("replace failed"))
                }
            ),
            textLayerGateway: .stub()
        )
        let result = service.applyPixels(
            Data([0x00]),
            to: .newLayer(name: "Imported")
        )

        XCTAssertEqual(result, .failure(.bridgeMutationFailed("replace failed")))
        XCTAssertEqual(addLayerCalls.values, ["Imported"])
        XCTAssertEqual(deleteLayerCalls.values, [7])
        XCTAssertEqual(setActiveLayerCalls.values, [3])
    }

    func testLayerContentTransactionSurfacesRollbackFailure() {
        let service = DocumentContentService(
            documentQueryGateway: .stub(
                presentation: .testValue(activeLayerIndex: 3)
            ),
            documentMutationGateway: .stub(
                addLayer: { _ in .success(7) },
                deleteLayer: { _ in
                    .failure(.bridgeMutationFailed("delete rollback failed"))
                },
                setActiveLayer: { _ in
                    .failure(.bridgeMutationFailed("active layer rollback failed"))
                },
                replaceLayerPixels: { _, _ in
                    .failure(.bridgeMutationFailed("replace failed"))
                }
            ),
            textLayerGateway: .stub()
        )
        let result = service.applyPixels(
            Data([0x00]),
            to: .newLayer(name: "Imported")
        )

        XCTAssertEqual(
            result,
            .failure(
                .transactionFailure(
                    primary: .bridgeMutationFailed("replace failed"),
                    rollback: .transactionFailure(
                        primary: .bridgeMutationFailed("delete rollback failed"),
                        rollback: .bridgeMutationFailed("active layer rollback failed")
                    )
                )
            )
        )
    }

    func testAIImageApplyRollsBackCreatedLayerOnFailure() {
        let addLayerCalls = TestRecorder<String>()
        let deleteLayerCalls = TestRecorder<Int>()
        let setActiveLayerCalls = TestRecorder<Int>()

        let service = DocumentContentService(
            documentQueryGateway: .stub(
                presentation: .testValue(activeLayerIndex: 2)
            ),
            documentMutationGateway: .stub(
                addLayer: { name in
                    addLayerCalls.record(name)
                    return .success(9)
                },
                deleteLayer: { index in
                    deleteLayerCalls.record(index)
                    return .success(())
                },
                setActiveLayer: { index in
                    setActiveLayerCalls.record(index)
                    return .success(())
                },
                replaceLayerPixels: { _, _ in
                    .failure(.bridgeMutationFailed("apply failed"))
                }
            ),
            textLayerGateway: .stub()
        )
        _ = service.applyPixels(
            Data([0x00, 0x00, 0x00, 0x00]),
            to: .newLayer(name: "AI Image")
        )

        XCTAssertEqual(addLayerCalls.values.count, 1)
        XCTAssertEqual(deleteLayerCalls.values, [9])
        XCTAssertEqual(setActiveLayerCalls.values, [2])
    }
}

private struct DerivedGpuDependencyProbe {
    @Dependency(\.canvasPreviewRenderer) var previewRenderer
    @Dependency(\.selectionMaskProcessor) var selectionMaskProcessor
    @Dependency(\.layerTransformProcessor) var layerTransformProcessor
    @Dependency(\.canvasPresentationEnvironment) var canvasPresentationEnvironment

    func outputs() -> [Data?] {
        let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 1,
            height: 1,
            revision: 0,
            compositePixelData: Data(count: 4),
            layers: []
        )
        let selection = CanvasSelection.unsafeUnchecked(bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            maskWidth: 1,
            maskHeight: 1,
            maskData: Data([255]),
            mode: .lasso
        )

        return [
            previewRenderer.compositePreviewImageData(
                snapshot: snapshot,
                activeLayerIndex: 0,
                adjustedActiveLayerPixels: Data(count: 4)
            ),
            selectionMaskProcessor.selectionOverlaySurface(
                maskData: Data([255]),
                width: 1,
                height: 1
            )?.pixelData,
            layerTransformProcessor.transformedLayerPixels(
                source: Data(repeating: 255, count: 4),
                canvasWidth: 1,
                canvasHeight: 1,
                selection: selection,
                translation: CGSize(width: 1, height: 0),
                scaleX: 1,
                scaleY: 1,
                rotationDegrees: 0,
                pivot: nil,
                mode: .standard,
                quadOffsets: .zero
            ),
            canvasPresentationEnvironment.previewRenderer.compositePreviewImageData(
                snapshot: snapshot,
                activeLayerIndex: 0,
                adjustedActiveLayerPixels: Data(count: 4)
            ),
            canvasPresentationEnvironment.selectionProcessor.selectionOverlaySurface(
                maskData: Data([255]),
                width: 1,
                height: 1
            )?.pixelData,
            canvasPresentationEnvironment.layerTransformProcessor.transformedLayerPixels(
                source: Data(repeating: 255, count: 4),
                canvasWidth: 1,
                canvasHeight: 1,
                selection: selection,
                translation: CGSize(width: 1, height: 0),
                scaleX: 1,
                scaleY: 1,
                rotationDegrees: 0,
                pivot: nil,
                mode: .standard,
                quadOffsets: .zero
            ),
        ]
    }
}

private func markedGateway(_ marker: UInt8) -> DocumentGpuOperationGateway {
    DocumentGpuOperationGateway.stub(
        compositedPreviewPixelData: { _, _, _ in Data([marker]) },
        selectionOverlayRGBA: { _, width, height in
            Data(repeating: marker, count: width * height * 4)
        },
        expandedSelectionMask: { request in
            [UInt8](repeating: marker, count: request.canvasWidth * request.canvasHeight)
        },
        transformedLayerPixelData: { _ in Data([marker]) }
    )
}
