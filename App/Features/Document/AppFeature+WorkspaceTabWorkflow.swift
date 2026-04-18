import ComposableArchitecture
import Foundation

extension AppFeature {
    enum WorkspaceProjectLoadIssue: Error, Equatable, Sendable {
        case workspaceItemRemovalFailed(String?)
        case importedStagingCleanupFailed(String?)

        func message(for language: AppLanguage) -> String {
            switch self {
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
        case project(LoadedPaintProject, [WorkspaceProjectLoadIssue])
        case imported(LoadedPaintProject, String, [WorkspaceProjectLoadIssue])
    }

    struct WorkspaceProjectLoadFailure: Error, Equatable, Sendable {
        let request: WorkspaceProjectLoadRequest
        let feedback: ApplicationFeedback
        let errorMessage: String?
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
                            feedback: .openFailed(AppFeature.optionalErrorMessage(error)),
                            errorMessage: AppFeature.optionalErrorMessage(error)
                        )
                    )
                }
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

    func workspaceProjectLoadWarningMessage(
        _ issues: [WorkspaceProjectLoadIssue],
        language: AppLanguage
    ) -> String? {
        guard !issues.isEmpty else { return nil }
        return issues.map { $0.message(for: language) }.joined(separator: "\n")
    }

    func workspaceProjectLoadEffect(
        request: WorkspaceProjectLoadRequest,
        onSuccess: @escaping @Sendable (WorkspaceProjectLoadResult) -> Action,
        onFailure: @escaping @Sendable (WorkspaceProjectLoadFailure) -> Action
    ) -> Effect<Action> {
        .run { [workspaceProjectLoadUseCase] send in
            switch workspaceProjectLoadUseCase.execute(request) {
            case let .success(result):
                await send(onSuccess(result))
            case let .failure(failure):
                await send(onFailure(failure))
            }
        }
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
        return .run { [workspaceProjectPreparationUseCase, workspaceProjectLoadUseCase] send in
            if let prepareRequest {
                switch workspaceProjectPreparationUseCase.execute(prepareRequest) {
                case .success:
                    break
                case let .failure(failure):
                    await send(
                        onFailure(
                            WorkspaceProjectLoadFailure(
                                request: request,
                                feedback: failure.feedback,
                                errorMessage: nil
                            )
                        )
                    )
                    return
                }
            }

            switch workspaceProjectLoadUseCase.execute(request) {
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
        return .run { [workspaceProjectPreparationUseCase, workspaceProjectLoadUseCase] send in
            if let prepareRequest {
                switch workspaceProjectPreparationUseCase.execute(prepareRequest) {
                case .success:
                    break
                case let .failure(failure):
                    await send(
                        onFailure(
                            WorkspaceProjectLoadFailure(
                                request: request,
                                feedback: failure.feedback,
                                errorMessage: nil
                            )
                        )
                    )
                    return
                }
            }

            switch workspaceProjectLoadUseCase.execute(request) {
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
