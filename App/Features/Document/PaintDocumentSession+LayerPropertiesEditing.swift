import CoreGraphics
import Foundation
import PrimoDocumentApplication

extension PaintDocumentSession {
    func setActiveLayer(index: Int) -> DocumentMutationResult {
        let useCase = LayerAttributeUseCase()
        switch useCase.execute(
            .setActiveLayer(index: index),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case .success:
            return .success(())
        }
    }

    func setLayerName(index: Int, name: String) -> DocumentMutationResult {
        let useCase = LayerAttributeUseCase()
        switch useCase.execute(
            .setLayerName(index: index, name: name),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case .success:
            return .success(())
        }
    }

    func setLayerVisibility(index: Int, isVisible: Bool) -> DocumentMutationResult {
        let useCase = LayerAttributeUseCase()
        switch useCase.execute(
            .setLayerVisibility(index: index, isVisible: isVisible),
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

    func setLayerLocked(index: Int, isLocked: Bool) -> DocumentMutationResult {
        let useCase = LayerAttributeUseCase()
        switch useCase.execute(
            .setLayerLocked(index: index, isLocked: isLocked),
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

    func setLayerAlphaLocked(index: Int, isAlphaLocked: Bool) -> DocumentMutationResult {
        let useCase = LayerAttributeUseCase()
        switch useCase.execute(
            .setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked),
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

    func setLayerClipped(index: Int, isClipped: Bool) -> DocumentMutationResult {
        let useCase = LayerAttributeUseCase()
        switch useCase.execute(
            .setLayerClipped(index: index, isClipped: isClipped),
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

    func revealLayerForEditing(index: Int) -> DocumentMutationResult {
        let useCase = LayerAttributeUseCase()
        switch useCase.execute(
            .revealLayerForEditing(index: index),
            in: documentLayerMutationContext,
            gateway: documentGateway.layers
        ) {
        case let .failure(failure):
            return .failure(mutationFailure(for: failure))
        case .success:
            return .success(())
        }
    }

    func setLayerOpacity(index: Int, opacity: Double) -> DocumentMutationResult {
        let useCase = LayerAttributeUseCase()
        switch useCase.execute(
            .setLayerOpacity(index: index, opacity: opacity),
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

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) -> DocumentMutationResult {
        let useCase = LayerAttributeUseCase()
        switch useCase.execute(
            .setLayerBlendMode(index: index, blendMode: blendMode),
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
