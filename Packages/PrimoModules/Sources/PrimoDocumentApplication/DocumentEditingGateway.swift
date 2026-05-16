import Foundation
import PrimoDocumentMutationContracts

package typealias DocumentEditingRequest = DocumentEditorRequest
public typealias DocumentEditingResult = DocumentEditorResult

package struct DocumentEditingGateway: Sendable {
    private let executeImpl: @Sendable (DocumentEditingRequest) -> Result<DocumentEditingResult, DocumentMutationFailure>

    package init(
        execute: @escaping @Sendable (DocumentEditingRequest) -> Result<DocumentEditingResult, DocumentMutationFailure>
    ) {
        self.executeImpl = execute
    }

    package func execute(_ request: DocumentEditingRequest) -> Result<DocumentEditingResult, DocumentMutationFailure> {
        executeImpl(request)
    }
}
