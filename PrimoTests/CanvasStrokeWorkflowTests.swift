import ComposableArchitecture
import XCTest
@testable import Primo

final class CanvasStrokeWorkflowTests: XCTestCase {
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

    func testFallbackStrokeCommitReturnsBridgeFailureWhenSnapshotIsMissing() {
        let result = withDependencies {
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            return feature.commitStrokeUsingFallbackPixels(
                state: &state,
                samples: [.testValue()],
                brush: feature.resolvedBrushSettings(for: state),
                activeLayer: .testValue(),
                refreshViaDirtyPresentation: false
            )
        }

        XCTAssertEqual(
            result,
            .failure(.bridgeMutationFailed("Missing fallback stroke snapshot"))
        )
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
