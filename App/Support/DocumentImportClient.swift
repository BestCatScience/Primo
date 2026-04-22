import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoWorkspaceInfrastructure

private enum DocumentImportClientKey: DependencyKey {
    static var liveValue: PrimoWorkspaceInfrastructure.DocumentImportClient {
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
    var documentImportClient: PrimoWorkspaceInfrastructure.DocumentImportClient {
        get { self[DocumentImportClientKey.self] }
        set { self[DocumentImportClientKey.self] = newValue }
    }
}
