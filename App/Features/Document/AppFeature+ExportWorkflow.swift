import ComposableArchitecture
import Foundation

extension AppFeature {
    private struct ExportWorkflowService {
        let paintDocumentClient: PaintDocumentClient
        let workspaceArtifactService: WorkspaceArtifactService
        let shareExportFactory: ShareExportFactory
        let fileClient: FileClient
        let dateClient: DateClient

        func makeDocumentShareExport(from pngData: Data) throws -> ShareExport {
            let url = try workspaceArtifactService.writePNGToTemporaryDirectory(pngData)
            return shareExportFactory.makeShareExport(url: url)
        }

        func timelapseCapture() -> TimelapseCapture? {
            paintDocumentClient.timelapseCapture()
        }

        func makeTimelapseExportEffect(
            capture: TimelapseCapture
        ) -> Effect<Action> {
            .run { [workspaceArtifactService, fileClient, dateClient] send in
                do {
                    let result = try TimelapseExporter.exportVideo(
                        from: capture,
                        to: workspaceArtifactService.timelapseTemporaryDirectory(),
                        fileClient: fileClient,
                        dateClient: dateClient
                    ) { progress in
                        Task {
                            await send(.timelapseExportProgressUpdated(progress))
                        }
                    }
                    await send(.timelapseExportSucceeded(result))
                } catch {
                    await send(
                        .timelapseExportFailed(
                            AppFeature.optionalErrorMessage(error)
                        )
                    )
                }
            }
            .cancellable(id: CancelID.timelapseExport, cancelInFlight: true)
        }

        func makeShareExport(url: URL) -> ShareExport {
            shareExportFactory.makeShareExport(url: url)
        }
    }

    private var exportWorkflowService: ExportWorkflowService {
        ExportWorkflowService(
            paintDocumentClient: paintDocumentClient,
            workspaceArtifactService: workspaceArtifactService,
            shareExportFactory: shareExportFactory,
            fileClient: fileClient,
            dateClient: dateClient
        )
    }

    func handleExportDocumentRequest(state: inout State) {
        guard let pngData = documentPresentationQueryService.compositePNGData(
            paperStyle: resolvedPaperStyle(for: state)
        ) else {
            state.application.presentFeedback(.exportFailed)
            return
        }
        do {
            state.export.presentShareSheet(
                try exportWorkflowService.makeDocumentShareExport(from: pngData)
            )
        } catch {
            state.application.presentFeedback(.exportFailed)
        }
    }

    func handleTimelapseExportRequest(state: inout State) -> Effect<Action> {
        guard let capture = exportWorkflowService.timelapseCapture() else {
            state.application.presentFeedback(.timelapseHistoryUnavailable)
            return .none
        }
        state.export.startTimelapsePreview(from: capture)
        return exportWorkflowService.makeTimelapseExportEffect(capture: capture)
    }

    func handleTimelapseExportProgressUpdated(
        state: inout State,
        progress: TimelapseExportProgress
    ) {
        state.export.updateTimelapsePreview(progress)
    }

    func handleTimelapseExportSucceeded(
        state: inout State,
        result: TimelapseExportResult
    ) {
        state.export.completeTimelapseExport(
            with: exportWorkflowService.makeShareExport(url: result.url)
        )
    }

    func handleTimelapseExportFailed(
        state: inout State,
        message: String?
    ) {
        state.export.failTimelapseExport()
        state.application.presentBanner(
            message ?? ApplicationFeedback.timelapseExportFailed(nil).message(for: state.application.appLanguage)
        )
    }

    func handleExportSheetDismissed(state: inout State) {
        state.export.dismissShareSheet()
    }
}
