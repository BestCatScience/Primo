import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoWorkspaceInfrastructure

typealias ImportedDocumentStageRequest = PrimoDocumentContracts.ImportedDocumentStageRequest
typealias ImportedDocumentStageResult = PrimoDocumentContracts.ImportedDocumentStageResult
typealias ImportedDocumentStageFailure = PrimoDocumentContracts.ImportedDocumentStageFailure
typealias DocumentImportClient = PrimoWorkspaceInfrastructure.DocumentImportClient

private enum DocumentImportClientKey: DependencyKey {
    static var liveValue: DocumentImportClient {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.uuidClient) var uuidClient
        @Dependency(\.securityScopedResourceClient) var securityScopedResourceClient
        return .live(
            fileClient: fileClient,
            uuidClient: uuidClient,
            securityScopedResourceClient: securityScopedResourceClient
        )
    }
}

extension DependencyValues {
    var documentImportClient: DocumentImportClient {
        get { self[DocumentImportClientKey.self] }
        set { self[DocumentImportClientKey.self] = newValue }
    }
}
