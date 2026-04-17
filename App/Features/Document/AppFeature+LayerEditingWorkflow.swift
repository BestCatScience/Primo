import Foundation

extension AppFeature {
    struct LayerWorkflowService {
        let paintDocumentClient: PaintDocumentClient

        func addLayer(named name: String) {
            paintDocumentClient.addLayer(name)
        }

        func createFolder(
            named name: String,
            afterLayerAt activeLayerIndex: Int
        ) -> Int {
            paintDocumentClient.createFolder(name, activeLayerIndex)
        }

        func deleteFolder(_ folderID: Int) -> Bool {
            paintDocumentClient.deleteFolder(folderID)
        }

        func deleteLayer(_ index: Int) -> Bool {
            paintDocumentClient.deleteLayer(index)
        }

        func duplicateLayer(
            _ index: Int,
            named duplicateName: String
        ) -> Int {
            paintDocumentClient.duplicateLayer(index, duplicateName)
        }

        func moveLayer(
            _ index: Int,
            to destinationIndex: Int
        ) -> Bool {
            paintDocumentClient.moveLayer(index, destinationIndex)
        }

        func assignLayer(
            _ index: Int,
            toFolder folderID: Int
        ) -> Bool {
            paintDocumentClient.assignLayerToFolder(index, folderID)
        }

        func mergeLayerDown(_ index: Int) -> Bool {
            paintDocumentClient.mergeLayerDown(index)
        }

        func setLayerVisibility(
            _ index: Int,
            visible: Bool
        ) {
            paintDocumentClient.setLayerVisibility(index, visible)
        }

        func setActiveLayer(_ index: Int) {
            paintDocumentClient.setActiveLayer(index)
        }

        func setLayerOpacity(
            _ index: Int,
            opacity: Double
        ) {
            paintDocumentClient.setLayerOpacity(index, opacity)
        }

        func setLayerLocked(
            _ index: Int,
            isLocked: Bool
        ) {
            paintDocumentClient.setLayerLocked(index, isLocked)
        }

        func setLayerAlphaLocked(
            _ index: Int,
            isAlphaLocked: Bool
        ) {
            paintDocumentClient.setLayerAlphaLocked(index, isAlphaLocked)
        }

        func setLayerClipped(
            _ index: Int,
            isClipped: Bool
        ) {
            paintDocumentClient.setLayerClipped(index, isClipped)
        }

        func setFolderExpanded(
            _ folderID: Int,
            isExpanded: Bool
        ) {
            paintDocumentClient.setFolderExpanded(folderID, isExpanded)
        }

        func setFolderVisibility(
            _ folderID: Int,
            visible: Bool
        ) {
            paintDocumentClient.setFolderVisibility(folderID, visible)
        }

        func setFolderName(
            _ folderID: Int,
            name: String
        ) {
            paintDocumentClient.setFolderName(folderID, name)
        }

        func setLayerBlendMode(
            _ index: Int,
            blendMode: LayerBlendMode
        ) {
            paintDocumentClient.setLayerBlendMode(index, blendMode)
        }

        func setLayerName(
            _ index: Int,
            name: String
        ) {
            paintDocumentClient.setLayerName(index, name)
        }

        func replaceLayerPixels(
            _ index: Int,
            pixelData: Data
        ) {
            paintDocumentClient.replaceLayerPixels(index, pixelData)
        }

        func setTextLayer(
            _ index: Int,
            textLayer: TextLayerData
        ) -> Bool {
            paintDocumentClient.setTextLayer(index, textLayer)
        }

        func clearLayer(_ index: Int) {
            paintDocumentClient.clearLayer(index)
        }

        func replaceLayerMask(
            _ index: Int,
            maskData: Data
        ) -> Bool {
            paintDocumentClient.replaceLayerMask(index, maskData)
        }

        func clearLayerMask(_ index: Int) -> Bool {
            paintDocumentClient.clearLayerMask(index)
        }

        func applyLayerMask(_ index: Int) -> Bool {
            paintDocumentClient.applyLayerMask(index)
        }
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
            applyCurrentDocumentPresentation(state: &state)
        } else {
            applyDirtyPresentation(state: &state)
        }
    }
}
