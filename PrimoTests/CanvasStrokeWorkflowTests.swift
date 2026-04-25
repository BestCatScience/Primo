import ComposableArchitecture
import PrimoDocumentGPUContracts
import PrimoDocumentStrokeApplication
import XCTest
@testable import Primo

final class CanvasStrokeWorkflowTests: XCTestCase {
    func testPrepareCanvasStrokeEditingReturnsTypedFailure() {
        let result = withDependencies {
            $0.documentRuntimeComposition = .stub(
                mutationGateway: .stub(
                    setLayerVisibility: { _, _ in .failure(.layerLocked(0)) }
                )
            )
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            return feature.prepareCanvasStrokeEditing(state: &state)
        }

        XCTAssertEqual(result, .failure(.layerLocked(0)))
    }

    func testGpuStrokeCommitSurfacesSessionFailure() {
        let result = withDependencies {
            $0.documentRuntimeComposition = .stub(
                strokeSessionUseCase: .stub { _ in
                    .failure(.bridgeMutationFailed("GPU stroke commit failed: missing base snapshot"))
                }
            )
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            return feature.resolveStrokeCommit(
                state: &state,
                samples: [.testValue()],
                context: AppFeature.CanvasStrokeContext(
                    activeLayer: .testValue(),
                    activeLayerIndex: 0,
                    brush: feature.resolvedBrushSettings(for: state),
                    previewBrush: feature.resolvedBrushSettings(for: state)
                ),
                keepsSelectionCleared: false,
                refreshViaDirtyPresentation: false
            )
        }

        XCTAssertEqual(
            result,
            .failed(.bridgeMutationFailed("GPU stroke commit failed: missing base snapshot"))
        )
    }

    func testPreviewOutcomeAppliesGpuRenderState() {
        let feature = AppFeature()
        var state = AppFeature.State()
        let snapshot = MetalDocumentSnapshot(
            width: 4,
            height: 4,
            revision: 12,
            compositePixelData: Data(repeating: 0, count: 64),
            layers: []
        )
        let handle = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)

        feature.applyStrokePreviewOutcome(
            .preview(
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
                )
            ),
            activeLayerIndex: 0,
            state: &state
        )

        XCTAssertEqual(state.canvas.strokeSession.baseSnapshot?.revision, 12)
        XCTAssertEqual(state.canvas.strokeSession.renderState?.surfaceHandle, handle)
        XCTAssertEqual(state.canvas.strokeSession.renderState?.dirtyRect, LayerPixelRect(originX: 1, originY: 1, width: 2, height: 2))
        XCTAssertEqual(state.canvas.strokeSession.renderState?.isApproximatePreview, true)
    }

    func testGpuCommitOutcomeAppliesLayerSurfaceMutation() {
        let surfaceCalls = TestRecorder<GpuLayerMutationPayload>()
        let handle = MetalBufferHandle(width: 4, height: 4, bytesPerRow: 16)

        let result = withDependencies {
            $0.documentRuntimeComposition = .stub(
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
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            return feature.resolveStrokeCommit(
                state: &state,
                samples: [.testValue()],
                context: AppFeature.CanvasStrokeContext(
                    activeLayer: .testValue(),
                    activeLayerIndex: 0,
                    brush: feature.resolvedBrushSettings(for: state),
                    previewBrush: feature.resolvedBrushSettings(for: state)
                ),
                keepsSelectionCleared: false,
                refreshViaDirtyPresentation: true
            )
        }

        XCTAssertEqual(result, .committed(DocumentMutationContract(canvasMutation: .none, refresh: .dirty, updatesWorkspaceArtifacts: false)))
        XCTAssertEqual(surfaceCalls.values.first?.gpuBufferHandle, handle)
        XCTAssertEqual(surfaceCalls.values.first?.dirtyRect, LayerPixelRect(originX: 1, originY: 1, width: 2, height: 2))
    }

    func testFillFailureRemainsTyped() {
        let sample = StylusSample.testValue()
        let result = withDependencies {
            $0.documentInteractionService = .stub(
                execute: { request in
                    switch request {
                    case .fill:
                        return .failure(.invalidLayerIndex(4))
                    default:
                        return .success(.none)
                    }
                }
            )
        } operation: {
            let feature = AppFeature()
            return feature.documentInteractionService.fill(
                sample,
                brush: feature.resolvedBrushSettings(for: AppFeature.State())
            )
        }

        XCTAssertEqual(result, .failure(.invalidLayerIndex(4)))
    }

    func testLayerContentTransactionRollsBackCreatedLayerOnFailure() {
        let addLayerCalls = TestRecorder<String>()
        let deleteLayerCalls = TestRecorder<Int>()
        let setActiveLayerCalls = TestRecorder<Int>()

        let result = withDependencies {
            $0.documentRuntimeComposition = .stub(
                queryGateway: .stub(
                    presentation: .testValue(activeLayerIndex: 3)
                ),
                mutationGateway: .stub(
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
                )
            )
        } operation: {
            let feature = AppFeature()
            return feature.layerContentWorkflowService.applyPixels(
                Data([0x00]),
                to: .newLayer(name: "Imported")
            )
        }

        XCTAssertEqual(result, .failure(.bridgeMutationFailed("replace failed")))
        XCTAssertEqual(addLayerCalls.values, ["Imported"])
        XCTAssertEqual(deleteLayerCalls.values, [7])
        XCTAssertEqual(setActiveLayerCalls.values, [3])
    }

    func testLayerContentTransactionSurfacesRollbackFailure() {
        let result = withDependencies {
            $0.documentRuntimeComposition = .stub(
                queryGateway: .stub(
                    presentation: .testValue(activeLayerIndex: 3)
                ),
                mutationGateway: .stub(
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
                )
            )
        } operation: {
            let feature = AppFeature()
            return feature.layerContentWorkflowService.applyPixels(
                Data([0x00]),
                to: .newLayer(name: "Imported")
            )
        }

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

        withDependencies {
            $0.documentRuntimeComposition = .stub(
                queryGateway: .stub(
                    presentation: .testValue(activeLayerIndex: 2)
                ),
                mutationGateway: .stub(
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
                )
            )
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            let descriptor = NanoBananaEditDescriptor(
                prompt: NonEmptyPrompt("Retouch")!,
                accessMode: .appManaged,
                model: .flashImage25,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .newLayer
            )
            let preview = NanoBananaPreviewState(
                descriptor: descriptor,
                outputLayerIndex: 0,
                pixelData: Data([0x00]),
                beforePreviewImageData: nil,
                afterPreviewImageData: nil
            )

            feature.handleNanoBananaEditSucceeded(
                state: &state,
                preview: preview
            )
        }

        XCTAssertEqual(addLayerCalls.values.count, 1)
        XCTAssertEqual(deleteLayerCalls.values, [9])
        XCTAssertEqual(setActiveLayerCalls.values, [9, 2])
    }
}
