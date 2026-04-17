import ComposableArchitecture
import Foundation

extension AppFeature {
    struct WorkspaceTabCoordinator {
        let paintDocumentClient: PaintDocumentClient
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
                        try? workspaceBackingStoreService.removeWorkspaceItem(workspaceItemToRemove)
                    }
                    await send(onSuccess(loaded))
                } catch {
                    await send(onFailure(error))
                }
            }
        }

        func loadAutosaveRecoveryEffect() -> Effect<Action> {
            .run { [workspaceCatalogService] send in
                let items = (try? workspaceCatalogService.loadAutosaveRecoveryItems()) ?? []
                await send(.autosaveRecoveryLoaded(items))
            }
        }
    }

    var workspaceTabCoordinator: WorkspaceTabCoordinator {
        WorkspaceTabCoordinator(
            paintDocumentClient: paintDocumentClient,
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
}
