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
            onFailure: @escaping @Sendable (String) -> Action
        ) -> Effect<Action> {
            .run { [paintDocumentClient] send in
                do {
                    let loaded = try paintDocumentClient.loadProject(fileURL)
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

        func restoreAutosaveEffect(item: AutosaveRecoveryItem) -> Effect<Action> {
            loadProjectEffect(
                from: item.autosaveProjectURL.fileURL,
                onSuccess: { .autosaveRecoveryOpened($0, item) },
                onFailure: { .openDocumentFailed($0) }
            )
        }

        func openProjectEffect(
            at url: DocumentProjectPath,
            removeWorkspaceItemAfterLoad: Bool
        ) -> Effect<Action> {
            .run { [paintDocumentClient, workspaceBackingStoreService] send in
                do {
                    let loaded = try paintDocumentClient.loadProject(url.fileURL)
                    if removeWorkspaceItemAfterLoad {
                        try? workspaceBackingStoreService.removeWorkspaceItem(url)
                    }
                    await send(.openDocumentLoaded(loaded, url))
                } catch {
                    await send(.openDocumentFailed(error.localizedDescription))
                }
            }
        }

        func loadTabSelectionEffect(
            tabID: OpenDocumentTab.ID,
            backingStoreURL: URL
        ) -> Effect<Action> {
            loadProjectEffect(
                from: backingStoreURL,
                onSuccess: { .tabSelectionLoaded(tabID, $0) },
                onFailure: { .tabSelectionFailed($0) }
            )
        }
    }

    var workspaceTabCoordinator: WorkspaceTabCoordinator {
        WorkspaceTabCoordinator(
            paintDocumentClient: paintDocumentClient,
            workspaceCatalogService: workspaceCatalogService,
            workspaceBackingStoreService: workspaceBackingStoreService
        )
    }
}
