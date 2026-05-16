import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import Testing

struct DocumentLayerMutationUseCaseTests {
    @Test
    func mutationContextEmbedsRevisionInValidatedLayerIndexes() throws {
        let context = DocumentLayerMutationContext(
            revision: DocumentRevision(42),
            layerCount: 3,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )

        let existingIndex = try #require(context.existingLayerIndex(1))
        let createdIndex = context.newlyCreatedLayerIndex(3)

        #expect(existingIndex.rawValue == 1)
        #expect(existingIndex.revision == DocumentRevision(42))
        #expect(createdIndex.rawValue == 3)
        #expect(createdIndex.revision == DocumentRevision(43))
    }

    @Test
    func structureUseCaseBuildsDuplicatePlanAndIndexMutation() {
        let useCase = LayerStructureUseCase()
        let context = DocumentLayerMutationContext(
            layerCount: 3,
            folderIDs: [4],
            isLayerLocked: { _ in false }
        )
        let gateway = StructureGatewayStub(duplicateLayerResult: .success(DocumentCreatedLayerIndex(5)))

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
    func structureUseCasePropagatesAtomicAddLayerFailure() {
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
        #expect(gateway.addedLayerNames == ["Ink"])
    }

    @Test
    func structureUseCaseBuildsAddLayerPlanFromAtomicAddLayer() throws {
        let useCase = LayerStructureUseCase()
        let context = DocumentLayerMutationContext(
            layerCount: 1,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )
        let gateway = StructureGatewayRecorder(
            addLayerResult: .success(.addedAndSelected(DocumentCreatedLayerIndex(3)))
        )

        let result = useCase.execute(
            .addLayer(name: "Ink"),
            in: context,
            gateway: gateway
        )

        let plan = try result.get()
        #expect(plan.resultingIndex == 3)
        #expect(plan.lifecycleEvent == .addLayer(name: "Ink", index: 3))
        #expect(gateway.addedLayerNames == ["Ink"])
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
    var addLayerResult: DocumentLayerAddSelectionResult = .success(.addedAndSelected(DocumentCreatedLayerIndex(0)))
    var duplicateLayerResult: DocumentLayerCreatedMutationResult = .success(DocumentCreatedLayerIndex(5))
    var createFolderResult: DocumentFolderCreatedMutationResult = .success(DocumentCreatedFolderID(9))

    func addLayerAndSelect(name: String) -> DocumentLayerAddSelectionResult { addLayerResult }
    func duplicateLayer(index: ExistingLayerIndex, name: String) -> DocumentLayerCreatedMutationResult { duplicateLayerResult }
    func deleteLayer(index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func moveLayer(from index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func createFolder(name: String, anchorLayerIndex: LayerAnchorIndex) -> DocumentFolderCreatedMutationResult { createFolderResult }
    func deleteFolder(id folderID: ExistingFolderID) -> DocumentLayerMutationResult { .success(()) }
    func assignLayer(index: ExistingLayerIndex, toFolder folderID: ExistingFolderID?) -> DocumentLayerMutationResult { .success(()) }
}

private final class StructureGatewayRecorder: @unchecked Sendable, LayerStructureGateway {
    var addLayerResult: DocumentLayerAddSelectionResult
    var addedLayerNames: [String] = []

    init(
        addLayerResult: DocumentLayerAddSelectionResult = .success(.addedAndSelected(DocumentCreatedLayerIndex(0)))
    ) {
        self.addLayerResult = addLayerResult
    }

    func addLayerAndSelect(name: String) -> DocumentLayerAddSelectionResult {
        addedLayerNames.append(name)
        return addLayerResult
    }

    func duplicateLayer(index: ExistingLayerIndex, name: String) -> DocumentLayerCreatedMutationResult { .success(DocumentCreatedLayerIndex(5)) }
    func deleteLayer(index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func moveLayer(from index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func createFolder(name: String, anchorLayerIndex: LayerAnchorIndex) -> DocumentFolderCreatedMutationResult { .success(DocumentCreatedFolderID(9)) }
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
