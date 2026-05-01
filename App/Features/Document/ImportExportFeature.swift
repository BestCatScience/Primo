import CasePaths
import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentPersistenceContracts
import PrimoDocumentRuntime
import PrimoWorkspaceApplication

@Reducer
struct ImportExportFeature {
    struct ImportedCanvasPlan: Equatable, Sendable {
        let request: ImportedCanvasRequest
        let layerName: String
    }

    struct SaveHistoryState: Equatable {
        var entries: [SaveHistoryEntry] = []
        var isPresented = false
    }

    struct ExportState: Equatable {
        var shareSheet: ShareExport?
        var timelapsePreview: TimelapseExportPreview?
    }

    @ObservableState
    struct State: Equatable {
        var saveHistory = SaveHistoryState()
        var export = ExportState()
    }

    @CasePathable
    enum Action: Equatable {
        enum Delegate: Equatable {
            case saveHistoryEntriesRequested
            case saveActiveDocumentRequested(preferredDestinationURL: DocumentProjectPath?)
            case saveDocumentCopyRequested
            case exportPNGDataRequested
            case exportFailed
            case timelapseHistoryUnavailable
            case presentBanner(String?)
            case presentFeedback(ApplicationFeature.Feedback)
            case newCanvasFromImagePrepared(ImportedCanvasPlan)
        }

        case saveHistoryRequested
        case saveHistoryLoaded([SaveHistoryEntry])
        case saveHistoryLoadFailed(String?)
        case saveHistoryLoadFailedFeedback(ApplicationFeature.Feedback)
        case saveHistoryDismissed
        case saveHistoryRestoreRequested(DocumentProjectPath, Bool)
        case saveHistoryOpened(LoadedPaintProject, DocumentProjectPath, Bool, [WorkspaceProjectLoadIssue])
        case saveHistoryRestoreCompleted
        case saveHistoryRestoreFailed(String?)
        case saveDocumentRequested
        case saveDocumentCopyRequested
        case exportDocumentRequested
        case exportSheetDismissed
        case exportTimelapseRequested
        case timelapseExportProgressUpdated(TimelapseExportProgress)
        case timelapseExportSucceeded(TimelapseExportResult)
        case timelapseExportFailed(String?)
        case photoImportReceived(name: String?, data: Data)
        case photoImportFailed(String?)
        case newCanvasFromImageReceived(name: String?, data: Data)
        case newCanvasFromImagePreparationCompleted(ImportedCanvasPlan)
        case newCanvasFromImageFailed(String?)
        case delegate(Delegate)
    }

    @Dependency(\.dateClient) var dateClient
    @Dependency(\.documentExportGateway) var documentExportGateway
    @Dependency(\.documentWorkspaceClient) var documentWorkspaceClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.uuidClient) var uuidClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .saveHistoryRequested:
                state.saveHistory.beginPresentation()
                return .send(.delegate(.saveHistoryEntriesRequested))

            case let .saveHistoryLoaded(entries):
                state.saveHistory.present(entries: entries)
                return .none

            case let .saveHistoryLoadFailed(message):
                state.saveHistory.dismiss()
                return .send(.delegate(.presentBanner(message)))

            case let .saveHistoryLoadFailedFeedback(feedback):
                state.saveHistory.dismiss()
                return .send(.delegate(.presentFeedback(feedback)))

            case .saveHistoryDismissed:
                state.saveHistory.dismiss()
                return .none

            case .saveHistoryRestoreCompleted:
                state.saveHistory.completeRestore()
                return .none

            case .saveDocumentRequested:
                return .send(.delegate(.saveActiveDocumentRequested(preferredDestinationURL: nil)))

            case .saveDocumentCopyRequested:
                return .send(.delegate(.saveDocumentCopyRequested))

            case .exportDocumentRequested:
                return handleExportDocumentRequest(state: &state)

            case .exportSheetDismissed:
                state.export.dismissShareSheet()
                return .none

            case .exportTimelapseRequested:
                return handleTimelapseExportRequest(state: &state)

            case let .timelapseExportProgressUpdated(progress):
                state.export.updateTimelapsePreview(progress)
                return .none

            case let .timelapseExportSucceeded(result):
                state.export.completeTimelapseExport(with: makeShareExport(url: result.url))
                return .none

            case let .timelapseExportFailed(message):
                state.export.failTimelapseExport()
                return .send(.delegate(.presentBanner(message)))

            case let .newCanvasFromImageReceived(name, data):
                return handleNewCanvasFromImageReceived(name: name, data: data)

            case let .newCanvasFromImageFailed(message):
                return .send(.delegate(.presentBanner(message)))

            case .delegate:
                return .none

            default:
                return .none
            }
        }
    }
}
