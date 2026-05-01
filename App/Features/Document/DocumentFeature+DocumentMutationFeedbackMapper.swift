import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
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
        case .invalidFolderID:
            return ApplicationFeature.Feedback.folderUnavailable.message(for: language)
        case .layerLocked:
            return ApplicationFeature.Feedback.layerEditLocked.message(for: language)
        case .alphaLocked:
            return ApplicationFeature.Feedback.layerAlphaEditLocked.message(for: language)
        case .invalidOpacity:
            return ApplicationFeature.Feedback.invalidLayerOpacity.message(for: language)
        case .emptyInput:
            return ApplicationFeature.Feedback.emptyDocumentMutationInput.message(for: language)
        case let .gpu(failure):
            return ApplicationFeature.Feedback.documentMutationBridgeFailed(failure.displayMessage).message(for: language)
        case let .bridgeMutationFailed(message):
            return ApplicationFeature.Feedback.documentMutationBridgeFailed(message).message(for: language)
        case .incompatibleLayerType:
            return ApplicationFeature.Feedback.unsupportedLayerType.message(for: language)
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
            case let .gpu(failure):
                return .documentMutationBridgeFailed(failure.displayMessage)
            case let .bridgeMutationFailed(message):
                return .documentMutationBridgeFailed(message)
            case .incompatibleLayerType:
                return .unsupportedLayerType
            case let .transactionFailure(primary, rollback):
                return .documentMutationTransactionFailed(primary, rollback)
            }
        }
    }
}
