import ComposableArchitecture
import Foundation

extension AppFeature {
    func routeWorkspaceAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .tabSelected(tabID):
            handleTabSelection(state: &state, tabID: tabID)
            return .none

        case let .tabCloseRequested(tabID):
            return requestCloseOperation(state: &state, operation: .tab(tabID))

        case let .closeOtherTabsRequested(tabID):
            return requestCloseOperation(state: &state, operation: .closeOtherTabs(tabID))

        case let .closeTabsToRightRequested(tabID):
            return requestCloseOperation(state: &state, operation: .closeTabsToRight(tabID))

        case .pendingCloseSaveConfirmed:
            return handlePendingCloseSaveConfirmed(state: &state)

        case .pendingCloseDiscardConfirmed:
            return handlePendingCloseDiscardConfirmed(state: &state)

        case .pendingCloseCancelled:
            handlePendingCloseCancelled(state: &state)
            return .none

        case let .tabClosed(tabID):
            handleTabClosed(state: &state, tabID: tabID)
            return .none

        case let .closeOtherTabs(tabID):
            return handleCloseOtherTabs(state: &state, retaining: tabID)

        case let .closeTabsToRight(tabID):
            handleCloseTabsToRight(state: &state, tabID: tabID)
            return .none

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

        case .homeReturnRequested:
            return handleHomeReturnRequest(state: &state)

        case let .openDocumentSelected(url):
            return handleOpenDocumentSelection(
                state: &state,
                url: url,
                removesStagedWorkspaceItem: true
            )

        case let .homeProjectSelected(url):
            return handleOpenDocumentSelection(
                state: &state,
                url: url,
                removesStagedWorkspaceItem: false
            )

        case let .openDocumentLoaded(loaded, sourceURL):
            return handleOpenDocumentLoaded(
                state: &state,
                loaded: loaded,
                sourceURL: sourceURL
            )

        case let .openDocumentFailed(message):
            handleOpenDocumentFailed(state: &state, message: message)
            return .none

        default:
            return nil
        }
    }
}
