import ComposableArchitecture
import Foundation

extension AppFeature {
    struct WorkspaceTabCoordinator {
        let paintDocumentClient: PaintDocumentClient
        let documentWorkspaceClient: DocumentWorkspaceClient

        func loadAutosaveRecoveryEffect() -> Effect<Action> {
            .run { [documentWorkspaceClient] send in
                let items = (try? documentWorkspaceClient.loadAutosaveRecoveryItems()) ?? []
                await send(.autosaveRecoveryLoaded(items))
            }
        }

        func restoreAutosaveEffect(item: AutosaveRecoveryItem) -> Effect<Action> {
            .run { [paintDocumentClient] send in
                do {
                    let loaded = try paintDocumentClient.loadProject(item.autosaveProjectURL.fileURL)
                    await send(.autosaveRecoveryOpened(loaded, item))
                } catch {
                    await send(.openDocumentFailed(error.localizedDescription))
                }
            }
        }

        func openProjectEffect(
            at url: DocumentProjectPath,
            removeWorkspaceItemAfterLoad: Bool
        ) -> Effect<Action> {
            .run { [paintDocumentClient, documentWorkspaceClient] send in
                do {
                    let loaded = try paintDocumentClient.loadProject(url.fileURL)
                    await send(.openDocumentLoaded(loaded, url))
                } catch {
                    await send(.openDocumentFailed(error.localizedDescription))
                }
                guard removeWorkspaceItemAfterLoad else { return }
                try? documentWorkspaceClient.removeWorkspaceItem(url)
            }
        }
    }

    var workspaceTabCoordinator: WorkspaceTabCoordinator {
        WorkspaceTabCoordinator(
            paintDocumentClient: paintDocumentClient,
            documentWorkspaceClient: documentWorkspaceClient
        )
    }
}
