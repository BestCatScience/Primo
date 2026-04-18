import ComposableArchitecture
import Foundation

extension AppFeature {
    enum WorkspaceProjectLoadIssue: Error, Equatable, Sendable {
        case workspaceItemRemovalFailed(String?)
        case importedStagingCleanupFailed(String?)
    }

    enum WorkspaceProjectLoadFailureReason: Error, Equatable, Sendable {
        case prepareDocumentReplacementFailed(WorkspacePersistenceFailureReason)
        case openFailed(String?)
        case importFailed(String?)
    }

    struct WorkspaceProjectLoadOperation: Equatable, Sendable {
        let fileURL: URL
        let removeWorkspaceItemOnSuccess: DocumentProjectPath?
    }

    struct WorkspaceImportedProjectLoadOperation: Equatable, Sendable {
        let sourceURL: URL
    }

    enum WorkspaceProjectLoadRequest: Equatable, Sendable {
        case project(WorkspaceProjectLoadOperation)
        case imported(WorkspaceImportedProjectLoadOperation)
    }

    enum WorkspaceProjectLoadResult: Equatable, Sendable {
        case project(LoadedPaintProject, [WorkspaceProjectLoadIssue])
        case imported(LoadedPaintProject, String, [WorkspaceProjectLoadIssue])
    }

    struct WorkspaceProjectLoadFailure: Error, Equatable, Sendable {
        let request: WorkspaceProjectLoadRequest
        let reason: WorkspaceProjectLoadFailureReason
    }

    struct WorkspaceProjectPreparationUseCase: Sendable {
        let workspacePersistenceUseCase: WorkspacePersistenceUseCase

        func execute(
            _ request: WorkspaceDocumentReplacementRequest
        ) -> Result<Void, WorkspacePersistenceFailure> {
            switch workspacePersistenceUseCase.execute(
                .prepareDocumentReplacement(request)
            ) {
            case .success:
                return .success(())
            case let .failure(failure):
                return .failure(failure)
            }
        }
    }

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

    struct WorkspaceProjectLoadUseCase: Sendable {
        let paintDocumentClient: PaintDocumentClient
        let documentImportClient: DocumentImportClient
        let cleanupService: WorkspaceProjectCleanupService

        func execute(
            _ request: WorkspaceProjectLoadRequest
        ) -> Result<WorkspaceProjectLoadResult, WorkspaceProjectLoadFailure> {
            switch request {
            case let .project(operation):
                return loadProject(operation, request: request)
            case let .imported(operation):
                return loadImportedProject(operation, request: request)
            }
        }

        private func loadProject(
            _ operation: WorkspaceProjectLoadOperation,
            request: WorkspaceProjectLoadRequest
        ) -> Result<WorkspaceProjectLoadResult, WorkspaceProjectLoadFailure> {
            do {
                let loaded = try paintDocumentClient.loadProject(operation.fileURL)
                let issues = cleanupService.discardWorkspaceItemIfNeeded(
                    operation.removeWorkspaceItemOnSuccess
                )
                return .success(.project(loaded, issues))
            } catch {
                return .failure(
                    WorkspaceProjectLoadFailure(
                        request: request,
                        reason: .openFailed(AppFeature.optionalErrorMessage(error))
                    )
                )
            }
        }

        private func loadImportedProject(
            _ operation: WorkspaceImportedProjectLoadOperation,
            request: WorkspaceProjectLoadRequest
        ) -> Result<WorkspaceProjectLoadResult, WorkspaceProjectLoadFailure> {
            switch documentImportClient.stageImportedDocument(
                ImportedDocumentStageRequest(sourceURL: operation.sourceURL)
            ) {
            case let .failure(error):
                return .failure(
                    WorkspaceProjectLoadFailure(
                        request: request,
                        reason: .importFailed(error.errorDescription)
                    )
                )

            case let .success(staged):
                do {
                    let loaded = try paintDocumentClient.loadProject(staged.stagedProjectURL.fileURL)
                    let issues = cleanupService.discardImportedStaging(
                        staged.stagedProjectURL
                    )
                    return .success(.imported(loaded, staged.suggestedTitle, issues))
                } catch {
                    _ = cleanupService.discardImportedStaging(
                        staged.stagedProjectURL
                    )
                    return .failure(
                        WorkspaceProjectLoadFailure(
                            request: request,
                            reason: .openFailed(AppFeature.optionalErrorMessage(error))
                        )
                    )
                }
            }
        }
    }

    struct WorkspaceProjectLoadCommand: Equatable, Sendable {
        let loadRequest: WorkspaceProjectLoadRequest
        let prepareDocumentReplacementRequest: WorkspaceDocumentReplacementRequest?
    }

    struct WorkspaceProjectLoadingService: Sendable {
        let preparationUseCase: WorkspaceProjectPreparationUseCase
        let loadUseCase: WorkspaceProjectLoadUseCase

        func execute(
            _ command: WorkspaceProjectLoadCommand
        ) -> Result<WorkspaceProjectLoadResult, WorkspaceProjectLoadFailure> {
            if let prepareRequest = command.prepareDocumentReplacementRequest {
                switch preparationUseCase.execute(prepareRequest) {
                case .success:
                    break
                case let .failure(failure):
                    return .failure(
                        WorkspaceProjectLoadFailure(
                            request: command.loadRequest,
                            reason: .prepareDocumentReplacementFailed(failure.reason)
                        )
                    )
                }
            }
            return loadUseCase.execute(command.loadRequest)
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
