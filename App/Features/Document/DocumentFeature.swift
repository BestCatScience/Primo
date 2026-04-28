import CasePaths
import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoWorkspaceApplication

@Reducer
struct DocumentFeature {
    @ObservableState
    struct State: Equatable {
        var brushPalette = BrushPaletteFeature.State()
        var layerSidebar = LayerSidebarFeature.State()
        var canvas = CanvasFeature.State()
        var brushPanel = StudioPanelLayoutState()
        var layerPanel = StudioPanelLayoutState()
    }

    @CasePathable
    enum Action: Equatable {
        case newCanvasRequested(width: Int, height: Int)
        case newCanvasPreparationCompleted(AppFeature.CanvasDimensions)
        case undoRequested
        case redoRequested
        case resizeCanvasRequested(width: Int, height: Int)
        case resizeCanvasExtentRequested(width: Int, height: Int)
        case editing(AppFeature.EditingAction)
        case brushPalette(BrushPaletteFeature.Action)
        case layerSidebar(LayerSidebarFeature.Action)
        case canvas(CanvasFeature.Action)
    }

    var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.brushPalette, action: \.brushPalette) {
                BrushPaletteFeature()
            }

            Scope(state: \.layerSidebar, action: \.layerSidebar) {
                LayerSidebarFeature()
            }

            Scope(state: \.canvas, action: \.canvas) {
                CanvasFeature()
            }
        }
    }
}
