import ComposableArchitecture
import Foundation

extension AppFeature {
    struct WorkspaceTabCoordinator {
        let paintDocumentClient: PaintDocumentClient
        let workspaceStorageService: WorkspaceStorageService

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
            .run { [workspaceStorageService] send in
                let items = (try? workspaceStorageService.loadAutosaveRecoveryItems()) ?? []
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
            .concatenate(
                loadProjectEffect(
                    from: url.fileURL,
                    onSuccess: { .openDocumentLoaded($0, url) },
                    onFailure: { .openDocumentFailed($0) }
                ),
                .run { [workspaceStorageService] _ in
                    guard removeWorkspaceItemAfterLoad else { return }
                    try? workspaceStorageService.removeWorkspaceItem(url)
                }
            )
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
            workspaceStorageService: workspaceStorageService
        )
    }
}
