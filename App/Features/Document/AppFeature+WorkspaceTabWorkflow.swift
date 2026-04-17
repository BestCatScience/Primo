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
            onFailure: @escaping @Sendable (String) -> Action,
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
                    await send(onFailure(error.localizedDescription))
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
        dismissesRecovery: Bool = false,
        removeWorkspaceItemOnSuccess: DocumentProjectPath? = nil,
        onSuccess: @escaping @Sendable (LoadedPaintProject) -> Action,
        onFailure: @escaping @Sendable (String) -> Action
    ) -> Effect<Action> {
        if persistCurrentTab, !state.application.showsHome {
            _ = persistActiveTabToBackingStore(state: &state)
        }
        if dismissesRecovery {
            state.recovery.dismiss()
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
