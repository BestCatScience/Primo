import Foundation
import PrimoDocumentMutationContracts

public typealias DocumentEditingRequest = DocumentEditorRequest
public typealias DocumentEditingResult = DocumentEditorResult

public struct DocumentEditingGateway: Sendable {
    private let executeImpl: @Sendable (DocumentEditingRequest) -> Result<DocumentEditingResult, DocumentMutationFailure>

    public init(
        execute: @escaping @Sendable (DocumentEditingRequest) -> Result<DocumentEditingResult, DocumentMutationFailure>
    ) {
        self.executeImpl = execute
    }

    public func execute(_ request: DocumentEditingRequest) -> Result<DocumentEditingResult, DocumentMutationFailure> {
        executeImpl(request)
    }
}
