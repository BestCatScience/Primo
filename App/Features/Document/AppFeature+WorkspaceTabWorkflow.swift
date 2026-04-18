import ComposableArchitecture
import Foundation

extension AppFeature {
    struct WorkspaceProjectLoadOperation: Equatable, Sendable {
        let fileURL: URL
        let prepareDocumentReplacementRequest: WorkspaceDocumentReplacementRequest?
        let removeWorkspaceItemOnSuccess: DocumentProjectPath?
    }

    struct WorkspaceImportedProjectLoadOperation: Equatable, Sendable {
        let sourceURL: URL
        let prepareDocumentReplacementRequest: WorkspaceDocumentReplacementRequest?
    }

    enum WorkspaceProjectLoadRequest: Equatable, Sendable {
        case project(WorkspaceProjectLoadOperation)
        case imported(WorkspaceImportedProjectLoadOperation)
    }

    enum WorkspaceProjectLoadResult: Equatable, Sendable {
        case project(LoadedPaintProject)
        case imported(LoadedPaintProject, String)
    }

    struct WorkspaceProjectLoadFailure: Error, Equatable, Sendable {
        let request: WorkspaceProjectLoadRequest
        let feedback: ApplicationFeedback
        let errorMessage: String?
    }

    struct WorkspaceProjectReplacementPreparationService: Sendable {
        let workspacePersistenceUseCase: WorkspacePersistenceUseCase

        func prepareIfNeeded(
            _ prepareRequest: WorkspaceDocumentReplacementRequest?,
            request: WorkspaceProjectLoadRequest
        ) -> Result<Void, WorkspaceProjectLoadFailure> {
            guard let prepareRequest else {
                return .success(())
            }
            let persistenceRequest = WorkspacePersistenceRequest.prepareDocumentReplacement(
                prepareRequest
            )
            switch workspacePersistenceUseCase.execute(persistenceRequest) {
            case .success:
                return .success(())
            case let .failure(failure):
                return .failure(
                    WorkspaceProjectLoadFailure(
                        request: request,
                        feedback: failure.feedback,
                        errorMessage: nil
                    )
                )
            }
        }
    }

    struct WorkspaceProjectLoadCleanupService: Sendable {
        let workspaceBackingStoreService: WorkspaceBackingStoreService
        let documentImportClient: DocumentImportClient

        func discardWorkspaceItemIfNeeded(
            _ workspaceItem: DocumentProjectPath?
        ) {
            guard let workspaceItem else { return }
            do {
                // Best-effort cleanup of a staged workspace item after a successful load.
                try workspaceBackingStoreService.removeWorkspaceItem(workspaceItem)
            } catch {
            }
        }

        func discardImportedStaging(
            _ stagedProjectURL: DocumentProjectPath
        ) {
            // Best-effort cleanup of a staged imported project after load completes.
            _ = documentImportClient.discardStagedDocument(stagedProjectURL)
        }
    }

    struct WorkspaceProjectLoadUseCase: Sendable {
        let paintDocumentClient: PaintDocumentClient
        let documentImportClient: DocumentImportClient
        let replacementPreparationService: WorkspaceProjectReplacementPreparationService
        let cleanupService: WorkspaceProjectLoadCleanupService

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
            switch replacementPreparationService.prepareIfNeeded(
                operation.prepareDocumentReplacementRequest,
                request: request
            ) {
            case let .failure(failure):
                return .failure(failure)
            case .success:
                break
            }

            do {
                let loaded = try paintDocumentClient.loadProject(operation.fileURL)
                cleanupService.discardWorkspaceItemIfNeeded(
                    operation.removeWorkspaceItemOnSuccess
                )
                return .success(.project(loaded))
            } catch {
                return .failure(
                    WorkspaceProjectLoadFailure(
                        request: request,
                        feedback: .openFailed(AppFeature.optionalErrorMessage(error)),
                        errorMessage: AppFeature.optionalErrorMessage(error)
                    )
                )
            }
        }

        private func loadImportedProject(
            _ operation: WorkspaceImportedProjectLoadOperation,
            request: WorkspaceProjectLoadRequest
        ) -> Result<WorkspaceProjectLoadResult, WorkspaceProjectLoadFailure> {
            switch replacementPreparationService.prepareIfNeeded(
                operation.prepareDocumentReplacementRequest,
                request: request
            ) {
            case let .failure(failure):
                return .failure(failure)
            case .success:
                break
            }

            switch documentImportClient.stageImportedDocument(
                ImportedDocumentStageRequest(sourceURL: operation.sourceURL)
            ) {
            case let .failure(error):
                return .failure(
                    WorkspaceProjectLoadFailure(
                        request: request,
                        feedback: .openFailed(error.errorDescription),
                        errorMessage: error.errorDescription
                    )
                )

            case let .success(staged):
                defer {
                    cleanupService.discardImportedStaging(
                        staged.stagedProjectURL
                    )
                }
                do {
                    let loaded = try paintDocumentClient.loadProject(staged.stagedProjectURL.fileURL)
                    return .success(.imported(loaded, staged.suggestedTitle))
                } catch {
                    return .failure(
                        WorkspaceProjectLoadFailure(
                            request: request,
                            feedback: .openFailed(AppFeature.optionalErrorMessage(error)),
                            errorMessage: AppFeature.optionalErrorMessage(error)
                        )
                    )
                }
            }
        }
    }

    var workspaceProjectReplacementPreparationService: WorkspaceProjectReplacementPreparationService {
        WorkspaceProjectReplacementPreparationService(
            workspacePersistenceUseCase: workspacePersistenceUseCase
        )
    }

    var workspaceProjectLoadCleanupService: WorkspaceProjectLoadCleanupService {
        WorkspaceProjectLoadCleanupService(
            workspaceBackingStoreService: workspaceBackingStoreService,
            documentImportClient: documentImportClient
        )
    }

    var workspaceProjectLoadUseCase: WorkspaceProjectLoadUseCase {
        WorkspaceProjectLoadUseCase(
            paintDocumentClient: paintDocumentClient,
            documentImportClient: documentImportClient,
            replacementPreparationService: workspaceProjectReplacementPreparationService,
            cleanupService: workspaceProjectLoadCleanupService
        )
    }

    func beginWorkspaceProjectLoad(
        state: inout State,
        fileURL: URL,
        persistCurrentTab: Bool = true,
        removeWorkspaceItemOnSuccess: DocumentProjectPath? = nil,
        onSuccess: @escaping @Sendable (LoadedPaintProject) -> Action,
        onFailure: @escaping @Sendable (WorkspaceProjectLoadFailure) -> Action
    ) -> Effect<Action> {
        let prepareRequest: WorkspaceDocumentReplacementRequest?
        if persistCurrentTab && !state.application.showsHome {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                prepareRequest = request
            case let .failure(failure):
                state.application.presentFeedback(failure.feedback)
                return .none
            }
        } else {
            prepareRequest = nil
        }
        state.application.beginHydration()
        let request = WorkspaceProjectLoadRequest.project(
            WorkspaceProjectLoadOperation(
                fileURL: fileURL,
                prepareDocumentReplacementRequest: prepareRequest,
                removeWorkspaceItemOnSuccess: removeWorkspaceItemOnSuccess
            )
        )
        return .run { [workspaceProjectLoadUseCase] send in
            switch workspaceProjectLoadUseCase.execute(request) {
            case let .success(.project(loaded)):
                await send(onSuccess(loaded))
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
        onSuccess: @escaping @Sendable (LoadedPaintProject, String) -> Action,
        onFailure: @escaping @Sendable (WorkspaceProjectLoadFailure) -> Action
    ) -> Effect<Action> {
        let prepareRequest: WorkspaceDocumentReplacementRequest?
        if persistCurrentTab && !state.application.showsHome {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                prepareRequest = request
            case let .failure(failure):
                state.application.presentFeedback(failure.feedback)
                return .none
            }
        } else {
            prepareRequest = nil
        }
        state.application.beginHydration()
        let request = WorkspaceProjectLoadRequest.imported(
            WorkspaceImportedProjectLoadOperation(
                sourceURL: sourceURL,
                prepareDocumentReplacementRequest: prepareRequest
            )
        )
        return .run { [workspaceProjectLoadUseCase] send in
            switch workspaceProjectLoadUseCase.execute(request) {
            case let .success(.imported(loaded, suggestedTitle)):
                await send(onSuccess(loaded, suggestedTitle))
            case .success(.project):
                return
            case let .failure(failure):
                await send(onFailure(failure))
            }
        }
    }
}
