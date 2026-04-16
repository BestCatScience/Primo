import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleBootstrapPresentationLoaded(
        state: inout State,
        presentation: PaintDocumentPresentation
    ) {
        applyPresentation(presentation, state: &state)
        state.application.finishHydration()
        Self.startupLogger.debug("Bootstrap presentation applied; initial UI is ready")
    }

    func handleAutosaveRecoveryLoaded(
        state: inout State,
        items: [AutosaveRecoveryItem]
    ) {
        state.recovery.present(items: items)
    }

    func handleAutosaveRecoveryDismissed(state: inout State) {
        state.recovery.dismiss()
    }

    func handleHomeSectionSelected(
        state: inout State,
        section: HomeSidebarSection
    ) {
        state.application.selectHomeSection(section)
    }

    func handlePendingCloseSaveConfirmed(state: inout State) -> Effect<Action> {
        guard let confirmation = state.workspace.pendingCloseConfirmation else { return .none }
        do {
            try saveTabsForClose(confirmation.tabIDs, state: &state)
            state.workspace.clearCloseConfirmation()
            return performCloseOperation(state: &state, operation: confirmation.operation)
        } catch {
            state.application.presentBanner(
                error.localizedDescription.isEmpty ? state.application.appLanguage.localized("Save failed") : error.localizedDescription
            )
            state.workspace.clearCloseConfirmation()
            return .none
        }
    }

    func handlePendingCloseDiscardConfirmed(state: inout State) -> Effect<Action> {
        guard let confirmation = state.workspace.pendingCloseConfirmation else { return .none }
        state.workspace.clearCloseConfirmation()
        return performCloseOperation(state: &state, operation: confirmation.operation)
    }

    func handlePendingCloseCancelled(state: inout State) {
        state.workspace.clearCloseConfirmation()
    }

    func handleMoveTabToSecondaryPane(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        state.workspace.beginSplitLayout()
        state.workspace.moveTab(tabID, to: .secondary, before: nil)
        state.workspace.ensureSelectionIntegrity()
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
        state.workspace.beginSplitLayout()
        state.workspace.ensureSelectionIntegrity()
    }

    func handleMergeWorkspacePanes(state: inout State) {
        let secondaryTabs = state.workspace.tabs(in: .secondary).map(\.id)
        for tabID in secondaryTabs {
            state.workspace.moveTab(tabID, to: .primary, before: nil)
        }
        state.workspace.collapseToPrimaryLayout()
        state.workspace.ensureSelectionIntegrity()
    }

    func handleWorkspacePaneActivated(
        state: inout State,
        pane: WorkspacePane
    ) -> Effect<Action> {
        state.workspace.focus(on: pane)
        guard let tabID = state.workspace.selectedTabID(for: pane) else { return .none }
        guard state.workspace.isActiveTab(tabID) == false else { return .none }
        return .send(.tabSelected(tabID))
    }

    func handlePresentationLoaded(
        state: inout State,
        presentation: PaintDocumentPresentation
    ) {
        guard !state.canvas.isStrokeActive else { return }
        applyPresentation(presentation, state: &state)
        Self.startupLogger.debug("Full presentation applied")
    }

    func handleNewCanvasFromImageFailed(
        state: inout State,
        message: String
    ) {
        state.application.presentBanner(
            message.isEmpty ? state.application.appLanguage.localized("Could not create canvas from image") : message
        )
    }

    func handleNanoBananaRegenerateRequested(state: inout State) -> Effect<Action> {
        guard let request = state.nanoBanana.regenerationRequest() else { return .none }
        return .send(.nanoBananaEditRequested(request))
    }

    func handleNanoBananaRetryJob(
        state: inout State,
        jobID: UUID
    ) -> Effect<Action> {
        guard let request = state.nanoBanana.retryRequest(for: jobID) else { return .none }
        return .send(.nanoBananaEditRequested(request))
    }

    func handleTimelapseExportProgressUpdated(
        state: inout State,
        progress: Double,
        previewData: Data?
    ) {
        state.export.updateTimelapsePreview(progress: progress, previewData: previewData)
    }

    func handleTimelapseExportSucceeded(
        state: inout State,
        url: URL
    ) {
        state.export.completeTimelapseExport(with: makeShareExport(url: url))
    }

    func handleTimelapseExportFailed(
        state: inout State,
        message: String
    ) {
        state.export.failTimelapseExport()
        state.application.presentBanner(message)
    }

    func handleExportSheetDismissed(state: inout State) {
        state.export.dismissShareSheet()
    }

    func handleBannerDismissed(state: inout State) {
        state.application.clearBanner()
    }

    func handleOpenDocumentFailed(
        state: inout State,
        message: String
    ) {
        state.application.finishHydration()
        state.application.presentBanner(
            message.isEmpty ? StudioStrings.openFailed(state.application.appLanguage) : message
        )
    }

    func handlePhotoImportFailed(
        state: inout State,
        message: String
    ) {
        state.application.presentBanner(
            message.isEmpty ? state.application.appLanguage.localized("Could not import photo") : message
        )
    }
}
