import ComposableArchitecture
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

    struct DocumentMutationFeedbackMapper {
        func feedback(
            for failure: DocumentMutationFailure,
            default defaultFeedback: ApplicationFeedback? = nil
        ) -> ApplicationFeedback? {
            if let defaultFeedback {
                return defaultFeedback
            }
            switch failure {
            case .invalidCanvasSize:
                return .canvasSizeUnsupported
            case .noUndoState:
                return .undoUnavailableWhileDrawing
            case .noRedoState:
                return .redoUnavailableWhileDrawing
            case .invalidLayerIndex,
                 .invalidFolderID,
                 .layerLocked,
                 .alphaLocked,
                 .invalidOpacity,
                 .emptyInput,
                 .bridgeMutationFailed,
                 .incompatibleLayerType:
                return nil
            }
        }
    }

    struct LayerWorkflowService {
        let paintDocumentClient: PaintDocumentClient

        func addLayer(named name: String) -> DocumentIndexedMutationResult {
            paintDocumentClient.addLayer(name)
        }

        func createFolder(
            named name: String,
            afterLayerAt activeLayerIndex: Int
        ) -> DocumentIndexedMutationResult {
            paintDocumentClient.createFolder(name, activeLayerIndex)
        }

        func deleteFolder(_ folderID: Int) -> DocumentMutationResult {
            paintDocumentClient.deleteFolder(folderID)
        }

        func deleteLayer(_ index: Int) -> DocumentMutationResult {
            paintDocumentClient.deleteLayer(index)
        }

        func duplicateLayer(
            _ index: Int,
            named duplicateName: String
        ) -> DocumentIndexedMutationResult {
            paintDocumentClient.duplicateLayer(index, duplicateName)
        }

        func moveLayer(
            _ index: Int,
            to destinationIndex: Int
        ) -> DocumentMutationResult {
            paintDocumentClient.moveLayer(index, destinationIndex)
        }

        func assignLayer(
            _ index: Int,
            toFolder folderID: Int
        ) -> DocumentMutationResult {
            paintDocumentClient.assignLayerToFolder(index, folderID)
        }

        func mergeLayerDown(_ index: Int) -> DocumentMutationResult {
            paintDocumentClient.mergeLayerDown(index)
        }

        func setLayerVisibility(
            _ index: Int,
            visible: Bool
        ) -> DocumentMutationResult {
            paintDocumentClient.setLayerVisibility(index, visible)
        }

        func setActiveLayer(_ index: Int) -> DocumentMutationResult {
            paintDocumentClient.setActiveLayer(index)
        }

        func setLayerOpacity(
            _ index: Int,
            opacity: Double
        ) -> DocumentMutationResult {
            paintDocumentClient.setLayerOpacity(index, opacity)
        }

        func setLayerLocked(
            _ index: Int,
            isLocked: Bool
        ) -> DocumentMutationResult {
            paintDocumentClient.setLayerLocked(index, isLocked)
        }

        func setLayerAlphaLocked(
            _ index: Int,
            isAlphaLocked: Bool
        ) -> DocumentMutationResult {
            paintDocumentClient.setLayerAlphaLocked(index, isAlphaLocked)
        }

        func setLayerClipped(
            _ index: Int,
            isClipped: Bool
        ) -> DocumentMutationResult {
            paintDocumentClient.setLayerClipped(index, isClipped)
        }

        func setFolderExpanded(
            _ folderID: Int,
            isExpanded: Bool
        ) -> DocumentMutationResult {
            paintDocumentClient.setFolderExpanded(folderID, isExpanded)
        }

        func setFolderVisibility(
            _ folderID: Int,
            visible: Bool
        ) -> DocumentMutationResult {
            paintDocumentClient.setFolderVisibility(folderID, visible)
        }

        func setFolderName(
            _ folderID: Int,
            name: String
        ) -> DocumentMutationResult {
            paintDocumentClient.setFolderName(folderID, name)
        }

        func setLayerBlendMode(
            _ index: Int,
            blendMode: LayerBlendMode
        ) -> DocumentMutationResult {
            paintDocumentClient.setLayerBlendMode(index, blendMode)
        }

        func setLayerName(
            _ index: Int,
            name: String
        ) -> DocumentMutationResult {
            paintDocumentClient.setLayerName(index, name)
        }

        func replaceLayerPixels(
            _ index: Int,
            pixelData: Data
        ) -> DocumentMutationResult {
            paintDocumentClient.replaceLayerPixels(index, pixelData)
        }

        func setTextLayer(
            _ index: Int,
            textLayer: TextLayerData
        ) -> DocumentMutationResult {
            paintDocumentClient.setTextLayer(index, textLayer)
        }

        func clearLayer(_ index: Int) -> DocumentMutationResult {
            paintDocumentClient.clearLayer(index)
        }

        func replaceLayerMask(
            _ index: Int,
            maskData: Data
        ) -> DocumentMutationResult {
            paintDocumentClient.replaceLayerMask(index, maskData)
        }

        func clearLayerMask(_ index: Int) -> DocumentMutationResult {
            paintDocumentClient.clearLayerMask(index)
        }

        func applyLayerMask(_ index: Int) -> DocumentMutationResult {
            paintDocumentClient.applyLayerMask(index)
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

    var documentMutationFeedbackMapper: DocumentMutationFeedbackMapper {
        DocumentMutationFeedbackMapper()
    }

    @discardableResult
    func completeDocumentMutation(
        state: inout State,
        contract: DocumentMutationContract = .dirty
    ) -> Effect<Action> {
        documentCanvasMutationCoordinator.apply(
            contract.canvasMutation,
            to: &state
        )
        let effect: Effect<Action>
        switch contract.refresh {
        case .none:
            effect = .none
        case .current:
            applyPresentation(documentPresentationQueryService.presentation(), state: &state)
            effect = .none
        case .dirty:
            effect = applyDirtyPresentation(state: &state)
        }
        documentMutationFeedbackCoordinator.apply(
            contract.successFeedback,
            to: &state
        )
        return effect
    }

    @discardableResult
    func performDocumentMutation<Success>(
        state: inout State,
        contract: DocumentMutationContract = .dirty,
        failureFeedback: ApplicationFeedback? = nil,
        mutation: () -> Result<Success, DocumentMutationFailure>,
        onSuccess: (Success, inout State) -> Void = { _, _ in }
    ) -> Effect<Action> {
        switch mutation() {
        case let .success(success):
            onSuccess(success, &state)
            return completeDocumentMutation(state: &state, contract: contract)
        case let .failure(failure):
            documentMutationFeedbackCoordinator.apply(
                documentMutationFeedbackMapper.feedback(
                    for: failure,
                    default: failureFeedback
                ),
                to: &state
            )
            return .none
        }
    }
}
