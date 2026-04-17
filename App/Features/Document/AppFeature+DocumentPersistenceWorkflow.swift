import ComposableArchitecture
import Foundation

extension AppFeature {
    private struct SaveHistoryWorkflowCoordinator {
        let workspaceCatalogService: WorkspaceCatalogService

        func loadSaveHistoryEffect(for activeTab: OpenDocumentTab) -> Effect<Action> {
            .run { [workspaceCatalogService] send in
                let entries = (try? workspaceCatalogService.loadSaveHistoryEntries(for: activeTab)) ?? []
                await send(.saveHistoryLoaded(entries))
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
            onFailure: { .saveHistoryRestoreFailed($0) }
        )
    }

    func handleSaveHistoryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        projectURL: DocumentProjectPath,
        openInNewTab: Bool
    ) {
        let restoredTitle = projectURL.displayName
        let restorationMessage = state.application.appLanguage.localized("保存履歴を復元しました")
        if openInNewTab || state.workspace.activeTab == nil {
            applyLoadedWorkspaceProject(
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
                        bannerMessage: restorationMessage
                    )
                ),
                state: &state
            )
        } else {
            let existingSourceURL = state.workspace.activeTab?.sourceProjectURL
            let existingTitle = state.workspace.activeTab?.title ?? restoredTitle
            applyLoadedWorkspaceProject(
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
                        bannerMessage: restorationMessage
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
        let savedURL: DocumentProjectPath
        switch persistActiveProjectToWorkspace(
            state: &state,
            preferredDestinationURL: preferredDestinationURL
        ) {
        case let .success(url):
            savedURL = url
        case let .failure(failure):
            state.application.presentBanner(failure.message)
            return .none
        }
        state.application.presentBanner(
            StudioStrings.savedDocument(savedURL.fileURL.lastPathComponent, state.application.appLanguage)
        )
        if let activeTab = state.workspace.activeTab {
            persistSaveHistorySnapshot(for: activeTab, trigger: .manualSave)
        }
        return .send(.homeProjectsLoadRequested)
    }

    func handleSaveHistoryRestoreFailed(
        state: inout State,
        message: String
    ) {
        state.application.failHydration(
            message: message.isEmpty
                ? state.application.appLanguage.localized("Could not restore save history")
                : message
        )
    }
}
