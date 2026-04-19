import ComposableArchitecture
import Foundation

extension AppFeature {
    func routeLayerEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case .editing(.clearActiveLayerButtonTapped), .brushPalette(.delegate(.clearActiveLayer)):
            return handleClearActiveLayer(state: &state)

        case .editing(.activeLayerVisibilityToggled):
            return handleActiveLayerVisibilityToggle(state: &state)

        case .editing(.selectPreviousLayer):
            return handleSelectAdjacentLayer(state: &state, direction: -1)

        case .editing(.selectNextLayer):
            return handleSelectAdjacentLayer(state: &state, direction: 1)

        case .brushPalette(.binding(\.paper.color)),
             .brushPalette(.binding(\.paper.isTransparent)):
            return handleBrushPalettePaperBindingChanged(state: &state)

        case .brushPalette:
            handleBrushPaletteStateRefresh(state: &state)
            return .none

        case .layerSidebar(.binding(\.paperColor)):
            return handlePaperColorBindingChanged(state: &state)

        case .layerSidebar(.binding(\.transparentPaper)):
            return handleTransparentPaperBindingChanged(state: &state)

        case .layerSidebar(.delegate(.addLayer)):
            return handleAddLayer(state: &state)

        case .layerSidebar(.delegate(.addFolder)):
            return handleAddFolder(state: &state)

        case let .layerSidebar(.delegate(.deleteFolder(folderID))):
            return handleFolderDeletion(state: &state, folderID: folderID)

        case let .layerSidebar(.delegate(.deleteLayer(index))):
            return handleLayerDeletion(state: &state, index: index)

        case let .layerSidebar(.delegate(.duplicateLayer(index))):
            return handleLayerDuplication(state: &state, index: index)

        case let .layerSidebar(.delegate(.moveLayer(index, destinationIndex))):
            return handleLayerMove(state: &state, index: index, destinationIndex: destinationIndex)

        case let .layerSidebar(.delegate(.moveLayerToFolder(index, folderID))):
            return handleLayerFolderAssignment(state: &state, index: index, folderID: folderID)

        case let .layerSidebar(.delegate(.removeLayerFromFolder(index))):
            return handleLayerFolderAssignment(state: &state, index: index, folderID: -1)

        case let .layerSidebar(.delegate(.setOpacity(index, opacity))):
            return handleLayerOpacityChange(state: &state, index: index, opacity: opacity)

        case let .layerSidebar(.delegate(.toggleLayerLock(index))):
            return handleLayerLockToggle(state: &state, index: index)

        case let .layerSidebar(.delegate(.toggleAlphaLock(index))):
            return handleLayerAlphaLockToggle(state: &state, index: index)

        case let .layerSidebar(.delegate(.toggleClippingMask(index))):
            return handleLayerClippingToggle(state: &state, index: index)

        case let .layerSidebar(.delegate(.mergeDown(index))):
            return handleLayerMergeDown(state: &state, index: index)

        case let .layerSidebar(.delegate(.selectLayer(index))):
            return handleLayerSelection(state: &state, index: index)

        case let .layerSidebar(.delegate(.toggleVisibility(index))):
            return handleLayerVisibilityToggle(state: &state, index: index)

        case let .layerSidebar(.delegate(.setFolderExpanded(folderID, isExpanded))):
            return handleFolderExpandedChange(state: &state, folderID: folderID, isExpanded: isExpanded)

        case let .layerSidebar(.delegate(.toggleFolderVisibility(folderID))):
            return handleFolderVisibilityToggle(state: &state, folderID: folderID)

        case let .layerSidebar(.delegate(.renameFolder(folderID, name))):
            return handleFolderRename(state: &state, folderID: folderID, name: name)

        case let .layerSidebar(.delegate(.setBlendMode(index, blendMode))):
            return handleLayerBlendModeChange(state: &state, index: index, blendMode: blendMode)

        case let .layerSidebar(.delegate(.renameLayer(index, name))):
            return handleLayerRename(state: &state, index: index, name: name)

        case .layerSidebar:
            return .none

        default:
            return nil
        }
    }
}
