import PrimoDocumentApplication
import PrimoDocumentDomain
import Testing

private final class DocumentEditorGatewaySpy: @unchecked Sendable, DocumentEditorGateway {
    var addedLayerNames: [String] = []
    var activeLayerIndices: [Int] = []
    var lastLayerNameUpdate: (name: String, index: Int)?

    func addLayer(name: String) -> Int {
        addedLayerNames.append(name)
        return 2
    }

    func setActiveLayerIndex(_ index: Int) {
        activeLayerIndices.append(index)
    }

    func duplicateLayer(index: Int, name: String) -> Int { -1 }
    func deleteLayer(index: Int) -> DocumentLayerMutationResult { .success(()) }
    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentLayerMutationResult { .success(()) }
    func createFolder(name: String, anchorLayerIndex: Int) -> Int { 1 }
    func deleteFolder(id folderID: Int) -> DocumentLayerMutationResult { .success(()) }
    func assignLayer(index: Int, toFolder folderID: Int) -> DocumentLayerMutationResult { .success(()) }

    func setLayerName(_ name: String, index: Int) {
        lastLayerNameUpdate = (name, index)
    }

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

        let plan = try #require(try result.get())
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

        let plan = try #require(try result.get())
        #expect(plan == .attribute(LayerAttributeMutationPlan()))
        #expect(gateway.lastLayerNameUpdate?.name == "Foreground")
        #expect(gateway.lastLayerNameUpdate?.index == 1)
    }
}
