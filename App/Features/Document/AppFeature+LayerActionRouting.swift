import ComposableArchitecture
import Foundation

extension AppIntegrationFeature {
    func routeLayerEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case .document(.editing(.clearActiveLayerButtonTapped)),
             .document(.brushPalette(.delegate(.clearActiveLayer))):
            return handleClearActiveLayer(state: &state)

        case .document(.editing(.activeLayerVisibilityToggled)):
            return handleActiveLayerVisibilityToggle(state: &state)

        case .document(.editing(.selectPreviousLayer)):
            return handleSelectAdjacentLayer(state: &state, direction: -1)

        case .document(.editing(.selectNextLayer)):
            return handleSelectAdjacentLayer(state: &state, direction: 1)

        case .document(.brushPalette(.binding(\.paper.color))),
             .document(.brushPalette(.binding(\.paper.isTransparent))):
            return handleBrushPalettePaperBindingChanged(state: &state)

        case .document(.brushPalette):
            handleBrushPaletteStateRefresh(state: &state)
            return .none

        case .document(.layerSidebar(.binding(\.paperColor))):
            return handlePaperColorBindingChanged(state: &state)

        case .document(.layerSidebar(.binding(\.transparentPaper))):
            return handleTransparentPaperBindingChanged(state: &state)

        case .document(.layerSidebar(.delegate(.addLayer))):
            return handleAddLayer(state: &state)

        case .document(.layerSidebar(.delegate(.addFolder))):
            return handleAddFolder(state: &state)

        case let .document(.layerSidebar(.delegate(.deleteFolder(folderID)))):
            return handleFolderDeletion(state: &state, folderID: folderID)

        case let .document(.layerSidebar(.delegate(.deleteLayer(index)))):
            return handleLayerDeletion(state: &state, index: index)

        case let .document(.layerSidebar(.delegate(.duplicateLayer(index)))):
            return handleLayerDuplication(state: &state, index: index)

        case let .document(.layerSidebar(.delegate(.moveLayer(index, destinationIndex)))):
            return handleLayerMove(state: &state, index: index, destinationIndex: destinationIndex)

        case let .document(.layerSidebar(.delegate(.moveLayerToFolder(index, folderID)))):
            return handleLayerFolderAssignment(state: &state, index: index, folderID: folderID)

        case let .document(.layerSidebar(.delegate(.removeLayerFromFolder(index)))):
            return handleLayerFolderAssignment(state: &state, index: index, folderID: -1)

        case let .document(.layerSidebar(.delegate(.setOpacity(index, opacity)))):
            return handleLayerOpacityChange(state: &state, index: index, opacity: opacity)

        case let .document(.layerSidebar(.delegate(.toggleLayerLock(index)))):
            return handleLayerLockToggle(state: &state, index: index)

        case let .document(.layerSidebar(.delegate(.toggleAlphaLock(index)))):
            return handleLayerAlphaLockToggle(state: &state, index: index)

        case let .document(.layerSidebar(.delegate(.toggleClippingMask(index)))):
            return handleLayerClippingToggle(state: &state, index: index)

        case let .document(.layerSidebar(.delegate(.mergeDown(index)))):
            return handleLayerMergeDown(state: &state, index: index)

        case let .document(.layerSidebar(.delegate(.selectLayer(index)))):
            return handleLayerSelection(state: &state, index: index)

        case let .document(.layerSidebar(.delegate(.toggleVisibility(index)))):
            return handleLayerVisibilityToggle(state: &state, index: index)

        case let .document(.layerSidebar(.delegate(.setFolderExpanded(folderID, isExpanded)))):
            return handleFolderExpandedChange(state: &state, folderID: folderID, isExpanded: isExpanded)

        case let .document(.layerSidebar(.delegate(.toggleFolderVisibility(folderID)))):
            return handleFolderVisibilityToggle(state: &state, folderID: folderID)

        case let .document(.layerSidebar(.delegate(.renameFolder(folderID, name)))):
            return handleFolderRename(state: &state, folderID: folderID, name: name)

        case let .document(.layerSidebar(.delegate(.setBlendMode(index, blendMode)))):
            return handleLayerBlendModeChange(state: &state, index: index, blendMode: blendMode)

        case let .document(.layerSidebar(.delegate(.renameLayer(index, name)))):
            return handleLayerRename(state: &state, index: index, name: name)

        case .document(.layerSidebar):
            return .none

        default:
            return nil
        }
    }
}
