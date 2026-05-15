import Foundation

// DocumentEditorUseCase is the authoritative application contract for document
// editing requests. App preflight may fail early for UX, but this boundary
// always validates against a fresh mutation context before the gateway runs.
public enum DocumentEditorRequest: Equatable, Sendable {
    case structure(LayerStructureCommand)
    case attribute(LayerAttributeCommand)
    case content(LayerContentMutationCommand)
}

public enum DocumentEditorResult: Equatable, Sendable {
    case structure(LayerStructureMutationPlan)
    case attribute(LayerAttributeMutationPlan)
    case content(LayerContentMutationPlan)
}

public protocol DocumentEditorGateway: LayerStructureGateway, LayerAttributeGateway, LayerContentGateway {}

public struct DocumentEditorUseCase: Sendable {
    private let structureUseCase: LayerStructureUseCase
    private let attributeUseCase: LayerAttributeUseCase
    private let contentUseCase: LayerContentMutationUseCase

    public init(
        structureUseCase: LayerStructureUseCase = .init(),
        attributeUseCase: LayerAttributeUseCase = .init(),
        contentUseCase: LayerContentMutationUseCase = .init()
    ) {
        self.structureUseCase = structureUseCase
        self.attributeUseCase = attributeUseCase
        self.contentUseCase = contentUseCase
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

        case let .content(command):
            return contentUseCase
                .execute(command, in: context, gateway: gateway)
                .map(DocumentEditorResult.content)
        }
    }
}
