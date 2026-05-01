import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import Testing

struct DocumentLayerMutationUseCaseTests {
    @Test
    func structureUseCaseBuildsDuplicatePlanAndIndexMutation() {
        let useCase = LayerStructureUseCase()
        let context = DocumentLayerMutationContext(
            layerCount: 3,
            folderIDs: [4],
            isLayerLocked: { _ in false }
        )
        let gateway = StructureGatewayStub(duplicateLayerResult: .success(5))

        let result = useCase.execute(
            .duplicateLayer(index: 1, name: "Copy"),
            in: context,
            gateway: gateway
        )

        let plan = try! result.get()
        #expect(plan.resultingIndex == 5)
        #expect(plan.indexMutation == .duplication(sourceIndex: 1, duplicatedIndex: 5))
        #expect(plan.lifecycleEvent == .duplicateLayer(index: 1, duplicatedIndex: 5, name: "Copy"))
    }

    @Test
    func structureUseCasePropagatesAddLayerFailureWithoutActivatingLayer() {
        let useCase = LayerStructureUseCase()
        let context = DocumentLayerMutationContext(
            layerCount: 1,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )
        let gateway = StructureGatewayRecorder(
            addLayerResult: .failure(.bridgeMutationFailed("addLayer"))
        )

        let result = useCase.execute(
            .addLayer(name: "Ink"),
            in: context,
            gateway: gateway
        )

        #expect(result == .failure(.bridgeMutationFailed("addLayer")))
        #expect(gateway.activeLayerIndices.isEmpty)
    }

    @Test
    func structureUseCasePropagatesActiveLayerFailureAfterAddingLayer() {
        let useCase = LayerStructureUseCase()
        let context = DocumentLayerMutationContext(
            layerCount: 1,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )
        let gateway = StructureGatewayRecorder(
            addLayerResult: .success(3),
            activeLayerResult: .failure(.bridgeMutationFailed("setActiveLayer"))
        )

        let result = useCase.execute(
            .addLayer(name: "Ink"),
            in: context,
            gateway: gateway
        )

        #expect(result == .failure(.bridgeMutationFailed("setActiveLayer")))
        #expect(gateway.activeLayerIndices == [3])
    }

    @Test
    func structureUseCasePropagatesDuplicateFailureWithoutSentinelIndex() {
        let useCase = LayerStructureUseCase()
        let context = DocumentLayerMutationContext(
            layerCount: 2,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )
        let gateway = StructureGatewayStub(
            duplicateLayerResult: .failure(.bridgeMutationFailed("duplicateLayer"))
        )

        let result = useCase.execute(
            .duplicateLayer(index: 1, name: "Copy"),
            in: context,
            gateway: gateway
        )

        #expect(result == .failure(.bridgeMutationFailed("duplicateLayer")))
    }

    @Test
    func structureUseCasePropagatesCreateFolderFailureWithoutSentinelID() {
        let useCase = LayerStructureUseCase()
        let context = DocumentLayerMutationContext(
            layerCount: 2,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )
        let gateway = StructureGatewayStub(
            createFolderResult: .failure(.bridgeMutationFailed("createFolder"))
        )

        let result = useCase.execute(
            .createFolder(name: "Group", anchorLayerIndex: 1),
            in: context,
            gateway: gateway
        )

        #expect(result == .failure(.bridgeMutationFailed("createFolder")))
    }

    @Test
    func attributeUseCaseRejectsInvalidOpacity() {
        let useCase = LayerAttributeUseCase()
        let context = DocumentLayerMutationContext(
            layerCount: 2,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )

        let result = useCase.execute(
            .setLayerOpacity(index: 0, opacity: 1.5),
            in: context,
            gateway: AttributeGatewayStub()
        )

        #expect(result == .failure(.invalidOpacity(1.5)))
    }

    @Test
    func attributeUseCaseProducesBlendModeLifecycleEvent() {
        let useCase = LayerAttributeUseCase()
        let context = DocumentLayerMutationContext(
            layerCount: 2,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )
        let gateway = AttributeGatewayStub()

        let result = useCase.execute(
            .setLayerBlendMode(index: 1, blendMode: .screen),
            in: context,
            gateway: gateway
        )

        let plan = try! result.get()
        #expect(plan.lifecycleEvent == .setLayerBlendMode(index: 1, blendMode: .screen))
    }

    @Test
    func attributeUseCasePropagatesSetterFailureWithoutLifecycleEvent() {
        let useCase = LayerAttributeUseCase()
        let context = DocumentLayerMutationContext(
            layerCount: 2,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )
        let gateway = AttributeGatewayStub(
            setLayerVisibleResult: .failure(.bridgeMutationFailed("setLayerVisible"))
        )

        let result = useCase.execute(
            .setLayerVisibility(index: 1, isVisible: false),
            in: context,
            gateway: gateway
        )

        #expect(result == .failure(.bridgeMutationFailed("setLayerVisible")))
    }
}

private struct StructureGatewayStub: LayerStructureGateway {
    var addLayerResult: DocumentLayerIndexedMutationResult = .success(0)
    var activeLayerResult: DocumentLayerMutationResult = .success(())
    var duplicateLayerResult: DocumentLayerIndexedMutationResult = .success(5)
    var createFolderResult: DocumentLayerIndexedMutationResult = .success(9)

    func addLayer(name: String) -> DocumentLayerIndexedMutationResult { addLayerResult }
    func setActiveLayerIndex(_ index: ExistingLayerIndex) -> DocumentLayerMutationResult { activeLayerResult }
    func duplicateLayer(index: ExistingLayerIndex, name: String) -> DocumentLayerIndexedMutationResult { duplicateLayerResult }
    func deleteLayer(index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func moveLayer(from index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func createFolder(name: String, anchorLayerIndex: LayerAnchorIndex) -> DocumentLayerIndexedMutationResult { createFolderResult }
    func deleteFolder(id folderID: ExistingFolderID) -> DocumentLayerMutationResult { .success(()) }
    func assignLayer(index: ExistingLayerIndex, toFolder folderID: ExistingFolderID?) -> DocumentLayerMutationResult { .success(()) }
}

private final class StructureGatewayRecorder: @unchecked Sendable, LayerStructureGateway {
    var addLayerResult: DocumentLayerIndexedMutationResult
    var activeLayerResult: DocumentLayerMutationResult
    var activeLayerIndices: [Int] = []

    init(
        addLayerResult: DocumentLayerIndexedMutationResult = .success(0),
        activeLayerResult: DocumentLayerMutationResult = .success(())
    ) {
        self.addLayerResult = addLayerResult
        self.activeLayerResult = activeLayerResult
    }

    func addLayer(name: String) -> DocumentLayerIndexedMutationResult { addLayerResult }

    func setActiveLayerIndex(_ index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        activeLayerIndices.append(index.rawValue)
        return activeLayerResult
    }

    func duplicateLayer(index: ExistingLayerIndex, name: String) -> DocumentLayerIndexedMutationResult { .success(5) }
    func deleteLayer(index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func moveLayer(from index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func createFolder(name: String, anchorLayerIndex: LayerAnchorIndex) -> DocumentLayerIndexedMutationResult { .success(9) }
    func deleteFolder(id folderID: ExistingFolderID) -> DocumentLayerMutationResult { .success(()) }
    func assignLayer(index: ExistingLayerIndex, toFolder folderID: ExistingFolderID?) -> DocumentLayerMutationResult { .success(()) }
}

private struct AttributeGatewayStub: LayerAttributeGateway {
    var setLayerVisibleResult: DocumentLayerMutationResult = .success(())

    func setActiveLayerIndex(_ index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setLayerName(_ name: String, index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setLayerVisible(_ isVisible: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult { setLayerVisibleResult }
    func setLayerLocked(_ isLocked: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setLayerClipped(_ isClipped: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setLayerOpacity(_ opacity: ValidatedLayerOpacity, index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setLayerBlendMode(_ blendMode: LayerBlendMode, index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setFolderExpanded(_ isExpanded: Bool, folderID: ExistingFolderID) -> DocumentLayerMutationResult { .success(()) }
    func setFolderVisible(_ isVisible: Bool, folderID: ExistingFolderID) -> DocumentLayerMutationResult { .success(()) }
    func setFolderName(_ name: String, folderID: ExistingFolderID) -> DocumentLayerMutationResult { .success(()) }
}
