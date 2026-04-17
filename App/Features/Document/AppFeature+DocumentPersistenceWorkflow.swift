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
        if !state.application.showsHome {
            persistActiveTabToBackingStore(state: &state)
        }
        state.application.beginHydration()
        return workspaceTabCoordinator.loadProjectEffect(
            from: projectURL.fileURL,
            onSuccess: { .saveHistoryOpened($0, projectURL, openInNewTab) },
            onFailure: { .openDocumentFailed($0) }
        )
    }

    func handleSaveHistoryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        projectURL: DocumentProjectPath,
        openInNewTab: Bool
    ) {
        let restoredTitle = projectURL.displayName
        if openInNewTab || state.workspace.activeTab == nil {
            applyLoadedProject(loaded, state: &state)
            activateNewTab(
                state: &state,
                title: "\(restoredTitle) Snapshot",
                sourceProjectURL: nil
            )
        } else {
            let existingSourceURL = state.workspace.activeTab?.sourceProjectURL
            let existingTitle = state.workspace.activeTab?.title ?? restoredTitle
            applyLoadedProject(loaded, state: &state)
            state.workspace.updateActiveTabMetadata(
                title: existingTitle,
                sourceProjectURL: existingSourceURL,
                previewImageData: compositePNGData(state: state),
                canvasSize: state.canvas.canvasSize
            )
        }
        state.workspace.setActiveTabDirty(true)
        persistActiveTabToBackingStore(state: &state)
        persistActiveTabAutosave(state: &state)
        state.application.finishHydration(showingHome: false)
        state.saveHistory.dismiss()
        state.application.presentBanner(state.application.appLanguage.localized("保存履歴を復元しました"))
    }

    func handleSaveDocumentRequest(
        state: inout State,
        preferredDestinationURL: DocumentProjectPath?
    ) -> Effect<Action> {
        guard let savedURL = persistActiveProjectToWorkspace(
            state: &state,
            preferredDestinationURL: preferredDestinationURL
        ) else {
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
}
