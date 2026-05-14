import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRuntime
import PrimoWorkspaceApplication
import PrimoWorkspaceRuntime

struct WorkspaceApplicationCapability: Sendable {
    let persistenceUseCase: WorkspacePersistenceUseCase
    let catalogUseCase: WorkspaceCatalogUseCase
    let makeProjectLoadingService: @Sendable (
        ProjectLoadingGateway<LoadedPaintProject>,
        DocumentImportGateway
    ) -> WorkspaceProjectLoadingService<LoadedPaintProject>

    init(
        persistenceUseCase: WorkspacePersistenceUseCase,
        catalogUseCase: WorkspaceCatalogUseCase,
        makeProjectLoadingService: @escaping @Sendable (
            ProjectLoadingGateway<LoadedPaintProject>,
            DocumentImportGateway
        ) -> WorkspaceProjectLoadingService<LoadedPaintProject>
    ) {
        self.persistenceUseCase = persistenceUseCase
        self.catalogUseCase = catalogUseCase
        self.makeProjectLoadingService = makeProjectLoadingService
    }

    init(services: WorkspaceApplicationServices) {
        self.init(
            persistenceUseCase: services.persistenceUseCase,
            catalogUseCase: services.catalogUseCase,
            makeProjectLoadingService: { projectLoader, documentImport in
                services.projectLoadingService(
                    projectLoader: projectLoader,
                    documentImport: documentImport
                )
            }
        )
    }
}

struct WorkspaceArtifactCapability: Sendable {
    let writePNGToTemporaryDirectory: @Sendable (Data) throws -> URL
    let timelapseTemporaryDirectory: @Sendable () -> URL
}

struct TimelapseExportCapability: Sendable {
    let exportVideo: @Sendable (
        TimelapseCapture,
        @escaping @Sendable (TimelapseExportProgress) -> Void
    ) throws -> TimelapseExportResult
}

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

private enum WorkspaceApplicationCapabilityKey: DependencyKey {
    static var liveValue: WorkspaceApplicationCapability {
        @Dependency(\.documentPersistenceCapability) var documentPersistenceCapability
        @Dependency(\.documentWorkspaceClient) var documentWorkspaceClient
        @Dependency(\.uuidClient) var uuidClient

        return WorkspaceApplicationCapability(
            services: WorkspaceApplicationServices(
                documentPersistenceGateway: documentPersistenceCapability.persistenceGateway,
                documentWorkspaceClient: documentWorkspaceClient,
                uuidClient: uuidClient
            )
        )
    }
}

private enum WorkspaceArtifactCapabilityKey: DependencyKey {
    static var liveValue: WorkspaceArtifactCapability {
        @Dependency(\.documentWorkspaceClient) var documentWorkspaceClient

        return WorkspaceArtifactCapability(
            writePNGToTemporaryDirectory: { data in
                try documentWorkspaceClient.writePNGToTemporaryDirectory(data)
            },
            timelapseTemporaryDirectory: {
                documentWorkspaceClient.timelapseTemporaryDirectory()
            }
        )
    }
}

private enum TimelapseExportCapabilityKey: DependencyKey {
    static var liveValue: TimelapseExportCapability {
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.workspaceArtifactCapability) var workspaceArtifactCapability

        return TimelapseExportCapability(
            exportVideo: { capture, progress in
                try TimelapseExportService.exportVideo(
                    from: capture,
                    to: workspaceArtifactCapability.timelapseTemporaryDirectory(),
                    fileClient: fileClient,
                    dateClient: dateClient,
                    progress: progress
                )
            }
        )
    }
}

extension DependencyValues {
    var documentWorkspaceClient: DocumentWorkspaceClient {
        get { self[DocumentWorkspaceClientKey.self] }
        set { self[DocumentWorkspaceClientKey.self] = newValue }
    }

    var workspaceApplicationCapability: WorkspaceApplicationCapability {
        get { self[WorkspaceApplicationCapabilityKey.self] }
        set { self[WorkspaceApplicationCapabilityKey.self] = newValue }
    }

    var workspaceArtifactCapability: WorkspaceArtifactCapability {
        get { self[WorkspaceArtifactCapabilityKey.self] }
        set { self[WorkspaceArtifactCapabilityKey.self] = newValue }
    }

    var timelapseExportCapability: TimelapseExportCapability {
        get { self[TimelapseExportCapabilityKey.self] }
        set { self[TimelapseExportCapabilityKey.self] = newValue }
    }
}
