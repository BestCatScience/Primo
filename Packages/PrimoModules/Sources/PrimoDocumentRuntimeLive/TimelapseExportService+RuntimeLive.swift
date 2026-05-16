import Foundation
import PrimoCoreTypes
import PrimoDocumentEngineInfrastructure
import PrimoDocumentPersistenceContracts
import PrimoDocumentRuntime
import PrimoSystemClients

public enum TimelapseExportService {
    public static func exportVideo(
        from capture: TimelapseCapture,
        to directory: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        progress: ((PrimoDocumentRuntime.TimelapseExportProgress) -> Void)? = nil
    ) throws -> PrimoDocumentRuntime.TimelapseExportResult {
        do {
            return try PrimoDocumentRuntime.TimelapseExportResult(
                PrimoDocumentEngineInfrastructure.TimelapseExportService.exportVideo(
                    from: capture,
                    to: directory,
                    fileClient: fileClient,
                    dateClient: dateClient,
                    progress: progress.map { callback in
                        { callback(PrimoDocumentRuntime.TimelapseExportProgress($0)) }
                    }
                )
            )
        } catch let error as PrimoDocumentEngineInfrastructure.TimelapseExportError {
            throw PrimoDocumentRuntime.TimelapseExportError(error)
        } catch {
            throw error
        }
    }
}

private extension PrimoDocumentRuntime.TimelapseExportProgress {
    init(_ infrastructure: PrimoDocumentEngineInfrastructure.TimelapseExportProgress) {
        self.init(
            progress: infrastructure.progress,
            previewSurface: infrastructure.previewSurface,
            previewImageData: infrastructure.previewImageData
        )
    }
}

private extension PrimoDocumentRuntime.TimelapseExportResult {
    init(_ infrastructure: PrimoDocumentEngineInfrastructure.TimelapseExportResult) {
        self.init(url: infrastructure.url)
    }
}

private extension PrimoDocumentRuntime.TimelapseExportError {
    init(_ infrastructure: PrimoDocumentEngineInfrastructure.TimelapseExportError) {
        switch infrastructure {
        case .insufficientFrames:
            self = .insufficientFrames
        case .cannotAddWriterInput:
            self = .cannotAddWriterInput
        case .failedToStartWriting:
            self = .failedToStartWriting
        case .invalidFrameData:
            self = .invalidFrameData
        case .exportFailed:
            self = .exportFailed
        case .cancelled:
            self = .cancelled
        }
    }
}
