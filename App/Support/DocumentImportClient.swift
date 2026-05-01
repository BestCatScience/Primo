import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoWorkspaceApplication
import PrimoWorkspaceRuntime

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
