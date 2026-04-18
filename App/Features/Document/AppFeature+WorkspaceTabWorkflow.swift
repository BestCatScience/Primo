import ComposableArchitecture
import Foundation

extension AppFeature {
    struct WorkspaceTabCoordinator {
        let paintDocumentClient: PaintDocumentClient
        let documentImportClient: DocumentImportClient
        let workspaceCatalogService: WorkspaceCatalogService
        let workspaceBackingStoreService: WorkspaceBackingStoreService
        let workspacePersistenceUseCase: WorkspacePersistenceUseCase

        func loadProjectEffect(
            from fileURL: URL,
            prepareDocumentReplacementRequest: WorkspaceDocumentReplacementRequest? = nil,
            onSuccess: @escaping @Sendable (LoadedPaintProject) -> Action,
            onPreparationFailure: @escaping @Sendable (WorkspacePersistenceFailure) -> Action,
            onFailure: @escaping @Sendable (Error) -> Action,
            removeWorkspaceItemOnSuccess: DocumentProjectPath? = nil
        ) -> Effect<Action> {
            .run { [paintDocumentClient, workspaceBackingStoreService, workspacePersistenceUseCase] send in
                if let prepareDocumentReplacementRequest {
                    let persistenceRequest = WorkspacePersistenceRequest.prepareDocumentReplacement(
                        prepareDocumentReplacementRequest
                    )
                    switch workspacePersistenceUseCase.execute(persistenceRequest) {
                    case .success:
                        break
                    case let .failure(failure):
                        await send(onPreparationFailure(failure))
                        return
                    }
                }
                do {
                    let loaded = try paintDocumentClient.loadProject(fileURL)
                    if let workspaceItemToRemove = removeWorkspaceItemOnSuccess {
                        do {
                            try workspaceBackingStoreService.removeWorkspaceItem(workspaceItemToRemove)
                        } catch {
                            // Best-effort cleanup of a staged workspace item after a successful load.
                        }
                    }
                    await send(onSuccess(loaded))
                } catch {
                    await send(onFailure(error))
                }
            }
        }

        func loadImportedProjectEffect(
            from sourceURL: URL,
            prepareDocumentReplacementRequest: WorkspaceDocumentReplacementRequest? = nil,
            onSuccess: @escaping @Sendable (LoadedPaintProject, String) -> Action,
            onPreparationFailure: @escaping @Sendable (WorkspacePersistenceFailure) -> Action,
            onFailure: @escaping @Sendable (Error) -> Action
        ) -> Effect<Action> {
            .run { [documentImportClient, paintDocumentClient, workspacePersistenceUseCase] send in
                if let prepareDocumentReplacementRequest {
                    let persistenceRequest = WorkspacePersistenceRequest.prepareDocumentReplacement(
                        prepareDocumentReplacementRequest
                    )
                    switch workspacePersistenceUseCase.execute(persistenceRequest) {
                    case .success:
                        break
                    case let .failure(failure):
                        await send(onPreparationFailure(failure))
                        return
                    }
                }
                let stagedResult = documentImportClient.stageImportedDocument(
                    ImportedDocumentStageRequest(sourceURL: sourceURL)
                )
                switch stagedResult {
                case let .failure(error):
                    await send(onFailure(error))

                case let .success(staged):
                    do {
                        let loaded = try paintDocumentClient.loadProject(staged.stagedProjectURL.fileURL)
                        _ = documentImportClient.discardStagedDocument(staged.stagedProjectURL)
                        await send(onSuccess(loaded, staged.suggestedTitle))
                    } catch {
                        _ = documentImportClient.discardStagedDocument(staged.stagedProjectURL)
                        await send(onFailure(error))
                    }
                }
            }
        }

        func loadAutosaveRecoveryEffect() -> Effect<Action> {
            .run { [workspaceCatalogService] send in
                do {
                    await send(.autosaveRecoveryLoaded(try workspaceCatalogService.loadAutosaveRecoveryItems()))
                } catch {
                    await send(
                        .autosaveRecoveryLoadFailed(
                            .autosaveRestoreFailed(AppFeature.optionalErrorMessage(error))
                        )
                    )
                }
            }
        }
    }

    var workspaceTabCoordinator: WorkspaceTabCoordinator {
        WorkspaceTabCoordinator(
            paintDocumentClient: paintDocumentClient,
            documentImportClient: documentImportClient,
            workspaceCatalogService: workspaceCatalogService,
            workspaceBackingStoreService: workspaceBackingStoreService,
            workspacePersistenceUseCase: workspacePersistenceUseCase
        )
    }

    func beginWorkspaceProjectLoad(
        state: inout State,
        fileURL: URL,
        persistCurrentTab: Bool = true,
        removeWorkspaceItemOnSuccess: DocumentProjectPath? = nil,
        onSuccess: @escaping @Sendable (LoadedPaintProject) -> Action,
        onPreparationFailure: @escaping @Sendable (WorkspacePersistenceFailure) -> Action,
        onFailure: @escaping @Sendable (Error) -> Action
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
        return workspaceTabCoordinator.loadProjectEffect(
            from: fileURL,
            prepareDocumentReplacementRequest: prepareRequest,
            onSuccess: onSuccess,
            onPreparationFailure: onPreparationFailure,
            onFailure: onFailure,
            removeWorkspaceItemOnSuccess: removeWorkspaceItemOnSuccess
        )
    }

    func beginImportedWorkspaceProjectLoad(
        state: inout State,
        sourceURL: URL,
        persistCurrentTab: Bool = true,
        onSuccess: @escaping @Sendable (LoadedPaintProject, String) -> Action,
        onPreparationFailure: @escaping @Sendable (WorkspacePersistenceFailure) -> Action,
        onFailure: @escaping @Sendable (Error) -> Action
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
        return workspaceTabCoordinator.loadImportedProjectEffect(
            from: sourceURL,
            prepareDocumentReplacementRequest: prepareRequest,
            onSuccess: onSuccess,
            onPreparationFailure: onPreparationFailure,
            onFailure: onFailure
        )
    }
}
