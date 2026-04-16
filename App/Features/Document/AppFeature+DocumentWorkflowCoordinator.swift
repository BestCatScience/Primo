import ComposableArchitecture
import Foundation

extension AppFeature {
    private struct DocumentWorkflowCoordinator {
        let paintDocumentClient: PaintDocumentClient
        let documentWorkspaceClient: DocumentWorkspaceClient
        let fileClient: FileClient
        let dateClient: DateClient

        func loadSaveHistoryEffect(for activeTab: OpenDocumentTab) -> Effect<Action> {
            .run { [documentWorkspaceClient] send in
                let entries = (try? documentWorkspaceClient.loadSaveHistoryEntries(activeTab)) ?? []
                await send(.saveHistoryLoaded(entries))
            }
        }

        func restoreSaveHistoryEffect(projectURL: URL, openInNewTab: Bool) -> Effect<Action> {
            .run { [paintDocumentClient] send in
                do {
                    let loaded = try paintDocumentClient.loadProject(projectURL)
                    await send(.saveHistoryOpened(loaded, projectURL, openInNewTab))
                } catch {
                    await send(.openDocumentFailed(error.localizedDescription))
                }
            }
        }

        func makeTimelapseExportEffect(
            capture: TimelapseCapture,
            failureMessage: String
        ) -> Effect<Action> {
            .run { [documentWorkspaceClient, fileClient, dateClient] send in
                do {
                    let url = try TimelapseExporter.exportVideo(
                        from: capture,
                        to: documentWorkspaceClient.timelapseTemporaryDirectory(),
                        fileClient: fileClient,
                        dateClient: dateClient
                    ) { progress, previewURL in
                        let previewData = try? fileClient.readData(previewURL)
                        Task {
                            await send(.timelapseExportProgressUpdated(progress, previewData))
                        }
                    }
                    await send(.timelapseExportSucceeded(url))
                } catch {
                    await send(.timelapseExportFailed(failureMessage))
                }
            }
            .cancellable(id: CancelID.timelapseExport, cancelInFlight: true)
        }
    }

    private var documentWorkflowCoordinator: DocumentWorkflowCoordinator {
        DocumentWorkflowCoordinator(
            paintDocumentClient: paintDocumentClient,
            documentWorkspaceClient: documentWorkspaceClient,
            fileClient: fileClient,
            dateClient: dateClient
        )
    }

    func handleSaveHistoryRequest(state: inout State) -> Effect<Action> {
        guard let activeTab = state.activeTab else { return .none }
        state.isShowingSaveHistory = true
        return documentWorkflowCoordinator.loadSaveHistoryEffect(for: activeTab)
    }

    func handleSaveHistoryRestoreRequest(
        state: inout State,
        projectURL: URL,
        openInNewTab: Bool
    ) -> Effect<Action> {
        if !state.showsHome {
            persistActiveTabToBackingStore(state: &state)
        }
        state.isHydrating = true
        return documentWorkflowCoordinator.restoreSaveHistoryEffect(
            projectURL: projectURL,
            openInNewTab: openInNewTab
        )
    }

    func handleSaveHistoryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        projectURL: URL,
        openInNewTab: Bool
    ) {
        let restoredTitle = projectURL.deletingPathExtension().lastPathComponent
        if openInNewTab || state.activeTab == nil {
            state.applyLoadedProject(loaded)
            activateNewTab(
                state: &state,
                title: "\(restoredTitle) Snapshot",
                sourceProjectURL: nil
            )
        } else {
            let existingSourceURL = state.activeTab?.sourceProjectURL
            let existingTitle = state.activeTab?.title ?? restoredTitle
            state.applyLoadedProject(loaded)
            state.updateActiveTabMetadata(
                title: existingTitle,
                sourceProjectURL: existingSourceURL,
                previewImageData: paintDocumentClient.compositePNGData(state.resolvedPaperStyle())
            )
        }
        state.setActiveTabDirty(true)
        persistActiveTabToBackingStore(state: &state)
        persistActiveTabAutosave(state: &state)
        state.isHydrating = false
        state.showsHome = false
        state.isShowingSaveHistory = false
        state.bannerMessage = state.appLanguage.localized("保存履歴を復元しました")
    }

    func handleSaveDocumentRequest(
        state: inout State,
        preferredDestinationURL: URL?
    ) -> Effect<Action> {
        guard let savedURL = persistActiveProjectToWorkspace(
            state: &state,
            preferredDestinationURL: preferredDestinationURL
        ) else {
            return .none
        }
        state.bannerMessage = StudioStrings.savedDocument(savedURL.lastPathComponent, state.appLanguage)
        if let activeTab = state.activeTab {
            persistSaveHistorySnapshot(for: activeTab, trigger: .manualSave)
        }
        return .send(.homeProjectsLoadRequested)
    }

    func handleTimelapseExportRequest(state: inout State) -> Effect<Action> {
        guard let capture = paintDocumentClient.timelapseCapture() else {
            state.bannerMessage = state.appLanguage.localized("Not enough drawing history for timelapse yet")
            return .none
        }
        state.timelapseExportPreview = TimelapseExportPreview(
            progress: 0,
            previewImageData: capture.previewImageData
        )
        return documentWorkflowCoordinator.makeTimelapseExportEffect(
            capture: capture,
            failureMessage: state.appLanguage.localized("Timelapse export failed")
        )
    }
}
