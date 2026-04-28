import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension RootFeatureWorkflowReducer {
    func handleTabSelection(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        guard state.workspace.tab(withID: tabID) != nil else {
            return .none
        }
        if state.workspace.isActiveTab(tabID), !state.application.showsHome {
            return .none
        }
        let replacementRequest: WorkspaceDocumentReplacementRequest?
        if !state.application.showsHome {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                replacementRequest = request
            case let .failure(failure):
                return .send(.application(.bannerPresented(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                )))
            }
        } else {
            replacementRequest = nil
        }
        return .merge(
            .send(.application(.hydrationStarted)),
            .send(.workspace(.tabProjectLoadRequested(tabID, replacementRequest)))
        )
    }

    func handleTabSelectionLoaded(
        state: inout State,
        tabID: OpenDocumentTab.ID,
        loaded: LoadedPaintProject
    ) -> Effect<Action> {
        guard let targetTab = state.workspace.tab(withID: tabID) else {
            return .send(.application(.hydrationFinished()))
        }
        return applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .selectedTab(tabID: tabID, pane: targetTab.pane)
            ),
            state: &state
        )
    }

}
