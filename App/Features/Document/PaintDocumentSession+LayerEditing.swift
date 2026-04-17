import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func canUndo() -> Bool {
        documentGateway.history.canUndo()
    }

    func canRedo() -> Bool {
        documentGateway.history.canRedo()
    }

    @discardableResult
    func undo() -> Bool {
        let didUndo = documentGateway.history.undo()
        if didUndo {
            applyDocumentLifecycleMutation(recording: .undo)
        }
        return didUndo
    }

    @discardableResult
    func redo() -> Bool {
        let didRedo = documentGateway.history.redo()
        if didRedo {
            applyDocumentLifecycleMutation(recording: .redo)
        }
        return didRedo
    }

    @discardableResult
    func addLayer(name: String) -> Int {
        let createdIndex = documentGateway.layers.addLayer(name: name)
        documentGateway.layers.setActiveLayerIndex(createdIndex)
        applyLayerLifecycleMutation(
            at: createdIndex,
            recording: .addLayer(name: name)
        )
        return createdIndex
    }

    @discardableResult
    func duplicateLayer(index: Int, name: String) -> Int {
        guard containsLayerIndex(index) else { return -1 }
        let duplicatedIndex = documentGateway.layers.duplicateLayer(index: index, name: name)
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
        guard containsLayerIndex(index) else { return false }
        let didDelete = documentGateway.layers.deleteLayer(index: index)
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
        guard containsLayerIndex(index), containsLayerIndex(destinationIndex) else {
            return false
        }
        let didMove = documentGateway.layers.moveLayer(from: index, to: destinationIndex)
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
