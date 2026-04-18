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

    struct DocumentCanvasMutationCoordinator {
        func apply(
            _ mutation: DocumentCanvasMutation,
            to state: inout State
        ) {
            switch mutation {
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
        }
    }

    struct DocumentPresentationRefreshCoordinator {
        func apply(
            _ refresh: DocumentPresentationRefresh,
            to state: inout State,
            applyCurrentPresentation: (inout State) -> Void,
            applyDirtyPresentation: (inout State) -> Void
        ) {
            switch refresh {
            case .none:
                break
            case .current:
                applyCurrentPresentation(&state)
            case .dirty:
                applyDirtyPresentation(&state)
            }
        }
    }

    struct DocumentMutationFeedbackCoordinator {
        func apply(
            _ feedback: ApplicationFeedback?,
            to state: inout State
        ) {
            guard let feedback else { return }
            state.application.presentFeedback(feedback)
        }
    }

    struct LayerWorkflowService {
        let paintDocumentClient: PaintDocumentClient

        @discardableResult
        func addLayer(named name: String) -> Int {
            switch paintDocumentClient.addLayer(name) {
            case let .success(index):
                return index
            case .failure:
                return -1
            }
        }

        func createFolder(
            named name: String,
            afterLayerAt activeLayerIndex: Int
        ) -> Int {
            switch paintDocumentClient.createFolder(name, activeLayerIndex) {
            case let .success(folderID):
                return folderID
            case .failure:
                return -1
            }
        }

        func deleteFolder(_ folderID: Int) -> Bool {
            if case .success = paintDocumentClient.deleteFolder(folderID) {
                return true
            }
            return false
        }

        func deleteLayer(_ index: Int) -> Bool {
            if case .success = paintDocumentClient.deleteLayer(index) {
                return true
            }
            return false
        }

        func duplicateLayer(
            _ index: Int,
            named duplicateName: String
        ) -> Int {
            switch paintDocumentClient.duplicateLayer(index, duplicateName) {
            case let .success(duplicatedIndex):
                return duplicatedIndex
            case .failure:
                return -1
            }
        }

        func moveLayer(
            _ index: Int,
            to destinationIndex: Int
        ) -> Bool {
            if case .success = paintDocumentClient.moveLayer(index, destinationIndex) {
                return true
            }
            return false
        }

        func assignLayer(
            _ index: Int,
            toFolder folderID: Int
        ) -> Bool {
            if case .success = paintDocumentClient.assignLayerToFolder(index, folderID) {
                return true
            }
            return false
        }

        func mergeLayerDown(_ index: Int) -> Bool {
            if case .success = paintDocumentClient.mergeLayerDown(index) {
                return true
            }
            return false
        }

        func setLayerVisibility(
            _ index: Int,
            visible: Bool
        ) -> Bool {
            if case .success = paintDocumentClient.setLayerVisibility(index, visible) {
                return true
            }
            return false
        }

        func setActiveLayer(_ index: Int) -> Bool {
            if case .success = paintDocumentClient.setActiveLayer(index) {
                return true
            }
            return false
        }

        func setLayerOpacity(
            _ index: Int,
            opacity: Double
        ) -> Bool {
            if case .success = paintDocumentClient.setLayerOpacity(index, opacity) {
                return true
            }
            return false
        }

        func setLayerLocked(
            _ index: Int,
            isLocked: Bool
        ) -> Bool {
            if case .success = paintDocumentClient.setLayerLocked(index, isLocked) {
                return true
            }
            return false
        }

        func setLayerAlphaLocked(
            _ index: Int,
            isAlphaLocked: Bool
        ) -> Bool {
            if case .success = paintDocumentClient.setLayerAlphaLocked(index, isAlphaLocked) {
                return true
            }
            return false
        }

        func setLayerClipped(
            _ index: Int,
            isClipped: Bool
        ) -> Bool {
            if case .success = paintDocumentClient.setLayerClipped(index, isClipped) {
                return true
            }
            return false
        }

        func setFolderExpanded(
            _ folderID: Int,
            isExpanded: Bool
        ) -> Bool {
            if case .success = paintDocumentClient.setFolderExpanded(folderID, isExpanded) {
                return true
            }
            return false
        }

        func setFolderVisibility(
            _ folderID: Int,
            visible: Bool
        ) -> Bool {
            if case .success = paintDocumentClient.setFolderVisibility(folderID, visible) {
                return true
            }
            return false
        }

        func setFolderName(
            _ folderID: Int,
            name: String
        ) -> Bool {
            if case .success = paintDocumentClient.setFolderName(folderID, name) {
                return true
            }
            return false
        }

        func setLayerBlendMode(
            _ index: Int,
            blendMode: LayerBlendMode
        ) -> Bool {
            if case .success = paintDocumentClient.setLayerBlendMode(index, blendMode) {
                return true
            }
            return false
        }

        func setLayerName(
            _ index: Int,
            name: String
        ) -> Bool {
            if case .success = paintDocumentClient.setLayerName(index, name) {
                return true
            }
            return false
        }

        func replaceLayerPixels(
            _ index: Int,
            pixelData: Data
        ) -> Bool {
            if case .success = paintDocumentClient.replaceLayerPixels(index, pixelData) {
                return true
            }
            return false
        }

        func setTextLayer(
            _ index: Int,
            textLayer: TextLayerData
        ) -> Bool {
            if case .success = paintDocumentClient.setTextLayer(index, textLayer) {
                return true
            }
            return false
        }

        func clearLayer(_ index: Int) -> Bool {
            if case .success = paintDocumentClient.clearLayer(index) {
                return true
            }
            return false
        }

        func replaceLayerMask(
            _ index: Int,
            maskData: Data
        ) -> Bool {
            if case .success = paintDocumentClient.replaceLayerMask(index, maskData) {
                return true
            }
            return false
        }

        func clearLayerMask(_ index: Int) -> Bool {
            if case .success = paintDocumentClient.clearLayerMask(index) {
                return true
            }
            return false
        }

        func applyLayerMask(_ index: Int) -> Bool {
            if case .success = paintDocumentClient.applyLayerMask(index) {
                return true
            }
            return false
        }
    }

    var layerWorkflowService: LayerWorkflowService {
        LayerWorkflowService(paintDocumentClient: paintDocumentClient)
    }

    var documentCanvasMutationCoordinator: DocumentCanvasMutationCoordinator {
        DocumentCanvasMutationCoordinator()
    }

    var documentPresentationRefreshCoordinator: DocumentPresentationRefreshCoordinator {
        DocumentPresentationRefreshCoordinator()
    }

    var documentMutationFeedbackCoordinator: DocumentMutationFeedbackCoordinator {
        DocumentMutationFeedbackCoordinator()
    }

    func completeDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty
    ) {
        documentCanvasMutationCoordinator.apply(
            contract.canvasMutation,
            to: &state
        )
        documentPresentationRefreshCoordinator.apply(
            contract.refresh,
            to: &state,
            applyCurrentPresentation: { state in
                applyPresentation(documentPresentationService.presentation(), state: &state)
            },
            applyDirtyPresentation: { state in
                applyDirtyPresentation(state: &state)
            }
        )
        documentMutationFeedbackCoordinator.apply(
            contract.successFeedback,
            to: &state
        )
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
