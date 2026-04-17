import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func canUndo() -> Bool {
        bridgeCanUndo()
    }

    func canRedo() -> Bool {
        bridgeCanRedo()
    }

    @discardableResult
    func undo() -> Bool {
        let didUndo = bridgeUndo()
        if didUndo {
            applyDocumentLifecycleMutation(recording: .undo)
        }
        return didUndo
    }

    @discardableResult
    func redo() -> Bool {
        let didRedo = bridgeRedo()
        if didRedo {
            applyDocumentLifecycleMutation(recording: .redo)
        }
        return didRedo
    }

    func addLayer(name: String) {
        setBridgeActiveLayerIndex(bridgeAddLayer(name: name))
        applyLayerLifecycleMutation(
            at: bridgeActiveLayerIndex(),
            recording: .addLayer(name: name)
        )
    }

    @discardableResult
    func duplicateLayer(index: Int, name: String) -> Int {
        requireExistingLayerIndex(index)
        let duplicatedIndex = bridgeDuplicateLayer(index: index, name: name)
        if duplicatedIndex >= 0 {
            if let textLayer = storedTextLayer(at: index) {
                remapStoredTextLayersForDuplication(of: index, duplicatedIndex: duplicatedIndex, duplicate: textLayer)
            } else {
                remapStoredTextLayersForInsertion(at: duplicatedIndex)
            }
            applyDocumentLifecycleMutation(
                recording: .duplicateLayer(index: .unchecked(index), name: name)
            )
        }
        return duplicatedIndex
    }

    @discardableResult
    func deleteLayer(index: Int) -> Bool {
        requireExistingLayerIndex(index)
        let didDelete = bridgeDeleteLayer(index: index)
        if didDelete {
            remapStoredTextLayersForDeletion(of: index)
            applyDocumentLifecycleMutation(
                recording: .deleteLayer(index: .unchecked(index))
            )
        }
        return didDelete
    }

    @discardableResult
    func moveLayer(from index: Int, to destinationIndex: Int) -> Bool {
        requireExistingLayerIndex(index)
        requireExistingLayerIndex(destinationIndex)
        let didMove = bridgeMoveLayer(from: index, to: destinationIndex)
        if didMove {
            remapStoredTextLayersForMove(from: index, to: destinationIndex)
            applyDocumentLifecycleMutation(
                recording: .moveLayer(
                    index: .unchecked(index),
                    destinationIndex: .unchecked(destinationIndex)
                )
            )
        }
        return didMove
    }

}
