import ComposableArchitecture
import Foundation

extension AppFeature {
    func routeSelectionEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .toolSelected(tool):
            handleToolSelection(
                state: &state,
                tool: tool,
                showsBrushSettingsPopover: false
            )
            return .none

        case let .toolLongPressed(tool):
            handleToolSelection(
                state: &state,
                tool: tool,
                showsBrushSettingsPopover: tool == .brush || tool == .erase
            )
            return .none

        case let .panelCollapseToggled(panel):
            togglePanelCollapse(for: panel, state: &state)
            return .none

        case .brushPalette(.delegate(.clearSelection)):
            handleClearSelection(state: &state)
            return .none

        case .brushPalette(.delegate(.invertSelection)):
            handleInvertSelection(state: &state)
            return .none

        case let .brushPalette(.delegate(.expandSelection(expansion))):
            handleAdjustSelection(state: &state, expansion: max(expansion, 1))
            return .none

        case let .brushPalette(.delegate(.contractSelection(contraction))):
            handleAdjustSelection(state: &state, expansion: -max(contraction, 1))
            return .none

        case let .featherSelectionRequested(radius):
            handleFeatherSelection(state: &state, radius: max(radius, 1))
            return .none

        case let .colorRangeSelectionRequested(request):
            return handleColorRangeSelectionRequest(state: &state, request: request)

        case .brushPalette(.delegate(.cancelTransform)):
            discardTransformPreview(state: &state)
            return .none

        case .brushPalette(.delegate(.applyTransform)):
            return applyTransform(state: &state)

        case let .brushPalette(.delegate(.applyText(draft))):
            return handleApplyText(state: &state, draft: draft)

        case .canvas(.delegate(.applyTransform)):
            return .none

        case let .canvas(.delegate(.placeText(point))):
            handlePlaceText(state: &state, point: point)
            return .none

        case .createLayerMaskFromSelectionRequested:
            return handleCreateLayerMask(state: &state)

        case .clearLayerMaskRequested:
            return handleClearLayerMask(state: &state)

        case .applyLayerMaskRequested:
            return handleApplyLayerMask(state: &state)

        default:
            return nil
        }
    }
}
