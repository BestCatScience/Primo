import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func setActiveLayer(index: Int) {
        bridge.activeLayerIndex = index
    }

    func setLayerName(index: Int, name: String) {
        bridge.setLayerName(name, at: index)
    }

    func setLayerVisibility(index: Int, isVisible: Bool) {
        bridge.setLayerVisible(isVisible, at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setLayerVisibility(index: index, isVisible: isVisible)
            )
        )
    }

    func setLayerLocked(index: Int, isLocked: Bool) {
        bridge.setLayerLocked(isLocked, at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setLayerLocked(index: index, isLocked: isLocked)
            )
        )
    }

    func setLayerAlphaLocked(index: Int, isAlphaLocked: Bool) {
        bridge.setLayerAlphaLocked(isAlphaLocked, at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked)
            )
        )
    }

    func setLayerClipped(index: Int, isClipped: Bool) {
        bridge.setLayerClipped(isClipped, at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setLayerClipped(index: index, isClipped: isClipped),
                invalidating: .layer(index)
            )
        )
    }

    func revealLayerForEditing(index: Int) {
        bridge.setLayerVisible(true, at: index)
    }

    func setLayerOpacity(index: Int, opacity: Double) {
        bridge.setLayerOpacity(CGFloat(opacity), at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setLayerOpacity(index: index, opacity: opacity),
                invalidating: .layer(index)
            )
        )
    }

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) {
        bridge.setLayerBlendMode(blendMode.rawValue, at: index)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setLayerBlendMode(index: index, blendMode: blendMode),
                invalidating: .layer(index)
            )
        )
    }
}
