import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication
import PrimoWorkspaceDomain

extension WorkspaceFeature {
    var workspaceApplicationServices: WorkspaceApplicationServices {
        WorkspaceApplicationServices(
            documentPersistenceGateway: documentPersistenceGateway,
            documentWorkspaceClient: documentWorkspaceClient,
            uuidClient: uuidClient
        )
    }

    var workspacePersistenceUseCase: WorkspacePersistenceUseCase {
        workspaceApplicationServices.persistenceUseCase
    }

    var workspaceCatalogUseCase: WorkspaceCatalogUseCase {
        workspaceApplicationServices.catalogUseCase
    }

    var documentImportGateway: DocumentImportGateway {
        DocumentImportGateway(
            stageImportedDocument: { request in
                documentImportClient.stageImportedDocument(
                    ImportedDocumentStageRequest(sourceURL: request.sourceURL)
                )
            },
            discardStagedDocument: { stagedProjectURL in
                documentImportClient.discardStagedDocument(stagedProjectURL)
            }
        )
    }

    var workspaceProjectLoaderGateway: ProjectLoadingGateway<LoadedPaintProject> {
        ProjectLoadingGateway(
            loadProject: { url in
                try documentPersistenceGateway.loadProject(url)
            }
        )
    }

    var workspaceProjectLoadingService: WorkspaceProjectLoadingService {
        workspaceApplicationServices.projectLoadingService(
            projectLoader: workspaceProjectLoaderGateway,
            documentImport: documentImportGateway
        )
    }

    func handleWorkspacePersistenceRequested(
        request: WorkspacePersistenceRequest
    ) -> Effect<Action> {
        .run { [workspacePersistenceUseCase] send in
            switch workspacePersistenceUseCase.execute(request) {
            case let .success(result):
                await send(.persistenceSucceeded(result))
            case let .failure(failure):
                await send(.persistenceFailed(failure))
            }
        }
    }

    func handleWorkspaceCatalogRequested(
        request: WorkspaceCatalogRequest
    ) -> Effect<Action> {
        .run { [workspaceCatalogUseCase] send in
            switch workspaceCatalogUseCase.execute(request) {
            case let .success(result):
                await send(.catalogSucceeded(result))
            case let .failure(failure):
                await send(.catalogFailed(failure))
            }
        }
    }

    func handleSaveHistoryEntriesRequested(state: inout State) -> Effect<Action> {
        guard let activeTab = state.activeTab else { return .none }
        return .send(
            .catalogRequested(
                .loadSaveHistoryEntries(
                    WorkspaceSaveHistoryLoadRequest(activeTab: activeTab)
                )
            )
        )
    }

    func handleTabProjectLoadRequested(
        state: inout State,
        tabID: OpenDocumentTab.ID,
        replacementRequest: WorkspaceDocumentReplacementRequest?
    ) -> Effect<Action> {
        guard let targetTab = state.tab(withID: tabID) else { return .none }
        let showingHomeOnFailure = state.activeTab == nil ? true : nil
        let command = WorkspaceProjectLoadCommand(
            loadRequest: .project(
                WorkspaceProjectLoadOperation(
                    fileURL: targetTab.backingStoreURL.fileURL,
                    removeWorkspaceItemOnSuccess: nil
                )
            ),
            prepareDocumentReplacementRequest: replacementRequest
        )
        return runProjectLoad(
            command,
            onSuccess: { loaded, _ in .tabSelectionLoaded(tabID, loaded) },
            onFailure: { failure in
                .delegate(
                    .workspaceProjectLoadFailedFeedback(
                        WorkspaceFeedbackMapper().feedback(for: failure, context: .openDocument),
                        showingHome: showingHomeOnFailure
                    )
                )
            }
        )
    }

    func handleProjectLoadRequested(
        url: DocumentProjectPath,
        removesStagedWorkspaceItem: Bool,
        replacementRequest: WorkspaceDocumentReplacementRequest?
    ) -> Effect<Action> {
        let command = WorkspaceProjectLoadCommand(
            loadRequest: .project(
                WorkspaceProjectLoadOperation(
                    fileURL: url.fileURL,
                    removeWorkspaceItemOnSuccess: removesStagedWorkspaceItem ? url : nil
                )
            ),
            prepareDocumentReplacementRequest: replacementRequest
        )
        return runProjectLoad(
            command,
            onSuccess: { loaded, issues in .openDocumentLoaded(loaded, url, issues) },
            onFailure: { failure in
                .delegate(
                    .workspaceProjectLoadFailedFeedback(
                        WorkspaceFeedbackMapper().feedback(for: failure, context: .openDocument),
                        showingHome: nil
                    )
                )
            }
        )
    }

    func handleAutosaveRecoveryProjectLoadRequested(
        item: AutosaveRecoveryItem,
        replacementRequest: WorkspaceDocumentReplacementRequest?
    ) -> Effect<Action> {
        let command = WorkspaceProjectLoadCommand(
            loadRequest: .project(
                WorkspaceProjectLoadOperation(
                    fileURL: item.autosaveProjectURL.fileURL,
                    removeWorkspaceItemOnSuccess: nil
                )
            ),
            prepareDocumentReplacementRequest: replacementRequest
        )
        return runProjectLoad(
            command,
            onSuccess: { loaded, issues in .autosaveRecoveryOpened(loaded, item, issues) },
            onFailure: { failure in
                .delegate(
                    .workspaceProjectLoadFailedFeedback(
                        WorkspaceFeedbackMapper().feedback(for: failure, context: .autosaveRestore),
                        showingHome: nil
                    )
                )
            }
        )
    }

    func handleImportedProjectLoadRequested(
        sourceURL: URL,
        replacementRequest: WorkspaceDocumentReplacementRequest?
    ) -> Effect<Action> {
        let command = WorkspaceProjectLoadCommand(
            loadRequest: .imported(
                WorkspaceImportedProjectLoadOperation(sourceURL: sourceURL)
            ),
            prepareDocumentReplacementRequest: replacementRequest
        )
        return .run { [workspaceProjectLoadingService] send in
            switch workspaceProjectLoadingService.execute(command) {
            case let .success(.imported(loaded, suggestedTitle, issues)):
                await send(.openImportedDocumentLoaded(loaded, suggestedTitle, issues))
            case .success(.project):
                return
            case let .failure(failure):
                await send(
                    .delegate(
                        .workspaceProjectLoadFailedFeedback(
                            WorkspaceFeedbackMapper().feedback(for: failure, context: .importDocument),
                            showingHome: nil
                        )
                    )
                )
            }
        }
        .cancellable(id: ApplicationFeature.CancelID.workspaceProjectLoad, cancelInFlight: true)
    }

    func runProjectLoad(
        _ command: WorkspaceProjectLoadCommand,
        onSuccess: @escaping @Sendable (LoadedPaintProject, [WorkspaceProjectLoadIssue]) -> Action,
        onFailure: @escaping @Sendable (WorkspaceProjectLoadFailure) -> Action
    ) -> Effect<Action> {
        .run { [workspaceProjectLoadingService] send in
            switch workspaceProjectLoadingService.execute(command) {
            case let .success(.project(loaded, issues)):
                await send(onSuccess(loaded, issues))
            case .success(.imported):
                return
            case let .failure(failure):
                await send(onFailure(failure))
            }
        }
        .cancellable(id: ApplicationFeature.CancelID.workspaceProjectLoad, cancelInFlight: true)
    }

    func handleWorkspaceCatalogSucceeded(
        state: inout State,
        result: WorkspaceCatalogResult
    ) -> Effect<Action> {
        switch result {
        case let .savedProjectsLoaded(projects):
            return .send(.delegate(.homeProjectsLoaded(projects)))

        case let .autosaveRecoveryItemsLoaded(items):
            return .send(.delegate(.autosaveRecoveryLoaded(items)))

        case let .saveHistoryEntriesLoaded(entries):
            return .send(.delegate(.saveHistoryLoaded(entries)))

        case let .savedProjectMoved(moveResult):
            if let openTabID = moveResult.openTabID {
                state.updateTab(id: openTabID, sourceProjectURL: moveResult.destinationURL)
            }
            return .send(.delegate(.requestHomeProjectsLoad))

        case let .autosaveEntryDiscarded(autosaveID):
            return .send(.delegate(.autosaveRecoveryDiscarded(autosaveID)))
        }
    }

    func handleWorkspaceCatalogFailed(
        failure: WorkspaceCatalogFailure
    ) -> Effect<Action> {
        let feedback = WorkspaceFeedbackMapper().feedback(for: failure)
        switch failure.request {
        case .loadSavedProjects:
            return .merge(
                .send(.delegate(.homeProjectsLoaded([]))),
                .send(.delegate(.presentFeedback(feedback)))
            )
        case .loadAutosaveRecoveryItems:
            return .send(.delegate(.autosaveRecoveryLoadFailed(feedback)))
        case .loadSaveHistoryEntries:
            return .send(.delegate(.saveHistoryLoadFailed(feedback)))
        case .moveSavedProject, .discardAutosaveEntry:
            return .send(.delegate(.presentFeedback(feedback)))
        }
    }

    func requestCloseOperation(
        state: inout State,
        operation: PendingCloseOperation
    ) -> Effect<Action> {
        let tabIDs: [OpenDocumentTab.ID] = {
            switch operation {
            case let .tab(tabID):
                return [tabID]
            case let .closeOtherTabs(tabID):
                return state.tabIDs(excluding: tabID)
            case let .closeTabsToRight(tabID):
                return state.tabIDsToRight(of: tabID)
            }
        }()

        let dirtyTabs = state.dirtyTabs(withIDs: tabIDs)
        guard !dirtyTabs.isEmpty else {
            return performCloseOperation(operation)
        }

        state.presentCloseConfirmation(operation: operation, dirtyTabs: dirtyTabs)
        return .none
    }

    func performCloseOperation(_ operation: PendingCloseOperation) -> Effect<Action> {
        switch operation {
        case let .tab(tabID):
            return .send(.tabClosed(tabID))
        case let .closeOtherTabs(tabID):
            return .send(.closeOtherTabs(tabID))
        case let .closeTabsToRight(tabID):
            return .send(.closeTabsToRight(tabID))
        }
    }

    func effect(
        for closureDisposition: WorkspaceFeature.WorkspaceTabClosureDisposition
    ) -> Effect<Action> {
        switch closureDisposition {
        case .none:
            return .none
        case .showHome:
            return .send(.delegate(.showHome))
        case let .select(tabID):
            return .send(.tabSelected(tabID))
        }
    }

    func handlePendingCloseDiscardConfirmed(state: inout State) -> Effect<Action> {
        guard let confirmation = state.consumeCloseConfirmation() else { return .none }
        return performCloseOperation(confirmation.operation)
    }

    func handlePendingCloseCancelled(state: inout State) {
        state.clearCloseConfirmation()
    }

    func handleTabClosed(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        guard let closure = state.closeTab(id: tabID) else { return .none }
        return .merge(
            effect(for: closure.disposition),
            .send(.persistenceRequested(discardArtifactsRequest(for: closure.removedTabs)))
        )
    }

    func handleCloseOtherTabs(
        state: inout State,
        retaining tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        let closure = state.closeOtherTabs(retaining: tabID)
        return .merge(
            effect(for: closure.disposition),
            .send(.persistenceRequested(discardArtifactsRequest(for: closure.removedTabs)))
        )
    }

    func handleCloseTabsToRight(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        let closure = state.closeTabsToRight(of: tabID)
        return .merge(
            effect(for: closure.disposition),
            .send(.persistenceRequested(discardArtifactsRequest(for: closure.removedTabs)))
        )
    }

    func handleMoveTabToSecondaryPane(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) {
        state.stageTabInSecondaryPane(tabID)
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
        state.splitIntoSecondaryPane()
    }

    func handleMergeWorkspacePanes(state: inout State) {
        state.mergeIntoPrimaryPane()
    }

    func handleWorkspacePaneActivated(
        state: inout State,
        pane: WorkspacePane
    ) -> Effect<Action> {
        switch state.activatePane(pane) {
        case .none:
            return .none
        case let .select(tabID):
            return .send(.tabSelected(tabID))
        }
    }

    func handleSavedProjectMove(
        state: inout State,
        url: DocumentProjectPath,
        relativeFolderPath: RelativeProjectFolderPath?
    ) -> Effect<Action> {
        .send(
            .catalogRequested(
                .moveSavedProject(
                    WorkspaceSavedProjectMoveRequest(
                        sourceURL: url,
                        relativeFolderPath: relativeFolderPath,
                        openTabID: state.tabID(forSourceProjectURL: url)
                    )
                )
            )
        )
    }

    func discardArtifactsRequest(
        for tabs: [OpenDocumentTab]
    ) -> WorkspacePersistenceRequest {
        workspaceApplicationWorkflowService.discardArtifactsRequest(for: tabs)
    }
}

extension WorkspaceFeature {
    func requestDocumentSnapshot(
        state: inout State,
        operation: PendingDocumentSnapshotOperation
    ) -> Effect<Action> {
        state.pendingDocumentSnapshotOperation = operation
        return .send(.delegate(.requestDocumentSnapshot))
    }

    func applySnapshotToActiveTab(
        _ snapshot: DocumentFeature.WorkspaceDocumentSnapshot,
        state: inout State
    ) -> OpenDocumentTab? {
        state.updateActiveTabMetadata(
            previewSurface: snapshot.previewSurface,
            canvasSize: snapshot.canvasSize
        )
        return state.activeTab
    }

    func documentReplacementRequest(
        state: inout State,
        snapshot: DocumentFeature.WorkspaceDocumentSnapshot
    ) -> Result<WorkspaceDocumentReplacementRequest, WorkspacePersistenceFailure> {
        _ = applySnapshotToActiveTab(snapshot, state: &state)
        return workspaceApplicationWorkflowService.documentReplacementRequest(
            context: WorkspaceDocumentContext(
                activeTab: state.activeTab,
                paperStyle: snapshot.paperStyle
            )
        )
    }

    func dirtyPresentationRequest(
        state: inout State,
        snapshot: DocumentFeature.WorkspaceDocumentSnapshot
    ) -> WorkspacePersistenceRequest? {
        _ = applySnapshotToActiveTab(snapshot, state: &state)
        return workspaceApplicationWorkflowService.dirtyPresentationRequest(
            context: WorkspaceDocumentContext(
                activeTab: state.activeTab,
                paperStyle: snapshot.paperStyle
            )
        )
    }

    func saveActiveDocumentRequest(
        state: inout State,
        snapshot: DocumentFeature.WorkspaceDocumentSnapshot,
        preferredDestinationURL: DocumentProjectPath?,
        trigger: SaveHistoryTrigger,
        purpose: WorkspaceDocumentSavePurpose
    ) -> Result<WorkspacePersistenceRequest, WorkspacePersistenceFailure> {
        _ = applySnapshotToActiveTab(snapshot, state: &state)
        return workspaceApplicationWorkflowService.saveActiveDocumentRequest(
            context: WorkspaceDocumentContext(
                activeTab: state.activeTab,
                paperStyle: snapshot.paperStyle
            ),
            preferredDestinationURL: preferredDestinationURL,
            trigger: trigger,
            purpose: purpose
        )
    }

    func duplicateActiveCanvasRequest(
        state: inout State,
        snapshot: DocumentFeature.WorkspaceDocumentSnapshot,
        destination: WorkspaceCanvasDuplicateDestination
    ) -> Result<WorkspacePersistenceRequest, WorkspacePersistenceFailure> {
        guard let activeTab = applySnapshotToActiveTab(snapshot, state: &state) else {
            return .failure(WorkspacePersistenceFailure(reason: .activeTabUnavailable))
        }
        let pane: WorkspacePane
        switch destination {
        case .currentPane:
            pane = activeTab.pane
        case .rightPane:
            pane = .secondary
            state.workspaceLayout = .splitRight
        case .belowPane:
            pane = .secondary
            state.workspaceLayout = .splitBelow
        }
        let title = state.duplicateTitle(for: activeTab.title)
        return .success(
            .duplicateActiveCanvas(
                WorkspaceActiveCanvasDuplicateRequest(
                    activeTab: activeTab,
                    title: title,
                    pane: pane,
                    paperStyle: snapshot.paperStyle
                )
            )
        )
    }

    func closeTabsPersistenceRequest(
        operation: PendingCloseOperation,
        tabIDs: [OpenDocumentTab.ID],
        snapshot: DocumentFeature.WorkspaceDocumentSnapshot,
        state: inout State
    ) -> Result<WorkspacePersistenceRequest, WorkspacePersistenceFailure> {
        var tabs = tabIDs.compactMap { state.tab(withID: $0) }
        let activeTabContext: WorkspaceDocumentContext?
        if let activeTabID = state.activeTabID, tabIDs.contains(activeTabID) {
            switch documentReplacementRequest(state: &state, snapshot: snapshot) {
            case let .success(request):
                activeTabContext = WorkspaceDocumentContext(
                    activeTab: request.activeTab,
                    paperStyle: request.paperStyle
                )
                if let index = tabs.firstIndex(where: { $0.id == request.activeTab.id }) {
                    tabs[index] = request.activeTab
                }
            case let .failure(failure):
                return .failure(failure)
            }
        } else {
            activeTabContext = nil
        }
        return workspaceApplicationWorkflowService.closeTabsPersistenceRequest(
            operation: operation,
            tabs: tabs,
            activeTabContext: activeTabContext
        )
    }

    func replacementRequestIfNeeded(
        state: inout State,
        snapshot: DocumentFeature.WorkspaceDocumentSnapshot
    ) -> Result<WorkspaceDocumentReplacementRequest?, WorkspacePersistenceFailure> {
        guard state.activeTab != nil else { return .success(nil) }
        return documentReplacementRequest(state: &state, snapshot: snapshot).map(Optional.some)
    }

    func handleLifecycleAutosaveRequested(state: inout State) -> Effect<Action> {
        guard state.activeTab?.isDirty == true else { return .none }
        return requestDocumentSnapshot(state: &state, operation: .lifecycleAutosave)
    }

    func handleHomeReturnRequested(state: inout State) -> Effect<Action> {
        guard state.activeTab != nil else {
            return .merge(
                .send(.delegate(.showHome)),
                .send(.delegate(.requestHomeProjectsLoad))
            )
        }
        return requestDocumentSnapshot(state: &state, operation: .homeReturnSave)
    }

    func handlePendingCloseSaveConfirmed(state: inout State) -> Effect<Action> {
        guard let confirmation = state.consumeCloseConfirmation() else { return .none }
        return requestDocumentSnapshot(
            state: &state,
            operation: .closeTabsSave(confirmation.operation, confirmation.tabIDs)
        )
    }

    func handleSaveActiveDocumentRequested(
        state: inout State,
        preferredDestinationURL: DocumentProjectPath?
    ) -> Effect<Action> {
        requestDocumentSnapshot(
            state: &state,
            operation: .saveActiveDocument(preferredDestinationURL)
        )
    }

    func handleOpenImportedDocumentRequest(
        state: inout State,
        sourceURL: URL
    ) -> Effect<Action> {
        guard state.activeTab != nil else {
            return .send(.importedProjectLoadRequested(sourceURL, replacementRequest: nil))
        }
        return requestDocumentSnapshot(state: &state, operation: .openImportedDocument(sourceURL))
    }

    func handleOpenDocumentSelection(
        state: inout State,
        url: DocumentProjectPath,
        removesStagedWorkspaceItem: Bool
    ) -> Effect<Action> {
        if let existingTabID = state.tabID(forSourceProjectURL: url) {
            return .merge(
                .send(.delegate(.workspaceProjectLoadCompleted(nil))),
                .send(.tabSelected(existingTabID))
            )
        }
        guard state.activeTab != nil else {
            return .send(
                .projectLoadRequested(
                    url,
                    removesStagedWorkspaceItem: removesStagedWorkspaceItem,
                    replacementRequest: nil
                )
            )
        }
        return requestDocumentSnapshot(
            state: &state,
            operation: .openDocument(url, removesStagedWorkspaceItem: removesStagedWorkspaceItem)
        )
    }

    func handleAutosaveRecoveryRestoreRequest(
        state: inout State,
        item: AutosaveRecoveryItem
    ) -> Effect<Action> {
        guard state.activeTab != nil else {
            return .send(.autosaveRecoveryProjectLoadRequested(item, replacementRequest: nil))
        }
        return requestDocumentSnapshot(state: &state, operation: .autosaveRecoveryRestore(item))
    }

    func handleSaveHistoryProjectLoadRequested(
        state: inout State,
        projectURL: DocumentProjectPath,
        openInNewTab: Bool,
        replacementRequest: WorkspaceDocumentReplacementRequest?
    ) -> Effect<Action> {
        if let replacementRequest {
            return loadSaveHistoryProject(
                projectURL: projectURL,
                openInNewTab: openInNewTab,
                replacementRequest: replacementRequest
            )
        }
        guard state.activeTab != nil else {
            return loadSaveHistoryProject(
                projectURL: projectURL,
                openInNewTab: openInNewTab,
                replacementRequest: nil
            )
        }
        return requestDocumentSnapshot(
            state: &state,
            operation: .saveHistoryRestore(projectURL, openInNewTab: openInNewTab)
        )
    }

    func loadSaveHistoryProject(
        projectURL: DocumentProjectPath,
        openInNewTab: Bool,
        replacementRequest: WorkspaceDocumentReplacementRequest?
    ) -> Effect<Action> {
        let command = WorkspaceProjectLoadCommand(
            loadRequest: .project(
                WorkspaceProjectLoadOperation(
                    fileURL: projectURL.fileURL,
                    removeWorkspaceItemOnSuccess: nil
                )
            ),
            prepareDocumentReplacementRequest: replacementRequest
        )
        return runProjectLoad(
            command,
            onSuccess: { loaded, issues in
                .delegate(.saveHistoryProjectOpened(loaded, projectURL, openInNewTab, issues))
            },
            onFailure: { failure in
                .delegate(
                    .saveHistoryRestoreFailedFeedback(
                        WorkspaceFeedbackMapper().feedback(for: failure, context: .saveHistoryRestore)
                    )
                )
            }
        )
    }

    func handleDocumentSnapshotPrepared(
        state: inout State,
        snapshot: DocumentFeature.WorkspaceDocumentSnapshot
    ) -> Effect<Action> {
        guard let operation = state.pendingDocumentSnapshotOperation else { return .none }
        state.pendingDocumentSnapshotOperation = nil
        switch operation {
        case .lifecycleAutosave:
            guard let request = dirtyPresentationRequest(state: &state, snapshot: snapshot) else { return .none }
            return .send(.persistenceRequested(request))

        case .homeReturnSave:
            switch saveActiveDocumentRequest(
                state: &state,
                snapshot: snapshot,
                preferredDestinationURL: state.activeTab?.sourceProjectURL,
                trigger: .autoSave,
                purpose: .homeReturn
            ) {
            case let .success(request):
                return .send(.persistenceRequested(request))
            case let .failure(failure):
                return .send(.delegate(.presentFeedback(WorkspaceFeedbackMapper().feedback(for: failure))))
            }

        case let .closeTabsSave(operation, tabIDs):
            switch closeTabsPersistenceRequest(
                operation: operation,
                tabIDs: tabIDs,
                snapshot: snapshot,
                state: &state
            ) {
            case let .success(request):
                return .send(.persistenceRequested(request))
            case let .failure(failure):
                return .send(.delegate(.presentFeedback(WorkspaceFeedbackMapper().feedback(for: failure))))
            }

        case let .saveActiveDocument(preferredDestinationURL):
            switch saveActiveDocumentRequest(
                state: &state,
                snapshot: snapshot,
                preferredDestinationURL: preferredDestinationURL,
                trigger: .manualSave,
                purpose: .saveDocument
            ) {
            case let .success(request):
                return .send(.persistenceRequested(request))
            case let .failure(failure):
                return .send(.delegate(.presentFeedback(WorkspaceFeedbackMapper().feedback(for: failure))))
            }

        case let .openImportedDocument(sourceURL):
            switch replacementRequestIfNeeded(state: &state, snapshot: snapshot) {
            case let .success(request):
                return .send(.importedProjectLoadRequested(sourceURL, replacementRequest: request))
            case let .failure(failure):
                return .send(.delegate(.presentFeedback(WorkspaceFeedbackMapper().feedback(for: failure))))
            }

        case let .openDocument(url, removesStagedWorkspaceItem):
            switch replacementRequestIfNeeded(state: &state, snapshot: snapshot) {
            case let .success(request):
                return .send(
                    .projectLoadRequested(
                        url,
                        removesStagedWorkspaceItem: removesStagedWorkspaceItem,
                        replacementRequest: request
                    )
                )
            case let .failure(failure):
                return .send(.delegate(.presentFeedback(WorkspaceFeedbackMapper().feedback(for: failure))))
            }

        case let .tabSelection(tabID):
            switch replacementRequestIfNeeded(state: &state, snapshot: snapshot) {
            case let .success(request):
                return .send(.tabProjectLoadRequested(tabID, request))
            case let .failure(failure):
                return .send(.delegate(.presentFeedback(WorkspaceFeedbackMapper().feedback(for: failure))))
            }

        case let .saveHistoryRestore(projectURL, openInNewTab):
            switch replacementRequestIfNeeded(state: &state, snapshot: snapshot) {
            case let .success(request):
                return loadSaveHistoryProject(
                    projectURL: projectURL,
                    openInNewTab: openInNewTab,
                    replacementRequest: request
                )
            case let .failure(failure):
                return .send(.delegate(.saveHistoryRestoreFailedFeedback(WorkspaceFeedbackMapper().feedback(for: failure))))
            }

        case let .autosaveRecoveryRestore(item):
            switch replacementRequestIfNeeded(state: &state, snapshot: snapshot) {
            case let .success(request):
                return .send(.autosaveRecoveryProjectLoadRequested(item, replacementRequest: request))
            case let .failure(failure):
                return .send(.delegate(.workspaceProjectLoadFailedFeedback(WorkspaceFeedbackMapper().feedback(for: failure), showingHome: nil)))
            }

        case let .freshDocument(request):
            switch replacementRequestIfNeeded(state: &state, snapshot: snapshot) {
            case .success:
                return beginFreshDocumentTabReservation(state: &state, request: request)
            case let .failure(failure):
                return .send(.delegate(.presentFeedback(WorkspaceFeedbackMapper().feedback(for: failure))))
            }

        case let .duplicateActiveCanvas(destination):
            switch duplicateActiveCanvasRequest(state: &state, snapshot: snapshot, destination: destination) {
            case let .success(request):
                return .send(.persistenceRequested(request))
            case let .failure(failure):
                return .send(.delegate(.presentFeedback(WorkspaceFeedbackMapper().feedback(for: failure))))
            }
        }
    }

    func handleTabSelection(
        state: inout State,
        tabID: OpenDocumentTab.ID
    ) -> Effect<Action> {
        guard state.tab(withID: tabID) != nil else { return .none }
        if state.isActiveTab(tabID) {
            return .send(.delegate(.workspaceProjectLoadCompleted(nil)))
        }
        guard state.activeTab != nil else {
            return .merge(
                .send(.delegate(.workspaceProjectLoadCompleted(nil))),
                .send(.tabProjectLoadRequested(tabID, nil))
            )
        }
        return requestDocumentSnapshot(state: &state, operation: .tabSelection(tabID))
    }

    func handleDuplicateActiveCanvasRequested(
        state: inout State,
        destination: WorkspaceCanvasDuplicateDestination
    ) -> Effect<Action> {
        guard state.activeTab != nil else { return .none }
        return requestDocumentSnapshot(state: &state, operation: .duplicateActiveCanvas(destination))
    }

    func handleTabSelectionLoaded(
        state: inout State,
        tabID: OpenDocumentTab.ID,
        loaded: LoadedPaintProject
    ) -> Effect<Action> {
        guard let tab = state.tab(withID: tabID) else { return .none }
        return applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .selectedTab(tabID: tabID, pane: tab.pane),
                successEffects: .init(
                    completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                )
            ),
            presentation: LoadedWorkspacePresentation(
                completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
            ),
            state: &state
        )
    }

    func beginFreshDocumentTabReservation(
        state: inout State,
        request: FreshDocumentRequest
    ) -> Effect<Action> {
        state.pendingWorkspaceTabReservation = .freshDocument(
            PendingFreshDocumentMutation(
                contract: request.contract,
                operation: {
                    switch request.operation {
                    case let .newCanvas(dimensions):
                        return .newCanvas(dimensions)
                    case let .importedCanvas(plan):
                        return .importedCanvas(plan)
                    }
                }()
            )
        )
        return .send(
            .persistenceRequested(
                .reserveNewTabBackingStore(
                    WorkspaceTabReservationRequest(
                        title: request.contract.tabTitle,
                        sourceProjectURL: nil,
                        pane: state.focusedWorkspacePane
                    )
                )
            )
        )
    }

    func handleFreshDocumentRequested(
        state: inout State,
        contract: DocumentFeature.FreshDocumentReplacementContract,
        operation: DocumentFeature.FreshDocumentMutationOperation
    ) -> Effect<Action> {
        let request = FreshDocumentRequest(contract: contract, operation: operation)
        guard state.activeTab != nil else {
            return beginFreshDocumentTabReservation(state: &state, request: request)
        }
        return requestDocumentSnapshot(state: &state, operation: .freshDocument(request))
    }

    func handleFreshDocumentMutationSucceeded(
        state: inout State,
        preparedTab: PreparedWorkspaceTab,
        contract: DocumentFeature.FreshDocumentReplacementContract,
        snapshot: DocumentFeature.WorkspaceDocumentSnapshot
    ) -> Effect<Action> {
        let tab = OpenDocumentTab(
            id: preparedTab.id,
            title: preparedTab.title,
            backingStoreURL: preparedTab.backingStoreURL,
            sourceProjectURL: preparedTab.sourceProjectURL,
            canvasSize: snapshot.canvasSize,
            isDirty: false,
            pane: preparedTab.pane,
            previewSurface: snapshot.previewSurface,
            previewImageData: nil
        )
        state.appendTab(tab)
        state.activateTab(preparedTab.id, pane: preparedTab.pane)
        var effects: [Effect<Action>] = [
            .send(.delegate(.workspaceProjectLoadCompleted(nil)))
        ]
        if let feedback = contract.successFeedback {
            effects.append(.send(.delegate(.presentFeedback(feedback))))
        }
        return .merge(effects)
    }

    func applyLoadedWorkspaceProject(
        _ loaded: LoadedPaintProject,
        using plan: LoadedWorkspaceProjectPlan,
        presentation: LoadedWorkspacePresentation = LoadedWorkspacePresentation(),
        state: inout State
    ) -> Effect<Action> {
        switch plan.destination {
        case let .newTab(title, sourceProjectURL):
            state.pendingWorkspaceTabReservation = .loadedProject(
                PendingLoadedWorkspaceProject(
                    loaded: loaded,
                    plan: plan,
                    presentation: presentation
                )
            )
            return .send(
                .persistenceRequested(
                    .reserveNewTabBackingStore(
                        WorkspaceTabReservationRequest(
                            title: title,
                            sourceProjectURL: sourceProjectURL,
                            pane: state.focusedWorkspacePane
                        )
                    )
                )
            )

        case .selectedTab, .activeTab:
            return requestLoadedProjectApplication(
                loaded,
                using: plan,
                presentation: presentation,
                preparedTab: nil,
                state: &state
            )
        }
    }

    func requestLoadedProjectApplication(
        _ loaded: LoadedPaintProject,
        using plan: LoadedWorkspaceProjectPlan,
        presentation: LoadedWorkspacePresentation,
        preparedTab: PreparedWorkspaceTab?,
        state: inout State
    ) -> Effect<Action> {
        state.pendingLoadedWorkspaceApplication = PendingLoadedWorkspaceApplication(
            loaded: loaded,
            plan: plan,
            presentation: presentation,
            preparedTab: preparedTab
        )
        return .send(.delegate(.applyLoadedProject(loaded)))
    }

    func handleLoadedProjectApplied(state: inout State) -> Effect<Action> {
        guard let pending = state.pendingLoadedWorkspaceApplication else { return .none }
        state.pendingLoadedWorkspaceApplication = nil
        let loaded = pending.loaded
        let plan = pending.plan
        _ = pending.presentation

        switch plan.destination {
        case let .selectedTab(tabID, pane):
            state.activateTab(tabID, pane: pane)

        case .newTab:
            guard let preparedTab = pending.preparedTab else {
                return .send(.delegate(.workspaceProjectLoadFailedFeedback(.couldNotCreateTab, showingHome: nil)))
            }
            let tab = OpenDocumentTab(
                id: preparedTab.id,
                title: preparedTab.title,
                backingStoreURL: preparedTab.backingStoreURL,
                sourceProjectURL: preparedTab.sourceProjectURL,
                canvasSize: loaded.presentation.canvasSize,
                isDirty: false,
                pane: preparedTab.pane,
                previewSurface: nil,
                previewImageData: nil
            )
            state.appendTab(tab)
            state.activateTab(preparedTab.id, pane: preparedTab.pane)

        case let .activeTab(title, sourceProjectURL):
            state.updateActiveTabMetadata(
                title: title,
                sourceProjectURL: sourceProjectURL,
                canvasSize: loaded.presentation.canvasSize
            )
        }

        switch loadedWorkspaceFollowUpRequest(plan: plan, state: &state) {
        case let .failure(failure):
            return .send(.delegate(.workspaceProjectLoadFailedFeedback(WorkspaceFeedbackMapper().feedback(for: failure), showingHome: nil)))
        case let .success(.some(request)):
            return .merge(
                applyLoadedWorkspaceSuccessEffects(plan.successEffects, state: &state),
                .send(.persistenceRequested(request)),
                .send(.delegate(.workspaceProjectLoadCompleted(nil)))
            )
        case .success(.none):
            return .merge(
                applyLoadedWorkspaceSuccessEffects(plan.successEffects, state: &state),
                .send(.delegate(.workspaceProjectLoadCompleted(nil)))
            )
        }
    }

    func loadedWorkspaceFollowUpRequest(
        plan: LoadedWorkspaceProjectPlan,
        state: inout State
    ) -> Result<WorkspacePersistenceRequest?, WorkspacePersistenceFailure> {
        let requiresBackingStorePersistence: Bool
        switch plan.destination {
        case .newTab:
            requiresBackingStorePersistence = true
        case .selectedTab, .activeTab:
            requiresBackingStorePersistence = false
        }
        switch workspaceApplicationWorkflowService.loadedWorkspaceFollowUp(
            plan: plan,
            context: WorkspaceDocumentContext(activeTab: state.activeTab, paperStyle: .default),
            requiresBackingStorePersistence: requiresBackingStorePersistence
        ) {
        case let .success(outcome):
            if outcome.marksActiveTabDirty {
                state.setActiveTabDirty(true)
            }
            return .success(outcome.followUpRequest)
        case let .failure(failure):
            return .failure(failure)
        }
    }

    func applyLoadedWorkspaceSuccessEffects(
        _ successEffects: LoadedWorkspaceProjectPlan.SuccessEffects,
        state: inout State
    ) -> Effect<Action> {
        var effects: [Effect<Action>] = []
        switch successEffects.recoveryResolution {
        case .none:
            break
        case let .removeItem(id):
            effects.append(.send(.delegate(.autosaveRecoveryDiscarded(id))))
        case let .completeRestore(id):
            effects.append(.send(.delegate(.autosaveRecoveryRestoreCompleted(id))))
        case .dismiss:
            effects.append(.send(.delegate(.autosaveRecoveryDismissed)))
        }

        switch successEffects.saveHistoryResolution {
        case .none:
            break
        case .completeRestore:
            effects.append(.send(.delegate(.saveHistoryRestoreCompleted)))
        }
        return .merge(effects)
    }

    func handleOpenImportedDocumentLoaded(
        state: inout State,
        loaded: LoadedPaintProject,
        suggestedTitle: String,
        issues: [WorkspaceProjectLoadIssue]
    ) -> Effect<Action> {
        let trimmedTitle = suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? "Imported Document" : trimmedTitle
        return applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .newTab(title: resolvedTitle, sourceProjectURL: nil),
                successEffects: .init(
                    completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                )
            ),
            presentation: LoadedWorkspacePresentation(
                issues: issues,
                completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
            ),
            state: &state
        )
    }

    func handleOpenDocumentLoaded(
        state: inout State,
        loaded: LoadedPaintProject,
        sourceURL: DocumentProjectPath,
        issues: [WorkspaceProjectLoadIssue]
    ) -> Effect<Action> {
        if let existingTabID = state.tabID(forSourceProjectURL: sourceURL) {
            return .merge(
                .send(.delegate(.workspaceProjectLoadCompleted(nil))),
                .send(.tabSelected(existingTabID))
            )
        }
        return applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .newTab(title: sourceURL.displayName, sourceProjectURL: sourceURL),
                successEffects: .init(
                    completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                )
            ),
            presentation: LoadedWorkspacePresentation(
                issues: issues,
                completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
            ),
            state: &state
        )
    }

    func handleAutosaveRecoveryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        item: AutosaveRecoveryItem,
        issues: [WorkspaceProjectLoadIssue]
    ) -> Effect<Action> {
        applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .newTab(title: item.title, sourceProjectURL: item.sourceProjectURL),
                followUp: .init(
                    marksTabDirty: true,
                    persistsToBackingStore: true,
                    persistsAutosave: true
                ),
                successEffects: .init(
                    discardedAutosaveEntryID: item.id,
                    recoveryResolution: .completeRestore(item.id),
                    completion: .restoredAutosave
                )
            ),
            presentation: LoadedWorkspacePresentation(
                issues: issues,
                completion: .restoredAutosave
            ),
            state: &state
        )
    }

    func handleSaveHistoryOpened(
        state: inout State,
        loaded: LoadedPaintProject,
        projectURL: DocumentProjectPath,
        openInNewTab: Bool,
        issues: [WorkspaceProjectLoadIssue]
    ) -> Effect<Action> {
        let restoredTitle = projectURL.displayName
        let destination: LoadedWorkspaceProjectPlan.Destination = {
            if openInNewTab || state.activeTab == nil {
                return .newTab(title: "\(restoredTitle) Snapshot", sourceProjectURL: nil)
            }
            return .activeTab(
                title: state.activeTab?.title ?? restoredTitle,
                sourceProjectURL: state.activeTab?.sourceProjectURL
            )
        }()
        return applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: destination,
                followUp: .init(
                    marksTabDirty: true,
                    persistsToBackingStore: true,
                    persistsAutosave: true
                ),
                successEffects: .init(
                    saveHistoryResolution: .completeRestore,
                    completion: .restoredSaveHistory
                )
            ),
            presentation: LoadedWorkspacePresentation(
                issues: issues,
                completion: .restoredSaveHistory
            ),
            state: &state
        )
    }

    func handleWorkspacePersistenceSucceeded(
        state: inout State,
        result: WorkspacePersistenceResult
    ) -> Effect<Action> {
        switch result {
        case .dirtyPresentationPersisted:
            return .none
        case let .activeDocumentSaved(saved):
            state.updateTab(
                id: saved.activeTabID,
                title: saved.savedURL.displayName,
                sourceProjectURL: saved.savedURL,
                previewSurface: saved.previewSurface,
                previewImageData: saved.previewImageData,
                canvasSize: saved.canvasSize,
                isDirty: false
            )
            switch saved.purpose {
            case .saveDocument:
                return .merge(
                    .send(.delegate(.presentFeedback(.savedDocument(saved.savedURL.fileURL.lastPathComponent)))),
                    .send(.delegate(.requestHomeProjectsLoad))
                )
            case .homeReturn:
                return .merge(
                    .send(.delegate(.presentFeedback(.savedDocument(saved.savedURL.fileURL.lastPathComponent)))),
                    .send(.delegate(.showHome)),
                    .send(.delegate(.requestHomeProjectsLoad))
                )
            }
        case let .activeCanvasDuplicated(duplicate):
            let preparedTab = duplicate.preparedTab
            let tab = OpenDocumentTab(
                id: preparedTab.id,
                title: preparedTab.title,
                backingStoreURL: preparedTab.backingStoreURL,
                sourceProjectURL: preparedTab.sourceProjectURL,
                canvasSize: duplicate.canvasSize,
                isDirty: false,
                pane: preparedTab.pane,
                previewSurface: duplicate.previewSurface,
                previewImageData: duplicate.previewImageData
            )
            state.appendTab(tab)
            if preparedTab.pane == .secondary, state.workspaceLayout == .single {
                state.workspaceLayout = .splitRight
            }
            state.activateTab(preparedTab.id, pane: preparedTab.pane)
            return .send(.delegate(.workspaceProjectLoadCompleted(nil)))
        case .documentReplacementPrepared:
            return .none
        case let .newTabBackingStoreReserved(preparedTab):
            guard let pendingReservation = state.pendingWorkspaceTabReservation else { return .none }
            state.pendingWorkspaceTabReservation = nil
            switch pendingReservation {
            case let .loadedProject(pending):
                return requestLoadedProjectApplication(
                    pending.loaded,
                    using: pending.plan,
                    presentation: pending.presentation,
                    preparedTab: preparedTab,
                    state: &state
                )
            case let .freshDocument(pending):
                let operation: DocumentFeature.FreshDocumentMutationOperation
                switch pending.operation {
                case let .newCanvas(dimensions):
                    operation = .newCanvas(dimensions)
                case let .importedCanvas(plan):
                    operation = .importedCanvas(plan)
                }
                return .send(
                    .delegate(
                        .requestFreshDocumentMutation(
                            DocumentFeature.FreshDocumentMutationRequest(
                                contract: pending.contract,
                                operation: operation,
                                preparedTab: preparedTab
                            )
                        )
                    )
                )
            }
        case let .loadedWorkspaceFollowUpApplied(followUp):
            return .merge(
                applyLoadedWorkspaceSuccessEffects(followUp.successEffects, state: &state),
                .send(.delegate(.workspaceProjectLoadCompleted(nil)))
            )
        case let .tabsSavedForClose(closeResult):
            return performCloseOperation(closeResult.operation)
        case .autosaveArtifactsDiscarded:
            return .none
        }
    }

    func handleWorkspacePersistenceFailed(
        state: inout State,
        failure: WorkspacePersistenceFailure
    ) -> Effect<Action> {
        if case .some(.reserveNewTabBackingStore) = failure.request {
            state.pendingWorkspaceTabReservation = nil
        }
        return .send(.delegate(.presentFeedback(WorkspaceFeedbackMapper().feedback(for: failure))))
    }
}

extension WorkspaceFeature {
    struct WorkspaceFeedbackMapper: Sendable {
        func feedback(for failure: WorkspacePersistenceFailure) -> ApplicationFeedback {
            switch failure.reason {
            case let .saveFailed(message):
                return .saveFailed(message)
            case .couldNotCreateTab:
                return .couldNotCreateTab
            case .activeTabUnavailable:
                return .saveFailed(nil)
            }
        }

        func feedback(
            for failure: WorkspaceCatalogFailure
        ) -> ApplicationFeedback {
            switch failure.reason {
            case let .loadSavedProjectsFailed(message):
                return .openFailed(message)
            case let .loadAutosaveRecoveryItemsFailed(message):
                return .autosaveRestoreFailed(message)
            case let .loadSaveHistoryEntriesFailed(message):
                return .saveHistoryRestoreFailed(message)
            case let .moveSavedProjectFailed(message):
                return .moveFailed(message)
            case let .discardAutosaveEntryFailed(message):
                return .autosaveRestoreFailed(message)
            }
        }

        func feedback(
            for failure: WorkspaceProjectLoadFailure,
            context: WorkspaceLoadFailureContext = .openDocument
        ) -> ApplicationFeedback {
            switch failure.reason {
            case let .prepareDocumentReplacementFailed(reason):
                return feedback(
                    for: WorkspacePersistenceFailure(
                        request: nil,
                        reason: reason
                    )
                )
            case let .openFailed(message):
                switch context {
                case .openDocument, .importDocument:
                    return .openFailed(message)
                case .autosaveRestore:
                    return .autosaveRestoreFailed(message)
                case .saveHistoryRestore:
                    return .saveHistoryRestoreFailed(message)
                }
            case let .importFailed(message):
                switch context {
                case .openDocument, .importDocument:
                    return .openFailed(message)
                case .autosaveRestore:
                    return .autosaveRestoreFailed(message)
                case .saveHistoryRestore:
                    return .saveHistoryRestoreFailed(message)
                }
            }
        }

        func bannerMessage(
            for issues: [WorkspacePersistenceIssue],
            language: AppLanguage
        ) -> String? {
            guard !issues.isEmpty else { return nil }
            return issues.map { message(for: $0, language: language) }.joined(separator: "\n")
        }

        func bannerMessage(
            for issues: [WorkspaceProjectLoadIssue],
            language: AppLanguage
        ) -> String? {
            guard !issues.isEmpty else { return nil }
            return issues.map { message(for: $0, language: language) }.joined(separator: "\n")
        }

        func loadedWorkspaceCompletionMessage(
            presentation: LoadedWorkspacePresentation,
            language: AppLanguage
        ) -> String? {
            if let issueBanner = bannerMessage(for: presentation.issues, language: language) {
                return issueBanner
            }
            return completionMessage(for: presentation.completion, language: language)
        }

        func loadedWorkspaceCompletionMessage(
            completion: LoadedWorkspaceProjectPlan.Completion,
            persistenceIssues: [WorkspacePersistenceIssue],
            language: AppLanguage
        ) -> String? {
            if let issueBanner = bannerMessage(for: persistenceIssues, language: language) {
                return issueBanner
            }
            return completionMessage(for: completion, language: language)
        }

        func message(
            for feedback: ApplicationFeedback?,
            language: AppLanguage
        ) -> String? {
            feedback?.message(for: language)
        }

        private func completionMessage(
            for completion: LoadedWorkspaceProjectPlan.Completion,
            language: AppLanguage
        ) -> String? {
            switch completion {
            case .none:
                return nil
            case let .openedDocument(layerCount):
                return ApplicationFeedback.openedDocument(layerCount).message(for: language)
            case .restoredSaveHistory:
                return ApplicationFeedback.restoredSaveHistory.message(for: language)
            case .restoredAutosave:
                return ApplicationFeedback.restoredAutosave.message(for: language)
            }
        }

        private func message(
            for issue: WorkspacePersistenceIssue,
            language: AppLanguage
        ) -> String {
            switch issue {
            case let .autosaveCleanupFailed(message):
                return (message?.isEmpty == false)
                    ? message!
                    : (language == .japanese
                        ? "保存後の自動保存クリーンアップに失敗しました"
                        : "Autosave cleanup failed after saving")
            case let .saveHistoryPersistFailed(message):
                return (message?.isEmpty == false)
                    ? message!
                    : (language == .japanese
                        ? "保存履歴の記録に失敗しました"
                        : "Saving to history failed")
            case let .workspaceItemRemovalFailed(message):
                return (message?.isEmpty == false)
                    ? message!
                    : (language == .japanese
                        ? "一時ワークスペース項目の削除に失敗しました"
                        : "Temporary workspace cleanup failed")
            case let .autosaveEntryDiscardFailed(message):
                return (message?.isEmpty == false)
                    ? message!
                    : (language == .japanese
                        ? "自動保存エントリの破棄に失敗しました"
                        : "Autosave entry cleanup failed")
            }
        }

        private func message(
            for issue: WorkspaceProjectLoadIssue,
            language: AppLanguage
        ) -> String {
            switch issue {
            case let .workspaceItemRemovalFailed(message):
                return (message?.isEmpty == false)
                    ? message!
                    : (language == .japanese
                        ? "読み込み後の一時ワークスペース項目の削除に失敗しました"
                        : "Temporary workspace cleanup failed after loading")
            case let .importedStagingCleanupFailed(message):
                return (message?.isEmpty == false)
                    ? message!
                    : (language == .japanese
                        ? "読み込み後の一時インポートデータの削除に失敗しました"
                        : "Imported staging cleanup failed after loading")
            }
        }
    }

    enum WorkspaceLoadFailureContext: Sendable {
        case openDocument
        case importDocument
        case autosaveRestore
        case saveHistoryRestore
    }
}
