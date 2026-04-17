import Foundation

extension AppFeature {
    enum DocumentPresentationRefresh {
        case none
        case current
        case dirty
    }

    struct LayerMutationFinalization {
        let index: Int
        var incrementsRevision = false
        var clearsSelection = true
    }

    struct DocumentMutationContract {
        var clearsSelection: Bool
        var finalizedLayerMutation: LayerMutationFinalization?
        var refresh: DocumentPresentationRefresh
        var successFeedback: ApplicationFeedback?

        init(
            clearsSelection: Bool = false,
            finalizedLayerMutation: LayerMutationFinalization? = nil,
            refresh: DocumentPresentationRefresh = .dirty,
            successFeedback: ApplicationFeedback? = nil
        ) {
            self.clearsSelection = clearsSelection
            self.finalizedLayerMutation = finalizedLayerMutation
            self.refresh = refresh
            self.successFeedback = successFeedback
        }

        static let dirty = DocumentMutationContract()
        static let currentPresentation = DocumentMutationContract(refresh: .current)
    }

    struct LayerWorkflowService {
        let paintDocumentClient: PaintDocumentClient

        @discardableResult
        func addLayer(named name: String) -> Int {
            paintDocumentClient.addLayer(name)
            return paintDocumentClient.presentation().activeLayerIndex
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

        func clearLayer(_ index: Int) -> Bool {
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

    func completeDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty
    ) {
        if let finalization = contract.finalizedLayerMutation {
            state.canvas.finalizeLayerMutation(
                at: finalization.index,
                incrementsRevision: finalization.incrementsRevision,
                clearsSelection: finalization.clearsSelection
            )
        } else if contract.clearsSelection {
            state.canvas.clearSelection()
        }

        switch contract.refresh {
        case .none:
            break
        case .current:
            applyCurrentDocumentPresentation(state: &state)
        case .dirty:
            applyDirtyPresentation(state: &state)
        }

        if let successFeedback = contract.successFeedback {
            state.application.presentFeedback(successFeedback)
        }
    }

    @discardableResult
    func handleDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty,
        mutation: () -> Bool
    ) -> Bool {
        guard mutation() else { return false }
        completeDocumentMutation(state: &state, contract: contract)
        return true
    }

    func handleLayerMutation(
        state: inout State,
        clearsSelection: Bool = false,
        updatesPresentationDirectly: Bool = false,
        mutation: () -> Bool
    ) {
        _ = handleDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                clearsSelection: clearsSelection,
                refresh: updatesPresentationDirectly ? .current : .dirty
            ),
            mutation: mutation
        )
    }
}
