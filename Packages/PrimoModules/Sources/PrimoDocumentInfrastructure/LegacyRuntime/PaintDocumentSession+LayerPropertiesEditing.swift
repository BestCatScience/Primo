import CoreGraphics
import Foundation
import PrimoDocumentApplication

extension PaintDocumentSession {
    func setActiveLayer(index: Int) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .attribute(.setActiveLayer(index: index)),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case .success(.attribute):
            return .success(())
        case .success:
            return .failure(.bridgeMutationFailed("setActiveLayer"))
        }
    }

    func setLayerName(index: Int, name: String) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .attribute(.setLayerName(index: index, name: name)),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case .success(.attribute):
            return .success(())
        case .success:
            return .failure(.bridgeMutationFailed("setLayerName"))
        }
    }

    func setLayerVisibility(index: Int, isVisible: Bool) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .attribute(.setLayerVisibility(index: index, isVisible: isVisible)),
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
            return .failure(.bridgeMutationFailed("setLayerVisibility"))
        }
    }

    func setLayerLocked(index: Int, isLocked: Bool) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .attribute(.setLayerLocked(index: index, isLocked: isLocked)),
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
            return .failure(.bridgeMutationFailed("setLayerLocked"))
        }
    }

    func setLayerAlphaLocked(index: Int, isAlphaLocked: Bool) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .attribute(.setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked)),
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
            return .failure(.bridgeMutationFailed("setLayerAlphaLocked"))
        }
    }

    func setLayerClipped(index: Int, isClipped: Bool) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .attribute(.setLayerClipped(index: index, isClipped: isClipped)),
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
            return .failure(.bridgeMutationFailed("setLayerClipped"))
        }
    }

    func revealLayerForEditing(index: Int) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .attribute(.revealLayerForEditing(index: index)),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case .success(.attribute):
            return .success(())
        case .success:
            return .failure(.bridgeMutationFailed("revealLayerForEditing"))
        }
    }

    func setLayerOpacity(index: Int, opacity: Double) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .attribute(.setLayerOpacity(index: index, opacity: opacity)),
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
            return .failure(.bridgeMutationFailed("setLayerOpacity"))
        }
    }

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) -> DocumentMutationResult {
        let useCase = DocumentEditorUseCase()
        switch useCase.execute(
            .attribute(.setLayerBlendMode(index: index, blendMode: blendMode)),
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
            return .failure(.bridgeMutationFailed("setLayerBlendMode"))
        }
    }
}
