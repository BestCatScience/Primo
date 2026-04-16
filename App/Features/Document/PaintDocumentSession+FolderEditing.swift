import Foundation

extension PaintDocumentSession {
    @discardableResult
    func createFolder(name: String, layerIndex: Int) -> Int {
        requireValidLayerAnchor(layerIndex, label: "Folder anchor index")
        let folderID = bridgeCreateFolder(name: name, layerIndex: layerIndex)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .createFolder(
                    folderID: .unchecked(folderID),
                    name: name,
                    anchorLayerIndex: layerIndex >= 0 ? .unchecked(layerIndex) : nil
                ),
                captureFrame: false
            )
        )
        return folderID
    }

    @discardableResult
    func deleteFolder(folderID: Int) -> Bool {
        let didDelete = bridgeDeleteFolder(id: folderID)
        if didDelete {
            applyLifecycleMutation(
                editingLifecycleService.mutation(recording: .deleteFolder(folderID: .unchecked(folderID)))
            )
        }
        return didDelete
    }

    func setFolderVisibility(folderID: Int, isVisible: Bool) {
        bridgeSetFolderVisible(isVisible, folderID: folderID)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setFolderVisibility(folderID: .unchecked(folderID), isVisible: isVisible)
            )
        )
    }

    func setFolderName(folderID: Int, name: String) {
        bridgeSetFolderName(name, folderID: folderID)
    }

    func setFolderExpanded(folderID: Int, isExpanded: Bool) {
        bridgeSetFolderExpanded(isExpanded, folderID: folderID)
    }

    @discardableResult
    func assignLayer(index: Int, toFolder folderID: Int) -> Bool {
        requireExistingLayerIndex(index)
        let didAssign = bridgeSetLayerFolder(index: index, folderID: folderID)
        if didAssign {
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .assignLayerToFolder(
                        index: .unchecked(index),
                        folderID: folderID >= 0 ? .unchecked(folderID) : nil
                    )
                )
            )
        }
        return didAssign
    }
}
