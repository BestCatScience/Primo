import ComposableArchitecture
import Foundation

extension AppFeature {
    private struct SaveHistoryWorkflowCoordinator {
        let workspaceCatalogService: WorkspaceCatalogService

        func loadSaveHistoryEffect(for activeTab: OpenDocumentTab) -> Effect<Action> {
            .run { [workspaceCatalogService] send in
                do {
                    await send(.saveHistoryLoaded(try workspaceCatalogService.loadSaveHistoryEntries(for: activeTab)))
                } catch {
                    await send(
                        .saveHistoryLoadFailed(
                            .saveHistoryRestoreFailed(AppFeature.optionalErrorMessage(error))
                        )
                    )
                }
            }
        }
    }

    private var saveHistoryWorkflowCoordinator: SaveHistoryWorkflowCoordinator {
        SaveHistoryWorkflowCoordinator(
            workspaceCatalogService: workspaceCatalogService
        )
    }

    func handleSaveHistoryRequest(state: inout State) -> Effect<Action> {
        guard let activeTab = state.workspace.activeTab else { return .none }
        state.saveHistory.beginPresentation()
        return saveHistoryWorkflowCoordinator.loadSaveHistoryEffect(for: activeTab)
    }

    func handleSaveHistoryRestoreRequest(
        state: inout State,
        projectURL: DocumentProjectPath,
        openInNewTab: Bool
    ) -> Effect<Action> {
        return beginWorkspaceProjectLoad(
            state: &state,
            fileURL: projectURL.fileURL,
            onSuccess: { .saveHistoryOpened($0, projectURL, openInNewTab) },
            onFailure: { .saveHistoryRestoreFailed(.saveHistoryRestoreFailed($0.errorMessage)) }
        )
    }

    func handleSaveHistoryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        projectURL: DocumentProjectPath,
        openInNewTab: Bool
    ) -> Effect<Action> {
        let restoredTitle = projectURL.displayName
        if openInNewTab || state.workspace.activeTab == nil {
            return applyLoadedWorkspaceProject(
                loaded,
                using: LoadedWorkspaceProjectPlan(
                    destination: .newTab(
                        title: "\(restoredTitle) Snapshot",
                        sourceProjectURL: nil
                    ),
                    followUp: .init(
                        marksTabDirty: true,
                        persistsToBackingStore: true,
                        persistsAutosave: true
                    ),
                    successEffects: .init(
                        saveHistoryResolution: .completeRestore,
                        feedback: .restoredSaveHistory
                    )
                ),
                state: &state
            )
        } else {
            let existingSourceURL = state.workspace.activeTab?.sourceProjectURL
            let existingTitle = state.workspace.activeTab?.title ?? restoredTitle
            return applyLoadedWorkspaceProject(
                loaded,
                using: LoadedWorkspaceProjectPlan(
                    destination: .activeTab(
                        title: existingTitle,
                        sourceProjectURL: existingSourceURL
                    ),
                    followUp: .init(
                        marksTabDirty: true,
                        persistsToBackingStore: true,
                        persistsAutosave: true
                    ),
                    successEffects: .init(
                        saveHistoryResolution: .completeRestore,
                        feedback: .restoredSaveHistory
                    )
                ),
                state: &state
            )
        }
    }

    func handleSaveDocumentRequest(
        state: inout State,
        preferredDestinationURL: DocumentProjectPath?
    ) -> Effect<Action> {
        switch saveActiveDocumentRequest(
            state: &state,
            preferredDestinationURL: preferredDestinationURL,
            trigger: .manualSave,
            purpose: .saveDocument
        ) {
        case let .success(request):
            return .send(.workspacePersistenceRequested(request))
        case let .failure(failure):
            state.application.presentFeedback(failure.feedback)
            return .none
        }
    }

    func handleSaveHistoryRestoreFailed(
        state: inout State,
        feedback: ApplicationFeedback
    ) {
        state.application.failHydration(feedback: feedback)
    }

    func handleSaveHistoryLoadFailed(
        state: inout State,
        feedback: ApplicationFeedback
    ) {
        state.saveHistory.dismiss()
        state.application.presentFeedback(feedback)
    }
}
