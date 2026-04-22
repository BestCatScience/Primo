import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceDomain

public typealias WorkspacePersistenceIssue = PrimoWorkspaceDomain.WorkspacePersistenceIssue
public typealias WorkspacePersistenceFailureReason = PrimoWorkspaceDomain.WorkspacePersistenceFailureReason
public typealias WorkspacePersistenceRequest = PrimoWorkspaceDomain.WorkspacePersistenceRequest
public typealias WorkspacePersistenceResult = PrimoWorkspaceDomain.WorkspacePersistenceResult
public typealias WorkspacePersistenceFailure = PrimoWorkspaceDomain.WorkspacePersistenceFailure
public typealias WorkspaceDirtyPresentationRequest = PrimoWorkspaceDomain.WorkspaceDirtyPresentationRequest
public typealias WorkspaceDocumentSavePurpose = PrimoWorkspaceDomain.WorkspaceDocumentSavePurpose
public typealias WorkspaceDocumentSaveRequest = PrimoWorkspaceDomain.WorkspaceDocumentSaveRequest
public typealias WorkspaceDocumentSaveResult = PrimoWorkspaceDomain.WorkspaceDocumentSaveResult
public typealias WorkspaceDocumentReplacementRequest = PrimoWorkspaceDomain.WorkspaceDocumentReplacementRequest
public typealias LoadedWorkspaceFollowUpPersistenceRequest = PrimoWorkspaceDomain.LoadedWorkspaceFollowUpPersistenceRequest
public typealias LoadedWorkspaceFollowUpPersistenceResult = PrimoWorkspaceDomain.LoadedWorkspaceFollowUpPersistenceResult
public typealias WorkspaceCloseTabsSaveRequest = PrimoWorkspaceDomain.WorkspaceCloseTabsSaveRequest
public typealias WorkspaceCloseTabsSaveResult = PrimoWorkspaceDomain.WorkspaceCloseTabsSaveResult
public typealias WorkspaceArtifactDiscardRequest = PrimoWorkspaceDomain.WorkspaceArtifactDiscardRequest
public typealias WorkspaceTabReservationRequest = PrimoWorkspaceDomain.WorkspaceTabReservationRequest
public typealias WorkspaceSavedProjectMoveRequest = PrimoWorkspaceDomain.WorkspaceSavedProjectMoveRequest
public typealias WorkspaceSavedProjectMoveResult = PrimoWorkspaceDomain.WorkspaceSavedProjectMoveResult
public typealias WorkspaceAutosaveEntryDiscardRequest = PrimoWorkspaceDomain.WorkspaceAutosaveEntryDiscardRequest
public typealias WorkspaceSaveHistoryLoadRequest = PrimoWorkspaceDomain.WorkspaceSaveHistoryLoadRequest
public typealias WorkspaceCatalogRequest = PrimoWorkspaceDomain.WorkspaceCatalogRequest
public typealias WorkspaceCatalogResult = PrimoWorkspaceDomain.WorkspaceCatalogResult
public typealias WorkspaceCatalogFailureReason = PrimoWorkspaceDomain.WorkspaceCatalogFailureReason
public typealias WorkspaceCatalogFailure = PrimoWorkspaceDomain.WorkspaceCatalogFailure
public typealias LoadedWorkspaceProjectPlan = PrimoWorkspaceDomain.LoadedWorkspaceProjectPlan
public typealias PreparedWorkspaceTab = PrimoWorkspaceDomain.PreparedWorkspaceTab
public typealias PendingCloseOperation = PrimoWorkspaceDomain.PendingCloseOperation
public typealias WorkspaceProjectLoadIssue = PrimoWorkspaceDomain.WorkspaceProjectLoadIssue
public typealias WorkspaceProjectLoadFailureReason = PrimoWorkspaceDomain.WorkspaceProjectLoadFailureReason
public typealias WorkspaceProjectLoadOperation = PrimoWorkspaceDomain.WorkspaceProjectLoadOperation
public typealias WorkspaceImportedProjectLoadOperation = PrimoWorkspaceDomain.WorkspaceImportedProjectLoadOperation
public typealias WorkspaceProjectLoadRequest = PrimoWorkspaceDomain.WorkspaceProjectLoadRequest
public typealias WorkspaceProjectLoadFailure = PrimoWorkspaceDomain.WorkspaceProjectLoadFailure
public typealias WorkspaceProjectLoadResult<LoadedProject: Equatable> = PrimoWorkspaceDomain.WorkspaceProjectLoadResult<LoadedProject>
public typealias WorkspaceProjectLoadCommand = PrimoWorkspaceDomain.WorkspaceProjectLoadCommand
public typealias WorkspaceProjectLoadingService<LoadedProject: Equatable> = PrimoWorkspaceDomain.WorkspaceProjectLoadingService<LoadedProject>
public typealias WorkspaceProjectCleanupService = PrimoWorkspaceDomain.WorkspaceProjectCleanupService

public struct WorkspacePersistenceUseCase: Sendable {
    public let base: PrimoWorkspaceDomain.WorkspacePersistenceUseCase

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
    public let base: PrimoWorkspaceDomain.WorkspaceCatalogUseCase

    public init(workspaceCatalog: WorkspaceCatalogGateway) {
        base = PrimoWorkspaceDomain.WorkspaceCatalogUseCase(workspaceCatalog: workspaceCatalog)
    }

    public func execute(_ request: WorkspaceCatalogRequest) -> Result<WorkspaceCatalogResult, WorkspaceCatalogFailure> {
        base.execute(request)
    }
}

public struct WorkspaceProjectPreparationUseCase: Sendable {
    public let base: PrimoWorkspaceDomain.WorkspaceProjectPreparationUseCase

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
    public let base: PrimoWorkspaceDomain.WorkspaceProjectLoadUseCase<LoadedProject>

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

public struct WorkspaceLoadedProjectFollowUpPlanner: Sendable {
    public init() {}

    public func request(
        plan: LoadedWorkspaceProjectPlan,
        context: WorkspaceDocumentReplacementRequest,
        requiresBackingStorePersistence: Bool
    ) -> WorkspacePersistenceRequest? {
        let shouldPersistToBackingStore = requiresBackingStorePersistence || plan.followUp.persistsToBackingStore
        guard shouldPersistToBackingStore
            || plan.followUp.persistsAutosave
            || plan.successEffects.discardedAutosaveEntryID != nil
        else {
            return nil
        }

        return .loadedWorkspaceFollowUp(
            LoadedWorkspaceFollowUpPersistenceRequest(
                activeTab: context.activeTab,
                paperStyle: context.paperStyle,
                persistsToBackingStore: shouldPersistToBackingStore,
                persistsAutosave: plan.followUp.persistsAutosave,
                successEffects: plan.successEffects
            )
        )
    }
}
