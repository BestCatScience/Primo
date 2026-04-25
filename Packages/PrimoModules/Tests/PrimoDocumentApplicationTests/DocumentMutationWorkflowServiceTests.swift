import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import Testing

struct DocumentMutationWorkflowServiceTests {
    @Test
    func layerStructureCommandsReturnResultingIndexes() throws {
        let service = DocumentMutationWorkflowService(
            documentEditingGateway: DocumentEditingGateway { request in
                switch request {
                case .structure(.duplicateLayer):
                    return .success(.structure(LayerStructureMutationPlan(resultingIndex: 4)))
                default:
                    return .failure(.bridgeMutationFailed("unexpected"))
                }
            },
            documentLayerEffectsGateway: .unused,
            documentMutationGateway: .unused,
            textLayerGateway: .unused
        )

        let index = try service.duplicateLayer(1, named: "Copy").get()

        #expect(index == 4)
    }

    @Test
    func directLayerContentCommandsRouteThroughMutationGateways() throws {
        let recorder = MutationRecorder()
        let service = DocumentMutationWorkflowService(
            documentEditingGateway: .failing,
            documentLayerEffectsGateway: .unused,
            documentMutationGateway: DocumentMutationGateway.stub(
                clearLayer: {
                    recorder.clearedLayerIndex = $0
                    return .success(())
                },
                applyLayerMask: {
                    recorder.appliedMaskIndex = $0
                    return .success(())
                }
            ),
            textLayerGateway: .unused
        )

        try service.clearLayer(2).get()
        try service.applyLayerMask(3).get()

        #expect(recorder.clearedLayerIndex == 2)
        #expect(recorder.appliedMaskIndex == 3)
    }

    @Test
    func failedCommandsReturnFailureWithoutOutcomeSideEffects() {
        let service = DocumentMutationWorkflowService(
            documentEditingGateway: DocumentEditingGateway { _ in
                .failure(.layerLocked(7))
            },
            documentLayerEffectsGateway: .unused,
            documentMutationGateway: .unused,
            textLayerGateway: .unused
        )

        let result: DocumentMutationResult = service.setLayerVisibility(7, visible: true)

        guard case let .failure(failure) = result else {
            Issue.record("Expected layerLocked failure")
            return
        }
        #expect(failure == .layerLocked(7))
    }
}

private final class MutationRecorder: @unchecked Sendable {
    var clearedLayerIndex: Int?
    var appliedMaskIndex: Int?
}

private extension DocumentEditingGateway {
    static let failing = DocumentEditingGateway { _ in
        .failure(.bridgeMutationFailed("unused"))
    }
}

private extension DocumentLayerEffectsGateway {
    static let unused = DocumentLayerEffectsGateway(
        mergeLayerDown: { _ in .failure(.bridgeMutationFailed("unused")) }
    )
}

private extension TextLayerGateway {
    static let unused = TextLayerGateway(
        textLayerData: { _ in nil },
        setTextLayer: { _, _ in .failure(.bridgeMutationFailed("unused")) },
        clearTextLayerData: { _ in }
    )
}

private extension DocumentMutationGateway {
    static let unused = stub()

    static func stub(
        clearLayer: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .failure(.bridgeMutationFailed("unused")) },
        applyLayerMask: @escaping @Sendable (Int) -> DocumentMutationResult = { _ in .failure(.bridgeMutationFailed("unused")) }
    ) -> DocumentMutationGateway {
        DocumentMutationGateway(
            resizeCanvas: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            resizeCanvasExtent: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            addLayer: { _ in .failure(.bridgeMutationFailed("unused")) },
            deleteLayer: { _ in .failure(.bridgeMutationFailed("unused")) },
            setActiveLayer: { _ in .failure(.bridgeMutationFailed("unused")) },
            setLayerName: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            setLayerVisibility: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            revealLayerForEditing: { _ in .failure(.bridgeMutationFailed("unused")) },
            replaceLayerPixels: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            replaceLayerPixelsInRect: { _, _, _ in .failure(.bridgeMutationFailed("unused")) },
            applyLayerSurfaceMutation: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            applyLayerMutation: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            applyTextLayerMutation: { _, _, _ in .failure(.bridgeMutationFailed("unused")) },
            replaceLayerMask: { _, _ in .failure(.bridgeMutationFailed("unused")) },
            clearLayerMask: { _ in .failure(.bridgeMutationFailed("unused")) },
            applyLayerMask: applyLayerMask,
            clearLayer: clearLayer,
            applyLayerProcessing: { _, _ in .failure(.bridgeMutationFailed("unused")) }
        )
    }
}
