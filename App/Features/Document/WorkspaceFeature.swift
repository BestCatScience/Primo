import CasePaths
import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication

@Reducer
struct WorkspaceFeature {
    typealias PendingWorkspaceTabReservation = DocumentFeatureRuntimeReducer.PendingWorkspaceTabReservation
    typealias WorkspacePersistenceRequest = DocumentFeatureRuntimeReducer.WorkspacePersistenceRequest
    typealias WorkspacePersistenceResult = DocumentFeatureRuntimeReducer.WorkspacePersistenceResult
    typealias WorkspacePersistenceFailure = DocumentFeatureRuntimeReducer.WorkspacePersistenceFailure
    typealias WorkspaceCatalogRequest = DocumentFeatureRuntimeReducer.WorkspaceCatalogRequest
    typealias WorkspaceCatalogResult = DocumentFeatureRuntimeReducer.WorkspaceCatalogResult
    typealias WorkspaceCatalogFailure = DocumentFeatureRuntimeReducer.WorkspaceCatalogFailure

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
        case persistenceRequested(WorkspacePersistenceRequest)
        case persistenceSucceeded(WorkspacePersistenceResult)
        case persistenceFailed(WorkspacePersistenceFailure)
        case catalogRequested(WorkspaceCatalogRequest)
        case catalogSucceeded(WorkspaceCatalogResult)
        case catalogFailed(WorkspaceCatalogFailure)
    }

    var body: some ReducerOf<Self> {
        Reduce { _, _ in .none }
    }
}
