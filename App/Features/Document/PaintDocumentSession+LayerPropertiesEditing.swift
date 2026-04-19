import CoreGraphics
import Foundation
import PrimoDocumentApplication

extension PaintDocumentSession {
    func setActiveLayer(index: Int) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(requirements: [.layer(index: index)])
        ) {
            documentGateway.layers.setActiveLayerIndex(index)
            return .success(())
        }
    }

    func setLayerName(index: Int, name: String) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(requirements: [.layer(index: index)])
        ) {
            documentGateway.layers.setLayerName(name, index: index)
            return .success(())
        }
    }

    func setLayerVisibility(index: Int, isVisible: Bool) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.layer(index: index)],
                applySideEffects: { session, _ in
                    session.applyLayerLifecycleMutation(
                        at: index,
                        recording: .setLayerVisibility(index: .unchecked(index), isVisible: isVisible)
                    )
                }
            )
        ) {
            documentGateway.layers.setLayerVisible(isVisible, index: index)
            return .success(())
        }
    }

    func setLayerLocked(index: Int, isLocked: Bool) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.layer(index: index)],
                applySideEffects: { session, _ in
                    session.applyLayerLifecycleMutation(
                        at: index,
                        recording: .setLayerLocked(index: .unchecked(index), isLocked: isLocked)
                    )
                }
            )
        ) {
            documentGateway.layers.setLayerLocked(isLocked, index: index)
            return .success(())
        }
    }

    func setLayerAlphaLocked(index: Int, isAlphaLocked: Bool) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.layer(index: index)],
                applySideEffects: { session, _ in
                    session.applyLayerLifecycleMutation(
                        at: index,
                        recording: .setLayerAlphaLocked(index: .unchecked(index), isAlphaLocked: isAlphaLocked)
                    )
                }
            )
        ) {
            documentGateway.layers.setLayerAlphaLocked(isAlphaLocked, index: index)
            return .success(())
        }
    }

    func setLayerClipped(index: Int, isClipped: Bool) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.layer(index: index)],
                applySideEffects: { session, _ in
                    session.applyLayerLifecycleMutation(
                        at: index,
                        recording: .setLayerClipped(index: .unchecked(index), isClipped: isClipped)
                    )
                }
            )
        ) {
            documentGateway.layers.setLayerClipped(isClipped, index: index)
            return .success(())
        }
    }

    func revealLayerForEditing(index: Int) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(requirements: [.layer(index: index)])
        ) {
            documentGateway.layers.setLayerVisible(true, index: index)
            return .success(())
        }
    }

    func setLayerOpacity(index: Int, opacity: Double) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.layer(index: index)],
                applySideEffects: { session, _ in
                    session.applyLayerLifecycleMutation(
                        at: index,
                        recording: .setLayerOpacity(index: .unchecked(index), opacity: opacity)
                    )
                }
            )
        ) {
            guard (0...1).contains(opacity) else {
                return .failure(.invalidOpacity(opacity))
            }
            documentGateway.layers.setLayerOpacity(CGFloat(opacity), index: index)
            return .success(())
        }
    }

    func setLayerBlendMode(index: Int, blendMode: LayerBlendMode) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.layer(index: index)],
                applySideEffects: { session, _ in
                    session.applyLayerLifecycleMutation(
                        at: index,
                        recording: .setLayerBlendMode(index: .unchecked(index), blendMode: blendMode)
                    )
                }
            )
        ) {
            documentGateway.layers.setLayerBlendMode(blendMode.rawValue, index: index)
            return .success(())
        }
    }
}
