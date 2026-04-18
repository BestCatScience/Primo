import ComposableArchitecture
import Foundation

extension AppFeature {
    func requestCloseOperation(
        state: inout State,
        operation: PendingCloseOperation
    ) -> Effect<Action> {
        let tabIDs: [OpenDocumentTab.ID] = {
            switch operation {
            case let .tab(tabID):
                return [tabID]
            case let .closeOtherTabs(tabID):
                return state.workspace.tabIDs(excluding: tabID)
            case let .closeTabsToRight(tabID):
                return state.workspace.tabIDsToRight(of: tabID)
            }
        }()

        let dirtyTabs = state.workspace.dirtyTabs(withIDs: tabIDs)
        guard !dirtyTabs.isEmpty else {
            return performCloseOperation(operation)
        }

        state.workspace.presentCloseConfirmation(operation: operation, dirtyTabs: dirtyTabs)
        return .none
    }

    func performCloseOperation(
        _ operation: PendingCloseOperation
    ) -> Effect<Action> {
        switch operation {
        case let .tab(tabID):
            return .send(.tabClosed(tabID))
        case let .closeOtherTabs(tabID):
            return .send(.closeOtherTabs(tabID))
        case let .closeTabsToRight(tabID):
            return .send(.closeTabsToRight(tabID))
        }
    }

    func effect(
        for closureDisposition: WorkspaceTabClosureDisposition,
        state: inout State
    ) -> Effect<Action> {
        switch closureDisposition {
        case .none:
            return .none
        case .showHome:
            state.application.showHome()
            return .none
        case let .select(tabID):
            return .send(.tabSelected(tabID))
        }
    }

    func handlePendingCloseSaveConfirmed(state: inout State) -> Effect<Action> {
        guard let confirmation = state.workspace.consumeCloseConfirmation() else { return .none }
        switch closeTabsPersistenceRequest(
            operation: confirmation.operation,
            tabIDs: confirmation.tabIDs,
            state: &state
        ) {
        case let .success(request):
            return .send(.workspacePersistenceRequested(request))
        case let .failure(failure):
            state.application.presentBanner(
                workspaceFeedbackMapper.message(
                    for: workspaceFeedbackMapper.feedback(for: failure),
                    language: state.application.appLanguage
                )
            )
            return .none
        }
    }

    func handlePendingCloseDiscardConfirmed(state: inout State) -> Effect<Action> {
        guard let confirmation = state.workspace.consumeCloseConfirmation() else { return .none }
        return performCloseOperation(confirmation.operation)
    }

    func handlePendingCloseCancelled(state: inout State) {
        state.workspace.clearCloseConfirmation()
    }

    func handleMoveTabToSecondaryPane(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        state.workspace.stageTabInSecondaryPane(tabID)
    }

    func handleTabReordered(
        state: inout State,
        movingID: OpenDocumentTab.ID,
        targetID: OpenDocumentTab.ID
    ) {
        state.workspace.reorderTabs(moving: movingID, before: targetID)
    }

    func handleTabDropped(
        state: inout State,
        movingID: OpenDocumentTab.ID,
        pane: WorkspacePane,
        targetID: OpenDocumentTab.ID?
    ) {
        state.workspace.moveTab(movingID, to: pane, before: targetID)
    }

    func handleSplitActiveTabIntoSecondaryPane(state: inout State) {
        state.workspace.splitIntoSecondaryPane()
    }

    func handleMergeWorkspacePanes(state: inout State) {
        state.workspace.mergeIntoPrimaryPane()
    }

    func handleWorkspacePaneActivated(
        state: inout State,
        pane: WorkspacePane
    ) -> Effect<Action> {
        switch state.workspace.activatePane(pane) {
        case .none:
            return .none
        case let .select(tabID):
            return .send(.tabSelected(tabID))
        }
    }

    func routeWorkspaceAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .tabSelected(tabID):
            return handleTabSelection(state: &state, tabID: tabID)

        case let .tabSelectionLoaded(tabID, loaded):
            return handleTabSelectionLoaded(state: &state, tabID: tabID, loaded: loaded)

        case let .tabSelectionFailed(feedback):
            handleTabSelectionFailed(state: &state, feedback: feedback)
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

        case .homeReturnRequested:
            return handleHomeReturnRequest(state: &state)

        case let .openImportedDocumentRequested(sourceURL):
            return handleOpenImportedDocumentRequest(
                state: &state,
                sourceURL: sourceURL
            )

        case let .openImportedDocumentLoaded(loaded, suggestedTitle, issues):
            return handleOpenImportedDocumentLoaded(
                state: &state,
                loaded: loaded,
                suggestedTitle: suggestedTitle,
                issues: issues
            )

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

        case let .openDocumentLoaded(loaded, sourceURL, issues):
            return handleOpenDocumentLoaded(
                state: &state,
                loaded: loaded,
                sourceURL: sourceURL,
                issues: issues
            )

        case let .openDocumentFailed(feedback):
            handleOpenDocumentFailed(state: &state, feedback: feedback)
            return .none

        default:
            return nil
        }
    }
}
