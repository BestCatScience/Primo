import CasePaths
import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication

@Reducer
struct WorkspaceFeature {
    @ObservableState
    struct State: Equatable {
        var openTabs: [OpenDocumentTab] = []
        var activeTabID: OpenDocumentTab.ID?
        var primarySelectedTabID: OpenDocumentTab.ID?
        var secondarySelectedTabID: OpenDocumentTab.ID?
        var focusedWorkspacePane: WorkspacePane = .primary
        var workspaceLayout: WorkspaceLayoutMode = .single
        var pendingCloseConfirmation: PendingCloseConfirmationState?
        var pendingWorkspaceTabReservation: AppFeature.PendingWorkspaceTabReservation?
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(OpenDocumentTab.ID)
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
        case moveSavedProject(DocumentProjectPath, RelativeProjectFolderPath?)
        case homeReturnRequested
        case openImportedDocumentRequested(URL)
        case openImportedDocumentLoaded(LoadedPaintProject, String, [WorkspaceProjectLoadIssue])
        case openDocumentSelected(DocumentProjectPath)
        case openDocumentLoaded(LoadedPaintProject, DocumentProjectPath, [WorkspaceProjectLoadIssue])
        case openDocumentFailed(String?)
        case persistenceRequested(AppFeature.WorkspacePersistenceRequest)
        case persistenceSucceeded(AppFeature.WorkspacePersistenceResult)
        case persistenceFailed(AppFeature.WorkspacePersistenceFailure)
        case catalogRequested(AppFeature.WorkspaceCatalogRequest)
        case catalogSucceeded(AppFeature.WorkspaceCatalogResult)
        case catalogFailed(AppFeature.WorkspaceCatalogFailure)
    }

    var body: some ReducerOf<Self> {
        Reduce { _, _ in .none }
    }
}
