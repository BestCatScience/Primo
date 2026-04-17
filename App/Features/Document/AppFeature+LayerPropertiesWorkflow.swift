import Foundation

extension AppFeature {
    func handleActiveLayerVisibilityToggle(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard let layer = state.layerSidebar.layer(withIndex: activeLayerIndex) else {
            return
        }
        layerWorkflowService.paintDocumentClient.setLayerVisibility(activeLayerIndex, !layer.visible)
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
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
        layerWorkflowService.paintDocumentClient.setActiveLayer(targetIndex)
        state.canvas.activateLayer(targetIndex)
        state.canvas.clearSelection()
        applyPresentation(paintDocumentClient.presentation(), state: &state)
    }

    func handleLayerOpacityChange(
        state: inout State,
        index: Int,
        opacity: Double
    ) {
        layerWorkflowService.paintDocumentClient.setLayerOpacity(index, opacity)
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
    }

    func handleLayerLockToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return
        }
        layerWorkflowService.paintDocumentClient.setLayerLocked(index, !layer.isLocked)
        applyDirtyPresentation(state: &state)
    }

    func handleLayerAlphaLockToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return
        }
        layerWorkflowService.paintDocumentClient.setLayerAlphaLocked(index, !layer.isAlphaLocked)
        applyDirtyPresentation(state: &state)
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
        layerWorkflowService.paintDocumentClient.setLayerClipped(index, !layer.isClipped)
        applyDirtyPresentation(state: &state)
    }

    func handleLayerSelection(
        state: inout State,
        index: Int
    ) {
        layerWorkflowService.paintDocumentClient.setActiveLayer(index)
        state.canvas.activateLayer(index)
        state.canvas.clearSelection()
        applyPresentation(paintDocumentClient.presentation(), state: &state)
    }

    func handleLayerVisibilityToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return
        }
        layerWorkflowService.paintDocumentClient.setLayerVisibility(index, !layer.visible)
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
    }

    func handleFolderExpandedChange(
        state: inout State,
        folderID: Int,
        isExpanded: Bool
    ) {
        layerWorkflowService.paintDocumentClient.setFolderExpanded(folderID, isExpanded)
        applyPresentation(paintDocumentClient.presentation(), state: &state)
    }

    func handleFolderVisibilityToggle(
        state: inout State,
        folderID: Int
    ) {
        guard let folder = state.layerSidebar.folder(withID: folderID) else {
            return
        }
        layerWorkflowService.paintDocumentClient.setFolderVisibility(folderID, !folder.visible)
        applyDirtyPresentation(state: &state)
    }

    func handleFolderRename(
        state: inout State,
        folderID: Int,
        name: String
    ) {
        layerWorkflowService.paintDocumentClient.setFolderName(folderID, name)
        applyDirtyPresentation(state: &state)
    }

    func handleLayerBlendModeChange(
        state: inout State,
        index: Int,
        blendMode: LayerBlendMode
    ) {
        layerWorkflowService.paintDocumentClient.setLayerBlendMode(index, blendMode)
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
    }

    func handleLayerRename(
        state: inout State,
        index: Int,
        name: String
    ) {
        layerWorkflowService.paintDocumentClient.setLayerName(index, name)
        applyDirtyPresentation(state: &state)
    }
}
