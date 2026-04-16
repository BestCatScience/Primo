import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func canUndo() -> Bool {
        bridge.canUndo()
    }

    func canRedo() -> Bool {
        bridge.canRedo()
    }

    @discardableResult
    func undo() -> Bool {
        let didUndo = bridge.undo()
        if didUndo {
            applyLifecycleMutation(
                editingLifecycleService.mutation(recording: .undo, invalidating: .all)
            )
        }
        return didUndo
    }

    @discardableResult
    func redo() -> Bool {
        let didRedo = bridge.redo()
        if didRedo {
            applyLifecycleMutation(
                editingLifecycleService.mutation(recording: .redo, invalidating: .all)
            )
        }
        return didRedo
    }

    func addLayer(name: String) {
        bridge.activeLayerIndex = bridge.addLayer(name: name)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .addLayer(name: name),
                invalidating: .layer(Int(bridge.activeLayerIndex))
            )
        )
    }

    @discardableResult
    func duplicateLayer(index: Int, name: String) -> Int {
        let duplicatedIndex = Int(bridge.duplicateLayer(at: index, name: name))
        if duplicatedIndex >= 0 {
            if let textLayer = textLayers[index] {
                textLayers = remappedTextLayersForDuplication(of: index, duplicatedIndex: duplicatedIndex, duplicate: textLayer)
            } else {
                textLayers = remappedTextLayersForInsertion(at: duplicatedIndex)
            }
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .duplicateLayer(index: index, name: name),
                    invalidating: .all
                )
            )
        }
        return duplicatedIndex
    }

    @discardableResult
    func deleteLayer(index: Int) -> Bool {
        let didDelete = bridge.deleteLayer(at: index)
        if didDelete {
            textLayers = remappedTextLayersForDeletion(of: index)
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .deleteLayer(index: index),
                    invalidating: .all
                )
            )
        }
        return didDelete
    }

    @discardableResult
    func moveLayer(from index: Int, to destinationIndex: Int) -> Bool {
        let didMove = bridge.moveLayer(at: index, to: destinationIndex)
        if didMove {
            textLayers = remappedTextLayersForMove(from: index, to: destinationIndex)
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .moveLayer(index: index, destinationIndex: destinationIndex),
                    invalidating: .all
                )
            )
        }
        return didMove
    }

}
