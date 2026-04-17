import Foundation

extension AppFeature {
    func handleAddLayer(state: inout State) {
        let namingPolicy = namingPolicy(for: state)
        let newLayerIndex = layerWorkflowService.addLayer(
            named: namingPolicy.defaultLayerName(for: state.layerSidebar)
        )
        state.canvas.activateLayerForEditing(newLayerIndex)
        applyDirtyPresentation(state: &state)
    }

    func handleAddFolder(state: inout State) {
        let namingPolicy = namingPolicy(for: state)
        let nextFolderNumber = state.layerSidebar.rows.reduce(into: 0) { partialResult, row in
            if case .folder = row {
                partialResult += 1
            }
        } + 1
        _ = layerWorkflowService.createFolder(
            named: namingPolicy.folderName(forOrdinal: nextFolderNumber),
            afterLayerAt: state.layerSidebar.activeLayerIndex
        )
        applyDirtyPresentation(state: &state)
    }

    func handleFolderDeletion(
        state: inout State,
        folderID: Int
    ) {
        handleLayerMutation(state: &state) {
            layerWorkflowService.deleteFolder(folderID)
        }
    }

    func handleLayerDeletion(
        state: inout State,
        index: Int
    ) {
        handleLayerMutation(state: &state, clearsSelection: true) {
            layerWorkflowService.deleteLayer(index)
        }
    }

    func handleLayerDuplication(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return
        }
        let duplicateName = namingPolicy(for: state).duplicatedLayerName(for: layer.name)
        handleLayerMutation(state: &state, clearsSelection: true) {
            layerWorkflowService.duplicateLayer(index, named: duplicateName) >= 0
        }
    }

    func handleLayerMove(
        state: inout State,
        index: Int,
        destinationIndex: Int
    ) {
        handleLayerMutation(state: &state, clearsSelection: true) {
            layerWorkflowService.moveLayer(index, to: destinationIndex)
        }
    }

    func handleLayerFolderAssignment(
        state: inout State,
        index: Int,
        folderID: Int
    ) {
        handleLayerMutation(state: &state) {
            layerWorkflowService.assignLayer(index, toFolder: folderID)
        }
    }

    func handleLayerMergeDown(
        state: inout State,
        index: Int
    ) {
        handleLayerMutation(state: &state, clearsSelection: true) {
            layerWorkflowService.mergeLayerDown(index)
        }
    }
}
