import CoreGraphics
import Foundation

extension PaintDocumentSession {
    @discardableResult
    func setActiveLayer(index: Int) -> Bool {
        guard containsLayerIndex(index) else { return false }
        documentGateway.layers.setActiveLayerIndex(index)
        return true
    }

    @discardableResult
    func setLayerName(index: Int, name: String) -> Bool {
        guard containsLayerIndex(index) else { return false }
        documentGateway.layers.setLayerName(name, index: index)
        return true
    }

    @discardableResult
    func setLayerVisibility(index: Int, isVisible: Bool) -> Bool {
        guard containsLayerIndex(index) else { return false }
        documentGateway.layers.setLayerVisible(isVisible, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerVisibility(index: .unchecked(index), isVisible: isVisible)
        )
        return true
    }

    @discardableResult
    func setLayerLocked(index: Int, isLocked: Bool) -> Bool {
        guard containsLayerIndex(index) else { return false }
        documentGateway.layers.setLayerLocked(isLocked, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerLocked(index: .unchecked(index), isLocked: isLocked)
        )
        return true
    }

    @discardableResult
    func setLayerAlphaLocked(index: Int, isAlphaLocked: Bool) -> Bool {
        guard containsLayerIndex(index) else { return false }
        documentGateway.layers.setLayerAlphaLocked(isAlphaLocked, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerAlphaLocked(index: .unchecked(index), isAlphaLocked: isAlphaLocked)
        )
        return true
    }

    @discardableResult
    func setLayerClipped(index: Int, isClipped: Bool) -> Bool {
        guard containsLayerIndex(index) else { return false }
        documentGateway.layers.setLayerClipped(isClipped, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerClipped(index: .unchecked(index), isClipped: isClipped)
        )
        return true
    }

    @discardableResult
    func revealLayerForEditing(index: Int) -> Bool {
        guard containsLayerIndex(index) else { return false }
        documentGateway.layers.setLayerVisible(true, index: index)
        return true
    }

    @discardableResult
    func setLayerOpacity(index: Int, opacity: Double) -> Bool {
        guard containsLayerIndex(index), (0...1).contains(opacity) else { return false }
        documentGateway.layers.setLayerOpacity(CGFloat(opacity), index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerOpacity(index: .unchecked(index), opacity: opacity)
        )
        return true
    }

    @discardableResult
    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) -> Bool {
        guard containsLayerIndex(index) else { return false }
        documentGateway.layers.setLayerBlendMode(blendMode.rawValue, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerBlendMode(index: .unchecked(index), blendMode: blendMode)
        )
        return true
    }
}
