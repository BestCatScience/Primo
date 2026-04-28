import CasePaths
import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoWorkspaceApplication

@Reducer
struct DocumentFeature {
    typealias CanvasDimensions = DocumentFeatureRuntimeReducer.CanvasDimensions

    @ObservableState
    struct State: Equatable {
        var brushPalette = BrushPaletteFeature.State()
        var layerSidebar = LayerSidebarFeature.State()
        var canvas = CanvasFeature.State()
        var brushPanel = StudioPanelLayoutState()
        var layerPanel = StudioPanelLayoutState()
    }

    enum EditingAction: Equatable {
        case featherSelectionRequested(Int)
        case colorRangeSelectionRequested(ColorRangeSelectionRequest)
        case toolSelected(StudioToolKind)
        case toolLongPressed(StudioToolKind)
        case clearActiveLayerButtonTapped
        case createLayerMaskFromSelectionRequested
        case clearLayerMaskRequested
        case applyLayerMaskRequested
        case gradientMapSelected(GradientMapPreset)
        case gradientMapPreviewChanged(GradientMapSettings?)
        case gradientMapApplied(GradientMapSettings)
        case hueSaturationBrightnessPreviewChanged(HueSaturationBrightnessSettings?)
        case hueSaturationBrightnessApplied(HueSaturationBrightnessSettings)
        case brightnessContrastPreviewChanged(BrightnessContrastSettings?)
        case brightnessContrastApplied(BrightnessContrastSettings)
        case levelsPreviewChanged(LevelsAdjustmentSettings?)
        case levelsApplied(LevelsAdjustmentSettings)
        case toneCurvePreviewChanged(ToneCurveSettings?)
        case toneCurveApplied(ToneCurveSettings)
        case colorBalancePreviewChanged(ColorBalanceSettings?)
        case colorBalanceApplied(ColorBalanceSettings)
        case thresholdPreviewChanged(ThresholdSettings?)
        case thresholdApplied(ThresholdSettings)
        case posterizePreviewChanged(PosterizeSettings?)
        case posterizeApplied(PosterizeSettings)
        case luminanceToAlphaRequested
        case activeLayerVisibilityToggled
        case selectPreviousLayer
        case selectNextLayer
        case panelCollapseToggled(StudioPanelKind)
    }

    @CasePathable
    enum Action: Equatable {
        case newCanvasRequested(width: Int, height: Int)
        case newCanvasPreparationCompleted(CanvasDimensions)
        case undoRequested
        case redoRequested
        case resizeCanvasRequested(width: Int, height: Int)
        case resizeCanvasExtentRequested(width: Int, height: Int)
        case editing(EditingAction)
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
