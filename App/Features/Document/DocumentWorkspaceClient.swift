import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentRuntime
import PrimoWorkspaceInfrastructure

private enum DocumentWorkspaceClientKey: DependencyKey {
    static var liveValue: DocumentWorkspaceClient {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient

        return .live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient,
            previewGateway: DocumentWorkspacePreviewGateway(
                loadProjectPreview: { url in
                    let preview = try DocumentProjectPreviewLoader.loadPreview(
                        from: url,
                        fileClient: fileClient,
                        dateClient: dateClient,
                        uuidClient: uuidClient
                    )
                    return DocumentWorkspacePreview(
                        canvasSize: preview.canvasSize,
                        layerCount: preview.layerCount,
                        previewSurface: preview.previewSurface,
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
