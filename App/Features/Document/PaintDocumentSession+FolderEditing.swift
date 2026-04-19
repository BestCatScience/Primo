import Foundation
import PrimoDocumentApplication

extension PaintDocumentSession {
    func createFolder(name: String, layerIndex: Int) -> DocumentIndexedMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.layerAnchor(index: layerIndex)],
                applySideEffects: { session, folderID in
                    session.applyRecordedLifecycleMutation(
                        recording: .createFolder(
                            folderID: .unchecked(folderID),
                            name: name,
                            anchorLayerIndex: layerIndex >= 0 ? .unchecked(layerIndex) : nil
                        ),
                        captureFrame: false
                    )
                }
            )
        ) {
            .success(documentGateway.layers.createFolder(name: name, layerIndex: layerIndex))
        }
    }

    func deleteFolder(folderID: Int) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.folder(folderID: folderID)],
                applySideEffects: { session, _ in
                    session.applyRecordedLifecycleMutation(
                        recording: .deleteFolder(folderID: .unchecked(folderID))
                    )
                }
            )
        ) {
            documentGateway.layers.deleteFolderResult(id: folderID)
        }
    }

    func setFolderVisibility(folderID: Int, isVisible: Bool) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(
                requirements: [.folder(folderID: folderID)],
                applySideEffects: { session, _ in
                    session.applyRecordedLifecycleMutation(
                        recording: .setFolderVisibility(folderID: .unchecked(folderID), isVisible: isVisible)
                    )
                }
            )
        ) {
            documentGateway.layers.setFolderVisible(isVisible, folderID: folderID)
            return .success(())
        }
    }

    func setFolderName(folderID: Int, name: String) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(requirements: [.folder(folderID: folderID)])
        ) {
            documentGateway.layers.setFolderName(name, folderID: folderID)
            return .success(())
        }
    }

    func setFolderExpanded(folderID: Int, isExpanded: Bool) -> DocumentMutationResult {
        executeMutation(
            SessionMutationContract(requirements: [.folder(folderID: folderID)])
        ) {
            documentGateway.layers.setFolderExpanded(isExpanded, folderID: folderID)
            return .success(())
        }
    }

    func assignLayer(index: Int, toFolder folderID: Int) -> DocumentMutationResult {
        let requirements: [DocumentMutationCommand] = folderID >= 0
            ? [.layer(index: index), .folder(folderID: folderID)]
            : [.layer(index: index)]
        return executeMutation(
            SessionMutationContract(
                requirements: requirements,
                applySideEffects: { session, _ in
                    session.applyRecordedLifecycleMutation(
                        recording: .assignLayerToFolder(
                            index: .unchecked(index),
                            folderID: folderID >= 0 ? .unchecked(folderID) : nil
                        )
                    )
                }
            )
        ) {
            documentGateway.layers.setLayerFolderResult(index: index, folderID: folderID)
        }
    }
}
