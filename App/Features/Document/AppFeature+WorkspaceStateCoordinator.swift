import CoreGraphics
import Foundation
import PrimoDocumentDomain
import PrimoWorkspaceApplication

extension AppFeature {
    enum WorkspaceTabClosureDisposition {
        case none
        case showHome
        case select(OpenDocumentTab.ID)
    }

    enum WorkspacePaneActivationDisposition {
        case none
        case select(OpenDocumentTab.ID)
    }

    struct WorkspaceTabClosureResult {
        let removedTabs: [OpenDocumentTab]
        let disposition: WorkspaceTabClosureDisposition
    }
}

extension AppFeature.WorkspaceState {
    var activeTabIndex: Int? {
        guard let activeTabID else { return nil }
        return openTabs.firstIndex(where: { $0.id == activeTabID })
    }

    var activeTab: OpenDocumentTab? {
        guard let activeTabIndex else { return nil }
        return openTabs[activeTabIndex]
    }

    func isActiveTab(_ tabID: OpenDocumentTab.ID) -> Bool {
        activeTabID == tabID
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

    mutating func activateTab(_ tabID: OpenDocumentTab.ID, pane: WorkspacePane) {
        activeTabID = tabID
        setSelectedTabID(tabID, for: pane)
        focus(on: pane)
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

    func tab(withID tabID: OpenDocumentTab.ID) -> OpenDocumentTab? {
        openTabs.first(where: { $0.id == tabID })
    }

    func tabID(
        forSourceProjectURL sourceProjectURL: DocumentProjectPath
    ) -> OpenDocumentTab.ID? {
        openTabs.first { $0.sourceProjectURL == sourceProjectURL }?.id
    }

    func tabIDs(excluding retainedTabID: OpenDocumentTab.ID) -> [OpenDocumentTab.ID] {
        openTabs.filter { $0.id != retainedTabID }.map(\.id)
    }

    func tabIDsToRight(of tabID: OpenDocumentTab.ID) -> [OpenDocumentTab.ID] {
        guard let tab = tab(withID: tabID) else { return [] }
        let paneTabs = tabs(in: tab.pane)
        guard let index = paneTabs.firstIndex(where: { $0.id == tabID }) else { return [] }
        return Array(paneTabs.dropFirst(index + 1).map(\.id))
    }

    func dirtyTabs(withIDs tabIDs: [OpenDocumentTab.ID]) -> [OpenDocumentTab] {
        openTabs.filter { tabIDs.contains($0.id) && $0.isDirty }
    }

    mutating func appendTab(_ tab: OpenDocumentTab) {
        openTabs.append(tab)
    }

    @discardableResult
    mutating func updateTab(
        id tabID: OpenDocumentTab.ID,
        title: String? = nil,
        sourceProjectURL: DocumentProjectPath? = nil,
        previewImageData: Data? = nil,
        canvasSize: CGSize? = nil,
        isDirty: Bool? = nil
    ) -> OpenDocumentTab? {
        guard let tabIndex = openTabs.firstIndex(where: { $0.id == tabID }) else { return nil }
        if let title {
            openTabs[tabIndex].title = title
        }
        if let sourceProjectURL {
            openTabs[tabIndex].sourceProjectURL = sourceProjectURL
        }
        if let previewImageData {
            openTabs[tabIndex].previewImageData = previewImageData
        }
        if let canvasSize {
            openTabs[tabIndex].canvasSize = canvasSize
        }
        if let isDirty {
            openTabs[tabIndex].isDirty = isDirty
        }
        return openTabs[tabIndex]
    }

    mutating func updateActiveTabMetadata(
        title: String? = nil,
        sourceProjectURL: DocumentProjectPath? = nil,
        previewImageData: Data? = nil,
        canvasSize: CGSize
    ) {
        guard let activeTabID else { return }
        updateTab(
            id: activeTabID,
            title: title,
            sourceProjectURL: sourceProjectURL,
            previewImageData: previewImageData,
            canvasSize: canvasSize
        )
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

    mutating func beginSplitLayout() {
        workspaceLayout = .split
    }

    mutating func focus(on pane: WorkspacePane) {
        focusedWorkspacePane = pane
    }

    mutating func clearActiveTab() {
        activeTabID = nil
    }

    mutating func collapseToPrimaryLayout() {
        workspaceLayout = .single
        secondarySelectedTabID = nil
        focusedWorkspacePane = .primary
    }

    mutating func presentCloseConfirmation(
        operation: PendingCloseOperation,
        dirtyTabs: [OpenDocumentTab]
    ) {
        pendingCloseConfirmation = PendingCloseConfirmationState(
            operation: operation,
            tabIDs: dirtyTabs.map(\.id),
            tabTitles: dirtyTabs.map(\.title)
        )
    }

    mutating func clearCloseConfirmation() {
        pendingCloseConfirmation = nil
    }

    mutating func consumeCloseConfirmation() -> PendingCloseConfirmationState? {
        let confirmation = pendingCloseConfirmation
        pendingCloseConfirmation = nil
        return confirmation
    }

    @discardableResult
    mutating func removeTab(id tabID: OpenDocumentTab.ID) -> OpenDocumentTab? {
        guard let tabIndex = openTabs.firstIndex(where: { $0.id == tabID }) else { return nil }
        let removedTab = openTabs.remove(at: tabIndex)
        ensureSelectionIntegrity()
        return removedTab
    }

    @discardableResult
    mutating func removeTabs(withIDs tabIDs: Set<OpenDocumentTab.ID>) -> [OpenDocumentTab] {
        let removedTabs = openTabs.filter { tabIDs.contains($0.id) }
        openTabs.removeAll { tabIDs.contains($0.id) }
        ensureSelectionIntegrity()
        return removedTabs
    }

    @discardableResult
    mutating func retainOnlyTab(id tabID: OpenDocumentTab.ID) -> [OpenDocumentTab] {
        let removedTabs = openTabs.filter { $0.id != tabID }
        openTabs = openTabs.filter { $0.id == tabID }
        primarySelectedTabID = openTabs.first(where: { $0.pane == .primary })?.id
        secondarySelectedTabID = openTabs.first(where: { $0.pane == .secondary })?.id
        ensureSelectionIntegrity()
        return removedTabs
    }

    mutating func closeTab(
        id tabID: OpenDocumentTab.ID
    ) -> AppFeature.WorkspaceTabClosureResult? {
        let wasActive = isActiveTab(tabID)
        guard let closingTab = removeTab(id: tabID) else { return nil }

        guard wasActive else {
            return AppFeature.WorkspaceTabClosureResult(
                removedTabs: [closingTab],
                disposition: .none
            )
        }

        let replacement = selectedTab(in: closingTab.pane)
            ?? selectedTab(in: closingTab.pane == .primary ? .secondary : .primary)
        guard let replacement else {
            clearActiveTab()
            return AppFeature.WorkspaceTabClosureResult(
                removedTabs: [closingTab],
                disposition: .showHome
            )
        }

        clearActiveTab()
        return AppFeature.WorkspaceTabClosureResult(
            removedTabs: [closingTab],
            disposition: .select(replacement.id)
        )
    }

    mutating func closeOtherTabs(
        retaining tabID: OpenDocumentTab.ID
    ) -> AppFeature.WorkspaceTabClosureResult {
        let removedTabs = retainOnlyTab(id: tabID)
        return AppFeature.WorkspaceTabClosureResult(
            removedTabs: removedTabs,
            disposition: isActiveTab(tabID) ? .none : .select(tabID)
        )
    }

    mutating func closeTabsToRight(
        of tabID: OpenDocumentTab.ID
    ) -> AppFeature.WorkspaceTabClosureResult {
        let idsToRemove = Set(tabIDsToRight(of: tabID))
        let removedActiveTab = activeTabID.map(idsToRemove.contains) ?? false
        let removedTabs = removeTabs(withIDs: idsToRemove)
        return AppFeature.WorkspaceTabClosureResult(
            removedTabs: removedTabs,
            disposition: removedActiveTab ? .select(tabID) : .none
        )
    }

    mutating func stageTabInSecondaryPane(_ tabID: OpenDocumentTab.ID) {
        beginSplitLayout()
        moveTab(tabID, to: .secondary, before: nil)
        ensureSelectionIntegrity()
    }

    mutating func splitIntoSecondaryPane() {
        beginSplitLayout()
        ensureSelectionIntegrity()
    }

    mutating func mergeIntoPrimaryPane() {
        let secondaryTabs = tabs(in: .secondary).map(\.id)
        for tabID in secondaryTabs {
            moveTab(tabID, to: .primary, before: nil)
        }
        collapseToPrimaryLayout()
        ensureSelectionIntegrity()
    }

    mutating func activatePane(
        _ pane: WorkspacePane
    ) -> AppFeature.WorkspacePaneActivationDisposition {
        focus(on: pane)
        guard let tabID = selectedTabID(for: pane) else { return .none }
        guard isActiveTab(tabID) == false else { return .none }
        return .select(tabID)
    }

    mutating func ensureSelectionIntegrity() {
        if let activeTabID,
           openTabs.contains(where: { $0.id == activeTabID }) == false {
            self.activeTabID = nil
        }
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
