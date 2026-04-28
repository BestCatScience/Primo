import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentEngineInfrastructure
import PrimoDocumentGPUContracts
import PrimoDocumentStrokeApplication
import XCTest
@testable import Primo

final class CanvasStrokeWorkflowTests: XCTestCase {
    func testPrepareCanvasStrokeEditingReturnsTypedFailure() {
        let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: DocumentLayerCommandService(
                mutationGateway: .stub(
                    setLayerVisibility: { _, _ in .failure(.layerLocked(0)) }
                )
            ),
            strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
        )
        var state = DocumentFeature.State()
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
        let coordinator = DocumentFeature.CanvasStrokeSessionCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
            strokeInteraction: CanvasStrokeInteractionService(
                sessionUseCase: .stub { _ in
                    .failure(.bridgeMutationFailed("GPU stroke commit failed: missing base snapshot"))
                }
            )
        )
        var state = DocumentFeature.State()
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
        let result = coordinator.resolveStrokeCommit(
            state: &state,
            samples: [.testValue()],
            context: DocumentFeature.CanvasStrokeContext(
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
        var state = DocumentFeature.State()
        let snapshot = MetalDocumentSnapshot(
            width: 4,
            height: 4,
            revision: 12,
            compositePixelData: Data(repeating: 0, count: 64),
            layers: []
        )
        let handle = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)

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
        XCTAssertEqual(state.canvas.strokeSession.renderState?.dirtyRect, LayerPixelRect(originX: 1, originY: 1, width: 2, height: 2))
        XCTAssertEqual(state.canvas.strokeSession.renderState?.isApproximatePreview, true)
    }

    func testAppendStrokePreviewPassesCurrentRenderStateToSessionUseCase() {
        let expectedHandle = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)
        let recordedRenderStates = TestRecorder<StrokeSessionRenderState?>()
        let coordinator = DocumentFeature.CanvasStrokeSessionCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
            strokeInteraction: CanvasStrokeInteractionService(
                sessionUseCase: .stub { command in
                    if case let .append(_, _, renderState, _, _, _, _) = command {
                        recordedRenderStates.record(renderState)
                    }
                    return .failure(.bridgeMutationFailed("recorded"))
                }
            )
        )
        var state = DocumentFeature.State()
        let previewBrush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
        state.canvas.strokeSession.renderState = StrokeSessionRenderState(
            baseRevision: 12,
            layerIndex: 0,
            surfaceHandle: expectedHandle,
            dirtyRect: LayerPixelRect(originX: 1, originY: 1, width: 2, height: 2),
            isApproximatePreview: true,
            previewBrush: previewBrush,
            sampleCount: 32,
            supportsIncrementalContinuation: true
        )
        let result = coordinator.resolveAppendedStrokePreview(
            state: state,
            samples: [.testValue()],
            context: DocumentFeature.CanvasStrokeContext(
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
            DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: DocumentFeature.State())
        )
        XCTAssertEqual(recordedRenderStates.values.first.flatMap { $0 }?.sampleCount, 32)
        XCTAssertEqual(recordedRenderStates.values.first.flatMap { $0 }?.supportsIncrementalContinuation, true)
    }

    func testGpuCommitOutcomeAppliesLayerSurfaceMutation() {
        let surfaceCalls = TestRecorder<GpuLayerMutationPayload>()
        let handle = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)

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
        let coordinator = DocumentFeature.CanvasStrokeSessionCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: runtime.mutationGateway),
            strokeInteraction: CanvasStrokeInteractionService(sessionUseCase: runtime.strokeSessionUseCase)
        )
        var state = DocumentFeature.State()
        let brush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
        let result = coordinator.resolveStrokeCommit(
            state: &state,
            samples: [.testValue()],
            context: DocumentFeature.CanvasStrokeContext(
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
        XCTAssertEqual(surfaceCalls.values.first?.dirtyRect, LayerPixelRect(originX: 1, originY: 1, width: 2, height: 2))
    }

    func testPreviewReplacementReleasesPreviousSurfaceHandle() {
        let oldHandle = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)
        let newHandle = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)
        let releasedHandles = TestRecorder<MetalBufferHandle?>()
        var gpuOperations = DocumentGpuOperationGateway.stub()
        gpuOperations.releaseSurfaceHandle = { handle in
            releasedHandles.record(handle)
        }

        do {
            let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
                layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
                strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
            )
            var state = DocumentFeature.State()
            let previewBrush = DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: state)
            let snapshot = MetalDocumentSnapshot(
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
                dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 4, height: 4),
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
        let handle = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)
        let releasedHandles = TestRecorder<MetalBufferHandle?>()
        var gpuOperations = DocumentGpuOperationGateway.stub()
        gpuOperations.releaseSurfaceHandle = { handle in
            releasedHandles.record(handle)
        }

        let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
            strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
        )
        var state = DocumentFeature.State()
        state.canvas.strokeSession.renderState = StrokeSessionRenderState(
            baseRevision: 11,
            layerIndex: 0,
            surfaceHandle: handle,
            dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 4, height: 4),
            isApproximatePreview: false
        )

        coordinator.resetPreviewState(state: &state) { handle in
            gpuOperations.releaseSurfaceHandle(handle)
        }

        XCTAssertEqual(releasedHandles.values, [handle])
    }

    func testCompletedCommitDoesNotReleaseTransferredPreviewSurfaceHandle() {
        let handle = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)
        let releasedHandles = TestRecorder<MetalBufferHandle?>()
        var gpuOperations = DocumentGpuOperationGateway.stub()
        gpuOperations.releaseSurfaceHandle = { handle in
            releasedHandles.record(handle)
        }

        let coordinator = DocumentFeature.CanvasStrokeStateCoordinator(
            layerCommands: DocumentLayerCommandService(mutationGateway: .stub()),
            strokeCommands: DocumentStrokeCommandService(strokeGateway: .stub())
        )
        var state = DocumentFeature.State()
        state.canvas.strokeSession.renderState = StrokeSessionRenderState(
            baseRevision: 11,
            layerIndex: 0,
            surfaceHandle: handle,
            dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 4, height: 4),
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
            DocumentFeature.canvasToolStateCoordinator.resolvedBrushSettings(for: DocumentFeature.State())
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

    func testNanoBananaApplyRollsBackCreatedLayerOnFailure() {
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
            to: .newLayer(name: "Nano Banana")
        )

        XCTAssertEqual(addLayerCalls.values.count, 1)
        XCTAssertEqual(deleteLayerCalls.values, [9])
        XCTAssertEqual(setActiveLayerCalls.values, [9, 2])
    }
}
