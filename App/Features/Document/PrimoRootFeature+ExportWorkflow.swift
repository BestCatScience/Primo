import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentEngineInfrastructure

extension CrossFeatureIntegrationReducer {
    private struct ExportWorkflowService {
        let documentExportGateway: DocumentExportGateway
        let workspaceArtifactService: WorkspaceArtifactService
        let shareExportFactory: ShareExportFactory
        let fileClient: FileClient
        let dateClient: DateClient

        func makeDocumentShareExport(from pngData: Data) throws -> ShareExport {
            let url = try workspaceArtifactService.writePNGToTemporaryDirectory(pngData)
            return shareExportFactory.makeShareExport(url: url)
        }

        func timelapseCapture() -> TimelapseCapture? {
            documentExportGateway.timelapseCapture()
        }

        func makeTimelapseExportEffect(
            capture: TimelapseCapture
        ) -> Effect<Action> {
            .run { [workspaceArtifactService, fileClient, dateClient] send in
                do {
                    let result = try TimelapseExportService.exportVideo(
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
                            PrimoRootFeature.optionalErrorMessage(error)
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
            documentExportGateway: documentExportGateway,
            workspaceArtifactService: workspaceArtifactService,
            shareExportFactory: shareExportFactory,
            fileClient: fileClient,
            dateClient: dateClient
        )
    }

    func handleExportDocumentRequest(state: inout State) {
        let paperStyle = resolvedPaperStyle(for: state)
        let surface = state.canvas.renderSnapshot.map {
            renderedCompositeSurface(snapshot: $0, paperStyle: paperStyle)
        } ?? documentPresentationQueryService.compositeSurface(
            paperStyle: paperStyle
        )
        guard let pngData = surface.flatMap(DocumentRasterImageService.pngData(from:)) else {
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
