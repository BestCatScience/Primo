import CasePaths
import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication
import PrimoWorkspaceInfrastructure

@Reducer
struct WorkspaceFeature {
    typealias WorkspacePersistenceRequest = PrimoWorkspaceApplication.WorkspacePersistenceRequest
    typealias WorkspacePersistenceResult = PrimoWorkspaceApplication.WorkspacePersistenceResult
    typealias WorkspacePersistenceFailure = PrimoWorkspaceApplication.WorkspacePersistenceFailure
    typealias WorkspacePersistenceFailureReason = PrimoWorkspaceApplication.WorkspacePersistenceFailureReason
    typealias WorkspaceCatalogRequest = PrimoWorkspaceApplication.WorkspaceCatalogRequest
    typealias WorkspaceCatalogResult = PrimoWorkspaceApplication.WorkspaceCatalogResult
    typealias WorkspaceCatalogFailure = PrimoWorkspaceApplication.WorkspaceCatalogFailure
    typealias WorkspaceCatalogFailureReason = PrimoWorkspaceApplication.WorkspaceCatalogFailureReason
    typealias WorkspacePersistenceIssue = PrimoWorkspaceApplication.WorkspacePersistenceIssue
    typealias WorkspaceDirtyPresentationRequest = PrimoWorkspaceApplication.WorkspaceDirtyPresentationRequest
    typealias WorkspaceDocumentSavePurpose = PrimoWorkspaceApplication.WorkspaceDocumentSavePurpose
    typealias WorkspaceDocumentSaveRequest = PrimoWorkspaceApplication.WorkspaceDocumentSaveRequest
    typealias WorkspaceDocumentSaveResult = PrimoWorkspaceApplication.WorkspaceDocumentSaveResult
    typealias WorkspaceDocumentReplacementRequest = PrimoWorkspaceApplication.WorkspaceDocumentReplacementRequest
    typealias LoadedWorkspaceFollowUpPersistenceRequest = PrimoWorkspaceApplication.LoadedWorkspaceFollowUpPersistenceRequest
    typealias LoadedWorkspaceFollowUpPersistenceResult = PrimoWorkspaceApplication.LoadedWorkspaceFollowUpPersistenceResult
    typealias WorkspaceCloseTabsSaveRequest = PrimoWorkspaceApplication.WorkspaceCloseTabsSaveRequest
    typealias WorkspaceCloseTabsSaveResult = PrimoWorkspaceApplication.WorkspaceCloseTabsSaveResult
    typealias WorkspaceArtifactDiscardRequest = PrimoWorkspaceApplication.WorkspaceArtifactDiscardRequest
    typealias WorkspaceTabReservationRequest = PrimoWorkspaceApplication.WorkspaceTabReservationRequest
    typealias WorkspaceSavedProjectMoveRequest = PrimoWorkspaceApplication.WorkspaceSavedProjectMoveRequest
    typealias WorkspaceSavedProjectMoveResult = PrimoWorkspaceApplication.WorkspaceSavedProjectMoveResult
    typealias WorkspaceAutosaveEntryDiscardRequest = PrimoWorkspaceApplication.WorkspaceAutosaveEntryDiscardRequest
    typealias WorkspaceSaveHistoryLoadRequest = PrimoWorkspaceApplication.WorkspaceSaveHistoryLoadRequest
    typealias WorkspaceProjectLoadIssue = PrimoWorkspaceApplication.WorkspaceProjectLoadIssue
    typealias WorkspaceProjectLoadCommand = PrimoWorkspaceApplication.WorkspaceProjectLoadCommand
    typealias WorkspaceProjectLoadOperation = PrimoWorkspaceApplication.WorkspaceProjectLoadOperation
    typealias WorkspaceImportedProjectLoadOperation = PrimoWorkspaceApplication.WorkspaceImportedProjectLoadOperation
    typealias WorkspaceProjectLoadFailure = PrimoWorkspaceApplication.WorkspaceProjectLoadFailure
    typealias WorkspaceProjectLoadingService = PrimoWorkspaceApplication.WorkspaceProjectLoadingService<LoadedPaintProject>
    typealias LoadedWorkspaceProjectPlan = PrimoWorkspaceApplication.LoadedWorkspaceProjectPlan
    typealias PreparedWorkspaceTab = PrimoWorkspaceApplication.PreparedWorkspaceTab
    typealias WorkspaceDocumentContext = PrimoWorkspaceApplication.WorkspaceDocumentContext
    typealias WorkspaceLoadedProjectFollowUpPlanner = PrimoWorkspaceApplication.WorkspaceLoadedProjectFollowUpPlanner
    typealias WorkspaceApplicationWorkflowService = PrimoWorkspaceApplication.WorkspaceApplicationWorkflowService
    typealias ApplicationFeedback = ApplicationFeature.Feedback
    typealias WorkspacePersistenceUseCase = PrimoWorkspaceApplication.WorkspacePersistenceUseCase
    typealias WorkspaceCatalogUseCase = PrimoWorkspaceApplication.WorkspaceCatalogUseCase
    typealias WorkspaceBackingStoreService = PrimoWorkspaceInfrastructure.WorkspaceBackingStoreService
    typealias WorkspaceCatalogService = PrimoWorkspaceInfrastructure.WorkspaceCatalogService
    typealias WorkspaceArtifactService = PrimoWorkspaceInfrastructure.WorkspaceArtifactService
    typealias WorkspaceIdentityService = PrimoWorkspaceInfrastructure.WorkspaceIdentityService
    typealias WorkspaceApplicationServices = PrimoWorkspaceInfrastructure.WorkspaceApplicationServices

    @Dependency(\.documentImportClient) var documentImportClient
    @Dependency(\.documentPersistenceGateway) var documentPersistenceGateway
    @Dependency(\.documentWorkspaceClient) var documentWorkspaceClient
    @Dependency(\.workspaceApplicationWorkflowService) var workspaceApplicationWorkflowService
    @Dependency(\.uuidClient) var uuidClient

    enum PendingWorkspaceTabReservation: Equatable, Sendable {
        case loadedProject(PendingLoadedWorkspaceProject)
        case freshDocument(PendingFreshDocumentMutation)
    }

    struct PendingLoadedWorkspaceProject: Equatable, Sendable {
        let loaded: LoadedPaintProject
        let plan: PrimoWorkspaceApplication.LoadedWorkspaceProjectPlan
        let presentation: LoadedWorkspacePresentation
    }

    struct PendingFreshDocumentMutation: Equatable, Sendable {
        enum Operation: Equatable, Sendable {
            case newCanvas(DocumentFeature.CanvasDimensions)
            case importedCanvas(ImportExportFeature.ImportedCanvasPlan)
        }

        let contract: DocumentFeature.FreshDocumentReplacementContract
        let operation: Operation
    }

    struct LoadedWorkspacePresentation: Equatable, Sendable {
        var issues: [WorkspaceProjectLoadIssue] = []
        var completion: PrimoWorkspaceApplication.LoadedWorkspaceProjectPlan.Completion = .none
    }

    @ObservableState
    struct State: Equatable {
        var openTabs: [OpenDocumentTab] = []
        var activeTabID: OpenDocumentTab.ID?
        var primarySelectedTabID: OpenDocumentTab.ID?
        var secondarySelectedTabID: OpenDocumentTab.ID?
        var focusedWorkspacePane: WorkspacePane = .primary
        var workspaceLayout: WorkspaceLayoutMode = .single
        var pendingCloseConfirmation: PendingCloseConfirmationState?
        var pendingWorkspaceTabReservation: PendingWorkspaceTabReservation?
    }

    @CasePathable
    enum Action: Equatable {
        enum Delegate: Equatable {
            case showHome
            case presentBanner(String?)
            case presentFeedback(ApplicationFeedback)
            case applyLoadedProject(LoadedPaintProject)
            case workspaceProjectLoadFailed(message: String?, showingHome: Bool?)
            case workspaceProjectLoadFailedFeedback(ApplicationFeedback, showingHome: Bool?)
            case homeProjectsLoaded([SavedProjectSummary])
            case autosaveRecoveryLoaded([AutosaveRecoveryItem])
            case autosaveRecoveryLoadFailed(ApplicationFeedback)
            case autosaveRecoveryDiscarded(WorkspaceItemID)
            case saveHistoryLoaded([SaveHistoryEntry])
            case saveHistoryLoadFailed(ApplicationFeedback)
            case saveHistoryProjectOpened(LoadedPaintProject, DocumentProjectPath, Bool, [WorkspaceProjectLoadIssue])
            case saveHistoryRestoreFailedFeedback(ApplicationFeedback)
            case requestHomeProjectsLoad
        }

        case tabSelected(OpenDocumentTab.ID)
        case tabProjectLoadRequested(OpenDocumentTab.ID, WorkspaceDocumentReplacementRequest?)
        case tabSelectionLoaded(OpenDocumentTab.ID, LoadedPaintProject)
        case tabSelectionFailed(String?)
        case tabCloseRequested(OpenDocumentTab.ID)
        case tabClosed(OpenDocumentTab.ID)
        case closeOtherTabsRequested(OpenDocumentTab.ID)
        case closeOtherTabs(OpenDocumentTab.ID)
        case closeTabsToRightRequested(OpenDocumentTab.ID)
        case closeTabsToRight(OpenDocumentTab.ID)
        case pendingCloseSaveConfirmed
        case pendingCloseDiscardConfirmed
        case pendingCloseCancelled
        case moveTabToSecondaryPane(OpenDocumentTab.ID)
        case tabReordered(moving: OpenDocumentTab.ID, before: OpenDocumentTab.ID)
        case tabDropped(moving: OpenDocumentTab.ID, toPane: WorkspacePane, before: OpenDocumentTab.ID?)
        case splitActiveTabIntoSecondaryPane
        case mergeWorkspacePanes
        case workspacePaneActivated(WorkspacePane)
        case homeProjectSelected(DocumentProjectPath)
        case projectLoadRequested(
            DocumentProjectPath,
            removesStagedWorkspaceItem: Bool,
            replacementRequest: WorkspaceDocumentReplacementRequest?
        )
        case moveSavedProject(DocumentProjectPath, RelativeProjectFolderPath?)
        case homeReturnRequested
        case openImportedDocumentRequested(URL)
        case importedProjectLoadRequested(URL, replacementRequest: WorkspaceDocumentReplacementRequest?)
        case openImportedDocumentLoaded(LoadedPaintProject, String, [WorkspaceProjectLoadIssue])
        case openDocumentSelected(DocumentProjectPath)
        case openDocumentLoaded(LoadedPaintProject, DocumentProjectPath, [WorkspaceProjectLoadIssue])
        case openDocumentFailed(String?)
        case autosaveRecoveryRestoreRequested(AutosaveRecoveryItem)
        case autosaveRecoveryProjectLoadRequested(AutosaveRecoveryItem, replacementRequest: WorkspaceDocumentReplacementRequest?)
        case autosaveRecoveryOpened(LoadedPaintProject, AutosaveRecoveryItem, [WorkspaceProjectLoadIssue])
        case lifecycleAutosaveRequested
        case persistenceRequested(WorkspacePersistenceRequest)
        case persistenceSucceeded(WorkspacePersistenceResult)
        case persistenceFailed(WorkspacePersistenceFailure)
        case saveHistoryEntriesRequested
        case saveHistoryProjectLoadRequested(
            DocumentProjectPath,
            openInNewTab: Bool,
            replacementRequest: WorkspaceDocumentReplacementRequest?
        )
        case catalogRequested(WorkspaceCatalogRequest)
        case catalogSucceeded(WorkspaceCatalogResult)
        case catalogFailed(WorkspaceCatalogFailure)
        case delegate(Delegate)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .tabCloseRequested(tabID):
                return requestCloseOperation(state: &state, operation: .tab(tabID))

            case let .closeOtherTabsRequested(tabID):
                return requestCloseOperation(state: &state, operation: .closeOtherTabs(tabID))

            case let .closeTabsToRightRequested(tabID):
                return requestCloseOperation(state: &state, operation: .closeTabsToRight(tabID))

            case .pendingCloseDiscardConfirmed:
                return handlePendingCloseDiscardConfirmed(state: &state)

            case .pendingCloseCancelled:
                handlePendingCloseCancelled(state: &state)
                return .none

            case let .tabClosed(tabID):
                return handleTabClosed(state: &state, tabID: tabID)

            case let .closeOtherTabs(tabID):
                return handleCloseOtherTabs(state: &state, retaining: tabID)

            case let .closeTabsToRight(tabID):
                return handleCloseTabsToRight(state: &state, tabID: tabID)

            case let .moveTabToSecondaryPane(tabID):
                handleMoveTabToSecondaryPane(state: &state, tabID: tabID)
                return .none

            case let .tabReordered(movingID, targetID):
                handleTabReordered(state: &state, movingID: movingID, targetID: targetID)
                return .none

            case let .tabDropped(movingID, pane, targetID):
                handleTabDropped(state: &state, movingID: movingID, pane: pane, targetID: targetID)
                return .none

            case .splitActiveTabIntoSecondaryPane:
                handleSplitActiveTabIntoSecondaryPane(state: &state)
                return .none

            case .mergeWorkspacePanes:
                handleMergeWorkspacePanes(state: &state)
                return .none

            case let .workspacePaneActivated(pane):
                return handleWorkspacePaneActivated(state: &state, pane: pane)

            case let .moveSavedProject(url, relativeFolderPath):
                return handleSavedProjectMove(
                    state: &state,
                    url: url,
                    relativeFolderPath: relativeFolderPath
                )

            case let .persistenceRequested(request):
                return handleWorkspacePersistenceRequested(request: request)

            case .saveHistoryEntriesRequested:
                return handleSaveHistoryEntriesRequested(state: &state)

            case let .saveHistoryProjectLoadRequested(projectURL, openInNewTab, replacementRequest):
                return handleSaveHistoryProjectLoadRequested(
                    projectURL: projectURL,
                    openInNewTab: openInNewTab,
                    replacementRequest: replacementRequest
                )

            case let .tabProjectLoadRequested(tabID, replacementRequest):
                return handleTabProjectLoadRequested(
                    state: &state,
                    tabID: tabID,
                    replacementRequest: replacementRequest
                )

            case let .projectLoadRequested(url, removesStagedWorkspaceItem, replacementRequest):
                return handleProjectLoadRequested(
                    url: url,
                    removesStagedWorkspaceItem: removesStagedWorkspaceItem,
                    replacementRequest: replacementRequest
                )

            case let .importedProjectLoadRequested(sourceURL, replacementRequest):
                return handleImportedProjectLoadRequested(
                    sourceURL: sourceURL,
                    replacementRequest: replacementRequest
                )

            case let .autosaveRecoveryProjectLoadRequested(item, replacementRequest):
                return handleAutosaveRecoveryProjectLoadRequested(
                    item: item,
                    replacementRequest: replacementRequest
                )

            case let .catalogRequested(request):
                return handleWorkspaceCatalogRequested(request: request)

            case let .catalogSucceeded(result):
                return handleWorkspaceCatalogSucceeded(state: &state, result: result)

            case let .catalogFailed(failure):
                return handleWorkspaceCatalogFailed(failure: failure)

            case let .openDocumentFailed(message):
                return .send(.delegate(.workspaceProjectLoadFailed(message: message, showingHome: nil)))

            case let .tabSelectionFailed(message):
                return .send(
                    .delegate(
                        .workspaceProjectLoadFailed(
                            message: message,
                            showingHome: state.activeTab == nil ? true : nil
                        )
                    )
                )

            case .delegate:
                return .none
            default:
                return .none
            }
        }
    }
}
