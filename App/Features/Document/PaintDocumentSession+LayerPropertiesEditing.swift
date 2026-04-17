import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func setActiveLayer(index: Int) {
        requireExistingLayerIndex(index, label: "Active layer index")
        setBridgeActiveLayerIndex(index)
    }

    func setLayerName(index: Int, name: String) {
        requireExistingLayerIndex(index)
        bridgeSetLayerName(name, index: index)
    }

    func setLayerVisibility(index: Int, isVisible: Bool) {
        requireExistingLayerIndex(index)
        bridgeSetLayerVisible(isVisible, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerVisibility(index: .unchecked(index), isVisible: isVisible)
        )
    }

    func setLayerLocked(index: Int, isLocked: Bool) {
        requireExistingLayerIndex(index)
        bridgeSetLayerLocked(isLocked, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerLocked(index: .unchecked(index), isLocked: isLocked)
        )
    }

    func setLayerAlphaLocked(index: Int, isAlphaLocked: Bool) {
        requireExistingLayerIndex(index)
        bridgeSetLayerAlphaLocked(isAlphaLocked, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerAlphaLocked(index: .unchecked(index), isAlphaLocked: isAlphaLocked)
        )
    }

    func setLayerClipped(index: Int, isClipped: Bool) {
        requireExistingLayerIndex(index)
        bridgeSetLayerClipped(isClipped, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerClipped(index: .unchecked(index), isClipped: isClipped)
        )
    }

    func revealLayerForEditing(index: Int) {
        requireExistingLayerIndex(index)
        bridgeSetLayerVisible(true, index: index)
    }

    func setLayerOpacity(index: Int, opacity: Double) {
        requireExistingLayerIndex(index)
        precondition((0...1).contains(opacity), "Layer opacity must be in 0...1.")
        bridgeSetLayerOpacity(CGFloat(opacity), index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerOpacity(index: .unchecked(index), opacity: opacity)
        )
    }

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) {
        requireExistingLayerIndex(index)
        bridgeSetLayerBlendMode(blendMode.rawValue, index: index)
        applyLayerLifecycleMutation(
            at: index,
            recording: .setLayerBlendMode(index: .unchecked(index), blendMode: blendMode)
        )
    }
}
