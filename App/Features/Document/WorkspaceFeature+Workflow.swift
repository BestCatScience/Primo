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

    func handleSaveHistoryProjectLoadRequested(
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
