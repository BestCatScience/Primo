import ComposableArchitecture
import Foundation

extension AppFeature {
    func routeDocumentEditorAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .document(.newCanvasRequested(width, height)):
            return handleNewCanvasRequest(state: &state, width: width, height: height)

        case let .document(.newCanvasPreparationCompleted(dimensions)):
            return handleNewCanvasPreparationCompleted(state: &state, dimensions: dimensions)

        case let .document(.resizeCanvasRequested(width, height)):
            return handleResizeCanvasRequest(state: &state, width: width, height: height)

        case let .document(.resizeCanvasExtentRequested(width, height)):
            return handleResizeCanvasExtentRequest(state: &state, width: width, height: height)

        case .document(.undoRequested):
            return handleUndoRequested(state: &state)

        case .document(.redoRequested):
            return handleRedoRequested(state: &state)

        default:
            return nil
        }
    }

    func routeAssetImportExportAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case let .document(.newCanvasFromImageReceived(name, data)):
            return handleNewCanvasFromImageReceived(state: &state, name: name, data: data)

        case let .document(.newCanvasFromImagePreparationCompleted(plan)):
            return handleNewCanvasFromImagePreparationCompleted(state: &state, plan: plan)

        case let .document(.newCanvasFromImageFailed(message)):
            handleNewCanvasFromImageFailed(state: &state, message: message)
            return .none

        case .document(.saveHistoryRequested):
            return handleSaveHistoryRequest(state: &state)

        case let .document(.saveHistoryLoaded(entries)):
            state.saveHistory.present(entries: entries)
            return .none

        case let .document(.saveHistoryLoadFailed(message)):
            handleSaveHistoryLoadFailed(state: &state, message: message)
            return .none

        case .document(.saveHistoryDismissed):
            state.saveHistory.dismiss()
            return .none

        case let .document(.saveHistoryRestoreRequested(projectURL, openInNewTab)):
            return handleSaveHistoryRestoreRequest(
                state: &state,
                projectURL: projectURL,
                openInNewTab: openInNewTab
            )

        case let .document(.saveHistoryOpened(loaded, projectURL, openInNewTab, issues)):
            return handleSaveHistoryOpened(
                state: &state,
                loaded: loaded,
                projectURL: projectURL,
                openInNewTab: openInNewTab,
                issues: issues
            )

        case let .document(.saveHistoryRestoreFailed(message)):
            handleSaveHistoryRestoreFailed(state: &state, message: message)
            return .none

        case .document(.exportDocumentRequested):
            handleExportDocumentRequest(state: &state)
            return .none

        case .document(.saveDocumentRequested):
            return handleSaveDocumentRequest(
                state: &state,
                preferredDestinationURL: state.workspace.activeTab?.sourceProjectURL
            )

        case .document(.saveDocumentCopyRequested):
            return handleSaveDocumentRequest(
                state: &state,
                preferredDestinationURL: nil
            )

        case .document(.exportTimelapseRequested):
            return handleTimelapseExportRequest(state: &state)

        case let .document(.timelapseExportProgressUpdated(progress)):
            handleTimelapseExportProgressUpdated(state: &state, progress: progress)
            return .none

        case let .document(.timelapseExportSucceeded(result)):
            handleTimelapseExportSucceeded(state: &state, result: result)
            return .none

        case let .document(.timelapseExportFailed(message)):
            handleTimelapseExportFailed(state: &state, message: message)
            return .none

        case let .document(.photoImportReceived(name, data)):
            return handlePhotoImport(state: &state, name: name, data: data)

        case let .document(.photoImportFailed(message)):
            handlePhotoImportFailed(state: &state, message: message)
            return .none

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

        default:
            return nil
        }
    }

    func routeDocumentAction(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        if let effect = routeDocumentEditorAction(state: &state, action: action) {
            return effect
        }
        return routeAssetImportExportAction(state: &state, action: action)
    }
}
