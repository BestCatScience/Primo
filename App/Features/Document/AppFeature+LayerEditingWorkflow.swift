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
            state.canvas.selection = nil
        }
        if updatesPresentationDirectly {
            state.applyPresentation(paintDocumentClient.presentation())
        } else {
            applyDirtyPresentation(state: &state)
        }
    }
}
