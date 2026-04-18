import ComposableArchitecture
import XCTest
@testable import Primo

final class CanvasStrokeWorkflowTests: XCTestCase {
    func testPrepareCanvasStrokeEditingReturnsTypedFailure() {
        let result = withDependencies {
            $0.paintDocumentClient = .stub(
                setLayerVisibility: { _, _ in
                    .failure(.layerLocked(0))
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
            $0.paintDocumentClient = .stub()
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
            $0.paintDocumentClient = .stub(
                fill: { _, _ in
                    .failure(.invalidLayerIndex(4))
                }
            )
        } operation: {
            let feature = AppFeature()
            return feature.canvasStrokeWorkflowService.fill(
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
            $0.paintDocumentClient = .stub(
                presentation: .testValue(activeLayerIndex: 3),
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

    func testNanoBananaApplyRollsBackCreatedLayerOnFailure() {
        let addLayerCalls = TestRecorder<String>()
        let deleteLayerCalls = TestRecorder<Int>()
        let setActiveLayerCalls = TestRecorder<Int>()

        withDependencies {
            $0.paintDocumentClient = .stub(
                presentation: .testValue(activeLayerIndex: 2),
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
        } operation: {
            let feature = AppFeature()
            var state = AppFeature.State()
            let request = NanoBananaGenerationRequest(
                prompt: "Retouch",
                config: NanoBananaRequestConfig(
                    accessMode: .appManaged,
                    credential: "",
                    endpoint: "https://example.com"
                ),
                model: .flashImage25,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .newLayer
            )
            let preview = NanoBananaPreviewState(
                request: request,
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
