import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
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
                    let previewSurface = loaded.presentation.renderSnapshot.map {
                        AppFeature.renderedCompositeSurface(
                            snapshot: $0,
                            paperStyle: loaded.paperStyle
                        )
                    }
                    return DocumentWorkspacePreview(
                        canvasSize: loaded.presentation.canvasSize,
                        layerCount: loaded.presentation.layerRows.count,
                        previewSurface: previewSurface,
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
