import ComposableArchitecture
import Foundation
import PrimoDocumentApplication

struct LayerWorkflowReducer: Reducer {
    typealias State = DocumentFeature.State
    typealias AppliedLayerContentMutation = PrimoDocumentApplication.AppliedLayerContentMutation
    typealias DocumentMutationContract = DocumentFeature.DocumentMutationContract
    typealias DocumentMutationFeedbackMapper = DocumentFeature.DocumentMutationFeedbackMapper
    typealias DocumentNamingPolicy = DocumentFeature.DocumentNamingPolicy
    typealias LayerContentMutationTarget = PrimoDocumentApplication.LayerContentMutationTarget
    typealias LayerContentWorkflowService = PrimoDocumentApplication.DocumentContentService
    typealias LayerMutationFinalization = DocumentFeature.LayerMutationFinalization
    typealias LayerWorkflowService = DocumentFeature.LayerWorkflowService

    @Dependency(\.appLanguageClient) var appLanguageClient
    @Dependency(\.documentGpuOperationGateway) var documentGpuOperationGateway
    @Dependency(\.documentMutationGateway) var documentMutationGateway
    @Dependency(\.documentMutationWorkflowService) var documentMutationWorkflowService
    @Dependency(\.documentQueryGateway) var documentQueryGateway
    @Dependency(\.documentStrokeSessionUseCase) var documentStrokeSessionUseCase
    @Dependency(\.textLayerGateway) var textLayerGateway

    enum Action: Equatable {
        case editing(DocumentFeature.EditingAction)
        case photoImportReceived(name: String?, data: Data)
        case brushPalette(BrushPaletteFeature.Action)
        case layerSidebar(LayerSidebarFeature.Action)
        case delegate(DocumentFeature.Action.Delegate)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .editing(editingAction):
            return reduceEditingAction(editingAction, state: &state)
        case let .photoImportReceived(name, data):
            return handlePhotoImport(state: &state, name: name, data: data)
        case let .layerSidebar(.delegate(.setOpacity(index, opacity))):
            return handleLayerOpacityChange(state: &state, index: index, opacity: opacity)
        case let .layerSidebar(.delegate(.toggleLayerLock(index))):
            return handleLayerLockToggle(state: &state, index: index)
        case let .layerSidebar(.delegate(.toggleAlphaLock(index))):
            return handleLayerAlphaLockToggle(state: &state, index: index)
        case let .layerSidebar(.delegate(.toggleClippingMask(index))):
            return handleLayerClippingToggle(state: &state, index: index)
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
        case let .layerSidebar(.delegate(.mergeDown(index))):
            return handleLayerMergeDown(state: &state, index: index)
        case let .brushPalette(.delegate(.applyText(draft))):
            return handleApplyText(state: &state, draft: draft)
        case .brushPalette(.delegate(.clearActiveLayer)):
            return handleClearActiveLayer(state: &state)
        default:
            return .none
        }
    }

    private func reduceEditingAction(
        _ action: DocumentFeature.EditingAction,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .activeLayerVisibilityToggled:
            return handleActiveLayerVisibilityToggle(state: &state)
        case .selectPreviousLayer:
            return handleSelectAdjacentLayer(state: &state, direction: -1)
        case .selectNextLayer:
            return handleSelectAdjacentLayer(state: &state, direction: 1)
        case .clearActiveLayerButtonTapped:
            return handleClearActiveLayer(state: &state)
        case .createLayerMaskFromSelectionRequested:
            return handleCreateLayerMask(state: &state)
        case .clearLayerMaskRequested:
            return handleClearLayerMask(state: &state)
        case .applyLayerMaskRequested:
            return handleApplyLayerMask(state: &state)
        default:
            return .none
        }
    }
}
