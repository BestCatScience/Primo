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

        case let .resizeCanvasRequested(width, height):
            handleResizeCanvasRequest(state: &state, width: width, height: height)
            return .none

        case let .resizeCanvasExtentRequested(width, height):
            handleResizeCanvasExtentRequest(state: &state, width: width, height: height)
            return .none

        case let .newCanvasFromImageReceived(name, data):
            return handleNewCanvasFromImageReceived(state: &state, name: name, data: data)

        case let .newCanvasFromImageFailed(feedback):
            handleNewCanvasFromImageFailed(state: &state, feedback: feedback)
            return .none

        case .undoRequested:
            handleUndoRequested(state: &state)
            return .none

        case .redoRequested:
            handleRedoRequested(state: &state)
            return .none

        case .saveHistoryRequested:
            return handleSaveHistoryRequest(state: &state)

        case let .saveHistoryLoaded(entries):
            state.saveHistory.present(entries: entries)
            return .none

        case let .saveHistoryLoadFailed(feedback):
            handleSaveHistoryLoadFailed(state: &state, feedback: feedback)
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

        case let .saveHistoryOpened(loaded, projectURL, openInNewTab):
            handleSaveHistoryOpened(
                state: &state,
                loaded: loaded,
                projectURL: projectURL,
                openInNewTab: openInNewTab
            )
            return .none

        case let .saveHistoryRestoreFailed(feedback):
            handleSaveHistoryRestoreFailed(state: &state, feedback: feedback)
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

        case let .nanoBananaEditRequested(request):
            return handleNanoBananaEditRequest(state: &state, request: request)

        case let .nanoBananaEditSucceeded(preview):
            handleNanoBananaEditSucceeded(state: &state, preview: preview)
            return .none

        case let .nanoBananaEditFailed(feedback):
            handleNanoBananaEditFailed(state: &state, feedback: feedback)
            return .none

        case .nanoBananaCancelRequested:
            return handleNanoBananaCancelRequested(state: &state)

        case .nanoBananaRegenerateRequested:
            return handleNanoBananaRegenerateRequested(state: &state)

        case let .nanoBananaRetryJob(jobID):
            return handleNanoBananaRetryJob(state: &state, jobID: jobID)

        case let .timelapseExportProgressUpdated(progress):
            handleTimelapseExportProgressUpdated(state: &state, progress: progress)
            return .none

        case let .timelapseExportSucceeded(result):
            handleTimelapseExportSucceeded(state: &state, result: result)
            return .none

        case let .timelapseExportFailed(feedback):
            handleTimelapseExportFailed(state: &state, feedback: feedback)
            return .none

        case let .photoImportReceived(name, data):
            handlePhotoImport(state: &state, name: name, data: data)
            return .none

        case let .photoImportFailed(feedback):
            handlePhotoImportFailed(state: &state, feedback: feedback)
            return .none

        default:
            return nil
        }
    }
}
