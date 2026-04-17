import Foundation

extension AppFeature {
    enum DocumentCanvasMutation {
        case none
        case clearSelection
        case finalizeLayer(LayerMutationFinalization)
        case completeTransform(layerIndex: Int, selection: CanvasSelection?)
        case resetTransientEditingState
        case resetTransformPreview
    }

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
        var canvasMutation: DocumentCanvasMutation
        var refresh: DocumentPresentationRefresh
        var successFeedback: ApplicationFeedback?

        init(
            canvasMutation: DocumentCanvasMutation = .none,
            refresh: DocumentPresentationRefresh = .dirty,
            successFeedback: ApplicationFeedback? = nil
        ) {
            self.canvasMutation = canvasMutation
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
        ) -> Bool {
            paintDocumentClient.setLayerVisibility(index, visible)
        }

        func setActiveLayer(_ index: Int) -> Bool {
            paintDocumentClient.setActiveLayer(index)
        }

        func setLayerOpacity(
            _ index: Int,
            opacity: Double
        ) -> Bool {
            paintDocumentClient.setLayerOpacity(index, opacity)
        }

        func setLayerLocked(
            _ index: Int,
            isLocked: Bool
        ) -> Bool {
            paintDocumentClient.setLayerLocked(index, isLocked)
        }

        func setLayerAlphaLocked(
            _ index: Int,
            isAlphaLocked: Bool
        ) -> Bool {
            paintDocumentClient.setLayerAlphaLocked(index, isAlphaLocked)
        }

        func setLayerClipped(
            _ index: Int,
            isClipped: Bool
        ) -> Bool {
            paintDocumentClient.setLayerClipped(index, isClipped)
        }

        func setFolderExpanded(
            _ folderID: Int,
            isExpanded: Bool
        ) -> Bool {
            paintDocumentClient.setFolderExpanded(folderID, isExpanded)
        }

        func setFolderVisibility(
            _ folderID: Int,
            visible: Bool
        ) -> Bool {
            paintDocumentClient.setFolderVisibility(folderID, visible)
        }

        func setFolderName(
            _ folderID: Int,
            name: String
        ) -> Bool {
            paintDocumentClient.setFolderName(folderID, name)
        }

        func setLayerBlendMode(
            _ index: Int,
            blendMode: LayerBlendMode
        ) -> Bool {
            paintDocumentClient.setLayerBlendMode(index, blendMode)
        }

        func setLayerName(
            _ index: Int,
            name: String
        ) -> Bool {
            paintDocumentClient.setLayerName(index, name)
        }

        func replaceLayerPixels(
            _ index: Int,
            pixelData: Data
        ) -> Bool {
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
        switch contract.canvasMutation {
        case .none:
            break
        case .clearSelection:
            state.canvas.clearSelection()
        case let .finalizeLayer(finalization):
            state.canvas.finalizeLayerMutation(
                at: finalization.index,
                incrementsRevision: finalization.incrementsRevision,
                clearsSelection: finalization.clearsSelection
            )
        case let .completeTransform(layerIndex, selection):
            state.canvas.completeTransformMutation(
                at: layerIndex,
                selection: selection
            )
        case .resetTransientEditingState:
            state.canvas.resetTransientEditingState()
        case .resetTransformPreview:
            state.canvas.resetTransformPreview()
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

    @discardableResult
    func handleDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty,
        failureFeedback: ApplicationFeedback,
        mutation: () -> Bool
    ) -> Bool {
        guard handleDocumentMutation(
            state: &state,
            contract: contract,
            mutation: mutation
        ) else {
            state.application.presentFeedback(failureFeedback)
            return false
        }
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
                canvasMutation: clearsSelection ? .clearSelection : .none,
                refresh: updatesPresentationDirectly ? .current : .dirty
            ),
            mutation: mutation
        )
    }
}
