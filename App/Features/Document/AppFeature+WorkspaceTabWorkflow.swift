import ComposableArchitecture
import Foundation

extension AppFeature {
    struct WorkspaceTabCoordinator {
        let paintDocumentClient: PaintDocumentClient
        let documentImportClient: DocumentImportClient
        let workspaceCatalogService: WorkspaceCatalogService
        let workspaceBackingStoreService: WorkspaceBackingStoreService

        func loadProjectEffect(
            from fileURL: URL,
            onSuccess: @escaping @Sendable (LoadedPaintProject) -> Action,
            onFailure: @escaping @Sendable (Error) -> Action,
            removeWorkspaceItemOnSuccess: DocumentProjectPath? = nil
        ) -> Effect<Action> {
            .run { [paintDocumentClient, workspaceBackingStoreService] send in
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
            onSuccess: @escaping @Sendable (LoadedPaintProject, String) -> Action,
            onFailure: @escaping @Sendable (Error) -> Action
        ) -> Effect<Action> {
            .run { [documentImportClient, paintDocumentClient] send in
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
                let items: [AutosaveRecoveryItem]
                do {
                    items = try workspaceCatalogService.loadAutosaveRecoveryItems()
                } catch {
                    items = []
                }
                await send(.autosaveRecoveryLoaded(items))
            }
        }
    }

    var workspaceTabCoordinator: WorkspaceTabCoordinator {
        WorkspaceTabCoordinator(
            paintDocumentClient: paintDocumentClient,
            documentImportClient: documentImportClient,
            workspaceCatalogService: workspaceCatalogService,
            workspaceBackingStoreService: workspaceBackingStoreService
        )
    }

    func beginWorkspaceProjectLoad(
        state: inout State,
        fileURL: URL,
        persistCurrentTab: Bool = true,
        removeWorkspaceItemOnSuccess: DocumentProjectPath? = nil,
        onSuccess: @escaping @Sendable (LoadedPaintProject) -> Action,
        onFailure: @escaping @Sendable (Error) -> Action
    ) -> Effect<Action> {
        if persistCurrentTab {
            switch prepareForDocumentReplacement(state: &state) {
            case .success:
                break
            case let .failure(failure):
                state.application.presentFeedback(failure.feedback)
                return .none
            }
        }
        state.application.beginHydration()
        return workspaceTabCoordinator.loadProjectEffect(
            from: fileURL,
            onSuccess: onSuccess,
            onFailure: onFailure,
            removeWorkspaceItemOnSuccess: removeWorkspaceItemOnSuccess
        )
    }

    func beginImportedWorkspaceProjectLoad(
        state: inout State,
        sourceURL: URL,
        persistCurrentTab: Bool = true,
        onSuccess: @escaping @Sendable (LoadedPaintProject, String) -> Action,
        onFailure: @escaping @Sendable (Error) -> Action
    ) -> Effect<Action> {
        if persistCurrentTab {
            switch prepareForDocumentReplacement(state: &state) {
            case .success:
                break
            case let .failure(failure):
                state.application.presentFeedback(failure.feedback)
                return .none
            }
        }
        state.application.beginHydration()
        return workspaceTabCoordinator.loadImportedProjectEffect(
            from: sourceURL,
            onSuccess: onSuccess,
            onFailure: onFailure
        )
    }
}
