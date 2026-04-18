import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoWorkspaceDomain

extension AppFeature {
    typealias WorkspaceProjectLoadIssue = PrimoWorkspaceDomain.WorkspaceProjectLoadIssue
    typealias WorkspaceProjectLoadFailureReason = PrimoWorkspaceDomain.WorkspaceProjectLoadFailureReason
    typealias WorkspaceProjectLoadOperation = PrimoWorkspaceDomain.WorkspaceProjectLoadOperation
    typealias WorkspaceImportedProjectLoadOperation = PrimoWorkspaceDomain.WorkspaceImportedProjectLoadOperation
    typealias WorkspaceProjectLoadRequest = PrimoWorkspaceDomain.WorkspaceProjectLoadRequest
    typealias WorkspaceProjectLoadResult = PrimoWorkspaceDomain.WorkspaceProjectLoadResult<LoadedPaintProject>
    typealias WorkspaceProjectLoadFailure = PrimoWorkspaceDomain.WorkspaceProjectLoadFailure
    typealias WorkspaceProjectPreparationUseCase = PrimoWorkspaceDomain.WorkspaceProjectPreparationUseCase
    typealias WorkspaceProjectLoadUseCase = PrimoWorkspaceDomain.WorkspaceProjectLoadUseCase<LoadedPaintProject>
    typealias WorkspaceProjectLoadCommand = PrimoWorkspaceDomain.WorkspaceProjectLoadCommand
    typealias WorkspaceProjectLoadingService = PrimoWorkspaceDomain.WorkspaceProjectLoadingService<LoadedPaintProject>

    struct WorkspaceProjectCleanupService: Sendable {
        let workspaceBackingStoreService: WorkspaceBackingStoreService
        let documentImportClient: DocumentImportClient

        func discardWorkspaceItemIfNeeded(
            _ workspaceItem: DocumentProjectPath?
        ) -> [WorkspaceProjectLoadIssue] {
            guard let workspaceItem else { return [] }
            do {
                try workspaceBackingStoreService.removeWorkspaceItem(workspaceItem)
                return []
            } catch {
                return [
                    .workspaceItemRemovalFailed(
                        AppFeature.optionalErrorMessage(error)
                    )
                ]
            }
        }

        func discardImportedStaging(
            _ stagedProjectURL: DocumentProjectPath
        ) -> [WorkspaceProjectLoadIssue] {
            switch documentImportClient.discardStagedDocument(stagedProjectURL) {
            case .success:
                return []
            case let .failure(failure):
                return [
                    .importedStagingCleanupFailed(
                        failure.errorDescription
                    )
                ]
            }
        }
    }

    var workspaceProjectPreparationUseCase: WorkspaceProjectPreparationUseCase {
        WorkspaceProjectPreparationUseCase(
            workspacePersistenceUseCase: workspacePersistenceUseCase
        )
    }

    var workspaceProjectCleanupService: WorkspaceProjectCleanupService {
        WorkspaceProjectCleanupService(
            workspaceBackingStoreService: workspaceBackingStoreService,
            documentImportClient: documentImportClient
        )
    }

    var workspaceProjectLoadUseCase: WorkspaceProjectLoadUseCase {
        WorkspaceProjectLoadUseCase(
            paintDocumentClient: paintDocumentClient,
            documentImportClient: documentImportClient,
            cleanupService: workspaceProjectCleanupService
        )
    }

    var workspaceProjectLoadingService: WorkspaceProjectLoadingService {
        WorkspaceProjectLoadingService(
            preparationUseCase: workspaceProjectPreparationUseCase,
            loadUseCase: workspaceProjectLoadUseCase
        )
    }

    func beginWorkspaceProjectLoad(
        state: inout State,
        fileURL: URL,
        persistCurrentTab: Bool = true,
        removeWorkspaceItemOnSuccess: DocumentProjectPath? = nil,
        onSuccess: @escaping @Sendable (LoadedPaintProject, [WorkspaceProjectLoadIssue]) -> Action,
        onFailure: @escaping @Sendable (WorkspaceProjectLoadFailure) -> Action
    ) -> Effect<Action> {
        let prepareRequest: WorkspaceDocumentReplacementRequest?
        if persistCurrentTab && !state.application.showsHome {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                prepareRequest = request
            case let .failure(failure):
                state.application.presentBanner(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                )
                return .none
            }
        } else {
            prepareRequest = nil
        }
        state.application.beginHydration()
        let command = WorkspaceProjectLoadCommand(
            loadRequest: .project(
            WorkspaceProjectLoadOperation(
                fileURL: fileURL,
                removeWorkspaceItemOnSuccess: removeWorkspaceItemOnSuccess
            )
            ),
            prepareDocumentReplacementRequest: prepareRequest
        )
        return .run { [workspaceProjectLoadingService] send in
            switch workspaceProjectLoadingService.execute(command) {
            case let .success(.project(loaded, issues)):
                await send(onSuccess(loaded, issues))
            case .success(.imported):
                return
            case let .failure(failure):
                await send(onFailure(failure))
            }
        }
    }

    func beginImportedWorkspaceProjectLoad(
        state: inout State,
        sourceURL: URL,
        persistCurrentTab: Bool = true,
        onSuccess: @escaping @Sendable (LoadedPaintProject, String, [WorkspaceProjectLoadIssue]) -> Action,
        onFailure: @escaping @Sendable (WorkspaceProjectLoadFailure) -> Action
    ) -> Effect<Action> {
        let prepareRequest: WorkspaceDocumentReplacementRequest?
        if persistCurrentTab && !state.application.showsHome {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                prepareRequest = request
            case let .failure(failure):
                state.application.presentBanner(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                )
                return .none
            }
        } else {
            prepareRequest = nil
        }
        state.application.beginHydration()
        let command = WorkspaceProjectLoadCommand(
            loadRequest: .imported(
            WorkspaceImportedProjectLoadOperation(
                sourceURL: sourceURL
            )
            ),
            prepareDocumentReplacementRequest: prepareRequest
        )
        return .run { [workspaceProjectLoadingService] send in
            switch workspaceProjectLoadingService.execute(command) {
            case let .success(.imported(loaded, suggestedTitle, issues)):
                await send(onSuccess(loaded, suggestedTitle, issues))
            case .success(.project):
                return
            case let .failure(failure):
                await send(onFailure(failure))
            }
        }
    }
}

extension PrimoWorkspaceDomain.WorkspaceProjectLoadUseCase where LoadedProject == LoadedPaintProject {
    init(
        paintDocumentClient: PaintDocumentClient,
        documentImportClient: DocumentImportClient,
        cleanupService: AppFeature.WorkspaceProjectCleanupService
    ) {
        self.init(
            projectLoader: ProjectLoadingGateway<LoadedPaintProject>(
                loadProject: { url in
                    try paintDocumentClient.loadProject(url)
                }
            ),
            documentImport: DocumentImportGateway(
                stageImportedDocument: { request in
                    documentImportClient.stageImportedDocument(
                        ImportedDocumentStageRequest(sourceURL: request.sourceURL)
                    )
                },
                discardStagedDocument: { stagedProjectURL in
                    documentImportClient.discardStagedDocument(stagedProjectURL)
                }
            ),
            cleanupService: PrimoWorkspaceDomain.WorkspaceProjectCleanupService(
                workspaceBackingStore: WorkspaceBackingStoreGateway(
                    saveProject: { fileURL, paperStyle in
                        try cleanupService.workspaceBackingStoreService.saveProject(at: fileURL, paperStyle: paperStyle)
                    },
                    persistProjectSnapshot: { sourceURL, preferredDestinationURL in
                        try cleanupService.workspaceBackingStoreService.persistProjectSnapshot(
                            sourceURL,
                            preferredDestinationURL: preferredDestinationURL
                        )
                    },
                    createTabBackingStoreURL: { tabID in
                        try cleanupService.workspaceBackingStoreService.createTabBackingStoreURL(tabID)
                    },
                    persistAutosaveSnapshot: { backingStoreURL, tab in
                        try cleanupService.workspaceBackingStoreService.persistAutosaveSnapshot(backingStoreURL, tab)
                    },
                    discardAutosaveSnapshot: { tab in
                        try cleanupService.workspaceBackingStoreService.discardAutosaveSnapshot(tab)
                    },
                    persistSaveHistorySnapshot: { backingStoreURL, tab, trigger in
                        try cleanupService.workspaceBackingStoreService.persistSaveHistorySnapshot(
                            backingStoreURL,
                            tab,
                            trigger
                        )
                    },
                    removeWorkspaceItem: { url in
                        try cleanupService.workspaceBackingStoreService.removeWorkspaceItem(url)
                    }
                ),
                documentImport: DocumentImportGateway(
                    stageImportedDocument: { request in
                        documentImportClient.stageImportedDocument(
                            ImportedDocumentStageRequest(sourceURL: request.sourceURL)
                        )
                    },
                    discardStagedDocument: { stagedProjectURL in
                        documentImportClient.discardStagedDocument(stagedProjectURL)
                    }
                )
            )
        )
    }
}
