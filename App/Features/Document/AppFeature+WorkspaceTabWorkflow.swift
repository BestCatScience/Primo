import ComposableArchitecture
import Foundation

extension AppFeature {
    private struct WorkspaceTabCoordinator {
        let paintDocumentClient: PaintDocumentClient
        let documentWorkspaceClient: DocumentWorkspaceClient

        func loadAutosaveRecoveryEffect() -> Effect<Action> {
            .run { [documentWorkspaceClient] send in
                let items = (try? documentWorkspaceClient.loadAutosaveRecoveryItems()) ?? []
                await send(.autosaveRecoveryLoaded(items))
            }
        }

        func restoreAutosaveEffect(item: AutosaveRecoveryItem) -> Effect<Action> {
            .run { [paintDocumentClient] send in
                do {
                    let loaded = try paintDocumentClient.loadProject(item.autosaveProjectURL.fileURL)
                    await send(.autosaveRecoveryOpened(loaded, item))
                } catch {
                    await send(.openDocumentFailed(error.localizedDescription))
                }
            }
        }

        func openProjectEffect(
            at url: DocumentProjectPath,
            removeWorkspaceItemAfterLoad: Bool
        ) -> Effect<Action> {
            .run { [paintDocumentClient, documentWorkspaceClient] send in
                do {
                    let loaded = try paintDocumentClient.loadProject(url.fileURL)
                    await send(.openDocumentLoaded(loaded, url))
                } catch {
                    await send(.openDocumentFailed(error.localizedDescription))
                }
                guard removeWorkspaceItemAfterLoad else { return }
                try? documentWorkspaceClient.removeWorkspaceItem(url)
            }
        }
    }

    private var workspaceTabCoordinator: WorkspaceTabCoordinator {
        WorkspaceTabCoordinator(
            paintDocumentClient: paintDocumentClient,
            documentWorkspaceClient: documentWorkspaceClient
        )
    }

    func handleAutosaveRecoveryLoadRequest() -> Effect<Action> {
        workspaceTabCoordinator.loadAutosaveRecoveryEffect()
    }

    func handleAutosaveRecoveryRestoreRequest(
        state: inout State,
        autosaveID: WorkspaceItemID
    ) -> Effect<Action> {
        guard let item = state.autosaveRecoveryItems.first(where: { $0.id == autosaveID }) else {
            return .none
        }
        if !state.showsHome {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        state.isHydrating = true
        state.isShowingAutosaveRecovery = false
        return workspaceTabCoordinator.restoreAutosaveEffect(item: item)
    }

    func handleAutosaveRecoveryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        item: AutosaveRecoveryItem
    ) {
        try? documentWorkspaceClient.discardAutosaveEntry(item.id)
        state.applyLoadedProject(loaded)
        activateNewTab(
            state: &state,
            title: item.title,
            sourceProjectURL: item.sourceProjectURL
        )
        state.setActiveTabDirty(true)
        _ = persistActiveTabToBackingStore(state: &state)
        persistActiveTabAutosave(state: &state)
        state.isHydrating = false
        state.showsHome = false
        state.autosaveRecoveryItems.removeAll { $0.id == item.id }
        state.isShowingAutosaveRecovery = false
        state.bannerMessage = state.appLanguage.localized("自動保存から復元しました")
    }

    func handleAutosaveRecoveryDiscardRequest(
        state: inout State,
        autosaveID: WorkspaceItemID
    ) {
        state.autosaveRecoveryItems.removeAll { $0.id == autosaveID }
        state.isShowingAutosaveRecovery = !state.autosaveRecoveryItems.isEmpty
        try? documentWorkspaceClient.discardAutosaveEntry(autosaveID)
    }

    func handleTabSelection(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let targetTab = state.openTabs.first(where: { $0.id == tabID }) else {
            return
        }
        if !state.showsHome, state.activeTabID != tabID {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        do {
            let loaded = try paintDocumentClient.loadProject(targetTab.backingStoreURL.fileURL)
            state.activeTabID = tabID
            state.setSelectedTabID(tabID, for: targetTab.pane)
            state.focusedWorkspacePane = targetTab.pane
            state.applyLoadedProject(loaded)
            state.showsHome = false
        } catch {
            state.bannerMessage = error.localizedDescription.isEmpty ? StudioStrings.openFailed(state.appLanguage) : error.localizedDescription
        }
    }

    func handleTabClosed(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let closingIndex = state.openTabs.firstIndex(where: { $0.id == tabID }) else {
            return
        }
        let closingTab = state.openTabs[closingIndex]
        let wasActive = state.activeTabID == tabID
        state.openTabs.remove(at: closingIndex)
        clearAutosave(for: closingTab)
        try? documentWorkspaceClient.removeWorkspaceItem(closingTab.backingStoreURL)
        state.ensureWorkspaceSelectionIntegrity()

        guard wasActive else { return }
        let replacement = state.selectedTab(in: closingTab.pane)
            ?? state.selectedTab(in: closingTab.pane == .primary ? .secondary : .primary)
        guard let replacement else {
            state.activeTabID = nil
            state.showsHome = true
            return
        }

        do {
            let loaded = try paintDocumentClient.loadProject(replacement.backingStoreURL.fileURL)
            state.activeTabID = replacement.id
            state.focusedWorkspacePane = replacement.pane
            state.applyLoadedProject(loaded)
            state.showsHome = false
        } catch {
            state.activeTabID = nil
            state.showsHome = true
            state.bannerMessage = error.localizedDescription.isEmpty ? StudioStrings.openFailed(state.appLanguage) : error.localizedDescription
        }
    }

    func handleCloseOtherTabs(
        state: inout State,
        retaining tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        let retainedTabs = state.openTabs.filter { $0.id == tabID }
        let removedTabs = state.openTabs.filter { $0.id != tabID }
        removedTabs.forEach {
            clearAutosave(for: $0)
            try? documentWorkspaceClient.removeWorkspaceItem($0.backingStoreURL)
        }
        state.openTabs = retainedTabs
        state.primarySelectedTabID = retainedTabs.first(where: { $0.pane == .primary })?.id
        state.secondarySelectedTabID = retainedTabs.first(where: { $0.pane == .secondary })?.id
        if state.activeTabID != tabID {
            return .send(.tabSelected(tabID))
        }
        state.ensureWorkspaceSelectionIntegrity()
        return .none
    }

    func handleCloseTabsToRight(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        guard let tabIndex = state.openTabs.firstIndex(where: { $0.id == tabID }) else { return }
        let tab = state.openTabs[tabIndex]
        let paneTabs = state.openTabs.enumerated().filter { $0.element.pane == tab.pane }
        guard let paneIndex = paneTabs.firstIndex(where: { $0.element.id == tabID }) else { return }
        let idsToRemove = Set(paneTabs.dropFirst(paneIndex + 1).map(\.element.id))
        let removedTabs = state.openTabs.filter { idsToRemove.contains($0.id) }
        removedTabs.forEach {
            clearAutosave(for: $0)
            try? documentWorkspaceClient.removeWorkspaceItem($0.backingStoreURL)
        }
        state.openTabs.removeAll { idsToRemove.contains($0.id) }
        state.ensureWorkspaceSelectionIntegrity()
    }

    func handleSavedProjectMove(
        state: inout State,
        url: DocumentProjectPath,
        relativeFolderPath: RelativeProjectFolderPath?
    ) -> Effect<Action> {
        do {
            let destinationURL = try documentWorkspaceClient.moveSavedProject(url, relativeFolderPath)
            if let openTabIndex = state.openTabs.firstIndex(where: { $0.sourceProjectURL == url }) {
                state.openTabs[openTabIndex].sourceProjectURL = destinationURL
            }
            return .send(.homeProjectsLoadRequested)
        } catch {
            state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Move failed") : error.localizedDescription
            return .none
        }
    }

    func handleOpenDocumentSelection(
        state: inout State,
        url: DocumentProjectPath,
        removesStagedWorkspaceItem: Bool
    ) -> Effect<Action> {
        if let existingTabID = state.tabID(forSourceProjectURL: url) {
            state.showsHome = false
            state.isHydrating = false
            return .send(.tabSelected(existingTabID))
        }
        if !state.showsHome {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        state.isHydrating = true
        return workspaceTabCoordinator.openProjectEffect(
            at: url,
            removeWorkspaceItemAfterLoad: removesStagedWorkspaceItem
        )
    }

    func handleOpenDocumentLoaded(
        state: inout State,
        loaded: LoadedPaintProject,
        sourceURL: DocumentProjectPath
    ) -> Effect<Action> {
        if let existingTabID = state.tabID(forSourceProjectURL: sourceURL) {
            state.activeTabID = existingTabID
            state.isHydrating = false
            state.showsHome = false
            return .send(.tabSelected(existingTabID))
        }
        state.applyLoadedProject(loaded)
        activateNewTab(
            state: &state,
            title: sourceURL.displayName,
            sourceProjectURL: sourceURL
        )
        state.isHydrating = false
        state.showsHome = false
        state.bannerMessage = StudioStrings.openedDocument(loaded.presentation.layerRows.count, state.appLanguage)
        return .none
    }
}
