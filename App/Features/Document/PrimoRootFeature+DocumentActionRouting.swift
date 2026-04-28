import ComposableArchitecture
import Foundation

extension CrossFeatureIntegrationReducer {
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
        case let .importExport(.newCanvasFromImageReceived(name, data)):
            return handleNewCanvasFromImageReceived(state: &state, name: name, data: data)

        case let .importExport(.newCanvasFromImagePreparationCompleted(plan)):
            return handleNewCanvasFromImagePreparationCompleted(state: &state, plan: plan)

        case let .importExport(.newCanvasFromImageFailed(message)):
            handleNewCanvasFromImageFailed(state: &state, message: message)
            return .none

        case .importExport(.saveHistoryRequested):
            return handleSaveHistoryRequest(state: &state)

        case let .importExport(.saveHistoryLoaded(entries)):
            state.saveHistory.present(entries: entries)
            return .none

        case let .importExport(.saveHistoryLoadFailed(message)):
            handleSaveHistoryLoadFailed(state: &state, message: message)
            return .none

        case .importExport(.saveHistoryDismissed):
            state.saveHistory.dismiss()
            return .none

        case let .importExport(.saveHistoryRestoreRequested(projectURL, openInNewTab)):
            return handleSaveHistoryRestoreRequest(
                state: &state,
                projectURL: projectURL,
                openInNewTab: openInNewTab
            )

        case let .importExport(.saveHistoryOpened(loaded, projectURL, openInNewTab, issues)):
            return handleSaveHistoryOpened(
                state: &state,
                loaded: loaded,
                projectURL: projectURL,
                openInNewTab: openInNewTab,
                issues: issues
            )

        case let .importExport(.saveHistoryRestoreFailed(message)):
            handleSaveHistoryRestoreFailed(state: &state, message: message)
            return .none

        case .importExport(.exportDocumentRequested):
            handleExportDocumentRequest(state: &state)
            return .none

        case .importExport(.saveDocumentRequested):
            return handleSaveDocumentRequest(
                state: &state,
                preferredDestinationURL: state.workspace.activeTab?.sourceProjectURL
            )

        case .importExport(.saveDocumentCopyRequested):
            return handleSaveDocumentRequest(
                state: &state,
                preferredDestinationURL: nil
            )

        case .importExport(.exportTimelapseRequested):
            return handleTimelapseExportRequest(state: &state)

        case let .importExport(.timelapseExportProgressUpdated(progress)):
            handleTimelapseExportProgressUpdated(state: &state, progress: progress)
            return .none

        case let .importExport(.timelapseExportSucceeded(result)):
            handleTimelapseExportSucceeded(state: &state, result: result)
            return .none

        case let .importExport(.timelapseExportFailed(message)):
            handleTimelapseExportFailed(state: &state, message: message)
            return .none

        case let .importExport(.photoImportReceived(name, data)):
            return handlePhotoImport(state: &state, name: name, data: data)

        case let .importExport(.photoImportFailed(message)):
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
