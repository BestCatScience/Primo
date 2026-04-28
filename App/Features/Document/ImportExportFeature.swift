import CasePaths
import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoWorkspaceApplication

@Reducer
struct ImportExportFeature {
    typealias ImportedCanvasPlan = DocumentFeatureRuntimeReducer.ImportedCanvasPlan

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
        case newCanvasFromImagePreparationCompleted(ImportedCanvasPlan)
        case newCanvasFromImageFailed(String?)
    }

    var body: some ReducerOf<Self> {
        Reduce { _, _ in .none }
    }
}
