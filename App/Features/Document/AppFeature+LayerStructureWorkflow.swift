import Foundation

extension AppFeature {
    func handleAddLayer(state: inout State) {
        layerWorkflowService.paintDocumentClient.addLayer("Layer \(state.layerSidebar.layers.count + 1)")
        state.canvas.activateLayer(state.layerSidebar.layers.count)
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
    }

    func handleAddFolder(state: inout State) {
        let nextFolderNumber = state.layerSidebar.rows.reduce(into: 0) { partialResult, row in
            if case .folder = row {
                partialResult += 1
            }
        } + 1
        _ = layerWorkflowService.paintDocumentClient.createFolder(
            StudioStrings.folderName(nextFolderNumber, state.application.appLanguage),
            state.layerSidebar.activeLayerIndex
        )
        applyDirtyPresentation(state: &state)
    }

    func handleFolderDeletion(
        state: inout State,
        folderID: Int
    ) {
        handleLayerMutation(state: &state) {
            layerWorkflowService.paintDocumentClient.deleteFolder(folderID)
        }
    }

    func handleLayerDeletion(
        state: inout State,
        index: Int
    ) {
        handleLayerMutation(state: &state, clearsSelection: true) {
            layerWorkflowService.paintDocumentClient.deleteLayer(index)
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
            layerWorkflowService.paintDocumentClient.duplicateLayer(index, duplicateName) >= 0
        }
    }

    func handleLayerMove(
        state: inout State,
        index: Int,
        destinationIndex: Int
    ) {
        handleLayerMutation(state: &state, clearsSelection: true) {
            layerWorkflowService.paintDocumentClient.moveLayer(index, destinationIndex)
        }
    }

    func handleLayerFolderAssignment(
        state: inout State,
        index: Int,
        folderID: Int
    ) {
        handleLayerMutation(state: &state) {
            layerWorkflowService.paintDocumentClient.assignLayerToFolder(index, folderID)
        }
    }

    func handleLayerMergeDown(
        state: inout State,
        index: Int
    ) {
        handleLayerMutation(state: &state, clearsSelection: true) {
            layerWorkflowService.paintDocumentClient.mergeLayerDown(index)
        }
    }
}
