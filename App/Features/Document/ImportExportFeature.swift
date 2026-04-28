import CasePaths
import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoWorkspaceApplication

@Reducer
struct ImportExportFeature {
    @ObservableState
    struct State: Equatable {
        var saveHistory = AppFeature.SaveHistoryState()
        var export = AppFeature.ExportState()
    }

    @CasePathable
    enum Action: Equatable {
        case saveHistoryRequested
        case saveHistoryLoaded([SaveHistoryEntry])
        case saveHistoryLoadFailed(String?)
        case saveHistoryDismissed
        case saveHistoryRestoreRequested(DocumentProjectPath, Bool)
        case saveHistoryOpened(LoadedPaintProject, DocumentProjectPath, Bool, [WorkspaceProjectLoadIssue])
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
        case newCanvasFromImagePreparationCompleted(AppFeature.ImportedCanvasPlan)
        case newCanvasFromImageFailed(String?)
    }

    var body: some ReducerOf<Self> {
        Reduce { _, _ in .none }
    }
}
