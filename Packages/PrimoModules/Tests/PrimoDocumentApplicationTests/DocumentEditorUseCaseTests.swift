import PrimoDocumentApplication
import PrimoDocumentDomain
import Testing

private final class DocumentEditorGatewaySpy: @unchecked Sendable, DocumentEditorGateway {
    var addedLayerNames: [String] = []
    var activeLayerIndices: [Int] = []
    var lastLayerNameUpdate: (name: String, index: Int)?

    func addLayerAndSelect(name: String) -> DocumentLayerAddSelectionResult {
        addedLayerNames.append(name)
        return .success(.addedAndSelected(index: 2))
    }

    func setActiveLayerIndex(_ index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        activeLayerIndices.append(index.rawValue)
        return .success(())
    }

    func duplicateLayer(index: ExistingLayerIndex, name: String) -> DocumentLayerIndexedMutationResult { .failure(.bridgeMutationFailed("unused")) }
    func deleteLayer(index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func moveLayer(from index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func createFolder(name: String, anchorLayerIndex: LayerAnchorIndex) -> DocumentLayerIndexedMutationResult { .success(1) }
    func deleteFolder(id folderID: ExistingFolderID) -> DocumentLayerMutationResult { .success(()) }
    func assignLayer(index: ExistingLayerIndex, toFolder folderID: ExistingFolderID?) -> DocumentLayerMutationResult { .success(()) }

    func setLayerName(_ name: String, index: ExistingLayerIndex) -> DocumentLayerMutationResult {
        lastLayerNameUpdate = (name, index.rawValue)
        return .success(())
    }

    func setLayerVisible(_ isVisible: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setLayerLocked(_ isLocked: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setLayerClipped(_ isClipped: Bool, index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setLayerOpacity(_ opacity: ValidatedLayerOpacity, index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setLayerBlendMode(_ blendMode: LayerBlendMode, index: ExistingLayerIndex) -> DocumentLayerMutationResult { .success(()) }
    func setFolderExpanded(_ isExpanded: Bool, folderID: ExistingFolderID) -> DocumentLayerMutationResult { .success(()) }
    func setFolderVisible(_ isVisible: Bool, folderID: ExistingFolderID) -> DocumentLayerMutationResult { .success(()) }
    func setFolderName(_ name: String, folderID: ExistingFolderID) -> DocumentLayerMutationResult { .success(()) }
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
        #expect(gateway.activeLayerIndices.isEmpty)
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
