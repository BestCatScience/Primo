import Foundation

public enum DocumentEditorRequest: Equatable, Sendable {
    case structure(LayerStructureCommand)
    case attribute(LayerAttributeCommand)
}

public enum DocumentEditorResult: Equatable, Sendable {
    case structure(LayerStructureMutationPlan)
    case attribute(LayerAttributeMutationPlan)
}

public protocol DocumentEditorGateway: LayerStructureGateway, LayerAttributeGateway {}

public struct DocumentEditorUseCase: Sendable {
    private let structureUseCase: LayerStructureUseCase
    private let attributeUseCase: LayerAttributeUseCase

    public init(
        structureUseCase: LayerStructureUseCase = .init(),
        attributeUseCase: LayerAttributeUseCase = .init()
    ) {
        self.structureUseCase = structureUseCase
        self.attributeUseCase = attributeUseCase
    }

    public func execute(
        _ request: DocumentEditorRequest,
        in context: DocumentLayerMutationContext,
        gateway: any DocumentEditorGateway
    ) -> Result<DocumentEditorResult, DocumentLayerMutationFailure> {
        switch request {
        case let .structure(command):
            return structureUseCase
                .execute(command, in: context, gateway: gateway)
                .map(DocumentEditorResult.structure)

        case let .attribute(command):
            return attributeUseCase
                .execute(command, in: context, gateway: gateway)
                .map(DocumentEditorResult.attribute)
        }
    }
}
