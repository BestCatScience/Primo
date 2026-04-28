import XCTest
@testable import Primo

final class DocumentMutationFeedbackMapperTests: XCTestCase {
    func testInvalidOpacityUsesDedicatedFeedback() {
        let mapper = DocumentFeatureRuntimeReducer().documentMutationFeedbackMapper

        XCTAssertEqual(
            mapper.feedback(for: .invalidOpacity(1.4)),
            .invalidLayerOpacity
        )
    }

    func testPrimaryDocumentMutationFailuresMapToUserVisibleFeedback() {
        let mapper = DocumentFeatureRuntimeReducer().documentMutationFeedbackMapper

        XCTAssertEqual(mapper.feedback(for: .invalidLayerIndex(2)), .layerUnavailable)
        XCTAssertEqual(mapper.feedback(for: .invalidFolderID(7)), .folderUnavailable)
        XCTAssertEqual(mapper.feedback(for: .layerLocked(1)), .layerEditLocked)
        XCTAssertEqual(mapper.feedback(for: .alphaLocked(1)), .layerAlphaEditLocked)
        XCTAssertEqual(mapper.feedback(for: .emptyInput), .emptyDocumentMutationInput)
        XCTAssertEqual(
            mapper.feedback(for: .bridgeMutationFailed("bridge failed")),
            .documentMutationBridgeFailed("bridge failed")
        )
        XCTAssertEqual(mapper.feedback(for: .incompatibleLayerType(3)), .unsupportedLayerType)
        XCTAssertEqual(
            mapper.feedback(
                for: .transactionFailure(
                    primary: .layerLocked(1),
                    rollback: .bridgeMutationFailed("rollback failed")
                )
            ),
            .documentMutationTransactionFailed(
                .layerLocked(1),
                .bridgeMutationFailed("rollback failed")
            )
        )
    }
}
