import Foundation

extension AppFeature {
    func handleActiveLayerVisibilityToggle(state: inout State) {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard let layer = state.layerSidebar.layer(withIndex: activeLayerIndex) else {
            return
        }
        layerWorkflowService.setLayerVisibility(activeLayerIndex, visible: !layer.visible)
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
        layerWorkflowService.setActiveLayer(targetIndex)
        state.canvas.activateLayerForEditing(targetIndex)
        applyCurrentDocumentPresentation(state: &state)
    }

    func handleLayerOpacityChange(
        state: inout State,
        index: Int,
        opacity: Double
    ) {
        layerWorkflowService.setLayerOpacity(index, opacity: opacity)
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
        layerWorkflowService.setLayerLocked(index, isLocked: !layer.isLocked)
        applyDirtyPresentation(state: &state)
    }

    func handleLayerAlphaLockToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return
        }
        layerWorkflowService.setLayerAlphaLocked(index, isAlphaLocked: !layer.isAlphaLocked)
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
        layerWorkflowService.setLayerClipped(index, isClipped: !layer.isClipped)
        applyDirtyPresentation(state: &state)
    }

    func handleLayerSelection(
        state: inout State,
        index: Int
    ) {
        layerWorkflowService.setActiveLayer(index)
        state.canvas.activateLayerForEditing(index)
        applyCurrentDocumentPresentation(state: &state)
    }

    func handleLayerVisibilityToggle(
        state: inout State,
        index: Int
    ) {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return
        }
        layerWorkflowService.setLayerVisibility(index, visible: !layer.visible)
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
    }

    func handleFolderExpandedChange(
        state: inout State,
        folderID: Int,
        isExpanded: Bool
    ) {
        layerWorkflowService.setFolderExpanded(folderID, isExpanded: isExpanded)
        applyCurrentDocumentPresentation(state: &state)
    }

    func handleFolderVisibilityToggle(
        state: inout State,
        folderID: Int
    ) {
        guard let folder = state.layerSidebar.folder(withID: folderID) else {
            return
        }
        layerWorkflowService.setFolderVisibility(folderID, visible: !folder.visible)
        applyDirtyPresentation(state: &state)
    }

    func handleFolderRename(
        state: inout State,
        folderID: Int,
        name: String
    ) {
        layerWorkflowService.setFolderName(folderID, name: name)
        applyDirtyPresentation(state: &state)
    }

    func handleLayerBlendModeChange(
        state: inout State,
        index: Int,
        blendMode: LayerBlendMode
    ) {
        layerWorkflowService.setLayerBlendMode(index, blendMode: blendMode)
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
    }

    func handleLayerRename(
        state: inout State,
        index: Int,
        name: String
    ) {
        layerWorkflowService.setLayerName(index, name: name)
        applyDirtyPresentation(state: &state)
    }
}
