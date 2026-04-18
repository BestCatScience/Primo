import Foundation

extension PaintDocumentSession {
    func createFolder(name: String, layerIndex: Int) -> DocumentIndexedMutationResult {
        guard containsValidLayerAnchor(layerIndex) else {
            return .failure(.invalidLayerIndex(layerIndex))
        }
        let folderID = documentGateway.layers.createFolder(name: name, layerIndex: layerIndex)
        applyRecordedLifecycleMutation(
            recording: .createFolder(
                folderID: .unchecked(folderID),
                name: name,
                anchorLayerIndex: layerIndex >= 0 ? .unchecked(layerIndex) : nil
            ),
            captureFrame: false
        )
        return .success(folderID)
    }

    func deleteFolder(folderID: Int) -> DocumentMutationResult {
        if let failure = folderMutationFailure(folderID) {
            return .failure(failure)
        }
        let didDelete = documentGateway.layers.deleteFolder(id: folderID)
        if didDelete {
            applyRecordedLifecycleMutation(
                recording: .deleteFolder(folderID: .unchecked(folderID))
            )
        }
        return wrapMutationResult(
            didDelete,
            operation: "deleteFolder"
        )
    }

    func setFolderVisibility(folderID: Int, isVisible: Bool) -> DocumentMutationResult {
        if let failure = folderMutationFailure(folderID) {
            return .failure(failure)
        }
        documentGateway.layers.setFolderVisible(isVisible, folderID: folderID)
        applyRecordedLifecycleMutation(
            recording: .setFolderVisibility(folderID: .unchecked(folderID), isVisible: isVisible)
        )
        return .success(())
    }

    func setFolderName(folderID: Int, name: String) -> DocumentMutationResult {
        if let failure = folderMutationFailure(folderID) {
            return .failure(failure)
        }
        documentGateway.layers.setFolderName(name, folderID: folderID)
        return .success(())
    }

    func setFolderExpanded(folderID: Int, isExpanded: Bool) -> DocumentMutationResult {
        if let failure = folderMutationFailure(folderID) {
            return .failure(failure)
        }
        documentGateway.layers.setFolderExpanded(isExpanded, folderID: folderID)
        return .success(())
    }

    func assignLayer(index: Int, toFolder folderID: Int) -> DocumentMutationResult {
        if let failure = layerMutationFailure(index) {
            return .failure(failure)
        }
        if folderID >= 0, let failure = folderMutationFailure(folderID) {
            return .failure(failure)
        }
        let didAssign = documentGateway.layers.setLayerFolder(index: index, folderID: folderID)
        if didAssign {
            applyRecordedLifecycleMutation(
                recording: .assignLayerToFolder(
                    index: .unchecked(index),
                    folderID: folderID >= 0 ? .unchecked(folderID) : nil
                )
            )
        }
        return wrapMutationResult(
            didAssign,
            operation: "assignLayerToFolder"
        )
    }
}
