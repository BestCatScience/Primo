import Foundation

extension AppFeature {
    struct AppFeatureWorkspaceStateCoordinator {
        func selectedTabID(for pane: WorkspacePane, in state: AppFeature.State) -> OpenDocumentTab.ID? {
            switch pane {
            case .primary:
                return state.primarySelectedTabID
            case .secondary:
                return state.secondarySelectedTabID
            }
        }

        func setSelectedTabID(
            _ tabID: OpenDocumentTab.ID?,
            for pane: WorkspacePane,
            in state: inout AppFeature.State
        ) {
            switch pane {
            case .primary:
                state.primarySelectedTabID = tabID
            case .secondary:
                state.secondarySelectedTabID = tabID
            }
        }

        func tabs(in pane: WorkspacePane, state: AppFeature.State) -> [OpenDocumentTab] {
            state.openTabs.filter { $0.pane == pane }
        }

        func selectedTab(in pane: WorkspacePane, state: AppFeature.State) -> OpenDocumentTab? {
            guard let tabID = selectedTabID(for: pane, in: state) else { return nil }
            return state.openTabs.first(where: { $0.id == tabID })
        }

        func hasTabs(in pane: WorkspacePane, state: AppFeature.State) -> Bool {
            state.openTabs.contains(where: { $0.pane == pane })
        }

        func tabID(
            forSourceProjectURL sourceProjectURL: DocumentProjectPath,
            in state: AppFeature.State
        ) -> OpenDocumentTab.ID? {
            state.openTabs.first { $0.sourceProjectURL == sourceProjectURL }?.id
        }

        func updateActiveTabMetadata(
            title: String? = nil,
            sourceProjectURL: DocumentProjectPath? = nil,
            previewImageData: Data? = nil,
            in state: inout AppFeature.State
        ) {
            guard let activeTabIndex = state.activeTabIndex else { return }
            if let title {
                state.openTabs[activeTabIndex].title = title
            }
            if let sourceProjectURL {
                state.openTabs[activeTabIndex].sourceProjectURL = sourceProjectURL
            }
            if let previewImageData {
                state.openTabs[activeTabIndex].previewImageData = previewImageData
            }
            state.openTabs[activeTabIndex].canvasSize = state.canvas.canvasSize
        }

        func setActiveTabDirty(_ isDirty: Bool, in state: inout AppFeature.State) {
            guard let activeTabIndex = state.activeTabIndex else { return }
            state.openTabs[activeTabIndex].isDirty = isDirty
        }

        func reorderTabs(
            moving movingID: OpenDocumentTab.ID,
            before targetID: OpenDocumentTab.ID,
            in state: inout AppFeature.State
        ) {
            guard
                let sourceIndex = state.openTabs.firstIndex(where: { $0.id == movingID }),
                let destinationIndex = state.openTabs.firstIndex(where: { $0.id == targetID }),
                sourceIndex != destinationIndex
            else {
                return
            }
            let tab = state.openTabs.remove(at: sourceIndex)
            let adjustedDestination = sourceIndex < destinationIndex ? max(destinationIndex - 1, 0) : destinationIndex
            state.openTabs.insert(tab, at: adjustedDestination)
        }

        func moveTab(
            _ movingID: OpenDocumentTab.ID,
            to pane: WorkspacePane,
            before targetID: OpenDocumentTab.ID?,
            in state: inout AppFeature.State
        ) {
            guard let sourceIndex = state.openTabs.firstIndex(where: { $0.id == movingID }) else { return }
            let sourcePane = state.openTabs[sourceIndex].pane
            var tab = state.openTabs.remove(at: sourceIndex)
            tab.pane = pane

            if let targetID, let destinationIndex = state.openTabs.firstIndex(where: { $0.id == targetID }) {
                state.openTabs.insert(tab, at: destinationIndex)
            } else {
                state.openTabs.append(tab)
            }

            setSelectedTabID(tab.id, for: pane, in: &state)
            if selectedTabID(for: sourcePane, in: state) == movingID {
                setSelectedTabID(tabs(in: sourcePane, state: state).first?.id, for: sourcePane, in: &state)
            }
            if state.activeTabID == movingID {
                state.focusedWorkspacePane = pane
            }
            state.workspaceLayout = hasTabs(in: .secondary, state: state) ? .split : .single
        }

        func ensureWorkspaceSelectionIntegrity(state: inout AppFeature.State) {
            if state.primarySelectedTabID != nil,
               state.openTabs.contains(where: { $0.id == state.primarySelectedTabID && $0.pane == .primary }) == false {
                state.primarySelectedTabID = tabs(in: .primary, state: state).first?.id
            }
            if state.secondarySelectedTabID != nil,
               state.openTabs.contains(where: { $0.id == state.secondarySelectedTabID && $0.pane == .secondary }) == false {
                state.secondarySelectedTabID = tabs(in: .secondary, state: state).first?.id
            }
            if state.primarySelectedTabID == nil {
                state.primarySelectedTabID = tabs(in: .primary, state: state).first?.id
            }
            if !hasTabs(in: .secondary, state: state) {
                state.secondarySelectedTabID = nil
                state.workspaceLayout = .single
                if state.focusedWorkspacePane == .secondary {
                    state.focusedWorkspacePane = .primary
                }
            }
        }
    }
}
