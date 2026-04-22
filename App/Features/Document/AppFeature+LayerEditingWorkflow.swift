import ComposableArchitecture
import Foundation
import PrimoBrushDomain
import PrimoDocumentContracts
import PrimoDocumentDomain

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
        var updatesWorkspaceArtifacts: Bool

        init(
            canvasMutation: DocumentCanvasMutation = .none,
            refresh: DocumentPresentationRefresh = .dirty,
            successFeedback: ApplicationFeedback? = nil,
            updatesWorkspaceArtifacts: Bool = true
        ) {
            self.canvasMutation = canvasMutation
            self.refresh = refresh
            self.successFeedback = successFeedback
            self.updatesWorkspaceArtifacts = updatesWorkspaceArtifacts
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
        let documentEditingGateway: DocumentEditingGateway
        let documentLayerEffectsGateway: DocumentLayerEffectsGateway
        let documentMutationGateway: DocumentMutationGateway
        let textLayerGateway: TextLayerGateway

        func addLayer(named name: String) -> DocumentIndexedMutationResult {
            executeIndexed(.structure(.addLayer(name: name)))
        }

        func createFolder(
            named name: String,
            afterLayerAt activeLayerIndex: Int
        ) -> DocumentIndexedMutationResult {
            executeIndexed(.structure(.createFolder(name: name, anchorLayerIndex: activeLayerIndex)))
        }

        func deleteFolder(_ folderID: Int) -> DocumentMutationResult {
            execute(.structure(.deleteFolder(folderID: folderID)))
        }

        func deleteLayer(_ index: Int) -> DocumentMutationResult {
            execute(.structure(.deleteLayer(index: index)))
        }

        func duplicateLayer(
            _ index: Int,
            named duplicateName: String
        ) -> DocumentIndexedMutationResult {
            executeIndexed(.structure(.duplicateLayer(index: index, name: duplicateName)))
        }

        func moveLayer(
            _ index: Int,
            to destinationIndex: Int
        ) -> DocumentMutationResult {
            execute(.structure(.moveLayer(index: index, destinationIndex: destinationIndex)))
        }

        func assignLayer(
            _ index: Int,
            toFolder folderID: Int
        ) -> DocumentMutationResult {
            execute(.structure(.assignLayerToFolder(index: index, folderID: folderID)))
        }

        func mergeLayerDown(_ index: Int) -> DocumentMutationResult {
            documentLayerEffectsGateway.mergeLayerDown(index)
        }

        func setLayerVisibility(
            _ index: Int,
            visible: Bool
        ) -> DocumentMutationResult {
            execute(.attribute(.setLayerVisibility(index: index, isVisible: visible)))
        }

        func setActiveLayer(_ index: Int) -> DocumentMutationResult {
            execute(.attribute(.setActiveLayer(index: index)))
        }

        func setLayerOpacity(
            _ index: Int,
            opacity: Double
        ) -> DocumentMutationResult {
            execute(.attribute(.setLayerOpacity(index: index, opacity: opacity)))
        }

        func setLayerLocked(
            _ index: Int,
            isLocked: Bool
        ) -> DocumentMutationResult {
            execute(.attribute(.setLayerLocked(index: index, isLocked: isLocked)))
        }

        func setLayerAlphaLocked(
            _ index: Int,
            isAlphaLocked: Bool
        ) -> DocumentMutationResult {
            execute(.attribute(.setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked)))
        }

        func setLayerClipped(
            _ index: Int,
            isClipped: Bool
        ) -> DocumentMutationResult {
            execute(.attribute(.setLayerClipped(index: index, isClipped: isClipped)))
        }

        func setFolderExpanded(
            _ folderID: Int,
            isExpanded: Bool
        ) -> DocumentMutationResult {
            execute(.attribute(.setFolderExpanded(folderID: folderID, isExpanded: isExpanded)))
        }

        func setFolderVisibility(
            _ folderID: Int,
            visible: Bool
        ) -> DocumentMutationResult {
            execute(.attribute(.setFolderVisibility(folderID: folderID, isVisible: visible)))
        }

        func setFolderName(
            _ folderID: Int,
            name: String
        ) -> DocumentMutationResult {
            execute(.attribute(.setFolderName(folderID: folderID, name: name)))
        }

        func setLayerBlendMode(
            _ index: Int,
            blendMode: LayerBlendMode
        ) -> DocumentMutationResult {
            execute(.attribute(.setLayerBlendMode(index: index, blendMode: blendMode)))
        }

        func setLayerName(
            _ index: Int,
            name: String
        ) -> DocumentMutationResult {
            execute(.attribute(.setLayerName(index: index, name: name)))
        }

        func replaceLayerPixels(
            _ index: Int,
            pixelData: Data
        ) -> DocumentMutationResult {
            documentMutationGateway.replaceLayerPixels(index, pixelData)
        }

        func setTextLayer(
            _ index: Int,
            textLayer: TextLayerData
        ) -> DocumentMutationResult {
            textLayerGateway.setTextLayer(index, textLayer)
        }

        func clearLayer(_ index: Int) -> DocumentMutationResult {
            documentMutationGateway.clearLayer(index)
        }

        func replaceLayerMask(
            _ index: Int,
            maskData: Data
        ) -> DocumentMutationResult {
            documentMutationGateway.replaceLayerMask(index, maskData)
        }

        func clearLayerMask(_ index: Int) -> DocumentMutationResult {
            documentMutationGateway.clearLayerMask(index)
        }

        func applyLayerMask(_ index: Int) -> DocumentMutationResult {
            documentMutationGateway.applyLayerMask(index)
        }

        private func execute(_ request: DocumentEditingRequest) -> DocumentMutationResult {
            documentEditingGateway.execute(request).map { _ in () }
        }

        private func executeIndexed(_ request: DocumentEditingRequest) -> DocumentIndexedMutationResult {
            documentEditingGateway.execute(request).flatMap { result in
                guard case let .structure(plan) = result, let index = plan.resultingIndex else {
                    return .failure(.bridgeMutationFailed("documentEditingGateway"))
                }
                return .success(index)
            }
        }
    }

    var layerWorkflowService: LayerWorkflowService {
        LayerWorkflowService(
            documentEditingGateway: documentEditingGateway,
            documentLayerEffectsGateway: documentLayerEffectsGateway,
            documentMutationGateway: documentMutationGateway,
            textLayerGateway: textLayerGateway
        )
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
            effect = applyDirtyPresentation(
                state: &state,
                updatesWorkspaceArtifacts: contract.updatesWorkspaceArtifacts
            )
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
