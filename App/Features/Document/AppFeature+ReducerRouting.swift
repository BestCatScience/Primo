import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleBootstrapPresentationLoaded(
        state: inout State,
        presentation: PaintDocumentPresentation
    ) {
        state.applyPresentation(presentation)
        state.isHydrating = false
        Self.startupLogger.debug("Bootstrap presentation applied; initial UI is ready")
    }

    func handleAutosaveRecoveryLoaded(
        state: inout State,
        items: [AutosaveRecoveryItem]
    ) {
        state.autosaveRecoveryItems = items
        state.isShowingAutosaveRecovery = !items.isEmpty
    }

    func handleAutosaveRecoveryDismissed(state: inout State) {
        state.isShowingAutosaveRecovery = false
    }

    func handleHomeSectionSelected(
        state: inout State,
        section: HomeSidebarSection
    ) {
        state.homeSection = section
    }

    func handlePendingCloseSaveConfirmed(state: inout State) -> Effect<Action> {
        guard let confirmation = state.pendingCloseConfirmation else { return .none }
        do {
            try saveTabsForClose(confirmation.tabIDs, state: &state)
            state.pendingCloseConfirmation = nil
            return performCloseOperation(state: &state, operation: confirmation.operation)
        } catch {
            state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Save failed") : error.localizedDescription
            state.pendingCloseConfirmation = nil
            return .none
        }
    }

    func handlePendingCloseDiscardConfirmed(state: inout State) -> Effect<Action> {
        guard let confirmation = state.pendingCloseConfirmation else { return .none }
        state.pendingCloseConfirmation = nil
        return performCloseOperation(state: &state, operation: confirmation.operation)
    }

    func handlePendingCloseCancelled(state: inout State) {
        state.pendingCloseConfirmation = nil
    }

    func handleMoveTabToSecondaryPane(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        state.workspaceLayout = .split
        state.moveTab(tabID, to: .secondary, before: nil)
        state.ensureWorkspaceSelectionIntegrity()
    }

    func handleTabReordered(
        state: inout State,
        movingID: OpenDocumentTab.ID,
        targetID: OpenDocumentTab.ID
    ) {
        state.reorderTabs(moving: movingID, before: targetID)
    }

    func handleTabDropped(
        state: inout State,
        movingID: OpenDocumentTab.ID,
        pane: WorkspacePane,
        targetID: OpenDocumentTab.ID?
    ) {
        state.moveTab(movingID, to: pane, before: targetID)
    }

    func handleSplitActiveTabIntoSecondaryPane(state: inout State) {
        state.workspaceLayout = .split
        state.ensureWorkspaceSelectionIntegrity()
    }

    func handleMergeWorkspacePanes(state: inout State) {
        let secondaryTabs = state.tabs(in: .secondary).map(\.id)
        for tabID in secondaryTabs {
            state.moveTab(tabID, to: .primary, before: nil)
        }
        state.workspaceLayout = .single
        state.secondarySelectedTabID = nil
        state.focusedWorkspacePane = .primary
        state.ensureWorkspaceSelectionIntegrity()
    }

    func handleWorkspacePaneActivated(
        state: inout State,
        pane: WorkspacePane
    ) -> Effect<Action> {
        state.focusedWorkspacePane = pane
        guard let tabID = state.selectedTabID(for: pane) else { return .none }
        guard state.activeTabID != tabID else { return .none }
        return .send(.tabSelected(tabID))
    }

    func handlePresentationLoaded(
        state: inout State,
        presentation: PaintDocumentPresentation
    ) {
        guard !state.canvas.isStrokeActive else { return }
        state.applyPresentation(presentation)
        Self.startupLogger.debug("Full presentation applied")
    }

    func handleNewCanvasFromImageFailed(
        state: inout State,
        message: String
    ) {
        state.bannerMessage = message.isEmpty ? state.appLanguage.localized("Could not create canvas from image") : message
    }

    func handleNanoBananaPreviewDiscarded(state: inout State) {
        state.nanoBananaPreview = nil
        state.activeNanoBananaJobID = nil
    }

    func handleNanoBananaRegenerateRequested(state: inout State) -> Effect<Action> {
        guard let request = state.nanoBananaPreview?.request ?? state.pendingNanoBananaRequest else { return .none }
        state.nanoBananaPreview = nil
        return .send(.nanoBananaEditRequested(request))
    }

    func handleNanoBananaRetryJob(
        state: inout State,
        jobID: UUID
    ) -> Effect<Action> {
        guard let job = state.nanoBananaJobs.first(where: { $0.id == jobID }) else { return .none }
        return .send(.nanoBananaEditRequested(job.request))
    }

    func handleTimelapseExportProgressUpdated(
        state: inout State,
        progress: Double,
        previewData: Data?
    ) {
        state.timelapseExportPreview = TimelapseExportPreview(
            progress: progress,
            previewImageData: previewData ?? state.timelapseExportPreview?.previewImageData
        )
    }

    func handleTimelapseExportSucceeded(
        state: inout State,
        url: URL
    ) {
        state.timelapseExportPreview = nil
        state.exportSheet = makeShareExport(url: url)
    }

    func handleTimelapseExportFailed(
        state: inout State,
        message: String
    ) {
        state.timelapseExportPreview = nil
        state.bannerMessage = message
    }

    func handleExportSheetDismissed(state: inout State) {
        state.exportSheet = nil
    }

    func handleBannerDismissed(state: inout State) {
        state.bannerMessage = nil
    }

    func handleOpenDocumentFailed(
        state: inout State,
        message: String
    ) {
        state.isHydrating = false
        state.bannerMessage = message.isEmpty ? StudioStrings.openFailed(state.appLanguage) : message
    }

    func handlePhotoImportFailed(
        state: inout State,
        message: String
    ) {
        state.bannerMessage = message.isEmpty ? state.appLanguage.localized("Could not import photo") : message
    }
}
