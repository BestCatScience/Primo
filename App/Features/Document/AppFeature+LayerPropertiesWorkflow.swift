import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleActiveLayerVisibilityToggle(state: inout State) -> Effect<Action> {
        let activeLayerIndex = state.layerSidebar.activeLayerIndex
        guard let layer = state.layerSidebar.layer(withIndex: activeLayerIndex) else {
            return .none
        }
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            layerWorkflowService.setLayerVisibility(activeLayerIndex, visible: !layer.visible)
        }
    }

    func handleSelectAdjacentLayer(
        state: inout State,
        direction: Int
    ) -> Effect<Action> {
        guard let currentPosition = state.layerSidebar.layers.firstIndex(where: { $0.index == state.layerSidebar.activeLayerIndex }) else {
            return .none
        }
        let targetPosition = currentPosition + direction
        guard state.layerSidebar.layers.indices.contains(targetPosition) else {
            return .none
        }
        let targetIndex = state.layerSidebar.layers[targetPosition].index
        return performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                layerWorkflowService.setActiveLayer(targetIndex)
            },
            onSuccess: { _, state in
                state.canvas.activateLayerForEditing(targetIndex)
            }
        )
    }

    func handleLayerOpacityChange(
        state: inout State,
        index: Int,
        opacity: Double
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection)
        ) {
            layerWorkflowService.setLayerOpacity(index, opacity: opacity)
        }
    }

    func handleLayerLockToggle(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return .none
        }
        return performDocumentMutation(state: &state) {
            layerWorkflowService.setLayerLocked(index, isLocked: !layer.isLocked)
        }
    }

    func handleLayerAlphaLockToggle(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return .none
        }
        return performDocumentMutation(state: &state) {
            layerWorkflowService.setLayerAlphaLocked(index, isAlphaLocked: !layer.isAlphaLocked)
        }
    }

    func handleLayerClippingToggle(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return .none
        }
        guard layer.isClipped || index > 0 else {
            return .none
        }
        return performDocumentMutation(state: &state) {
            layerWorkflowService.setLayerClipped(index, isClipped: !layer.isClipped)
        }
    }

    func handleLayerSelection(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: .currentPresentation,
            mutation: {
                layerWorkflowService.setActiveLayer(index)
            },
            onSuccess: { _, state in
                state.canvas.activateLayerForEditing(index)
            }
        )
    }

    func handleLayerVisibilityToggle(
        state: inout State,
        index: Int
    ) -> Effect<Action> {
        guard let layer = state.layerSidebar.layer(withIndex: index) else {
            return .none
        }
        return performDocumentMutation(
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
    ) -> Effect<Action> {
        performDocumentMutation(
            state: &state,
            contract: .currentPresentation
        ) {
            layerWorkflowService.setFolderExpanded(folderID, isExpanded: isExpanded)
        }
    }

    func handleFolderVisibilityToggle(
        state: inout State,
        folderID: Int
    ) -> Effect<Action> {
        guard let folder = state.layerSidebar.folder(withID: folderID) else {
            return .none
        }
        return performDocumentMutation(state: &state) {
            layerWorkflowService.setFolderVisibility(folderID, visible: !folder.visible)
        }
    }

    func handleFolderRename(
        state: inout State,
        folderID: Int,
        name: String
    ) -> Effect<Action> {
        performDocumentMutation(state: &state) {
            layerWorkflowService.setFolderName(folderID, name: name)
        }
    }

    func handleLayerBlendModeChange(
        state: inout State,
        index: Int,
        blendMode: LayerBlendMode
    ) -> Effect<Action> {
        performDocumentMutation(
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
    ) -> Effect<Action> {
        performDocumentMutation(state: &state) {
            layerWorkflowService.setLayerName(index, name: name)
        }
    }
}
