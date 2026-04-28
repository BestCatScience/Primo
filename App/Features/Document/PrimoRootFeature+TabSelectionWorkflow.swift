import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension CrossFeatureIntegrationReducer {
    func handleTabSelection(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        guard let targetTab = state.workspace.tab(withID: tabID) else {
            return .none
        }
        if state.workspace.isActiveTab(tabID), !state.application.showsHome {
            return .none
        }
        let language = state.application.appLanguage
        return beginWorkspaceProjectLoad(
            state: &state,
            fileURL: targetTab.backingStoreURL.fileURL,
            persistCurrentTab: state.workspace.isActiveTab(tabID) == false,
            onSuccess: { loaded, _ in Action.tabSelectionLoaded(tabID, loaded) },
            onFailure: {
                Action.tabSelectionFailed(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: $0, context: .openDocument),
                        language: language
                    )
                )
            }
        )
    }

    func handleTabSelectionLoaded(
        state: inout State,
        tabID: OpenDocumentTab.ID,
        loaded: LoadedPaintProject
    ) -> Effect<Action> {
        guard let targetTab = state.workspace.tab(withID: tabID) else {
            state.application.finishHydration()
            return .none
        }
        return applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .selectedTab(tabID: tabID, pane: targetTab.pane)
            ),
            state: &state
        )
    }

    func handleTabSelectionFailed(
        state: inout State,
        message: String?
    ) {
        state.application.failHydration(
            message: message,
            showingHome: state.workspace.activeTab == nil ? true : nil
        )
    }

    func handleTabClosed(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        guard let closure = state.workspace.closeTab(id: tabID) else { return .none }
        return .merge(
            effect(for: closure.disposition, state: &state),
            .send(.workspacePersistenceRequested(discardArtifactsRequest(for: closure.removedTabs)))
        )
    }

    func handleCloseOtherTabs(
        state: inout State,
        retaining tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        let closure = state.workspace.closeOtherTabs(retaining: tabID)
        return .merge(
            effect(for: closure.disposition, state: &state),
            .send(.workspacePersistenceRequested(discardArtifactsRequest(for: closure.removedTabs)))
        )
    }

    func handleCloseTabsToRight(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        let closure = state.workspace.closeTabsToRight(of: tabID)
        return .merge(
            effect(for: closure.disposition, state: &state),
            .send(.workspacePersistenceRequested(discardArtifactsRequest(for: closure.removedTabs)))
        )
    }
}
