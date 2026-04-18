import Foundation
import XCTest
@testable import Primo

final class PaintDocumentMutationContractTests: XCTestCase {
    func testSessionSetActiveLayerRejectsInvalidLayerIndex() {
        let session = PaintDocumentSession()

        XCTAssertEqual(
            session.setActiveLayer(index: 99),
            .failure(.invalidLayerIndex(99))
        )
    }

    func testSessionClearLayerRejectsLockedLayer() {
        let session = PaintDocumentSession()
        XCTAssertEqual(
            session.setLayerLocked(index: 0, isLocked: true),
            .success(())
        )

        XCTAssertEqual(
            session.clearLayer(index: 0),
            .failure(.layerLocked(0))
        )
    }

    func testSessionSetLayerOpacityRejectsInvalidOpacity() {
        let session = PaintDocumentSession()

        XCTAssertEqual(
            session.setLayerOpacity(index: 0, opacity: 1.4),
            .failure(.invalidOpacity(1.4))
        )
    }

    func testClientReplaceLayerPixelsRejectsEmptyInput() {
        let client = PaintDocumentClient.live(
            fileClient: .live,
            dateClient: .live,
            uuidClient: .live
        )

        XCTAssertEqual(
            client.replaceLayerPixels(0, Data()),
            .failure(.emptyInput)
        )
    }
}
