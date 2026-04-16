import Foundation

extension AppFeature.State {
    var nanoBananaProgress: Double? {
        guard isNanoBananaGenerating else { return nil }
        return 0.6
    }

    var activeTabIndex: Int? {
        guard let activeTabID else { return nil }
        return openTabs.firstIndex(where: { $0.id == activeTabID })
    }

    var activeTab: OpenDocumentTab? {
        guard let activeTabIndex else { return nil }
        return openTabs[activeTabIndex]
    }

    func selectedTabID(for pane: WorkspacePane) -> OpenDocumentTab.ID? {
        AppFeature.stateCoordinator.selectedTabID(for: pane, in: self)
    }

    mutating func setSelectedTabID(_ tabID: OpenDocumentTab.ID?, for pane: WorkspacePane) {
        AppFeature.stateCoordinator.setSelectedTabID(tabID, for: pane, in: &self)
    }

    func tabs(in pane: WorkspacePane) -> [OpenDocumentTab] {
        AppFeature.stateCoordinator.tabs(in: pane, state: self)
    }

    func selectedTab(in pane: WorkspacePane) -> OpenDocumentTab? {
        AppFeature.stateCoordinator.selectedTab(in: pane, state: self)
    }

    func hasTabs(in pane: WorkspacePane) -> Bool {
        AppFeature.stateCoordinator.hasTabs(in: pane, state: self)
    }

    func tabID(forSourceProjectURL sourceProjectURL: DocumentProjectPath) -> OpenDocumentTab.ID? {
        AppFeature.stateCoordinator.tabID(forSourceProjectURL: sourceProjectURL, in: self)
    }

    mutating func applyPresentation(_ presentation: PaintDocumentPresentation) {
        AppFeature.uiStateCoordinator.applyPresentation(presentation, to: &self)
    }

    mutating func updateActiveTabMetadata(
        title: String? = nil,
        sourceProjectURL: DocumentProjectPath? = nil,
        previewImageData: Data? = nil
    ) {
        AppFeature.stateCoordinator.updateActiveTabMetadata(
            title: title,
            sourceProjectURL: sourceProjectURL,
            previewImageData: previewImageData,
            in: &self
        )
    }

    mutating func setActiveTabDirty(_ isDirty: Bool) {
        AppFeature.stateCoordinator.setActiveTabDirty(isDirty, in: &self)
    }

    mutating func reorderTabs(moving movingID: OpenDocumentTab.ID, before targetID: OpenDocumentTab.ID) {
        AppFeature.stateCoordinator.reorderTabs(moving: movingID, before: targetID, in: &self)
    }

    mutating func moveTab(_ movingID: OpenDocumentTab.ID, to pane: WorkspacePane, before targetID: OpenDocumentTab.ID?) {
        AppFeature.stateCoordinator.moveTab(movingID, to: pane, before: targetID, in: &self)
    }

    mutating func ensureWorkspaceSelectionIntegrity() {
        AppFeature.stateCoordinator.ensureWorkspaceSelectionIntegrity(state: &self)
    }

    mutating func applyLoadedProject(_ loaded: LoadedPaintProject) {
        AppFeature.uiStateCoordinator.applyLoadedProject(loaded, to: &self)
    }

    mutating func syncTextEditorWithActiveLayer() {
        AppFeature.uiStateCoordinator.syncTextEditorWithActiveLayer(state: &self)
    }

    mutating func applyLiveCompositePixelData(_ compositePixelData: Data) {
        AppFeature.uiStateCoordinator.applyLiveCompositePixelData(compositePixelData, to: &self)
    }

    mutating func applyLiveStrokePreview(
        baseSnapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) {
        AppFeature.uiStateCoordinator.applyLiveStrokePreview(
            baseSnapshot: baseSnapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            to: &self
        )
    }

    func resolvedBrushSettings() -> BrushRuntimeSettings {
        AppFeature.uiStateCoordinator.resolvedBrushSettings(for: self)
    }

    func previewStrokeStyle() -> PreviewStrokeStyle {
        AppFeature.uiStateCoordinator.previewStrokeStyle(for: self)
    }

    func resolvedPaperStyle() -> CanvasPaperStyle {
        AppFeature.uiStateCoordinator.resolvedPaperStyle(for: self)
    }

    func panelState(for panel: StudioPanelKind) -> StudioPanelLayoutState {
        AppFeature.stateCoordinator.panelState(for: panel, in: self)
    }

    mutating func setPanelState(_ panelState: StudioPanelLayoutState, for panel: StudioPanelKind) {
        AppFeature.stateCoordinator.setPanelState(panelState, for: panel, in: &self)
    }

    mutating func toggleCollapse(for panel: StudioPanelKind) {
        AppFeature.stateCoordinator.toggleCollapse(for: panel, in: &self)
    }

    mutating func syncToolSpecificBrushSize() {
        AppFeature.stateCoordinator.syncToolSpecificBrushSize(state: &self)
    }

    mutating func applyToolSpecificBrushSize(for tool: StudioToolKind) {
        AppFeature.stateCoordinator.applyToolSpecificBrushSize(for: tool, state: &self)
    }
}
