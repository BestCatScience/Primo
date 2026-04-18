import CoreGraphics
import Foundation

extension PaintDocumentSession {
    func canUndo() -> Bool {
        documentGateway.history.canUndo()
    }

    func canRedo() -> Bool {
        documentGateway.history.canRedo()
    }

    func undo() -> DocumentMutationResult {
        guard canUndo() else {
            return .failure(.noUndoState)
        }
        switch documentGateway.history.undoResult() {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            applyDocumentLifecycleMutation(recording: .undo)
            return .success(())
        }
    }

    func redo() -> DocumentMutationResult {
        guard canRedo() else {
            return .failure(.noRedoState)
        }
        switch documentGateway.history.redoResult() {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            applyDocumentLifecycleMutation(recording: .redo)
            return .success(())
        }
    }

    func addLayer(name: String) -> DocumentIndexedMutationResult {
        let createdIndex = documentGateway.layers.addLayer(name: name)
        documentGateway.layers.setActiveLayerIndex(createdIndex)
        applyLayerLifecycleMutation(
            at: createdIndex,
            recording: .addLayer(name: name)
        )
        return .success(createdIndex)
    }

    func duplicateLayer(index: Int, name: String) -> DocumentIndexedMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        let duplicatedIndex = documentGateway.layers.duplicateLayer(index: index, name: name)
        guard duplicatedIndex >= 0 else {
            return .failure(.bridgeMutationFailed("duplicateLayer"))
        }
        if let textLayer = storedTextLayer(at: index) {
            remapStoredTextLayersForDuplication(of: index, duplicatedIndex: duplicatedIndex, duplicate: textLayer)
        } else {
            remapStoredTextLayersForInsertion(at: duplicatedIndex)
        }
        applyDocumentLifecycleMutation(
            recording: .duplicateLayer(index: .unchecked(index), name: name)
        )
        return .success(duplicatedIndex)
    }

    func deleteLayer(index: Int) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        switch documentGateway.layers.deleteLayerResult(index: index) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            remapStoredTextLayersForDeletion(of: index)
            applyDocumentLifecycleMutation(
                recording: .deleteLayer(index: .unchecked(index))
            )
            return .success(())
        }
    }

    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        if let failure = layerMutationFailure(destinationIndex) {
            return .failure(failure)
        }
        switch documentGateway.layers.moveLayerResult(from: index, to: destinationIndex) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            remapStoredTextLayersForMove(from: index, to: destinationIndex)
            applyDocumentLifecycleMutation(
                recording: .moveLayer(
                    index: .unchecked(index),
                    destinationIndex: .unchecked(destinationIndex)
                )
            )
            return .success(())
        }
    }
}
