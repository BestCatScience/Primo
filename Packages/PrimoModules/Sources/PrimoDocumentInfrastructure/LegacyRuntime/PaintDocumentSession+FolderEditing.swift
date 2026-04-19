import Foundation
import PrimoDocumentApplication

extension PaintDocumentSession {
    func createFolder(name: String, layerIndex: Int) -> DocumentIndexedMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .structure(.createFolder(name: name, anchorLayerIndex: layerIndex)),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case let .success(.structure(plan)):
            if let event = plan.lifecycleEvent {
                applyLayerLifecycleEvent(event)
            }
            return .success(plan.resultingIndex ?? -1)
        case .success:
            return .failure(.bridgeMutationFailed("createFolder"))
        }
    }

    func deleteFolder(folderID: Int) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .structure(.deleteFolder(folderID: folderID)),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case let .success(.structure(plan)):
            if let event = plan.lifecycleEvent {
                applyLayerLifecycleEvent(event)
            }
            return .success(())
        case .success:
            return .failure(.bridgeMutationFailed("deleteFolder"))
        }
    }

    func setFolderVisibility(folderID: Int, isVisible: Bool) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .attribute(.setFolderVisibility(folderID: folderID, isVisible: isVisible)),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case let .success(.attribute(plan)):
            if let event = plan.lifecycleEvent {
                applyLayerLifecycleEvent(event)
            }
            return .success(())
        case .success:
            return .failure(.bridgeMutationFailed("setFolderVisibility"))
        }
    }

    func setFolderName(folderID: Int, name: String) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .attribute(.setFolderName(folderID: folderID, name: name)),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case .success(.attribute):
            return .success(())
        case .success:
            return .failure(.bridgeMutationFailed("setFolderName"))
        }
    }

    func setFolderExpanded(folderID: Int, isExpanded: Bool) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .attribute(.setFolderExpanded(folderID: folderID, isExpanded: isExpanded)),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case .success(.attribute):
            return .success(())
        case .success:
            return .failure(.bridgeMutationFailed("setFolderExpanded"))
        }
    }

    func assignLayer(index: Int, toFolder folderID: Int) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .structure(.assignLayerToFolder(index: index, folderID: folderID)),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case let .success(.structure(plan)):
            if let event = plan.lifecycleEvent {
                applyLayerLifecycleEvent(event)
            }
            return .success(())
        case .success:
            return .failure(.bridgeMutationFailed("assignLayerToFolder"))
        }
    }
}
