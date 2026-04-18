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
        switch documentGateway.layers.deleteFolderResult(id: folderID) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            applyRecordedLifecycleMutation(
                recording: .deleteFolder(folderID: .unchecked(folderID))
            )
            return .success(())
        }
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
        switch documentGateway.layers.setLayerFolderResult(index: index, folderID: folderID) {
        case let .failure(failure):
            return .failure(failure)
        case .success:
            applyRecordedLifecycleMutation(
                recording: .assignLayerToFolder(
                    index: .unchecked(index),
                    folderID: folderID >= 0 ? .unchecked(folderID) : nil
                )
            )
            return .success(())
        }
    }
}
