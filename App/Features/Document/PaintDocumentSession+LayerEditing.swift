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
            applyLifecycleMutation(
                editingLifecycleService.mutation(recording: .undo, invalidating: .all)
            )
        }
        return didUndo
    }

    @discardableResult
    func redo() -> Bool {
        let didRedo = bridgeRedo()
        if didRedo {
            applyLifecycleMutation(
                editingLifecycleService.mutation(recording: .redo, invalidating: .all)
            )
        }
        return didRedo
    }

    func addLayer(name: String) {
        setBridgeActiveLayerIndex(bridgeAddLayer(name: name))
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .addLayer(name: name),
                invalidating: .layer(bridgeActiveLayerIndex())
            )
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
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .duplicateLayer(index: .unchecked(index), name: name),
                    invalidating: .all
                )
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
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .deleteLayer(index: .unchecked(index)),
                    invalidating: .all
                )
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
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .moveLayer(index: .unchecked(index), destinationIndex: .unchecked(destinationIndex)),
                    invalidating: .all
                )
            )
        }
        return didMove
    }

}
