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
}
