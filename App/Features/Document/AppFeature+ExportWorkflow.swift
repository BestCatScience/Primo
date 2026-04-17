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
            capture: TimelapseCapture,
            failureMessage: String
        ) -> Effect<Action> {
            .run { [workspaceArtifactService, fileClient, dateClient] send in
                do {
                    let url = try TimelapseExporter.exportVideo(
                        from: capture,
                        to: workspaceArtifactService.timelapseTemporaryDirectory(),
                        fileClient: fileClient,
                        dateClient: dateClient
                    ) { progress, previewURL in
                        let previewData = try? fileClient.readData(previewURL)
                        Task {
                            await send(.timelapseExportProgressUpdated(progress, previewData))
                        }
                    }
                    await send(.timelapseExportSucceeded(url))
                } catch {
                    await send(.timelapseExportFailed(failureMessage))
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
        guard let pngData = compositePNGData(state: state) else {
            state.application.presentBanner(state.application.appLanguage.localized("Export failed"))
            return
        }
        do {
            state.export.presentShareSheet(
                try exportWorkflowService.makeDocumentShareExport(from: pngData)
            )
        } catch {
            state.application.presentBanner(state.application.appLanguage.localized("Export failed"))
        }
    }

    func handleTimelapseExportRequest(state: inout State) -> Effect<Action> {
        guard let capture = exportWorkflowService.timelapseCapture() else {
            state.application.presentBanner(
                state.application.appLanguage.localized("Not enough drawing history for timelapse yet")
            )
            return .none
        }
        state.export.startTimelapsePreview(from: capture)
        return exportWorkflowService.makeTimelapseExportEffect(
            capture: capture,
            failureMessage: state.application.appLanguage.localized("Timelapse export failed")
        )
    }

    func handleTimelapseExportProgressUpdated(
        state: inout State,
        progress: Double,
        previewData: Data?
    ) {
        state.export.updateTimelapsePreview(progress: progress, previewData: previewData)
    }

    func handleTimelapseExportSucceeded(
        state: inout State,
        url: URL
    ) {
        state.export.completeTimelapseExport(with: exportWorkflowService.makeShareExport(url: url))
    }

    func handleTimelapseExportFailed(
        state: inout State,
        message: String
    ) {
        state.export.failTimelapseExport()
        state.application.presentBanner(message)
    }

    func handleExportSheetDismissed(state: inout State) {
        state.export.dismissShareSheet()
    }
}
