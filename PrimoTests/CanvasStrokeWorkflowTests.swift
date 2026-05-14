import Foundation
import ComposableArchitecture
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoBrushRuntimeContracts
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentGPUContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication
import SwiftUI
import XCTest
@testable import Primo

@MainActor
final class CanvasStrokeWorkflowTests: XCTestCase {
    private func makeStrokeSessionCoordinator(
        layerCommands: LayerEditingRuntime = DocumentApplicationRuntime.stub().layerEditing,
        strokeInteraction: StrokeEditingRuntime
    ) -> DocumentFeature.CanvasStrokeSessionCoordinator {
        DocumentFeature.CanvasStrokeSessionCoordinator(
            layerCommands: layerCommands,
            strokeInteraction: strokeInteraction
        )
    }

    private func makeStrokeSessionCoordinator(
        layerCommands: LayerEditingRuntime = DocumentApplicationRuntime.stub().layerEditing,
        strokeInteraction: CanvasStrokeInteractionService
    ) -> DocumentFeature.CanvasStrokeSessionCoordinator {
        makeStrokeSessionCoordinator(
            layerCommands: layerCommands,
            strokeInteraction: StrokeEditingRuntime(
                strokeRuntime: CanvasStrokeRuntime(
                    strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub()),
                    canvasStrokeInteractionService: strokeInteraction
                )
            )
        )
    }

    func testDocumentRuntimeOverrideRefreshesDerivedRenderingDependencies() {
        let oldGateway = markedGateway(1)
        let newGateway = markedGateway(9)

        let outputs = withDependencies {
            $0.documentApplicationEnvironment = .stub(gpuOperationGateway: oldGateway)
            $0.documentApplicationEnvironment = .stub(gpuOperationGateway: newGateway)
        } operation: {
            DerivedGpuDependencyProbe().outputs()
        }

        XCTAssertEqual(outputs, [
            Data([9]),
            Data(repeating: 9, count: 4),
            Data([9]),
            Data(repeating: 9, count: 4),
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

    func testEraserRuntimeSettingsIgnorePaletteColorAndDisablePaintEngines() {
        var state = DocumentEditingState()
        state.canvas.currentTool = .erase
        state.brushPalette.brush.tipKind = .oil
        state.brushPalette.brush.smudgeEngineEnabled = true
        state.brushPalette.brush.wetness = 1.0
        state.brushPalette.brush.colorMixStrength = 1.0
        state.brushPalette.brush.selectedColorSlot = .secondary
        state.brushPalette.brush.secondaryColor = .red

        let settings = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)

        XCTAssertTrue(settings.isEraser)
        XCTAssertEqual(settings.tipKind, .ink)
        XCTAssertFalse(settings.smudgeEngineEnabled)
        XCTAssertEqual(settings.colorMixingMode, .off)
        XCTAssertEqual(settings.wetness, 0.0)
        XCTAssertEqual(settings.colorMixStrength, 0.0)
        XCTAssertEqual(settings.red, 255)
        XCTAssertEqual(settings.green, 255)
        XCTAssertEqual(settings.blue, 255)
    }

    func testEraserRuntimeSettingsAlwaysRespondToPressure() {
        var state = DocumentEditingState()
        state.canvas.currentTool = .erase
        state.brushPalette.brush.opacity = 0.2
        state.brushPalette.brush.flow = 0.2
        state.brushPalette.brush.opacityPressureSensitivity = 0.0

        let settings = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)

        XCTAssertEqual(settings.opacity, 1.0)
        XCTAssertEqual(settings.flow, 1.0)
        XCTAssertGreaterThanOrEqual(settings.opacityPressureSensitivity, 0.72)
    }

    func testAllDefaultBrushesAreEligibleForGpuResponsivePreviewMutation() {
        var failures: [String] = []

        for preset in BrushPreset.defaults {
            let brush = Self.runtimeSettings(for: preset)
            let previewBrush = GpuRenderingSupport.responsivePreviewBrush(from: brush)
            let canUseGpuMutation =
                GpuRenderingSupport.shouldUseIncrementalPreviewUpdate(for: previewBrush) ||
                GpuRenderingSupport.shouldUseGpuOnlyResponsivePreview(for: brush)

            if !canUseGpuMutation {
                failures.append("\(preset.name): responsive preview would fall back instead of using GPU mutation")
            }
            if GpuRenderingSupport.shouldUseGpuOnlyResponsivePreview(for: brush), previewBrush.smudgeEngineEnabled {
                failures.append("\(preset.name): oil/smudge responsive preview still enables smudge CPU orchestration")
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testDeferredPresentationLoadedDoesNotApplyStaleRenderSnapshot() async {
        let currentSnapshot = makeCompositeSnapshot(width: 4, height: 4, revision: 8)
        let pendingSnapshot = makeCompositeSnapshot(width: 4, height: 4, revision: 9)
        let stalePresentation = PaintDocumentPresentation.testValue(
            canvasSize: CGSize(width: 4, height: 4),
            renderSnapshot: makeCompositeSnapshot(width: 4, height: 4, revision: 7)
        )
        let store = TestStore(
            initialState: {
                var state = DocumentEditingState()
                state.canvas.renderSnapshot = currentSnapshot
                state.canvas.stagePendingCommittedSnapshot(pendingSnapshot)
                state.canvas.lastCommittedRenderRevision = currentSnapshot.revision
                return state
            }()
        ) {
            PresentationRefreshReducer()
        }
        store.exhaustivity = .off

        await store.send(.presentationLoaded(stalePresentation))
    }

    func testDeferredPresentationLoadedAppliesCurrentOrNewerRenderSnapshot() async {
        let currentSnapshot = makeCompositeSnapshot(width: 4, height: 4, revision: 8)
        let newerSnapshot = makeCompositeSnapshot(width: 4, height: 4, revision: 9)
        let presentation = PaintDocumentPresentation.testValue(
            canvasSize: CGSize(width: 4, height: 4),
            renderSnapshot: newerSnapshot
        )
        let store = TestStore(
            initialState: {
                var state = DocumentEditingState()
                state.canvas.renderSnapshot = currentSnapshot
                state.canvas.lastCommittedRenderRevision = currentSnapshot.revision
                return state
            }()
        ) {
            PresentationRefreshReducer()
        }
        store.exhaustivity = .off

        await store.send(.presentationLoaded(presentation)) {
            $0.canvas.renderSnapshot = newerSnapshot
            $0.canvas.lastCommittedRenderRevision = newerSnapshot.revision
        }
        await store.receive(.delegate(.presentationApplied))
    }

    func testWorkspaceSnapshotFallsBackWhenRenderSnapshotOnlyHasGpuCompositeHandle() {
        let fallbackSurface = DocumentCompositeSurface(
            unsafeUncheckedWidth: 1,
            height: 1,
            pixelData: Data([0xAA, 0xBB, 0xCC, 0xFF])
        )
        var state = DocumentEditingState()
        state.canvas.renderSnapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 4,
            height: 4,
            revision: 12,
            compositeBufferHandle: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16),
            compositePixelData: Data(),
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: Data(repeating: 0, count: 4 * 4 * 4)
                )
            ]
        )

        let snapshot = DocumentFeature.workspaceSnapshotCoordinator.snapshot(
            state: state,
            documentExportGateway: .stub(compositeSurface: { _ in fallbackSurface }),
            documentRenderingWorkflow: .stub()
        )

        XCTAssertEqual(snapshot.previewSurface, fallbackSurface)
    }

    func testRenderedCompositeSurfaceHandlesMissingCompositePixelData() {
        let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 4,
            height: 4,
            revision: 12,
            compositeBufferHandle: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16),
            compositePixelData: Data(),
            layers: []
        )

        XCTAssertNil(DocumentFeature.renderedCompositeSurfaceIfAvailable(
            snapshot: snapshot,
            paperStyle: .default,
            gpuOperations: .stub()
        ))

        let fallback = DocumentFeature.renderedCompositeSurface(
            snapshot: snapshot,
            paperStyle: .default,
            gpuOperations: .stub()
        )
        XCTAssertEqual(fallback.width, 4)
        XCTAssertEqual(fallback.height, 4)
        XCTAssertEqual(fallback.pixelData.count, 4 * 4 * 4)
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
            discardPreviewLease: { _ in }
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
        state.canvas.strokeSession.replaceRenderState(
            StrokeSessionRenderState(
                baseRevision: 12,
                layerIndex: 0,
                surfaceHandle: expectedHandle,
                dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 1, originY: 1, width: 2, height: 2),
                isApproximatePreview: true,
                previewBrush: previewBrush,
                sampleCount: 32,
                supportsIncrementalContinuation: true
            )
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
        state.canvas.strokeSession.replaceRenderState(
            StrokeSessionRenderState(
                baseRevision: 12,
                layerIndex: 0,
                surfaceHandle: expectedHandle,
                dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 4, height: 4),
                isApproximatePreview: false,
                previewBrush: brush,
                sampleCount: 1,
                supportsIncrementalContinuation: true
            )
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
            $0.strokeSession.resetCommittedPointCount()
            $0.shapePreviewIsLive = false
        }
        await store.receive(.delegate(.commitStroke(stroke.points.map(\.stylusSample))))
    }

    func testShapeStrokeEndWithSinglePointDoesNotCommit() async {
        let point = StrokePoint(
            position: SIMD2<Float>(1, 1),
            pressure: 1,
            altitude: 0,
            azimuth: 0,
            timestamp: 0,
            isPredicted: false
        )
        let stroke = Stroke(points: [point])
        let store = TestStore(initialState: {
            var state = CanvasFeature.State()
            state.currentTool = .shape
            state.activeStroke = stroke
            state.shapePreviewIsLive = true
            state.isStrokeActive = true
            return state
        }()) {
            CanvasFeature()
        }

        await store.send(.strokeEnded(stroke)) {
            $0.isStrokeActive = false
            $0.activeStroke = nil
            $0.strokeSession.resetCommittedPointCount()
            $0.shapePreviewIsLive = false
        }
    }

    func testShapeStrokeEndWithNoPointsDoesNotCommit() async {
        let stroke = Stroke(points: [])
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
            $0.strokeSession.resetCommittedPointCount()
            $0.shapePreviewIsLive = false
        }
    }

    func testShapeStrokeUpdateUsesOverlayPreviewInsteadOfGpuMutationPreview() async {
        let stroke = Stroke(points: [
            StrokePoint(
                position: SIMD2<Float>(1, 1),
                pressure: 1,
                altitude: 0,
                azimuth: 0,
                timestamp: 0,
                isPredicted: false
            ),
            StrokePoint(
                position: SIMD2<Float>(4, 4),
                pressure: 1,
                altitude: 0,
                azimuth: 0,
                timestamp: 1,
                isPredicted: false
            ),
        ])
        let store = TestStore(initialState: {
            var state = CanvasFeature.State()
            state.currentTool = .shape
            return state
        }()) {
            CanvasFeature()
        }

        await store.send(.strokeUpdated(stroke)) {
            $0.isStrokeActive = true
            $0.activeStroke = stroke
            $0.shapePreviewIsLive = true
        }
    }

    func testBlurStrokeCancelDiscardsInsteadOfFinalizing() async {
        let stroke = Stroke(points: [
            StrokePoint(
                position: SIMD2<Float>(1, 1),
                pressure: 1,
                altitude: 0,
                azimuth: 0,
                timestamp: 0,
                isPredicted: false
            )
        ])
        let store = TestStore(initialState: {
            var state = CanvasFeature.State()
            state.currentTool = .blur
            state.activeStroke = stroke
            state.isStrokeActive = true
            state.isAwaitingCommittedRender = true
            return state
        }()) {
            CanvasFeature()
        }

        await store.send(.strokeCancelled) {
            $0.isStrokeActive = false
            $0.isAwaitingCommittedRender = false
            $0.activeStroke = nil
            $0.strokeSession.resetCommittedPointCount()
        }
        await store.receive(.delegate(.cancelBlurStroke))
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
            state.strokeSession.markCommittedPointCount(previousStroke.points.count)
            return state
        }()) {
            CanvasFeature()
        }

        await store.send(.strokeEnded(endedStroke)) {
            $0.isStrokeActive = false
            $0.isAwaitingCommittedRender = true
            $0.activeStroke = endedStroke
            $0.strokeSession.resetCommittedPointCount()
        }
        await store.receive(.delegate(.appendSamples([third.stylusSample])))
        await store.receive(.delegate(.endStroke(endedStroke.points.map(\.stylusSample))))
    }

    func testGpuCommitOutcomeAppliesLayerSurfaceMutation() {
        let surfaceCalls = TestRecorder<GpuLayerMutationPayload>()
        let handle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)

        let runtime = DocumentApplicationRuntime.stub(
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
            layerCommands: runtime.layerEditing,
            strokeInteraction: runtime.strokeEditing
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
        case let .committed(contract, transferredPreviewLease):
            XCTAssertEqual(contract, DocumentFeature.DocumentMutationContract(canvasMutation: .none, refresh: .dirty, updatesWorkspaceArtifacts: false))
            XCTAssertTrue(transferredPreviewLease.isPresent)
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

        let runtime = DocumentApplicationRuntime.stub(
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
            layerCommands: runtime.layerEditing,
            strokeInteraction: runtime.strokeEditing
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

    func testGpuOnlyCommitStagesAuthoritativePendingSnapshotForNextStrokeBase() {
        let oldHandle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let committedHandle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let baseLayerPixels = Data(repeating: 0x22, count: 64)
        let baseSnapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 4,
            height: 4,
            revision: 12,
            transferKind: .dirtyRect,
            compositeBufferHandle: oldHandle,
            compositePixelData: Data(),
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    gpuBufferHandle: oldHandle,
                    pixelData: baseLayerPixels
                )
            ]
        )
        var state = DocumentEditingState()

        state.canvas.stagePendingCommittedStrokeSnapshot(
            baseSnapshot: baseSnapshot,
            surface: GpuLayerSurface(
                layerIndex: 0,
                width: 4,
                height: 4,
                handle: GpuSurfaceHandle(buffer: committedHandle),
                pixelData: nil
            )
        )

        guard let pendingSnapshot = state.canvas.pendingCommittedSnapshot else {
            XCTFail("Expected GPU-only commit to stage a pending snapshot")
            return
        }
        XCTAssertEqual(pendingSnapshot.revision, 13)
        XCTAssertEqual(pendingSnapshot.compositeBufferHandle, committedHandle)
        XCTAssertTrue(pendingSnapshot.compositePixelData.isEmpty)
        XCTAssertEqual(pendingSnapshot.layers.first?.gpuBufferHandle, committedHandle)
        XCTAssertEqual(pendingSnapshot.layers.first?.pixelData, baseLayerPixels)

        let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
            strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
        )
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
        let runtime = DocumentApplicationRuntime.stub(
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
            layerCommands: runtime.layerEditing,
            strokeCommands: runtime.strokeEditing
        )
        let sessionCoordinator = makeStrokeSessionCoordinator(
            layerCommands: runtime.layerEditing,
            strokeInteraction: runtime.strokeEditing
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
            discardPreviewLease: { _ in }
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
            discardPreviewLease: { _ in }
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

    func testPreviewIncrementalUpdatesCompactAfterBoundedQueueLimit() {
        let baseSnapshot = makeCompositeSnapshot(width: 4, height: 4, revision: 12)
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: DocumentEditingState())
        let surface = GpuLayerSurface(
            layerIndex: 0,
            width: 4,
            height: 4,
            handle: GpuSurfaceHandle(buffer: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16))
        )
        var state = DocumentEditingState()

        for index in 0..<9 {
            let x = index % 4
            let y = index / 4
            state.canvas.recordPreviewIncrementalUpdate(
                IncrementalLayerUpdate.unsafeUnchecked(
                    layerIndex: -1,
                    originX: x,
                    originY: y,
                    width: 1,
                    height: 1,
                    pixelData: Data(repeating: UInt8(index + 1), count: 4)
                ),
                previousRenderState: index == 0 ? nil : StrokeSessionRenderState(
                    baseRevision: 12,
                    layerIndex: 0,
                    surfaceHandle: surface.handle.buffer,
                    dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 4, height: 3),
                    isApproximatePreview: false,
                    previewBrush: brush,
                    sampleCount: index,
                    supportsIncrementalContinuation: true
                ),
                baseSnapshot: baseSnapshot,
                surface: surface,
                previewBrush: brush,
                sampleCount: index + 1
            )
        }

        XCTAssertEqual(state.canvas.pendingPreviewIncrementalUpdates.count, 1)
        let compacted = state.canvas.pendingPreviewIncrementalUpdates[0]
        XCTAssertEqual(compacted.originX, 0)
        XCTAssertEqual(compacted.originY, 0)
        XCTAssertEqual(compacted.width, 4)
        XCTAssertEqual(compacted.height, 3)
        XCTAssertEqual(compacted.pixelData.count, 4 * 3 * 4)
        XCTAssertEqual(Array(compacted.pixelData[0..<4]), [1, 1, 1, 1])
        let ninthOffset = ((2 * 4) + 0) * 4
        XCTAssertEqual(Array(compacted.pixelData[ninthOffset..<ninthOffset + 4]), [9, 9, 9, 9])
    }

    func testPreviewIncrementalUpdatesAccumulateForResponsivePreviewEvenWhenContinuationIsUnsupported() {
        let baseSnapshot = makeCompositeSnapshot(width: 4, height: 4, revision: 12)
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: DocumentEditingState())
        let surface = GpuLayerSurface(
            layerIndex: 0,
            width: 4,
            height: 4,
            handle: GpuSurfaceHandle(buffer: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16))
        )
        var state = DocumentEditingState()

        state.canvas.recordPreviewIncrementalUpdate(
            IncrementalLayerUpdate.unsafeUnchecked(
                layerIndex: -1,
                originX: 0,
                originY: 0,
                width: 1,
                height: 1,
                pixelData: Data(repeating: 1, count: 4)
            ),
            previousRenderState: nil,
            baseSnapshot: baseSnapshot,
            surface: surface,
            previewBrush: brush,
            sampleCount: 1
        )
        state.canvas.recordPreviewIncrementalUpdate(
            IncrementalLayerUpdate.unsafeUnchecked(
                layerIndex: -1,
                originX: 3,
                originY: 3,
                width: 1,
                height: 1,
                pixelData: Data(repeating: 2, count: 4)
            ),
            previousRenderState: StrokeSessionRenderState(
                baseRevision: 12,
                layerIndex: 0,
                surfaceHandle: surface.handle.buffer,
                dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 1, height: 1),
                isApproximatePreview: false,
                previewBrush: brush,
                sampleCount: 1,
                supportsIncrementalContinuation: false
            ),
            baseSnapshot: baseSnapshot,
            surface: surface,
            previewBrush: brush,
            sampleCount: 2
        )

        XCTAssertEqual(state.canvas.pendingPreviewIncrementalUpdates.count, 2)
        XCTAssertEqual(state.canvas.pendingPreviewIncrementalUpdates.first?.originX, 0)
        XCTAssertEqual(state.canvas.pendingPreviewIncrementalUpdates.first?.originY, 0)
        XCTAssertEqual(state.canvas.pendingPreviewIncrementalUpdates.last?.originX, 3)
        XCTAssertEqual(state.canvas.pendingPreviewIncrementalUpdates.last?.originY, 3)
        XCTAssertEqual(state.canvas.pendingPreviewIncrementalUpdates.last?.pixelData, Data(repeating: 2, count: 4))
    }

    func testGpuBackedPreviewIncrementalUpdateWithMaterializedPixelsStagesCommittedComposite() {
        let committedLayerPixels = Data(repeating: 0x55, count: 64)
        let baseSnapshot = makeCompositeSnapshot(width: 4, height: 4, revision: 12)
        var state = DocumentEditingState()
        state.canvas.recordPreviewIncrementalUpdate(
            IncrementalLayerUpdate.unsafeUnchecked(
                layerIndex: -1,
                originX: 2,
                originY: 2,
                width: 1,
                height: 1,
                gpuBufferHandle: MetalBufferHandle.unsafeUnchecked(width: 1, height: 1, bytesPerRow: 4),
                pixelData: Data([0x88, 0x87, 0x86, 0x85])
            ),
            previousRenderState: nil,
            baseSnapshot: baseSnapshot,
            surface: GpuLayerSurface(
                layerIndex: 0,
                width: 4,
                height: 4,
                handle: GpuSurfaceHandle(buffer: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16))
            ),
            previewBrush: DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state),
            sampleCount: 1
        )

        state.canvas.stagePendingCommittedStrokeSnapshot(
            baseSnapshot: baseSnapshot,
            surface: GpuLayerSurface(
                layerIndex: 0,
                width: 4,
                height: 4,
                handle: GpuSurfaceHandle(buffer: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)),
                pixelData: committedLayerPixels
            )
        )

        guard let pendingSnapshot = state.canvas.pendingCommittedSnapshot else {
            XCTFail("Expected pending committed snapshot")
            return
        }
        let offset = ((2 * 4) + 2) * 4
        XCTAssertEqual(Array(pendingSnapshot.compositePixelData[offset..<offset + 4]), [0x88, 0x87, 0x86, 0x85])
    }

    func testGpuCompositeOnlyBaseSnapshotStagesSingleLayerCommittedComposite() {
        let committedLayerPixels = Data(repeating: 0x66, count: 64)
        let baseSnapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 4,
            height: 4,
            revision: 12,
            compositeBufferHandle: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16),
            compositePixelData: Data(),
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
        var state = DocumentEditingState()

        state.canvas.stagePendingCommittedStrokeSnapshot(
            baseSnapshot: baseSnapshot,
            surface: GpuLayerSurface(
                layerIndex: 0,
                width: 4,
                height: 4,
                handle: GpuSurfaceHandle(buffer: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)),
                pixelData: committedLayerPixels
            )
        )

        XCTAssertEqual(state.canvas.pendingCommittedSnapshot?.compositePixelData, committedLayerPixels)
        XCTAssertNil(state.canvas.pendingCommittedSnapshot?.compositeBufferHandle)
    }

    func testOversizedPreviewIncrementalUpdateIsRejectedWhenPatchingComposite() {
        let committedLayerPixels = Data(repeating: 0x55, count: 64)
        let baseSnapshot = makeCompositeSnapshot(width: 4, height: 4, revision: 12)
        var state = DocumentEditingState()
        state.canvas.applyIncrementalRenderUpdate(
            IncrementalLayerUpdate.unsafeUnchecked(
                layerIndex: -1,
                originX: 3,
                originY: 3,
                width: 2,
                height: 2,
                pixelData: Data(repeating: 0x99, count: 16)
            )
        )

        state.canvas.stagePendingCommittedStrokeSnapshot(
            baseSnapshot: baseSnapshot,
            surface: GpuLayerSurface(
                layerIndex: 0,
                width: 4,
                height: 4,
                handle: GpuSurfaceHandle(buffer: MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)),
                pixelData: committedLayerPixels
            )
        )

        guard let pendingSnapshot = state.canvas.pendingCommittedSnapshot else {
            XCTFail("Expected pending committed snapshot")
            return
        }
        XCTAssertEqual(pendingSnapshot.compositePixelData, baseSnapshot.compositePixelData)
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
        let releasedLeases = TestRecorder<StrokePreviewLease>()

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
            let oldRenderState = StrokeSessionRenderState(
                baseRevision: 11,
                layerIndex: 0,
                surfaceHandle: oldHandle,
                dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 4, height: 4),
                isApproximatePreview: false
            )
            state.canvas.strokeSession.replaceRenderState(oldRenderState)

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
                discardPreviewLease: { lease in releasedLeases.record(lease) }
            )

            XCTAssertEqual(state.canvas.strokeSession.renderState?.surfaceHandle, newHandle)
            XCTAssertEqual(state.canvas.strokeSession.renderState?.previewBrush, previewBrush)
            XCTAssertEqual(state.canvas.strokeSession.renderState?.sampleCount, 12)
            XCTAssertEqual(state.canvas.strokeSession.renderState?.supportsIncrementalContinuation, true)
        }

        XCTAssertEqual(releasedLeases.values.count, 1)
        XCTAssertTrue(releasedLeases.values[0].isPresent)
    }

    func testResetStrokePreviewReleasesCurrentSurfaceHandle() {
        let handle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let releasedLeases = TestRecorder<StrokePreviewLease>()

        let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
            strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
        )
        var state = DocumentEditingState()
        state.canvas.strokeSession.replaceRenderState(StrokeSessionRenderState(
            baseRevision: 11,
            layerIndex: 0,
            surfaceHandle: handle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 4, height: 4),
            isApproximatePreview: false
        ))

        coordinator.resetPreviewState(state: &state) { lease in releasedLeases.record(lease) }

        XCTAssertEqual(releasedLeases.values.count, 1)
        XCTAssertTrue(releasedLeases.values[0].isPresent)
    }

    func testCompletedCommitDoesNotReleaseTransferredPreviewSurfaceHandle() {
        let handle = MetalBufferHandle.unsafeUnchecked(width: 4, height: 4, bytesPerRow: 16)
        let releasedLeases = TestRecorder<StrokePreviewLease>()

        let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
            strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
        )
        var state = DocumentEditingState()
        let renderState = StrokeSessionRenderState(
            baseRevision: 11,
            layerIndex: 0,
            surfaceHandle: handle,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: 4, height: 4),
            isApproximatePreview: false
        )
        state.canvas.strokeSession.replaceRenderState(renderState)

        coordinator.resetPreviewState(state: &state, preserving: renderState.previewLease) { lease in releasedLeases.record(lease) }

        XCTAssertTrue(releasedLeases.values.isEmpty)
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
                presentation: PaintDocumentPresentation.testValue(activeLayerIndex: 3)
            ),
            documentRenderGateway: .stub(),
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
                presentation: PaintDocumentPresentation.testValue(activeLayerIndex: 3)
            ),
            documentRenderGateway: .stub(),
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
                presentation: PaintDocumentPresentation.testValue(activeLayerIndex: 2)
            ),
            documentRenderGateway: .stub(),
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

    private func makeCompositeSnapshot(
        width: Int,
        height: Int,
        revision: Int
    ) -> MetalDocumentSnapshot {
        MetalDocumentSnapshot.unsafeUnchecked(
            width: width,
            height: height,
            revision: revision,
            compositePixelData: Data(repeating: 0x11, count: width * height * 4),
            layers: [
                MetalLayerSnapshot.unsafeUnchecked(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: Data(repeating: 0x22, count: width * height * 4)
                )
            ]
        )
    }

    private static func runtimeSettings(for preset: BrushPreset) -> BrushRuntimeSettings {
        BrushRuntimeSettingsAssemblyService().makeRuntimeSettings(
            brush: BrushRuntimeDescriptor(
                tipKind: preset.tipKind,
                radius: preset.radius,
                sizeSpeedSensitivity: preset.sizeSpeedSensitivity,
                taperIn: preset.taperIn,
                taperOut: preset.taperOut,
                opacity: preset.opacity,
                hardness: preset.hardness,
                roundness: preset.roundness,
                roundnessPressureSensitivity: preset.roundnessPressureSensitivity,
                roundnessTiltSensitivity: preset.roundnessTiltSensitivity,
                angle: preset.angle,
                anglePressureSensitivity: preset.anglePressureSensitivity,
                angleTiltSensitivity: preset.angleTiltSensitivity,
                angleMode: preset.angleMode,
                spacing: preset.spacing,
                spacingJitter: preset.spacingJitter,
                scatterEnabled: preset.scatterEnabled,
                scatterMode: preset.scatterMode,
                scatterLateral: preset.scatterLateral,
                scatterLinear: preset.scatterLinear,
                count: Double(preset.count),
                countJitter: preset.countJitter,
                countSizeJitter: preset.countSizeJitter,
                countOpacityJitter: preset.countOpacityJitter,
                angleJitter: preset.angleJitter,
                roundnessJitter: preset.roundnessJitter,
                textureMode: preset.textureMode,
                textureStrength: preset.textureStrength,
                flow: preset.flow,
                flowPressureSensitivity: preset.flowPressureSensitivity,
                flowJitter: preset.flowJitter,
                velocityInfluence: preset.velocityInfluence,
                wetness: preset.wetness,
                wetnessPressureSensitivity: preset.wetnessPressureSensitivity,
                opacityPressureSensitivity: preset.opacityPressureSensitivity,
                colorMixStrength: preset.colorMixStrength,
                smudgeRadius: preset.smudgeRadius,
                paintLoad: preset.paintLoad,
                smudgeEngineEnabled: preset.smudgeEngineEnabled,
                smudgeMode: preset.smudgeMode,
                smudgeLength: preset.smudgeLength,
                colorRate: preset.colorRate,
                loadPressureSensitivity: preset.loadPressureSensitivity,
                paintAmountPressureBypass: preset.paintAmountPressureBypass,
                paintDensityPressureBypass: preset.paintDensityPressureBypass,
                colorStretchPressureBypass: preset.colorStretchPressureBypass,
                dualEnabled: preset.dualBrushEnabled,
                dualTipKind: preset.dualTipKind,
                dualScale: preset.dualScale,
                dualSpacing: preset.dualSpacing,
                dualScatter: preset.dualScatter,
                dualAngle: preset.dualAngle,
                dualBlendMode: preset.dualBlendMode,
                grainScale: preset.grainScale,
                grainContrast: preset.grainContrast,
                paperScale: preset.paperScale,
                paperStrength: preset.paperStrength,
                paperThreshold: preset.paperThreshold,
                flipX: preset.flipX,
                flipY: preset.flipY,
                customTip: preset.customTip,
                pressureSensitivity: preset.pressureSensitivity,
                stabilization: 0,
                isEraser: false
            ),
            fill: BrushFillRuntimeDescriptor(
                thresholdMode: .opacity,
                opacityTolerance: 0,
                colorTolerance: 0.12,
                expansion: 0
            ),
            color: BrushColorComponents(
                red: Double(preset.red) / 255.0,
                green: Double(preset.green) / 255.0,
                blue: Double(preset.blue) / 255.0
            )
        )
    }
}

private struct DerivedGpuDependencyProbe {
    @Dependency(\.documentPreviewRenderingCapability) var previewRenderingCapability

    func outputs() -> [Data?] {
        let snapshot = MetalDocumentSnapshot.unsafeUnchecked(
            width: 1,
            height: 1,
            revision: 0,
            compositePixelData: Data(count: 4),
            layers: []
        )

        return [
            previewRenderingCapability.canvasPreviewRenderer.compositePreviewImageData(
                snapshot: snapshot,
                activeLayerIndex: 0,
                adjustedActiveLayerPixels: Data(count: 4)
            ),
            previewRenderingCapability.selectionMaskProcessor.selectionOverlaySurface(
                maskData: Data([255]),
                width: 1,
                height: 1
            )?.pixelData,
            previewRenderingCapability.canvasPresentationEnvironment.previewRenderer.compositePreviewImageData(
                snapshot: snapshot,
                activeLayerIndex: 0,
                adjustedActiveLayerPixels: Data(count: 4)
            ),
            previewRenderingCapability.canvasPresentationEnvironment.selectionProcessor.selectionOverlaySurface(
                maskData: Data([255]),
                width: 1,
                height: 1
            )?.pixelData,
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
