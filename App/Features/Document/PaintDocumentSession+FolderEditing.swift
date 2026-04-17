import Foundation

extension PaintDocumentSession {
    @discardableResult
    func createFolder(name: String, layerIndex: Int) -> Int {
        guard containsValidLayerAnchor(layerIndex) else { return -1 }
        let folderID = bridgeCreateFolder(name: name, layerIndex: layerIndex)
        applyRecordedLifecycleMutation(
            recording: .createFolder(
                folderID: .unchecked(folderID),
                name: name,
                anchorLayerIndex: layerIndex >= 0 ? .unchecked(layerIndex) : nil
            ),
            captureFrame: false
        )
        return folderID
    }

    @discardableResult
    func deleteFolder(folderID: Int) -> Bool {
        let didDelete = bridgeDeleteFolder(id: folderID)
        if didDelete {
            applyRecordedLifecycleMutation(
                recording: .deleteFolder(folderID: .unchecked(folderID))
            )
        }
        return didDelete
    }

    @discardableResult
    func setFolderVisibility(folderID: Int, isVisible: Bool) -> Bool {
        guard containsFolderID(folderID) else { return false }
        bridgeSetFolderVisible(isVisible, folderID: folderID)
        applyRecordedLifecycleMutation(
            recording: .setFolderVisibility(folderID: .unchecked(folderID), isVisible: isVisible)
        )
        return true
    }

    @discardableResult
    func setFolderName(folderID: Int, name: String) -> Bool {
        guard containsFolderID(folderID) else { return false }
        bridgeSetFolderName(name, folderID: folderID)
        return true
    }

    @discardableResult
    func setFolderExpanded(folderID: Int, isExpanded: Bool) -> Bool {
        guard containsFolderID(folderID) else { return false }
        bridgeSetFolderExpanded(isExpanded, folderID: folderID)
        return true
    }

    @discardableResult
    func assignLayer(index: Int, toFolder folderID: Int) -> Bool {
        guard containsLayerIndex(index) else { return false }
        guard folderID < 0 || containsFolderID(folderID) else { return false }
        let didAssign = bridgeSetLayerFolder(index: index, folderID: folderID)
        if didAssign {
            applyRecordedLifecycleMutation(
                recording: .assignLayerToFolder(
                    index: .unchecked(index),
                    folderID: folderID >= 0 ? .unchecked(folderID) : nil
                )
            )
        }
        return didAssign
    }
}
