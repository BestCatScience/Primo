import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceDomain

public struct WorkspaceDocumentContext: Equatable, Sendable {
    public let activeTab: OpenDocumentTab?
    public let paperStyle: CanvasPaperStyle

    public init(activeTab: OpenDocumentTab?, paperStyle: CanvasPaperStyle) {
        self.activeTab = activeTab
        self.paperStyle = paperStyle
    }
}

public struct WorkspaceLoadedProjectApplicationOutcome: Equatable, Sendable {
    public var marksActiveTabDirty: Bool
    public var followUpRequest: WorkspacePersistenceRequest?

    public init(
        marksActiveTabDirty: Bool,
        followUpRequest: WorkspacePersistenceRequest?
    ) {
        self.marksActiveTabDirty = marksActiveTabDirty
        self.followUpRequest = followUpRequest
    }
}

public enum WorkspacePersistenceApplicationOutcome: Equatable, Sendable {
    case none
    case refreshHomeProjects
    case showHomeAndRefreshProjects
    case completeLoadedWorkspace(successEffects: LoadedWorkspaceProjectPlan.SuccessEffects, issues: [WorkspacePersistenceIssue])
    case completeCloseOperation(PendingCloseOperation, issues: [WorkspacePersistenceIssue])
    case autosaveArtifactsDiscarded([WorkspacePersistenceIssue])
}

public enum WorkspaceCatalogApplicationOutcome: Equatable, Sendable {
    case savedProjectsLoaded([SavedProjectSummary])
    case autosaveRecoveryItemsLoaded([AutosaveRecoveryItem])
    case saveHistoryEntriesLoaded([SaveHistoryEntry])
    case savedProjectMoved(WorkspaceSavedProjectMoveResult)
    case autosaveEntryDiscarded(WorkspaceItemID)
}

public struct WorkspaceApplicationWorkflowService: Sendable {
    private let followUpPlanner: WorkspaceLoadedProjectFollowUpPlanner

    public init(followUpPlanner: WorkspaceLoadedProjectFollowUpPlanner = WorkspaceLoadedProjectFollowUpPlanner()) {
        self.followUpPlanner = followUpPlanner
    }

    public func documentReplacementRequest(
        context: WorkspaceDocumentContext
    ) -> Result<WorkspaceDocumentReplacementRequest, WorkspacePersistenceFailure> {
        guard let activeTab = context.activeTab else {
            return .failure(WorkspacePersistenceFailure(reason: .activeTabUnavailable))
        }
        return .success(
            WorkspaceDocumentReplacementRequest(
                activeTab: activeTab,
                paperStyle: context.paperStyle
            )
        )
    }

    public func dirtyPresentationRequest(
        context: WorkspaceDocumentContext
    ) -> WorkspacePersistenceRequest? {
        guard let activeTab = context.activeTab else { return nil }
        return .dirtyPresentationRefreshed(
            WorkspaceDirtyPresentationRequest(
                activeTab: activeTab,
                paperStyle: context.paperStyle
            )
        )
    }

    public func saveActiveDocumentRequest(
        context: WorkspaceDocumentContext,
        preferredDestinationURL: DocumentProjectPath?,
        trigger: SaveHistoryTrigger,
        purpose: WorkspaceDocumentSavePurpose
    ) -> Result<WorkspacePersistenceRequest, WorkspacePersistenceFailure> {
        documentReplacementRequest(context: context).map {
            .saveActiveDocument(
                WorkspaceDocumentSaveRequest(
                    activeTab: $0.activeTab,
                    paperStyle: $0.paperStyle,
                    preferredDestinationURL: preferredDestinationURL,
                    trigger: trigger,
                    purpose: purpose
                )
            )
        }
    }

    public func loadedWorkspaceFollowUp(
        plan: LoadedWorkspaceProjectPlan,
        context: WorkspaceDocumentContext,
        requiresBackingStorePersistence: Bool
    ) -> Result<WorkspaceLoadedProjectApplicationOutcome, WorkspacePersistenceFailure> {
        let shouldPersistToBackingStore = requiresBackingStorePersistence || plan.followUp.persistsToBackingStore
        guard shouldPersistToBackingStore
            || plan.followUp.persistsAutosave
            || plan.successEffects.discardedAutosaveEntryID != nil
        else {
            return .success(
                WorkspaceLoadedProjectApplicationOutcome(
                    marksActiveTabDirty: plan.followUp.marksTabDirty,
                    followUpRequest: nil
                )
            )
        }

        return documentReplacementRequest(context: context).map { replacement in
            WorkspaceLoadedProjectApplicationOutcome(
                marksActiveTabDirty: plan.followUp.marksTabDirty,
                followUpRequest: followUpPlanner.request(
                    plan: plan,
                    context: replacement,
                    requiresBackingStorePersistence: requiresBackingStorePersistence
                )
            )
        }
    }

    public func closeTabsPersistenceRequest(
        operation: PendingCloseOperation,
        tabs: [OpenDocumentTab],
        activeTabContext: WorkspaceDocumentContext?
    ) -> Result<WorkspacePersistenceRequest, WorkspacePersistenceFailure> {
        let activeTabRequest: WorkspaceDocumentReplacementRequest?
        if let activeTabContext {
            switch documentReplacementRequest(context: activeTabContext) {
            case let .success(request):
                activeTabRequest = request
            case let .failure(failure):
                return .failure(failure)
            }
        } else {
            activeTabRequest = nil
        }

        var closeTabs = tabs
        if let activeTabRequest,
           let index = closeTabs.firstIndex(where: { $0.id == activeTabRequest.activeTab.id }) {
            closeTabs[index] = activeTabRequest.activeTab
        }

        return .success(
            .saveTabsForClose(
                WorkspaceCloseTabsSaveRequest(
                    operation: operation,
                    tabs: closeTabs,
                    activeTab: activeTabRequest
                )
            )
        )
    }

    public func discardArtifactsRequest(for tabs: [OpenDocumentTab]) -> WorkspacePersistenceRequest {
        .discardAutosaveArtifacts(WorkspaceArtifactDiscardRequest(tabs: tabs))
    }

    public func persistenceOutcome(
        for result: WorkspacePersistenceResult
    ) -> WorkspacePersistenceApplicationOutcome {
        switch result {
        case .dirtyPresentationPersisted,
             .activeCanvasDuplicated,
             .documentReplacementPrepared,
             .newTabBackingStoreReserved:
            return .none
        case let .activeDocumentSaved(saved):
            switch saved.purpose {
            case .saveDocument:
                return .refreshHomeProjects
            case .homeReturn:
                return .showHomeAndRefreshProjects
            }
        case let .loadedWorkspaceFollowUpApplied(followUp):
            return .completeLoadedWorkspace(successEffects: followUp.successEffects, issues: followUp.issues)
        case let .tabsSavedForClose(closeResult):
            return .completeCloseOperation(closeResult.operation, issues: closeResult.issues)
        case let .autosaveArtifactsDiscarded(issues):
            return .autosaveArtifactsDiscarded(issues)
        }
    }

    public func catalogOutcome(
        for result: WorkspaceCatalogResult
    ) -> WorkspaceCatalogApplicationOutcome {
        switch result {
        case let .savedProjectsLoaded(projects):
            return .savedProjectsLoaded(projects)
        case let .autosaveRecoveryItemsLoaded(items):
            return .autosaveRecoveryItemsLoaded(items)
        case let .saveHistoryEntriesLoaded(entries):
            return .saveHistoryEntriesLoaded(entries)
        case let .savedProjectMoved(moveResult):
            return .savedProjectMoved(moveResult)
        case let .autosaveEntryDiscarded(autosaveID):
            return .autosaveEntryDiscarded(autosaveID)
        }
    }
}
