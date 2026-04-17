import Foundation

extension AppFeature {
    func handleActiveLayerVisibilityToggle(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard let layer = state.layerSidebar.layer(withIndex: activeLayerIndex) else {
            return
        }
        _ = handleDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            layerWorkflowService.setLayerVisibility(activeLayerIndex, visible: !layer.visible)
        }
    }

    func handleSelectAdjacentLayer(
        state: inout State,
        direction: Int
    ) {
        guard let currentPosition = state.layerSidebar.layers.firstIndex(where: { $0.index == state.layerSidebar.activeLayerIndex }) else {
            return
        }
        let targetPosition = currentPosition + direction
        guard state.layerSidebar.layers.indices.contains(targetPosition) else {
            return
        }
        let targetIndex = state.layerSidebar.layers[targetPosition].index
        guard layerWorkflowService.setActiveLayer(targetIndex) else {
            return
        }
        state.canvas.activateLayerForEditing(targetIndex)
        completeDocumentMutation(
            state: &state,
            contract: .currentPresentation
        )
    }

    func handleLayerOpacityChange(
        state: inout State,
        index: Int,
        opacity: Double
    ) {
        _ = handleDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            layerWorkflowService.setLayerOpacity(index, opacity: opacity)
        }
    }

    func handleLayerLockToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return
        }
        _ = handleDocumentMutation(state: &state) {
            layerWorkflowService.setLayerLocked(index, isLocked: !layer.isLocked)
        }
    }

    func handleLayerAlphaLockToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return
        }
        _ = handleDocumentMutation(state: &state) {
            layerWorkflowService.setLayerAlphaLocked(index, isAlphaLocked: !layer.isAlphaLocked)
        }
    }

    func handleLayerClippingToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return
        }
        guard layer.isClipped || index > 0 else {
            return
        }
        _ = handleDocumentMutation(state: &state) {
            layerWorkflowService.setLayerClipped(index, isClipped: !layer.isClipped)
        }
    }

    func handleLayerSelection(
        state: inout State,
        index: Int
    ) {
        guard layerWorkflowService.setActiveLayer(index) else {
            return
        }
        state.canvas.activateLayerForEditing(index)
        completeDocumentMutation(
            state: &state,
            contract: .currentPresentation
        )
    }

    func handleLayerVisibilityToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return
        }
        _ = handleDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            layerWorkflowService.setLayerVisibility(index, visible: !layer.visible)
        }
    }

    func handleFolderExpandedChange(
        state: inout State,
        folderID: Int,
        isExpanded: Bool
    ) {
        _ = handleDocumentMutation(
            state: &state,
            contract: .currentPresentation
        ) {
            layerWorkflowService.setFolderExpanded(folderID, isExpanded: isExpanded)
        }
    }

    func handleFolderVisibilityToggle(
        state: inout State,
        folderID: Int
    ) {
        guard let folder = state.layerSidebar.folder(withID: folderID) else {
            return
        }
        _ = handleDocumentMutation(state: &state) {
            layerWorkflowService.setFolderVisibility(folderID, visible: !folder.visible)
        }
    }

    func handleFolderRename(
        state: inout State,
        folderID: Int,
        name: String
    ) {
        _ = handleDocumentMutation(state: &state) {
            layerWorkflowService.setFolderName(folderID, name: name)
        }
    }

    func handleLayerBlendModeChange(
        state: inout State,
        index: Int,
        blendMode: LayerBlendMode
    ) {
        _ = handleDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            layerWorkflowService.setLayerBlendMode(index, blendMode: blendMode)
        }
    }

    func handleLayerRename(
        state: inout State,
        index: Int,
        name: String
    ) {
        _ = handleDocumentMutation(state: &state) {
            layerWorkflowService.setLayerName(index, name: name)
        }
    }
}
