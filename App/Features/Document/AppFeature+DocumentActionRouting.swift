import ComposableArchitecture
import Foundation

extension AppFeature {
    func routeDocumentAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .newCanvasRequested(width, height):
            return handleNewCanvasRequest(state: &state, width: width, height: height)

        case let .newCanvasPreparationCompleted(dimensions):
            return handleNewCanvasPreparationCompleted(state: &state, dimensions: dimensions)

        case let .resizeCanvasRequested(width, height):
            return handleResizeCanvasRequest(state: &state, width: width, height: height)

        case let .resizeCanvasExtentRequested(width, height):
            return handleResizeCanvasExtentRequest(state: &state, width: width, height: height)

        case let .newCanvasFromImageReceived(name, data):
            return handleNewCanvasFromImageReceived(state: &state, name: name, data: data)

        case let .newCanvasFromImagePreparationCompleted(plan):
            return handleNewCanvasFromImagePreparationCompleted(state: &state, plan: plan)

        case let .newCanvasFromImageFailed(message):
            handleNewCanvasFromImageFailed(state: &state, message: message)
            return .none

        case .undoRequested:
            return handleUndoRequested(state: &state)

        case .redoRequested:
            return handleRedoRequested(state: &state)

        case .saveHistoryRequested:
            return handleSaveHistoryRequest(state: &state)

        case let .saveHistoryLoaded(entries):
            state.saveHistory.present(entries: entries)
            return .none

        case let .saveHistoryLoadFailed(message):
            handleSaveHistoryLoadFailed(state: &state, message: message)
            return .none

        case .saveHistoryDismissed:
            state.saveHistory.dismiss()
            return .none

        case let .saveHistoryRestoreRequested(projectURL, openInNewTab):
            return handleSaveHistoryRestoreRequest(
                state: &state,
                projectURL: projectURL,
                openInNewTab: openInNewTab
            )

        case let .saveHistoryOpened(loaded, projectURL, openInNewTab, issues):
            return handleSaveHistoryOpened(
                state: &state,
                loaded: loaded,
                projectURL: projectURL,
                openInNewTab: openInNewTab,
                issues: issues
            )

        case let .saveHistoryRestoreFailed(message):
            handleSaveHistoryRestoreFailed(state: &state, message: message)
            return .none

        case .exportDocumentRequested:
            handleExportDocumentRequest(state: &state)
            return .none

        case .saveDocumentRequested:
            return handleSaveDocumentRequest(
                state: &state,
                preferredDestinationURL: state.workspace.activeTab?.sourceProjectURL
            )

        case .saveDocumentCopyRequested:
            return handleSaveDocumentRequest(
                state: &state,
                preferredDestinationURL: nil
            )

        case .exportTimelapseRequested:
            return handleTimelapseExportRequest(state: &state)

        case let .nanoBanana(.delegate(delegateAction)):
            switch delegateAction {
            case let .requestEdit(request):
                return handleNanoBananaEditRequest(state: &state, request: request)
            case .cancelEdit:
                return handleNanoBananaCancelRequested(state: &state)
            }

        case let .nanoBanana(.generationSucceeded(preview)):
            handleNanoBananaEditSucceeded(state: &state, preview: preview)
            return .none

        case let .nanoBanana(.generationFailed(feedback)):
            handleNanoBananaEditFailed(state: &state, feedback: feedback)
            return .none

        case let .timelapseExportProgressUpdated(progress):
            handleTimelapseExportProgressUpdated(state: &state, progress: progress)
            return .none

        case let .timelapseExportSucceeded(result):
            handleTimelapseExportSucceeded(state: &state, result: result)
            return .none

        case let .timelapseExportFailed(message):
            handleTimelapseExportFailed(state: &state, message: message)
            return .none

        case let .photoImportReceived(name, data):
            return handlePhotoImport(state: &state, name: name, data: data)

        case let .photoImportFailed(message):
            handlePhotoImportFailed(state: &state, message: message)
            return .none

        default:
            return nil
        }
    }
}
