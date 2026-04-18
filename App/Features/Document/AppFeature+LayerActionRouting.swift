import ComposableArchitecture
import Foundation

extension AppFeature {
    func routeLayerEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case .clearActiveLayerButtonTapped, .brushPalette(.delegate(.clearActiveLayer)):
            handleClearActiveLayer(state: &state)
            return .none

        case .activeLayerVisibilityToggled:
            handleActiveLayerVisibilityToggle(state: &state)
            return .none

        case .selectPreviousLayer:
            handleSelectAdjacentLayer(state: &state, direction: -1)
            return .none

        case .selectNextLayer:
            handleSelectAdjacentLayer(state: &state, direction: 1)
            return .none

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
            handleAddLayer(state: &state)
            return .none

        case .layerSidebar(.delegate(.addFolder)):
            handleAddFolder(state: &state)
            return .none

        case let .layerSidebar(.delegate(.deleteFolder(folderID))):
            handleFolderDeletion(state: &state, folderID: folderID)
            return .none

        case let .layerSidebar(.delegate(.deleteLayer(index))):
            handleLayerDeletion(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.duplicateLayer(index))):
            handleLayerDuplication(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.moveLayer(index, destinationIndex))):
            handleLayerMove(state: &state, index: index, destinationIndex: destinationIndex)
            return .none

        case let .layerSidebar(.delegate(.moveLayerToFolder(index, folderID))):
            handleLayerFolderAssignment(state: &state, index: index, folderID: folderID)
            return .none

        case let .layerSidebar(.delegate(.removeLayerFromFolder(index))):
            handleLayerFolderAssignment(state: &state, index: index, folderID: -1)
            return .none

        case let .layerSidebar(.delegate(.setOpacity(index, opacity))):
            handleLayerOpacityChange(state: &state, index: index, opacity: opacity)
            return .none

        case let .layerSidebar(.delegate(.toggleLayerLock(index))):
            handleLayerLockToggle(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.toggleAlphaLock(index))):
            handleLayerAlphaLockToggle(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.toggleClippingMask(index))):
            handleLayerClippingToggle(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.mergeDown(index))):
            handleLayerMergeDown(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.selectLayer(index))):
            handleLayerSelection(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.toggleVisibility(index))):
            handleLayerVisibilityToggle(state: &state, index: index)
            return .none

        case let .layerSidebar(.delegate(.setFolderExpanded(folderID, isExpanded))):
            handleFolderExpandedChange(state: &state, folderID: folderID, isExpanded: isExpanded)
            return .none

        case let .layerSidebar(.delegate(.toggleFolderVisibility(folderID))):
            handleFolderVisibilityToggle(state: &state, folderID: folderID)
            return .none

        case let .layerSidebar(.delegate(.renameFolder(folderID, name))):
            handleFolderRename(state: &state, folderID: folderID, name: name)
            return .none

        case let .layerSidebar(.delegate(.setBlendMode(index, blendMode))):
            handleLayerBlendModeChange(state: &state, index: index, blendMode: blendMode)
            return .none

        case let .layerSidebar(.delegate(.renameLayer(index, name))):
            handleLayerRename(state: &state, index: index, name: name)
            return .none

        case .layerSidebar:
            return .none

        default:
            return nil
        }
    }
}
