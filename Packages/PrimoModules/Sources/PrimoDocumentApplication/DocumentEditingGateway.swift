import Foundation
import PrimoDocumentMutationContracts

public typealias DocumentEditingRequest = DocumentEditorRequest
public typealias DocumentEditingResult = DocumentEditorResult

public struct DocumentEditingGateway: Sendable {
    public let execute: @Sendable (DocumentEditingRequest) -> Result<DocumentEditingResult, DocumentMutationFailure>

    public init(
        execute: @escaping @Sendable (DocumentEditingRequest) -> Result<DocumentEditingResult, DocumentMutationFailure>
    ) {
        self.execute = execute
    }
}
