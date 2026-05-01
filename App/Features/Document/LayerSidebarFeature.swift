import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import SwiftUI

@Reducer
struct LayerSidebarFeature {
    @ObservableState
    struct State: Equatable {
        var layers: [LayerRowModel] = []
        var rows: [LayerSidebarRowModel] = []
        var layerBuffers: [LayerCanvasBuffer] = []
        var activeLayerIndex: Int = 0
        var paperColor: Color = .white
        var transparentPaper = false
        var showsPaperEditor = false

        var nextLayerOrdinal: Int {
            layers.count + 1
        }

        func layer(withIndex index: Int) -> LayerRowModel? {
            layers.first(where: { $0.index == index })
        }

        func folder(withID folderID: Int) -> LayerFolderModel? {
            rows.compactMap { row -> LayerFolderModel? in
                if case let .folder(folder) = row, folder.id == folderID {
                    return folder
                }
                return nil
            }.first
        }

        func numberedLayerName(prefix: String) -> String {
            "\(prefix) \(nextLayerOrdinal)"
        }

        mutating func activateLayer(_ index: Int) {
            activeLayerIndex = index
        }

        mutating func syncPaper(
            color: Color,
            isTransparent: Bool
        ) {
            paperColor = color
            transparentPaper = isTransparent
        }

        mutating func applyPresentation(
            layers: [LayerRowModel],
            rows: [LayerSidebarRowModel],
            layerBuffers: [LayerCanvasBuffer],
            activeLayerIndex: Int,
            paperColor: Color,
            transparentPaper: Bool
        ) {
            self.layers = layers
            self.rows = rows
            self.layerBuffers = layerBuffers
            self.activeLayerIndex = activeLayerIndex
            syncPaper(color: paperColor, isTransparent: transparentPaper)
        }

        mutating func presentPaperEditor() {
            showsPaperEditor = true
        }

        mutating func dismissPaperEditor() {
            showsPaperEditor = false
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case addLayerButtonTapped
        case addFolderButtonTapped
        case layerTapped(Int)
        case folderTapped(Int)
        case folderVisibilityButtonTapped(Int)
        case renameFolderCommitted(Int, String)
        case deleteFolderButtonTapped(Int)
        case removeLayerFromFolderButtonTapped(Int)
        case visibilityButtonTapped(Int)
        case layerLockButtonTapped(Int)
        case alphaLockButtonTapped(Int)
        case clippingMaskButtonTapped(Int)
        case mergeDownButtonTapped(Int)
        case duplicateLayerButtonTapped(Int)
        case opacityChanged(Int, Double)
        case blendModeSelected(Int, LayerBlendMode)
        case renameLayerCommitted(Int, String)
        case deleteLayerButtonTapped(Int)
        case moveLayerRequested(Int, Int)
        case moveLayerToFolderRequested(Int, Int)
        case paperRowTapped
        case paperEditorDismissed
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case addLayer
        case addFolder
        case selectLayer(Int)
        case setFolderExpanded(Int, Bool)
        case toggleFolderVisibility(Int)
        case renameFolder(Int, String)
        case deleteFolder(Int)
        case toggleVisibility(Int)
        case toggleLayerLock(Int)
        case toggleAlphaLock(Int)
        case toggleClippingMask(Int)
        case mergeDown(Int)
        case duplicateLayer(Int)
        case setOpacity(Int, Double)
        case setBlendMode(Int, LayerBlendMode)
        case renameLayer(Int, String)
        case deleteLayer(Int)
        case moveLayer(Int, Int)
        case moveLayerToFolder(Int, Int)
        case removeLayerFromFolder(Int)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .addLayerButtonTapped:
                return .send(.delegate(.addLayer))
            case .addFolderButtonTapped:
                return .send(.delegate(.addFolder))
            case let .layerTapped(index):
                state.activateLayer(index)
                return .send(.delegate(.selectLayer(index)))
            case let .folderTapped(folderID):
                guard let folder = state.folder(withID: folderID) else {
                    return .none
                }
                return .send(.delegate(.setFolderExpanded(folderID, !folder.isExpanded)))
            case let .folderVisibilityButtonTapped(folderID):
                return .send(.delegate(.toggleFolderVisibility(folderID)))
            case let .renameFolderCommitted(folderID, name):
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return .none
                }
                return .send(.delegate(.renameFolder(folderID, trimmed)))
            case let .deleteFolderButtonTapped(folderID):
                return .send(.delegate(.deleteFolder(folderID)))
            case let .removeLayerFromFolderButtonTapped(layerIndex):
                return .send(.delegate(.removeLayerFromFolder(layerIndex)))
            case let .visibilityButtonTapped(index):
                return .send(.delegate(.toggleVisibility(index)))
            case let .layerLockButtonTapped(index):
                return .send(.delegate(.toggleLayerLock(index)))
            case let .alphaLockButtonTapped(index):
                return .send(.delegate(.toggleAlphaLock(index)))
            case let .clippingMaskButtonTapped(index):
                return .send(.delegate(.toggleClippingMask(index)))
            case let .mergeDownButtonTapped(index):
                return .send(.delegate(.mergeDown(index)))
            case let .duplicateLayerButtonTapped(index):
                return .send(.delegate(.duplicateLayer(index)))
            case let .opacityChanged(index, opacity):
                return .send(.delegate(.setOpacity(index, opacity)))
            case let .blendModeSelected(index, blendMode):
                return .send(.delegate(.setBlendMode(index, blendMode)))
            case let .renameLayerCommitted(index, name):
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return .none
                }
                return .send(.delegate(.renameLayer(index, trimmed)))
            case let .deleteLayerButtonTapped(index):
                return .send(.delegate(.deleteLayer(index)))
            case let .moveLayerRequested(sourceIndex, destinationIndex):
                guard sourceIndex != destinationIndex else {
                    return .none
                }
                return .send(.delegate(.moveLayer(sourceIndex, destinationIndex)))
            case let .moveLayerToFolderRequested(layerIndex, folderID):
                return .send(.delegate(.moveLayerToFolder(layerIndex, folderID)))
            case .paperRowTapped:
                state.presentPaperEditor()
                return .none
            case .paperEditorDismissed:
                state.dismissPaperEditor()
                return .none
            case .delegate:
                return .none
            }
        }
    }
}
