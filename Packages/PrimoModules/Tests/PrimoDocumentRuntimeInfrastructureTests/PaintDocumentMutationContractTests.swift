import Foundation
import Testing
@testable import PrimoDocumentRuntimeInfrastructure

struct PaintDocumentMutationContractTests {
    @Test
    func redoRejectsMissingHistory() {
        let runtime = DocumentRuntimeFactory.live()
        #expect(runtime.historyGateway.canRedo() == false)
        expectFailure(runtime.historyGateway.redo(), .noRedoState)
    }

    @Test
    func setActiveLayerRejectsInvalidLayerIndex() {
        let runtime = DocumentRuntimeFactory.live()
        expectFailure(runtime.mutationGateway.setActiveLayer(99), .invalidLayerIndex(99))
    }

    @Test
    func clearLayerRejectsLockedLayer() {
        let runtime = DocumentRuntimeFactory.live()
        expectSuccess(runtime.setLayerLocked(0, true))
        expectFailure(runtime.mutationGateway.clearLayer(0), .layerLocked(0))
    }

    @Test
    func setLayerOpacityRejectsInvalidOpacity() {
        let runtime = DocumentRuntimeFactory.live()
        expectFailure(runtime.setLayerOpacity(0, 1.4), .invalidOpacity(1.4))
    }

    @Test
    func assignLayerRejectsInvalidFolderID() {
        let runtime = DocumentRuntimeFactory.live()
        expectFailure(runtime.assignLayerToFolder(0, 999), .invalidFolderID(999))
    }

    @Test
    func replaceLayerPixelsRejectsEmptyInput() {
        let runtime = DocumentRuntimeFactory.live()
        expectFailure(runtime.mutationGateway.replaceLayerPixels(0, Data()), .emptyInput)
    }

    @Test
    func replaceLayerPixelsInRectRejectsEmptyInput() {
        let runtime = DocumentRuntimeFactory.live()
        let rect = LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2)
        expectFailure(runtime.mutationGateway.replaceLayerPixelsInRect(0, rect, Data()), .emptyInput)
    }

    @Test
    func replaceLayerPixelsInRectRejectsMismatchedRectPayload() {
        let runtime = DocumentRuntimeFactory.live()
        let rect = LayerPixelRect(originX: 0, originY: 0, width: 2, height: 2)
        expectFailure(
            runtime.mutationGateway.replaceLayerPixelsInRect(0, rect, Data(count: 4)),
            .bridgeMutationFailed("replaceLayerPixelsInRect")
        )
    }

    private func expectSuccess(_ result: DocumentMutationResult) {
        switch result {
        case .success:
            #expect(Bool(true))
        case let .failure(failure):
            Issue.record("Expected success, got \(String(describing: failure))")
        }
    }

    private func expectFailure(_ result: DocumentMutationResult, _ expected: DocumentMutationFailure) {
        switch result {
        case .success:
            Issue.record("Expected failure \(String(describing: expected)), got success")
        case let .failure(failure):
            #expect(failure == expected)
        }
    }
}
