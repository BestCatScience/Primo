import Foundation

extension PaintDocumentSession {
    @discardableResult
    func createFolder(name: String, layerIndex: Int) -> Int {
        let folderID = Int(bridge.createFolder(name: name, layerIndex: layerIndex))
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .createFolder(
                    folderID: folderID,
                    name: name,
                    anchorLayerIndex: layerIndex >= 0 ? layerIndex : nil
                ),
                captureFrame: false
            )
        )
        return folderID
    }

    @discardableResult
    func deleteFolder(folderID: Int) -> Bool {
        let didDelete = bridge.deleteFolder(id: folderID)
        if didDelete {
            applyLifecycleMutation(
                editingLifecycleService.mutation(recording: .deleteFolder(folderID: folderID))
            )
        }
        return didDelete
    }

    func setFolderVisibility(folderID: Int, isVisible: Bool) {
        bridge.setFolderVisible(isVisible, folderID: folderID)
        applyLifecycleMutation(
            editingLifecycleService.mutation(
                recording: .setFolderVisibility(folderID: folderID, isVisible: isVisible)
            )
        )
    }

    func setFolderName(folderID: Int, name: String) {
        bridge.setFolderName(name, folderID: folderID)
    }

    func setFolderExpanded(folderID: Int, isExpanded: Bool) {
        bridge.setFolderExpanded(isExpanded, folderID: folderID)
    }

    @discardableResult
    func assignLayer(index: Int, toFolder folderID: Int) -> Bool {
        let didAssign = bridge.setLayerFolder(at: index, folderID: folderID)
        if didAssign {
            applyLifecycleMutation(
                editingLifecycleService.mutation(
                    recording: .assignLayerToFolder(index: index, folderID: folderID >= 0 ? folderID : nil)
                )
            )
        }
        return didAssign
    }
}
