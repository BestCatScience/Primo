import Foundation

extension AppFeature.State {
    var activeTabIndex: Int? {
        workspace.activeTabIndex
    }

    var activeTab: OpenDocumentTab? {
        workspace.activeTab
    }

    func selectedTabID(for pane: WorkspacePane) -> OpenDocumentTab.ID? {
        workspace.selectedTabID(for: pane)
    }

    mutating func setSelectedTabID(_ tabID: OpenDocumentTab.ID?, for pane: WorkspacePane) {
        workspace.setSelectedTabID(tabID, for: pane)
    }

    func tabs(in pane: WorkspacePane) -> [OpenDocumentTab] {
        workspace.tabs(in: pane)
    }

    func selectedTab(in pane: WorkspacePane) -> OpenDocumentTab? {
        workspace.selectedTab(in: pane)
    }

    func hasTabs(in pane: WorkspacePane) -> Bool {
        workspace.hasTabs(in: pane)
    }

    func tabID(forSourceProjectURL sourceProjectURL: DocumentProjectPath) -> OpenDocumentTab.ID? {
        workspace.tabID(forSourceProjectURL: sourceProjectURL)
    }

    mutating func updateActiveTabMetadata(
        title: String? = nil,
        sourceProjectURL: DocumentProjectPath? = nil,
        previewImageData: Data? = nil
    ) {
        workspace.updateActiveTabMetadata(
            title: title,
            sourceProjectURL: sourceProjectURL,
            previewImageData: previewImageData,
            canvasSize: canvas.canvasSize
        )
    }

    mutating func setActiveTabDirty(_ isDirty: Bool) {
        workspace.setActiveTabDirty(isDirty)
    }

    mutating func reorderTabs(moving movingID: OpenDocumentTab.ID, before targetID: OpenDocumentTab.ID) {
        workspace.reorderTabs(moving: movingID, before: targetID)
    }

    mutating func moveTab(_ movingID: OpenDocumentTab.ID, to pane: WorkspacePane, before targetID: OpenDocumentTab.ID?) {
        workspace.moveTab(movingID, to: pane, before: targetID)
    }

    mutating func ensureWorkspaceSelectionIntegrity() {
        workspace.ensureSelectionIntegrity()
    }
}
