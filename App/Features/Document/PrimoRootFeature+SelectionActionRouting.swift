import ComposableArchitecture
import Foundation

extension DocumentFeatureRuntimeReducer {
    func routeSelectionEditingAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .document(.editing(.toolSelected(tool))):
            handleToolSelection(
                state: &state,
                tool: tool,
                showsBrushSettingsPopover: false
            )
            return .none

        case let .document(.editing(.toolLongPressed(tool))):
            handleToolSelection(
                state: &state,
                tool: tool,
                showsBrushSettingsPopover: tool == .brush || tool == .erase
            )
            return .none

        case let .document(.editing(.panelCollapseToggled(panel))):
            togglePanelCollapse(for: panel, state: &state)
            return .none

        case .document(.brushPalette(.delegate(.clearSelection))):
            handleClearSelection(state: &state)
            return .none

        case .document(.brushPalette(.delegate(.invertSelection))):
            handleInvertSelection(state: &state)
            return .none

        case let .document(.brushPalette(.delegate(.expandSelection(expansion)))):
            handleAdjustSelection(state: &state, expansion: max(expansion, 1))
            return .none

        case let .document(.brushPalette(.delegate(.contractSelection(contraction)))):
            handleAdjustSelection(state: &state, expansion: -max(contraction, 1))
            return .none

        case let .document(.editing(.featherSelectionRequested(radius))):
            handleFeatherSelection(state: &state, radius: max(radius, 1))
            return .none

        case let .document(.editing(.colorRangeSelectionRequested(request))):
            return handleColorRangeSelectionRequest(state: &state, request: request)

        case .document(.brushPalette(.delegate(.cancelTransform))):
            discardTransformPreview(state: &state)
            return .none

        case .document(.brushPalette(.delegate(.applyTransform))):
            return applyTransform(state: &state)

        case let .document(.brushPalette(.delegate(.applyText(draft)))):
            return handleApplyText(state: &state, draft: draft)

        case .document(.canvas(.delegate(.applyTransform))):
            return .none

        case let .document(.canvas(.delegate(.placeText(point)))):
            handlePlaceText(state: &state, point: point)
            return .none

        case .document(.editing(.createLayerMaskFromSelectionRequested)):
            return handleCreateLayerMask(state: &state)

        case .document(.editing(.clearLayerMaskRequested)):
            return handleClearLayerMask(state: &state)

        case .document(.editing(.applyLayerMaskRequested)):
            return handleApplyLayerMask(state: &state)

        default:
            return nil
        }
    }
}
