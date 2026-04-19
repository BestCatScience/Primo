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
        let gateway = StructureGatewayStub(duplicateLayerResult: 5)

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
}

private struct StructureGatewayStub: LayerStructureGateway {
    var duplicateLayerResult: Int = -1

    func addLayer(name: String) -> Int { 0 }
    func setActiveLayerIndex(_ index: Int) {}
    func duplicateLayer(index: Int, name: String) -> Int { duplicateLayerResult }
    func deleteLayer(index: Int) -> DocumentLayerMutationResult { .success(()) }
    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentLayerMutationResult { .success(()) }
    func createFolder(name: String, anchorLayerIndex: Int) -> Int { 9 }
    func deleteFolder(id folderID: Int) -> DocumentLayerMutationResult { .success(()) }
    func assignLayer(index: Int, toFolder folderID: Int) -> DocumentLayerMutationResult { .success(()) }
}

private struct AttributeGatewayStub: LayerAttributeGateway {
    func setActiveLayerIndex(_ index: Int) {}
    func setLayerName(_ name: String, index: Int) {}
    func setLayerVisible(_ isVisible: Bool, index: Int) {}
    func setLayerLocked(_ isLocked: Bool, index: Int) {}
    func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: Int) {}
    func setLayerClipped(_ isClipped: Bool, index: Int) {}
    func setLayerOpacity(_ opacity: Double, index: Int) {}
    func setLayerBlendMode(_ blendMode: LayerBlendMode, index: Int) {}
    func setFolderExpanded(_ isExpanded: Bool, folderID: Int) {}
    func setFolderVisible(_ isVisible: Bool, folderID: Int) {}
    func setFolderName(_ name: String, folderID: Int) {}
}
