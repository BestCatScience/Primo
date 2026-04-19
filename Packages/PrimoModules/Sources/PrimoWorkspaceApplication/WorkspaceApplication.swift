import Foundation
import PrimoDocumentContracts
import PrimoWorkspaceDomain

public typealias WorkspacePersistenceRequest = PrimoWorkspaceDomain.WorkspacePersistenceRequest
public typealias WorkspacePersistenceResult = PrimoWorkspaceDomain.WorkspacePersistenceResult
public typealias WorkspacePersistenceFailure = PrimoWorkspaceDomain.WorkspacePersistenceFailure
public typealias WorkspaceCatalogRequest = PrimoWorkspaceDomain.WorkspaceCatalogRequest
public typealias WorkspaceCatalogResult = PrimoWorkspaceDomain.WorkspaceCatalogResult
public typealias WorkspaceCatalogFailure = PrimoWorkspaceDomain.WorkspaceCatalogFailure
public typealias WorkspaceProjectLoadRequest = PrimoWorkspaceDomain.WorkspaceProjectLoadRequest
public typealias WorkspaceProjectLoadFailure = PrimoWorkspaceDomain.WorkspaceProjectLoadFailure
public typealias WorkspaceProjectCleanupService = PrimoWorkspaceDomain.WorkspaceProjectCleanupService

public struct WorkspacePersistenceUseCase: Sendable {
    fileprivate let base: PrimoWorkspaceDomain.WorkspacePersistenceUseCase

    public init(
        workspaceBackingStore: WorkspaceBackingStoreGateway,
        workspaceCatalog: WorkspaceCatalogGateway,
        identityGenerator: WorkspaceIdentityGenerator
    ) {
        base = PrimoWorkspaceDomain.WorkspacePersistenceUseCase(
            workspaceBackingStore: workspaceBackingStore,
            workspaceCatalog: workspaceCatalog,
            identityGenerator: identityGenerator
        )
    }

    public func execute(_ request: WorkspacePersistenceRequest) -> Result<WorkspacePersistenceResult, WorkspacePersistenceFailure> {
        base.execute(request)
    }
}

public struct WorkspaceCatalogUseCase: Sendable {
    fileprivate let base: PrimoWorkspaceDomain.WorkspaceCatalogUseCase

    public init(workspaceCatalog: WorkspaceCatalogGateway) {
        base = PrimoWorkspaceDomain.WorkspaceCatalogUseCase(workspaceCatalog: workspaceCatalog)
    }

    public func execute(_ request: WorkspaceCatalogRequest) -> Result<WorkspaceCatalogResult, WorkspaceCatalogFailure> {
        base.execute(request)
    }
}

public struct WorkspaceProjectPreparationUseCase: Sendable {
    fileprivate let base: PrimoWorkspaceDomain.WorkspaceProjectPreparationUseCase

    public init(workspacePersistenceUseCase: WorkspacePersistenceUseCase) {
        base = PrimoWorkspaceDomain.WorkspaceProjectPreparationUseCase(
            workspacePersistenceUseCase: workspacePersistenceUseCase.base
        )
    }

    public func execute(
        _ request: WorkspaceDocumentReplacementRequest
    ) -> Result<Void, WorkspacePersistenceFailure> {
        base.execute(request)
    }
}

public struct WorkspaceProjectLoadUseCase<LoadedProject>: Sendable where LoadedProject: Equatable {
    fileprivate let base: PrimoWorkspaceDomain.WorkspaceProjectLoadUseCase<LoadedProject>

    public init(
        projectLoader: ProjectLoadingGateway<LoadedProject>,
        documentImport: DocumentImportGateway,
        cleanupService: WorkspaceProjectCleanupService
    ) {
        base = PrimoWorkspaceDomain.WorkspaceProjectLoadUseCase(
            projectLoader: projectLoader,
            documentImport: documentImport,
            cleanupService: cleanupService
        )
    }

    public func execute(
        _ request: WorkspaceProjectLoadRequest
    ) -> Result<PrimoWorkspaceDomain.WorkspaceProjectLoadResult<LoadedProject>, WorkspaceProjectLoadFailure> {
        base.execute(request)
    }
}
