import Foundation
import PrimoDocumentApplication

extension PaintDocumentSession {
    func createFolder(name: String, layerIndex: Int) -> DocumentIndexedMutationResult {
        let useCase = LayerStructureUseCase()
        switch useCase.execute(
            .createFolder(name: name, anchorLayerIndex: layerIndex),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case let .success(plan):
            if let event = plan.lifecycleEvent {
                applyLayerLifecycleEvent(event)
            }
            return .success(plan.resultingIndex ?? -1)
        }
    }

    func deleteFolder(folderID: Int) -> DocumentMutationResult {
        let useCase = LayerStructureUseCase()
        switch useCase.execute(
            .deleteFolder(folderID: folderID),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case let .success(plan):
            if let event = plan.lifecycleEvent {
                applyLayerLifecycleEvent(event)
            }
            return .success(())
        }
    }

    func setFolderVisibility(folderID: Int, isVisible: Bool) -> DocumentMutationResult {
        let useCase = LayerAttributeUseCase()
        switch useCase.execute(
            .setFolderVisibility(folderID: folderID, isVisible: isVisible),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case let .success(plan):
            if let event = plan.lifecycleEvent {
                applyLayerLifecycleEvent(event)
            }
            return .success(())
        }
    }

    func setFolderName(folderID: Int, name: String) -> DocumentMutationResult {
        let useCase = LayerAttributeUseCase()
        switch useCase.execute(
            .setFolderName(folderID: folderID, name: name),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case .success:
            return .success(())
        }
    }

    func setFolderExpanded(folderID: Int, isExpanded: Bool) -> DocumentMutationResult {
        let useCase = LayerAttributeUseCase()
        switch useCase.execute(
            .setFolderExpanded(folderID: folderID, isExpanded: isExpanded),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case .success:
            return .success(())
        }
    }

    func assignLayer(index: Int, toFolder folderID: Int) -> DocumentMutationResult {
        let useCase = LayerStructureUseCase()
        switch useCase.execute(
            .assignLayerToFolder(index: index, folderID: folderID),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case let .success(plan):
            if let event = plan.lifecycleEvent {
                applyLayerLifecycleEvent(event)
            }
            return .success(())
        }
    }
}
