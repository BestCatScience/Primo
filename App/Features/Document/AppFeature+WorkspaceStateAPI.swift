import Foundation

extension AppFeature.State {
    var activeTabIndex: Int? {
        guard let activeTabID else { return nil }
        return openTabs.firstIndex(where: { $0.id == activeTabID })
    }

    var activeTab: OpenDocumentTab? {
        guard let activeTabIndex else { return nil }
        return openTabs[activeTabIndex]
    }

    func selectedTabID(for pane: WorkspacePane) -> OpenDocumentTab.ID? {
        AppFeature.workspaceStateCoordinator.selectedTabID(for: pane, in: self)
    }

    mutating func setSelectedTabID(_ tabID: OpenDocumentTab.ID?, for pane: WorkspacePane) {
        AppFeature.workspaceStateCoordinator.setSelectedTabID(tabID, for: pane, in: &self)
    }

    func tabs(in pane: WorkspacePane) -> [OpenDocumentTab] {
        AppFeature.workspaceStateCoordinator.tabs(in: pane, state: self)
    }

    func selectedTab(in pane: WorkspacePane) -> OpenDocumentTab? {
        AppFeature.workspaceStateCoordinator.selectedTab(in: pane, state: self)
    }

    func hasTabs(in pane: WorkspacePane) -> Bool {
        AppFeature.workspaceStateCoordinator.hasTabs(in: pane, state: self)
    }

    func tabID(forSourceProjectURL sourceProjectURL: DocumentProjectPath) -> OpenDocumentTab.ID? {
        AppFeature.workspaceStateCoordinator.tabID(forSourceProjectURL: sourceProjectURL, in: self)
    }

    mutating func updateActiveTabMetadata(
        title: String? = nil,
        sourceProjectURL: DocumentProjectPath? = nil,
        previewImageData: Data? = nil
    ) {
        AppFeature.workspaceStateCoordinator.updateActiveTabMetadata(
            title: title,
            sourceProjectURL: sourceProjectURL,
            previewImageData: previewImageData,
            in: &self
        )
    }

    mutating func setActiveTabDirty(_ isDirty: Bool) {
        AppFeature.workspaceStateCoordinator.setActiveTabDirty(isDirty, in: &self)
    }

    mutating func reorderTabs(moving movingID: OpenDocumentTab.ID, before targetID: OpenDocumentTab.ID) {
        AppFeature.workspaceStateCoordinator.reorderTabs(moving: movingID, before: targetID, in: &self)
    }

    mutating func moveTab(_ movingID: OpenDocumentTab.ID, to pane: WorkspacePane, before targetID: OpenDocumentTab.ID?) {
        AppFeature.workspaceStateCoordinator.moveTab(movingID, to: pane, before: targetID, in: &self)
    }

    mutating func ensureWorkspaceSelectionIntegrity() {
        AppFeature.workspaceStateCoordinator.ensureWorkspaceSelectionIntegrity(state: &self)
    }
}
