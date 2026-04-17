import ComposableArchitecture
import Foundation

extension AppFeature {
    private enum BrushPaletteSyncScope {
        case none
        case interaction
        case paper
    }

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

        case let .brushPalette(brushAction):
            switch brushPaletteSyncScope(for: brushAction) {
            case .paper:
                handleBrushPalettePaperBindingChanged(state: &state)
            case .interaction:
                handleBrushPaletteInteractionRefresh(state: &state)
            case .none:
                break
            }
            return .none

        case .layerSidebar(.binding(\.paperColor)):
            handlePaperColorBindingChanged(state: &state)
            return .none

        case .layerSidebar(.binding(\.transparentPaper)):
            handleTransparentPaperBindingChanged(state: &state)
            return .none

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

    private func brushPaletteSyncScope(for action: BrushPaletteFeature.Action) -> BrushPaletteSyncScope {
        switch action {
        case .binding(\.paper.color),
             .binding(\.paper.isTransparent):
            return .paper

        case .binding(\.brush.radius),
             .binding(\.brush.color),
             .binding(\.brush.secondaryColor),
             .binding(\.brush.selectedColorSlot),
             .binding(\.brush.tipKind),
             .binding(\.brush.sizeSpeedSensitivity),
             .binding(\.brush.opacity),
             .binding(\.brush.hardness),
             .binding(\.brush.roundness),
             .binding(\.brush.roundnessPressureSensitivity),
             .binding(\.brush.roundnessTiltSensitivity),
             .binding(\.brush.angle),
             .binding(\.brush.anglePressureSensitivity),
             .binding(\.brush.angleTiltSensitivity),
             .binding(\.brush.angleMode),
             .binding(\.brush.spacing),
             .binding(\.brush.spacingJitter),
             .binding(\.brush.scatterEnabled),
             .binding(\.brush.scatterMode),
             .binding(\.brush.scatterLateral),
             .binding(\.brush.scatterLinear),
             .binding(\.brush.count),
             .binding(\.brush.countJitter),
             .binding(\.brush.countSizeJitter),
             .binding(\.brush.countOpacityJitter),
             .binding(\.brush.angleJitter),
             .binding(\.brush.roundnessJitter),
             .binding(\.brush.textureMode),
             .binding(\.brush.textureStrength),
             .binding(\.brush.flow),
             .binding(\.brush.flowPressureSensitivity),
             .binding(\.brush.flowJitter),
             .binding(\.brush.velocityInfluence),
             .binding(\.brush.wetness),
             .binding(\.brush.wetnessPressureSensitivity),
             .binding(\.brush.opacityPressureSensitivity),
             .binding(\.brush.colorMixStrength),
             .binding(\.brush.paintLoad),
             .binding(\.brush.loadPressureSensitivity),
             .binding(\.brush.dualEnabled),
             .binding(\.brush.dualTipKind),
             .binding(\.brush.dualScale),
             .binding(\.brush.dualSpacing),
             .binding(\.brush.dualScatter),
             .binding(\.brush.dualAngle),
             .binding(\.brush.dualBlendMode),
             .binding(\.brush.grainScale),
             .binding(\.brush.grainContrast),
             .binding(\.brush.paperScale),
             .binding(\.brush.paperStrength),
             .binding(\.brush.paperThreshold),
             .binding(\.brush.flipX),
             .binding(\.brush.flipY),
             .binding(\.brush.pressureSensitivity),
             .binding(\.brush.stabilization),
             .binding(\.selection.toolMode),
             .binding(\.selection.combineMode),
             .binding(\.selection.thresholdMode),
             .binding(\.selection.opacityTolerance),
             .binding(\.selection.colorTolerance),
             .binding(\.selection.expansion),
             .binding(\.fill.thresholdMode),
             .binding(\.fill.opacityTolerance),
             .binding(\.fill.colorTolerance),
             .binding(\.fill.expansion),
             .binding(\.shape.mode),
             .binding(\.sampling.eyedropperSource),
             .selectPreset,
             .importedPresets,
             .resetCurrentBrushSettingsButtonTapped,
             .deleteSavedPresetButtonTapped,
             .renameSavedPresetButtonTapped:
            return .interaction

        default:
            return .none
        }
    }
}
