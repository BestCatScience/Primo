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
            case .invalidLayerIndex:
                return .layerUnavailable
            case .invalidFolderID:
                return .folderUnavailable
            case .layerLocked:
                return .layerEditLocked
            case .alphaLocked:
                return .layerAlphaEditLocked
            case .invalidOpacity:
                return .invalidLayerOpacity
            case .emptyInput:
                return .emptyDocumentMutationInput
            case let .bridgeMutationFailed(message):
                return .documentMutationBridgeFailed(message)
            case .incompatibleLayerType:
                return .unsupportedLayerType
            case let .transactionFailure(primary, rollback):
                return .documentMutationTransactionFailed(primary, rollback)
            }
        }
    }

    struct LayerWorkflowService {
        let documentLayerClient: DocumentLayerClient

        func addLayer(named name: String) -> DocumentIndexedMutationResult {
            documentLayerClient.addLayer(name)
        }

        func createFolder(
            named name: String,
            afterLayerAt activeLayerIndex: Int
        ) -> DocumentIndexedMutationResult {
            documentLayerClient.createFolder(name, activeLayerIndex)
        }

        func deleteFolder(_ folderID: Int) -> DocumentMutationResult {
            documentLayerClient.deleteFolder(folderID)
        }

        func deleteLayer(_ index: Int) -> DocumentMutationResult {
            documentLayerClient.deleteLayer(index)
        }

        func duplicateLayer(
            _ index: Int,
            named duplicateName: String
        ) -> DocumentIndexedMutationResult {
            documentLayerClient.duplicateLayer(index, duplicateName)
        }

        func moveLayer(
            _ index: Int,
            to destinationIndex: Int
        ) -> DocumentMutationResult {
            documentLayerClient.moveLayer(index, destinationIndex)
        }

        func assignLayer(
            _ index: Int,
            toFolder folderID: Int
        ) -> DocumentMutationResult {
            documentLayerClient.assignLayerToFolder(index, folderID)
        }

        func mergeLayerDown(_ index: Int) -> DocumentMutationResult {
            documentLayerClient.mergeLayerDown(index)
        }

        func setLayerVisibility(
            _ index: Int,
            visible: Bool
        ) -> DocumentMutationResult {
            documentLayerClient.setLayerVisibility(index, visible)
        }

        func setActiveLayer(_ index: Int) -> DocumentMutationResult {
            documentLayerClient.setActiveLayer(index)
        }

        func setLayerOpacity(
            _ index: Int,
            opacity: Double
        ) -> DocumentMutationResult {
            documentLayerClient.setLayerOpacity(index, opacity)
        }

        func setLayerLocked(
            _ index: Int,
            isLocked: Bool
        ) -> DocumentMutationResult {
            documentLayerClient.setLayerLocked(index, isLocked)
        }

        func setLayerAlphaLocked(
            _ index: Int,
            isAlphaLocked: Bool
        ) -> DocumentMutationResult {
            documentLayerClient.setLayerAlphaLocked(index, isAlphaLocked)
        }

        func setLayerClipped(
            _ index: Int,
            isClipped: Bool
        ) -> DocumentMutationResult {
            documentLayerClient.setLayerClipped(index, isClipped)
        }

        func setFolderExpanded(
            _ folderID: Int,
            isExpanded: Bool
        ) -> DocumentMutationResult {
            documentLayerClient.setFolderExpanded(folderID, isExpanded)
        }

        func setFolderVisibility(
            _ folderID: Int,
            visible: Bool
        ) -> DocumentMutationResult {
            documentLayerClient.setFolderVisibility(folderID, visible)
        }

        func setFolderName(
            _ folderID: Int,
            name: String
        ) -> DocumentMutationResult {
            documentLayerClient.setFolderName(folderID, name)
        }

        func setLayerBlendMode(
            _ index: Int,
            blendMode: LayerBlendMode
        ) -> DocumentMutationResult {
            documentLayerClient.setLayerBlendMode(index, blendMode)
        }

        func setLayerName(
            _ index: Int,
            name: String
        ) -> DocumentMutationResult {
            documentLayerClient.setLayerName(index, name)
        }

        func replaceLayerPixels(
            _ index: Int,
            pixelData: Data
        ) -> DocumentMutationResult {
            documentLayerClient.replaceLayerPixels(index, pixelData)
        }

        func setTextLayer(
            _ index: Int,
            textLayer: TextLayerData
        ) -> DocumentMutationResult {
            documentLayerClient.setTextLayer(index, textLayer)
        }

        func clearLayer(_ index: Int) -> DocumentMutationResult {
            documentLayerClient.clearLayer(index)
        }

        func replaceLayerMask(
            _ index: Int,
            maskData: Data
        ) -> DocumentMutationResult {
            documentLayerClient.replaceLayerMask(index, maskData)
        }

        func clearLayerMask(_ index: Int) -> DocumentMutationResult {
            documentLayerClient.clearLayerMask(index)
        }

        func applyLayerMask(_ index: Int) -> DocumentMutationResult {
            documentLayerClient.applyLayerMask(index)
        }
    }

    var layerWorkflowService: LayerWorkflowService {
        LayerWorkflowService(documentLayerClient: DocumentLayerClient(paintDocumentClient: paintDocumentClient))
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
