import ComposableArchitecture
import XCTest
@testable import Primo

final class CanvasStrokeWorkflowTests: XCTestCase {
    private static func oilSmudgeBrush() -> BrushRuntimeSettings {
        BrushRuntimeSettings(
            tipKind: .oil,
            radius: 8,
            opacity: 1,
            hardness: 0.8,
            roundness: 0.8,
            angle: 0,
            angleMode: .strokeDirection,
            stampSpacing: 0.1,
            spacingJitter: 0,
            scatterLateral: 0,
            scatterLinear: 0,
            count: 1,
            countJitter: 0,
            angleJitter: 0,
            roundnessJitter: 0,
            textureMode: .strokeLocked,
            textureStrength: 0.2,
            wetness: 0.12,
            colorMixStrength: 0.1,
            smudgeRadius: 0.36,
            paintLoad: 0.92,
            smudgeEngineEnabled: true,
            smudgeMode: .smearing,
            smudgeLength: 0.4,
            colorRate: 0.46,
            pressureSensitivity: 0.16,
            red: 46,
            green: 50,
            blue: 58
        )
    }

    func testPrepareCanvasStrokeEditingReturnsTypedFailure() {
        let result = withDependencies {
            $0.documentInteractionService = .stub(
                execute: { request in
                    switch request {
                    case .ensureLayerVisible:
                        return .failure(.layerLocked(0))
                    default:
                        return .success(.none)
                    }
                }
            )
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            return feature.prepareCanvasStrokeEditing(state: &state)
        }

        XCTAssertEqual(result, .failure(.layerLocked(0)))
    }

    func testCommittedStrokeCommitReturnsBridgeFailureWhenSnapshotIsMissing() {
        let result = withDependencies {
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            return feature.commitStrokeUsingCommittedPixels(
                state: &state,
                samples: [.testValue()],
                brush: feature.resolvedBrushSettings(for: state),
                activeLayer: .testValue(),
                refreshViaDirtyPresentation: false
            )
        }

        XCTAssertEqual(
            result,
            .failure(.bridgeMutationFailed("Missing GPU committed stroke snapshot"))
        )
    }

    func testResponsiveOilApproximatePreviewCommitsRectPixels() {
        let replaceCalls = TestRecorder<DocumentInteractionRequest>()
        let fallbackCalls = TestRecorder<[StylusSample]>()

        let result = withDependencies {
            $0.documentInteractionService = .stub(
                execute: { request in
                    switch request {
                    case .replaceLayerPixels, .replaceLayerPixelsInRect:
                        replaceCalls.record(request)
                    default:
                        break
                    }
                    return .success(.none)
                }
            )
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            state.brushPalette.ui.oilLivePreviewQuality = .responsive
            state.canvas.activeStrokePreviewIsApproximate = true
            state.canvas.setStrokePreviewRectPixelData(
                Data(repeating: 0x22, count: 16),
                dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2)
            )

            let service = AppFeature.CanvasStrokeCommitService(
                workflowService: feature.documentInteractionService,
                strokeProcessingService: feature.canvasStrokeProcessingService
            )
            let samples = [StylusSample.testValue()]
            return service.resolve(
                state: &state,
                samples: samples,
                context: AppFeature.CanvasStrokeContext(
                    activeLayer: .testValue(),
                    activeLayerIndex: 0,
                    brush: Self.oilSmudgeBrush(),
                    previewBrush: Self.oilSmudgeBrush()
                ),
                keepsSelectionCleared: false,
                refreshViaDirtyPresentation: true,
                clearSelectionWithoutRefresh: { _ in },
                commitFallbackPixels: { _, fallbackSamples, _, _, _ in
                    fallbackCalls.record(fallbackSamples)
                    return .success(())
                }
            )
        }

        XCTAssertEqual(fallbackCalls.values.count, 0)
        XCTAssertEqual(replaceCalls.values.count, 1)
        if case let .replaceLayerPixelsInRect(layerIndex, rect, pixelData) = replaceCalls.values.first {
            XCTAssertEqual(layerIndex, 0)
            XCTAssertEqual(rect, LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2))
            XCTAssertEqual(pixelData, Data(repeating: 0x22, count: 16))
        } else {
            XCTFail("Expected rect pixel commit")
        }
        XCTAssertEqual(result, .committed(DocumentMutationContract(canvasMutation: .none, refresh: .dirty, updatesWorkspaceArtifacts: false)))
    }

    func testResponsiveOilApproximatePreviewCommitsFullPixels() {
        let replaceCalls = TestRecorder<DocumentInteractionRequest>()
        let fallbackCalls = TestRecorder<[StylusSample]>()

        let result = withDependencies {
            $0.documentInteractionService = .stub(
                execute: { request in
                    switch request {
                    case .replaceLayerPixels, .replaceLayerPixelsInRect:
                        replaceCalls.record(request)
                    default:
                        break
                    }
                    return .success(.none)
                }
            )
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            state.brushPalette.ui.oilLivePreviewQuality = .responsive
            state.canvas.activeStrokePreviewIsApproximate = true
            state.canvas.setStrokePreviewLayerPixelData(Data(repeating: 0x33, count: 16))

            let service = AppFeature.CanvasStrokeCommitService(
                workflowService: feature.documentInteractionService,
                strokeProcessingService: feature.canvasStrokeProcessingService
            )
            return service.resolve(
                state: &state,
                samples: [.testValue()],
                context: AppFeature.CanvasStrokeContext(
                    activeLayer: .testValue(),
                    activeLayerIndex: 0,
                    brush: Self.oilSmudgeBrush(),
                    previewBrush: Self.oilSmudgeBrush()
                ),
                keepsSelectionCleared: false,
                refreshViaDirtyPresentation: true,
                clearSelectionWithoutRefresh: { _ in },
                commitFallbackPixels: { _, fallbackSamples, _, _, _ in
                    fallbackCalls.record(fallbackSamples)
                    return .success(())
                }
            )
        }

        XCTAssertEqual(fallbackCalls.values.count, 0)
        XCTAssertEqual(replaceCalls.values.count, 1)
        if case let .replaceLayerPixels(layerIndex, pixelData) = replaceCalls.values.first {
            XCTAssertEqual(layerIndex, 0)
            XCTAssertEqual(pixelData, Data(repeating: 0x33, count: 16))
        } else {
            XCTFail("Expected full pixel commit")
        }
        XCTAssertEqual(result, .committed(DocumentMutationContract(canvasMutation: .none, refresh: .dirty, updatesWorkspaceArtifacts: false)))
    }

    func testHighFidelityOilApproximatePreviewFallsBackToCommittedPixels() {
        let replaceCalls = TestRecorder<DocumentInteractionRequest>()
        let fallbackCalls = TestRecorder<[StylusSample]>()

        let result = withDependencies {
            $0.documentInteractionService = .stub(
                execute: { request in
                    switch request {
                    case .replaceLayerPixels, .replaceLayerPixelsInRect:
                        replaceCalls.record(request)
                    default:
                        break
                    }
                    return .success(.none)
                }
            )
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            state.brushPalette.ui.oilLivePreviewQuality = .highFidelity
            state.canvas.activeStrokePreviewIsApproximate = true
            state.canvas.setStrokePreviewLayerPixelData(Data(repeating: 0x11, count: 16))
            state.canvas.setStrokePreviewRectPixelData(
                Data(repeating: 0x22, count: 16),
                dirtyRect: LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2)
            )

            let service = AppFeature.CanvasStrokeCommitService(
                workflowService: feature.documentInteractionService,
                strokeProcessingService: feature.canvasStrokeProcessingService
            )
            let samples = [StylusSample.testValue()]
            return service.resolve(
                state: &state,
                samples: samples,
                context: AppFeature.CanvasStrokeContext(
                    activeLayer: .testValue(),
                    activeLayerIndex: 0,
                    brush: Self.oilSmudgeBrush(),
                    previewBrush: Self.oilSmudgeBrush()
                ),
                keepsSelectionCleared: false,
                refreshViaDirtyPresentation: true,
                clearSelectionWithoutRefresh: { _ in },
                commitFallbackPixels: { _, fallbackSamples, _, _, _ in
                    fallbackCalls.record(fallbackSamples)
                    return .success(())
                }
            )
        }

        XCTAssertEqual(replaceCalls.values, [])
        XCTAssertEqual(fallbackCalls.values.count, 1)
        XCTAssertEqual(result, .committed(DocumentMutationContract(canvasMutation: .none, refresh: .dirty, updatesWorkspaceArtifacts: false)))
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
