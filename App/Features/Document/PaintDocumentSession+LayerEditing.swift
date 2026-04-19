import CoreGraphics
import Foundation
import PrimoDocumentApplication

extension PaintDocumentSession {
    func canUndo() -> Bool {
        documentGateway.history.canUndo()
    }

    func canRedo() -> Bool {
        documentGateway.history.canRedo()
    }

    func undo() -> DocumentMutationResult {
        guard canUndo() else {
            return .failure(.noUndoState)
        }
        switch documentGateway.history.undoResult() {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            applyDocumentLifecycleMutation(recording: .undo)
            return .success(())
        }
    }

    func redo() -> DocumentMutationResult {
        guard canRedo() else {
            return .failure(.noRedoState)
        }
        switch documentGateway.history.redoResult() {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            applyDocumentLifecycleMutation(recording: .redo)
            return .success(())
        }
    }

    func addLayer(name: String) -> DocumentIndexedMutationResult {
        let useCase = LayerStructureUseCase()
        switch useCase.execute(
            .addLayer(name: name),
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

    func duplicateLayer(index: Int, name: String) -> DocumentIndexedMutationResult {
        let useCase = LayerStructureUseCase()
        switch useCase.execute(
            .duplicateLayer(index: index, name: name),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case let .success(plan):
            if let indexMutation = plan.indexMutation {
                applyLayerIndexMutation(indexMutation)
            }
            if let event = plan.lifecycleEvent {
                applyLayerLifecycleEvent(event)
            }
            return .success(plan.resultingIndex ?? -1)
        }
    }

    func deleteLayer(index: Int) -> DocumentMutationResult {
        let useCase = LayerStructureUseCase()
        switch useCase.execute(
            .deleteLayer(index: index),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case let .success(plan):
            if let indexMutation = plan.indexMutation {
                applyLayerIndexMutation(indexMutation)
            }
            if let event = plan.lifecycleEvent {
                applyLayerLifecycleEvent(event)
            }
            return .success(())
        }
    }

    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentMutationResult {
        let useCase = LayerStructureUseCase()
        switch useCase.execute(
            .moveLayer(index: index, destinationIndex: destinationIndex),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case let .success(plan):
            if let indexMutation = plan.indexMutation {
                applyLayerIndexMutation(indexMutation)
            }
            if let event = plan.lifecycleEvent {
                applyLayerLifecycleEvent(event)
            }
            return .success(())
        }
    }
}
