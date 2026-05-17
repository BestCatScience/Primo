import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentRuntime
import PrimoWorkspaceApplication
import PrimoWorkspaceInfrastructure

public extension DocumentWorkspaceClient {
    static func live(
        fileClient: FileClient,
        dateClient: DateClient,
        uuidClient: UUIDClient,
        previewGateway: DocumentWorkspacePreviewGateway
    ) -> DocumentWorkspaceClient {
        DocumentWorkspaceClient.infrastructureLive(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient,
            previewGateway: previewGateway
        )
    }
}

public extension DocumentImportClient {
    static func live(
        fileClient: FileClient,
        uuidClient: UUIDClient,
        securityScopedResourceClient: SecurityScopedResourceClient
    ) -> DocumentImportClient {
        DocumentImportClient.infrastructureLive(
            fileClient: fileClient,
            uuidClient: uuidClient,
            securityScopedResourceClient: securityScopedResourceClient
        )
    }
}

public enum WorkspaceRuntimeFactory {
    public static func liveApplicationServices(
        documentPersistenceGateway: DocumentPersistenceGateway,
        documentWorkspaceClient: DocumentWorkspaceClient,
        uuidClient: UUIDClient
    ) -> WorkspaceApplicationServices {
        WorkspaceApplicationServices(
            documentPersistenceGateway: documentPersistenceGateway,
            documentWorkspaceClient: documentWorkspaceClient,
            uuidClient: uuidClient
        )
    }

}
