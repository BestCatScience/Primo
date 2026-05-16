import Foundation
import PrimoDocumentApplication
import PrimoDocumentMutationContracts

extension DocumentFeature {
    static func documentMutationFailureMessage(
        _ failure: DocumentMutationFailure,
        language: AppLanguage
    ) -> String {
        switch failure {
        case .invalidCanvasSize:
            return ApplicationFeature.Feedback.canvasSizeUnsupported.message(for: language)
        case .noUndoState:
            return ApplicationFeature.Feedback.undoUnavailableWhileDrawing.message(for: language)
        case .noRedoState:
            return ApplicationFeature.Feedback.redoUnavailableWhileDrawing.message(for: language)
        case .invalidLayerIndex:
            return ApplicationFeature.Feedback.layerUnavailable.message(for: language)
        case .staleLayerIndex:
            return ApplicationFeature.Feedback.layerUnavailable.message(for: language)
        case .staleLayerAnchor:
            return ApplicationFeature.Feedback.layerUnavailable.message(for: language)
        case .invalidFolderID:
            return ApplicationFeature.Feedback.folderUnavailable.message(for: language)
        case .staleFolderID:
            return ApplicationFeature.Feedback.folderUnavailable.message(for: language)
        case .layerLocked:
            return ApplicationFeature.Feedback.layerEditLocked.message(for: language)
        case .alphaLocked:
            return ApplicationFeature.Feedback.layerAlphaEditLocked.message(for: language)
        case .invalidOpacity:
            return ApplicationFeature.Feedback.invalidLayerOpacity.message(for: language)
        case .emptyInput:
            return ApplicationFeature.Feedback.emptyDocumentMutationInput.message(for: language)
        case .gpu, .unexpectedGatewayResult, .rawAPIUnavailable, .inconsistentComposition, .bridgeMutationFailed, .rollbackFailed:
            return ApplicationFeature.Feedback.documentMutationBridgeFailed(failure.displayMessage).message(for: language)
        case .incompatibleLayerType:
            return ApplicationFeature.Feedback.unsupportedLayerType.message(for: language)
        case .invalidLayerProcessingRequest:
            return ApplicationFeature.Feedback.documentMutationBridgeFailed(nil).message(for: language)
        case let .transactionFailure(primary, rollback):
            return ApplicationFeature.Feedback.documentMutationTransactionFailed(
                primary,
                rollback
            )
            .message(for: language)
        }
    }

    struct DocumentMutationFeedbackMapper {
        func feedback(
            for failure: DocumentMutationFailure,
            default defaultFeedback: ApplicationFeature.Feedback? = nil
        ) -> ApplicationFeature.Feedback? {
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
            case .staleLayerIndex:
                return .layerUnavailable
            case .staleLayerAnchor:
                return .layerUnavailable
            case .invalidFolderID:
                return .folderUnavailable
            case .staleFolderID:
                return .folderUnavailable
            case .layerLocked:
                return .layerEditLocked
            case .alphaLocked:
                return .layerAlphaEditLocked
            case .invalidOpacity:
                return .invalidLayerOpacity
            case .emptyInput:
                return .emptyDocumentMutationInput
            case .gpu, .unexpectedGatewayResult, .rawAPIUnavailable, .inconsistentComposition, .bridgeMutationFailed, .rollbackFailed:
                return .documentMutationBridgeFailed(failure.displayMessage)
            case .incompatibleLayerType:
                return .unsupportedLayerType
            case .invalidLayerProcessingRequest:
                return .documentMutationBridgeFailed(nil)
            case let .transactionFailure(primary, rollback):
                return .documentMutationTransactionFailed(primary, rollback)
            }
        }
    }
}
