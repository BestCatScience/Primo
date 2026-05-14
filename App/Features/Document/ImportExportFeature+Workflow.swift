import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPersistenceContracts
import PrimoDocumentRuntime
import PrimoWorkspaceApplication

extension ImportExportFeature {
    enum ImportImagePlanFailure: Error, Equatable {
        case invalidImageData
        case unsupportedImageSize

        var message: String? { nil }
    }

    struct ShareExportFactory {
        let uuidClient: UUIDClient

        func makeShareExport(url: URL) -> ShareExport {
            ShareExport(id: uuidClient.generate(), url: url)
        }
    }

    var shareExportFactory: ShareExportFactory {
        ShareExportFactory(uuidClient: uuidClient)
    }

    func makeShareExport(url: URL) -> ShareExport {
        shareExportFactory.makeShareExport(url: url)
    }

    func handleExportDocumentRequest(state: inout State) -> Effect<Action> {
        guard let pngData = documentExportGateway.compositePNGData(.default) else {
            return .send(.delegate(.exportFailed))
        }
        do {
            let url = try workspaceArtifactCapability.writePNGToTemporaryDirectory(pngData)
            state.export.presentShareSheet(makeShareExport(url: url))
        } catch {
            return .send(.delegate(.exportFailed))
        }
        return .none
    }

    func handleTimelapseExportRequest(state: inout State) -> Effect<Action> {
        guard let capture = documentExportGateway.timelapseCapture() else {
            return .send(.delegate(.timelapseHistoryUnavailable))
        }
        state.export.startTimelapsePreview(from: capture)
        return .run { [timelapseExportCapability] send in
            do {
                let result = try timelapseExportCapability.exportVideo(capture) { progress in
                    Task {
                        await send(.timelapseExportProgressUpdated(progress))
                    }
                }
                await send(.timelapseExportSucceeded(result))
            } catch {
                await send(.timelapseExportFailed(Self.optionalErrorMessage(error)))
            }
        }
        .cancellable(id: ApplicationFeature.CancelID.timelapseExport, cancelInFlight: true)
    }

    func handleNewCanvasFromImageReceived(
        name: String?,
        data: Data
    ) -> Effect<Action> {
        switch Self.importedCanvasPlan(name: name, data: data) {
        case let .success(plan):
            return .send(.newCanvasFromImagePreparationCompleted(plan))
        case let .failure(failure):
            return .send(.newCanvasFromImageFailed(failure.message))
        }
    }

    static func importedCanvasPlan(
        name: String?,
        data: Data
    ) -> Result<ImportedCanvasPlan, ImportImagePlanFailure> {
        guard let decoded = DocumentRasterImageService.decodedImage(fromEncodedData: data) else {
            return .failure(.invalidImageData)
        }
        guard decoded.width > 0, decoded.height > 0 else {
            return .failure(.invalidImageData)
        }
        guard (64...8192).contains(decoded.width), (64...8192).contains(decoded.height) else {
            return .failure(.unsupportedImageSize)
        }
        let fallbackName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let layerName = fallbackName?.isEmpty == false ? fallbackName! : "Imported Image"
        return .success(
            ImportedCanvasPlan(
                request: ImportedCanvasRequest(
                    width: decoded.width,
                    height: decoded.height,
                    pixelData: decoded.pixelData
                ),
                layerName: layerName
            )
        )
    }

    static func optionalErrorMessage(_ error: Error) -> String? {
        let message = String(describing: error)
        return message.isEmpty ? nil : message
    }
}

extension ImportExportFeature.SaveHistoryState {
    mutating func beginPresentation() {
        isPresented = true
    }

    mutating func present(entries: [SaveHistoryEntry]) {
        self.entries = entries
        isPresented = true
    }

    mutating func dismiss() {
        isPresented = false
    }

    mutating func completeRestore() {
        dismiss()
    }
}

extension ImportExportFeature.ExportState {
    mutating func presentShareSheet(_ shareExport: ShareExport) {
        shareSheet = shareExport
    }

    mutating func clearOutputs() {
        shareSheet = nil
        timelapsePreview = nil
    }

    mutating func startTimelapsePreview(from capture: TimelapseCapture) {
        timelapsePreview = TimelapseExportPreview(
            progress: 0,
            previewSurface: capture.previewSurface,
            previewImageData: capture.previewImageData
        )
    }

    mutating func updateTimelapsePreview(_ progress: TimelapseExportProgress) {
        timelapsePreview = TimelapseExportPreview(
            progress: progress.progress,
            previewSurface: progress.previewSurface ?? timelapsePreview?.previewSurface,
            previewImageData: progress.previewImageData ?? timelapsePreview?.previewImageData
        )
    }

    mutating func completeTimelapseExport(with shareExport: ShareExport) {
        timelapsePreview = nil
        shareSheet = shareExport
    }

    mutating func failTimelapseExport() {
        timelapsePreview = nil
    }

    mutating func dismissShareSheet() {
        shareSheet = nil
    }
}
