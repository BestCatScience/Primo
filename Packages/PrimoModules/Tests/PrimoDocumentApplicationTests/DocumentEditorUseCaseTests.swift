import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import Testing

private final class DocumentEditorGatewaySpy: @unchecked Sendable, DocumentEditorGateway {
    var addedLayerNames: [String] = []
    var activeLayerIndices: [Int] = []
    var lastLayerNameUpdate: (name: String, index: Int)?
    var contentEvents: [String] = []

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

    func replaceLayerPixels(index: EditableLayerIndex, pixelData: LayerPixelData) -> DocumentLayerMutationResult {
        contentEvents.append("replacePixels:\(index.rawValue):\(pixelData.rgba.count)")
        return .success(())
    }

    func setTextLayer(index: EditableLayerIndex, textLayer: TextLayerData) -> DocumentLayerMutationResult {
        contentEvents.append("text:\(index.rawValue):\(textLayer.text)")
        return .success(())
    }

    func clearLayer(index: EditableLayerIndex) -> DocumentLayerMutationResult {
        contentEvents.append("clear:\(index.rawValue)")
        return .success(())
    }

    func applyLayerProcessing(index: EditableLayerIndex, request: ValidatedLayerProcessingRequest) -> DocumentLayerMutationResult {
        contentEvents.append("process:\(index.rawValue):\(request.rawValue == .luminanceToAlpha)")
        return .success(())
    }

    func replaceLayerMask(index: EditableLayerIndex, mask: LayerMaskData) -> DocumentLayerMutationResult {
        contentEvents.append("replaceMask:\(index.rawValue):\(mask.bytes.count)")
        return .success(())
    }

    func clearLayerMask(index: EditableLayerIndex) -> DocumentLayerMutationResult {
        contentEvents.append("clearMask:\(index.rawValue)")
        return .success(())
    }

    func applyLayerMask(index: EditableLayerIndex) -> DocumentLayerMutationResult {
        contentEvents.append("applyMask:\(index.rawValue)")
        return .success(())
    }
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

    @Test
    func contentRequestUsesLayerContentGateway() throws {
        let useCase = DocumentEditorUseCase()
        let gateway = DocumentEditorGatewaySpy()
        let context = DocumentLayerMutationContext(
            layerCount: 3,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )
        let payload = try #require(LayerPixelData(width: 1, height: 1, rgba: Data(repeating: 1, count: 4)))

        let result = useCase.execute(
            .content(.replacePixels(index: 2, pixelData: payload)),
            in: context,
            gateway: gateway
        )

        #expect(try result.get() == .content(LayerContentMutationPlan()))
        #expect(gateway.contentEvents == ["replacePixels:2:4"])
    }

    @Test
    func processingContentRequestUsesValidatedRequestWrapper() throws {
        let useCase = DocumentEditorUseCase()
        let gateway = DocumentEditorGatewaySpy()
        let context = DocumentLayerMutationContext(
            layerCount: 2,
            folderIDs: [],
            isLayerLocked: { _ in false }
        )

        let result = useCase.execute(
            .content(.applyProcessing(index: 1, request: .luminanceToAlpha)),
            in: context,
            gateway: gateway
        )

        #expect(try result.get() == .content(LayerContentMutationPlan()))
        #expect(gateway.contentEvents == ["process:1:true"])
    }

    @Test
    func contentRequestRejectsLockedLayerBeforeGateway() throws {
        let useCase = DocumentEditorUseCase()
        let gateway = DocumentEditorGatewaySpy()
        let context = DocumentLayerMutationContext(
            layerCount: 1,
            folderIDs: [],
            isLayerLocked: { $0 == 0 }
        )

        let result = useCase.execute(
            .content(.clear(index: 0)),
            in: context,
            gateway: gateway
        )

        guard case let .failure(failure) = result else {
            Issue.record("Expected locked layer failure")
            return
        }
        #expect(failure == .layerLocked(0))
        #expect(gateway.contentEvents.isEmpty)
    }
}
