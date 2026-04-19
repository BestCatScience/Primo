import CoreGraphics
import Foundation
import PrimoDocumentApplication

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
        executeMutation(
            SessionMutationContract(
                requirements: [.layer(index: index)],
                applySideEffects: { session, duplicatedIndex in
                    if let textLayer = session.storedTextLayer(at: index) {
                        session.remapStoredTextLayersForDuplication(
                            of: index,
                            duplicatedIndex: duplicatedIndex,
                            duplicate: textLayer
                        )
                    } else {
                        session.remapStoredTextLayersForInsertion(at: duplicatedIndex)
                    }
                    session.applyDocumentLifecycleMutation(
                        recording: .duplicateLayer(index: .unchecked(index), name: name)
                    )
                }
            )
        ) {
            let duplicatedIndex = documentGateway.layers.duplicateLayer(index: index, name: name)
            guard duplicatedIndex >= 0 else {
                return .failure(.bridgeMutationFailed("duplicateLayer"))
            }
            return .success(duplicatedIndex)
        }
    }

    func deleteLayer(index: Int) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.layer(index: index)],
                applySideEffects: { session, _ in
                    session.remapStoredTextLayersForDeletion(of: index)
                    session.applyDocumentLifecycleMutation(
                        recording: .deleteLayer(index: .unchecked(index))
                    )
                }
            )
        ) {
            documentGateway.layers.deleteLayerResult(index: index)
        }
    }

    func moveLayer(from index: Int, to destinationIndex: Int) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.layer(index: index), .layer(index: destinationIndex)],
                applySideEffects: { session, _ in
                    session.remapStoredTextLayersForMove(from: index, to: destinationIndex)
                    session.applyDocumentLifecycleMutation(
                        recording: .moveLayer(
                            index: .unchecked(index),
                            destinationIndex: .unchecked(destinationIndex)
                        )
                    )
                }
            )
        ) {
            documentGateway.layers.moveLayerResult(from: index, to: destinationIndex)
        }
    }
}
