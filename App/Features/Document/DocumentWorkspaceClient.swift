import ComposableArchitecture
import Foundation
import PrimoWorkspaceInfrastructure

private enum DocumentWorkspaceClientKey: DependencyKey {
    static var liveValue: DocumentWorkspaceClient {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient
        @Dependency(\.documentPersistenceGateway) var documentPersistenceGateway

        return .live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient,
            previewGateway: DocumentWorkspacePreviewGateway(
                loadProjectPreview: { url in
                    let loaded = try documentPersistenceGateway.loadProject(url)
                    return DocumentWorkspacePreview(
                        canvasSize: loaded.presentation.canvasSize,
                        layerCount: loaded.presentation.layerRows.count,
                        previewImageData: nil
                    )
                }
            )
        )
    }
}

extension DependencyValues {
    var documentWorkspaceClient: DocumentWorkspaceClient {
        get { self[DocumentWorkspaceClientKey.self] }
        set { self[DocumentWorkspaceClientKey.self] = newValue }
    }
}
