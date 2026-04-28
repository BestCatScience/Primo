import PrimoDocumentApplication
import PrimoDocumentDomain
import Testing

private final class DocumentEditorGatewaySpy: @unchecked Sendable, DocumentEditorGateway {
    var addedLayerNames: [String] = []
    var activeLayerIndices: [Int] = []
    var lastLayerNameUpdate: (name: String, index: Int)?

    func addLayer(name: String) -> DocumentLayerIndexedMutationResult {
        addedLayerNames.append(name)
        return .success(2)
    }

    func setActiveLayerIndex(_ index: Int) -> DocumentLayerMutationResult {
        activeLayerIndices.append(index)
        return .success(())
    }

    func duplicateLayer(index: Int, name: String) -> DocumentLayerIndexedMutationResult { .failure(.bridgeMutationFailed("unused")) }
    func deleteLayer(index: Int) -> DocumentLayerMutationResult { .success(()) }
    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentLayerMutationResult { .success(()) }
    func createFolder(name: String, anchorLayerIndex: Int) -> DocumentLayerIndexedMutationResult { .success(1) }
    func deleteFolder(id folderID: Int) -> DocumentLayerMutationResult { .success(()) }
    func assignLayer(index: Int, toFolder folderID: Int) -> DocumentLayerMutationResult { .success(()) }

    func setLayerName(_ name: String, index: Int) -> DocumentLayerMutationResult {
        lastLayerNameUpdate = (name, index)
        return .success(())
    }

    func setLayerVisible(_ isVisible: Bool, index: Int) -> DocumentLayerMutationResult { .success(()) }
    func setLayerLocked(_ isLocked: Bool, index: Int) -> DocumentLayerMutationResult { .success(()) }
    func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: Int) -> DocumentLayerMutationResult { .success(()) }
    func setLayerClipped(_ isClipped: Bool, index: Int) -> DocumentLayerMutationResult { .success(()) }
    func setLayerOpacity(_ opacity: Double, index: Int) -> DocumentLayerMutationResult { .success(()) }
    func setLayerBlendMode(_ blendMode: LayerBlendMode, index: Int) -> DocumentLayerMutationResult { .success(()) }
    func setFolderExpanded(_ isExpanded: Bool, folderID: Int) -> DocumentLayerMutationResult { .success(()) }
    func setFolderVisible(_ isVisible: Bool, folderID: Int) -> DocumentLayerMutationResult { .success(()) }
    func setFolderName(_ name: String, folderID: Int) -> DocumentLayerMutationResult { .success(()) }
}

struct DocumentEditorUseCaseTests {
    @Test
    func structureRequestUsesLayerStructureGateway() throws {
        let useCase = DocumentEditorUseCase()
        let gateway = DocumentEditorGatewaySpy()
        let context = DocumentLayerMutationContext(
            layerCount: 2,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )

        let result = useCase.execute(
            .structure(.addLayer(name: "Ink")),
            in: context,
            gateway: gateway
        )

        let plan = try result.get()
        #expect(plan == .structure(
            LayerStructureMutationPlan(
                resultingIndex: 2,
                lifecycleEvent: .addLayer(name: "Ink", index: 2)
            )
        ))
        #expect(gateway.addedLayerNames == ["Ink"])
        #expect(gateway.activeLayerIndices == [2])
    }

    @Test
    func attributeRequestUsesLayerAttributeGateway() throws {
        let useCase = DocumentEditorUseCase()
        let gateway = DocumentEditorGatewaySpy()
        let context = DocumentLayerMutationContext(
            layerCount: 3,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )

        let result = useCase.execute(
            .attribute(.setLayerName(index: 1, name: "Foreground")),
            in: context,
            gateway: gateway
        )

        let plan = try result.get()
        #expect(plan == .attribute(LayerAttributeMutationPlan()))
        #expect(gateway.lastLayerNameUpdate?.name == "Foreground")
        #expect(gateway.lastLayerNameUpdate?.index == 1)
    }
}
