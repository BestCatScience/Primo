import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func setActiveLayer(index: Int) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        documentGateway.layers.setActiveLayerIndex(index)
        return .success(())
    }

    func setLayerName(index: Int, name: String) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        documentGateway.layers.setLayerName(name, index: index)
        return .success(())
    }

    func setLayerVisibility(index: Int, isVisible: Bool) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        documentGateway.layers.setLayerVisible(isVisible, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerVisibility(index: .unchecked(index), isVisible: isVisible)
        )
        return .success(())
    }

    func setLayerLocked(index: Int, isLocked: Bool) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        documentGateway.layers.setLayerLocked(isLocked, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerLocked(index: .unchecked(index), isLocked: isLocked)
        )
        return .success(())
    }

    func setLayerAlphaLocked(index: Int, isAlphaLocked: Bool) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        documentGateway.layers.setLayerAlphaLocked(isAlphaLocked, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerAlphaLocked(index: .unchecked(index), isAlphaLocked: isAlphaLocked)
        )
        return .success(())
    }

    func setLayerClipped(index: Int, isClipped: Bool) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        documentGateway.layers.setLayerClipped(isClipped, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerClipped(index: .unchecked(index), isClipped: isClipped)
        )
        return .success(())
    }

    func revealLayerForEditing(index: Int) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        documentGateway.layers.setLayerVisible(true, index: index)
        return .success(())
    }

    func setLayerOpacity(index: Int, opacity: Double) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        guard (0...1).contains(opacity) else {
            return .failure(.invalidOpacity(opacity))
        }
        documentGateway.layers.setLayerOpacity(CGFloat(opacity), index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerOpacity(index: .unchecked(index), opacity: opacity)
        )
        return .success(())
    }

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        documentGateway.layers.setLayerBlendMode(blendMode.rawValue, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerBlendMode(index: .unchecked(index), blendMode: blendMode)
        )
        return .success(())
    }
}
