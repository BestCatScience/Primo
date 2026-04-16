import Foundation

extension AppFeature {
    struct LayerWorkflowService {
        let paintDocumentClient: PaintDocumentClient
    }

    var layerWorkflowService: LayerWorkflowService {
        LayerWorkflowService(paintDocumentClient: paintDocumentClient)
    }

    func handleLayerMutation(
        state: inout State,
        clearsSelection: Bool = false,
        updatesPresentationDirectly: Bool = false,
        mutation: () -> Bool
    ) {
        guard mutation() else { return }
        if clearsSelection {
            state.canvas.clearSelection()
        }
        if updatesPresentationDirectly {
            applyPresentation(paintDocumentClient.presentation(), state: &state)
        } else {
            applyDirtyPresentation(state: &state)
        }
    }
}
