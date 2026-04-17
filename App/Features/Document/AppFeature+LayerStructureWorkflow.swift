import Foundation

extension AppFeature {
    func handleAddLayer(state: inout State) {
        let newLayerIndex = layerWorkflowService.addLayer(
            named: state.layerSidebar.numberedLayerName(prefix: "Layer")
        )
        state.canvas.activateLayerForEditing(newLayerIndex)
        applyDirtyPresentation(state: &state)
    }

    func handleAddFolder(state: inout State) {
        let nextFolderNumber = state.layerSidebar.rows.reduce(into: 0) { partialResult, row in
            if case .folder = row {
                partialResult += 1
            }
        } + 1
        _ = layerWorkflowService.createFolder(
            named: StudioStrings.folderName(nextFolderNumber, state.application.appLanguage),
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
        let duplicateName = state.application.appLanguage == .japanese ? "\(layer.name) のコピー" : "\(layer.name) Copy"
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
