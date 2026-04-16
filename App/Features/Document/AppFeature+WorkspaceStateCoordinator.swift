import CoreGraphics
import Foundation

extension AppFeature.WorkspaceState {
    var activeTabIndex: Int? {
        guard let activeTabID else { return nil }
        return openTabs.firstIndex(where: { $0.id == activeTabID })
    }

    var activeTab: OpenDocumentTab? {
        guard let activeTabIndex else { return nil }
        return openTabs[activeTabIndex]
    }

    func selectedTabID(for pane: WorkspacePane) -> OpenDocumentTab.ID? {
        switch pane {
        case .primary:
            return primarySelectedTabID
        case .secondary:
            return secondarySelectedTabID
        }
    }

    mutating func setSelectedTabID(
        _ tabID: OpenDocumentTab.ID?,
        for pane: WorkspacePane
    ) {
        switch pane {
        case .primary:
            primarySelectedTabID = tabID
        case .secondary:
            secondarySelectedTabID = tabID
        }
    }

    func tabs(in pane: WorkspacePane) -> [OpenDocumentTab] {
        openTabs.filter { $0.pane == pane }
    }

    func selectedTab(in pane: WorkspacePane) -> OpenDocumentTab? {
        guard let tabID = selectedTabID(for: pane) else { return nil }
        return openTabs.first(where: { $0.id == tabID })
    }

    func hasTabs(in pane: WorkspacePane) -> Bool {
        openTabs.contains(where: { $0.pane == pane })
    }

    func tabID(
        forSourceProjectURL sourceProjectURL: DocumentProjectPath
    ) -> OpenDocumentTab.ID? {
        openTabs.first { $0.sourceProjectURL == sourceProjectURL }?.id
    }

    mutating func updateActiveTabMetadata(
        title: String? = nil,
        sourceProjectURL: DocumentProjectPath? = nil,
        previewImageData: Data? = nil,
        canvasSize: CGSize
    ) {
        guard let activeTabIndex else { return }
        if let title {
            openTabs[activeTabIndex].title = title
        }
        if let sourceProjectURL {
            openTabs[activeTabIndex].sourceProjectURL = sourceProjectURL
        }
        if let previewImageData {
            openTabs[activeTabIndex].previewImageData = previewImageData
        }
        openTabs[activeTabIndex].canvasSize = canvasSize
    }

    mutating func setActiveTabDirty(_ isDirty: Bool) {
        guard let activeTabIndex else { return }
        openTabs[activeTabIndex].isDirty = isDirty
    }

    mutating func reorderTabs(
        moving movingID: OpenDocumentTab.ID,
        before targetID: OpenDocumentTab.ID
    ) {
        guard
            let sourceIndex = openTabs.firstIndex(where: { $0.id == movingID }),
            let destinationIndex = openTabs.firstIndex(where: { $0.id == targetID }),
            sourceIndex != destinationIndex
        else {
            return
        }
        let tab = openTabs.remove(at: sourceIndex)
        let adjustedDestination = sourceIndex < destinationIndex ? max(destinationIndex - 1, 0) : destinationIndex
        openTabs.insert(tab, at: adjustedDestination)
    }

    mutating func moveTab(
        _ movingID: OpenDocumentTab.ID,
        to pane: WorkspacePane,
        before targetID: OpenDocumentTab.ID?
    ) {
        guard let sourceIndex = openTabs.firstIndex(where: { $0.id == movingID }) else { return }
        let sourcePane = openTabs[sourceIndex].pane
        var tab = openTabs.remove(at: sourceIndex)
        tab.pane = pane

        if let targetID, let destinationIndex = openTabs.firstIndex(where: { $0.id == targetID }) {
            openTabs.insert(tab, at: destinationIndex)
        } else {
            openTabs.append(tab)
        }

        setSelectedTabID(tab.id, for: pane)
        if selectedTabID(for: sourcePane) == movingID {
            setSelectedTabID(tabs(in: sourcePane).first?.id, for: sourcePane)
        }
        if activeTabID == movingID {
            focusedWorkspacePane = pane
        }
        workspaceLayout = hasTabs(in: .secondary) ? .split : .single
    }

    mutating func ensureSelectionIntegrity() {
        if primarySelectedTabID != nil,
           openTabs.contains(where: { $0.id == primarySelectedTabID && $0.pane == .primary }) == false {
            primarySelectedTabID = tabs(in: .primary).first?.id
        }
        if secondarySelectedTabID != nil,
           openTabs.contains(where: { $0.id == secondarySelectedTabID && $0.pane == .secondary }) == false {
            secondarySelectedTabID = tabs(in: .secondary).first?.id
        }
        if primarySelectedTabID == nil {
            primarySelectedTabID = tabs(in: .primary).first?.id
        }
        if !hasTabs(in: .secondary) {
            secondarySelectedTabID = nil
            workspaceLayout = .single
            if focusedWorkspacePane == .secondary {
                focusedWorkspacePane = .primary
            }
        }
    }
}
