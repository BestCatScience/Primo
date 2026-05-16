import Foundation
import PrimoCoreTypes
import PrimoDocumentEngineInfrastructure
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentRuntime
import PrimoSystemClients

private extension Result where Success == DocumentCommandOutcome, Failure == DocumentMutationFailure {
    func getOrFailureOutcome() -> DocumentCommandOutcome {
        switch self {
        case let .success(outcome):
            return outcome
        case let .failure(failure):
            return .failure(failure)
        }
    }
}

package extension DocumentRuntime {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
        let services = DocumentRuntimeServices(composition: composition)
        let presentationBroadcaster = DocumentRuntimePresentationBroadcaster {
            composition.queryGateway.lightweightPresentation()
        }
        let mutationOutcome: @Sendable (
            Result<DocumentMutationSuccess, DocumentMutationFailure>
        ) -> DocumentCommandOutcome = { result in
            if case .success = result {
                presentationBroadcaster.publishLatest()
            }
            return .mutation(result)
        }

        let executeClosure: @Sendable (DocumentCommand) async -> DocumentCommandOutcome = { command in
            switch command {
            case let .presentation(request):
                switch request {
                case .lightweight:
                    return composition.queryGateway.lightweightPresentation()
                        .map(DocumentCommandOutcome.presentation)
                        .getOrFailureOutcome()
                case .full, .current:
                    return composition.queryGateway.presentation()
                        .map(DocumentCommandOutcome.presentation)
                        .getOrFailureOutcome()
                }
            case let .canvas(command):
                switch command {
                case let .createSized(size):
                    return mutationOutcome(services.canvasCommands.createCanvas(size.width, size.height).map { .completed })
                case let .resizeSized(size):
                    return mutationOutcome(services.canvasCommands.resizeCanvas(size.width, size.height).map { .completed })
                case let .resizeExtentSized(size):
                    return mutationOutcome(services.canvasCommands.resizeCanvasExtent(size.width, size.height).map { .completed })
                case let .initializeImported(request, layerName):
                    return mutationOutcome(services.canvasCommands.initializeImportedCanvas(request, layerName).map { .completed })
                case .compositeSurface:
                    return services.canvasCommands.compositeSurface()
                        .map(DocumentCommandOutcome.compositeSurface)
                        .getOrFailureOutcome()
                case let .setPaperStyle(style):
                    return mutationOutcome(composition.persistenceGateway.setPaperStyle(style).map { .completed })
                }
            case let .layer(command):
                switch command {
                case let .edit(request):
                    return mutationOutcome(
                        composition.editingGateway.execute(request)
                            .map { _ in .completed }
                    )
                case let .mergeExistingLayerDown(index):
                    return mutationOutcome(composition.layerEffectsGateway.mergeLayerDown(index.rawValue).map { .completed })
                case let .setEditableTextLayer(index, textLayer):
                    return mutationOutcome(
                        composition.editingGateway.execute(.content(.setTextLayer(index: index.rawValue, textLayer: textLayer)))
                            .map { _ in .completed }
                    )
                case let .applyEditableProcessing(index, request):
                    return mutationOutcome(
                        composition.editingGateway.execute(.content(.applyProcessing(index: index.rawValue, request: request)))
                            .map { _ in .completed }
                    )
                }
            case let .stroke(command):
                switch command {
                case let .begin(sample, settings):
                    return mutationOutcome(composition.strokeGateway.beginStroke(sample, settings).map { .completed })
                case let .append(sample):
                    return mutationOutcome(composition.strokeGateway.appendStroke(sample).map { .completed })
                case .end:
                    return mutationOutcome(composition.strokeGateway.endStroke().map { .completed })
                case .cancel:
                    return mutationOutcome(composition.strokeGateway.cancelStroke().map { .completed })
                case let .fill(sample, settings):
                    return mutationOutcome(composition.strokeGateway.fill(sample, settings).map { .completed })
                }
            case let .history(command):
                switch command {
                case .state:
                    let canUndo: Bool
                    switch composition.historyGateway.canUndo() {
                    case let .failure(failure):
                        return .failure(failure)
                    case let .success(value):
                        canUndo = value
                    }
                    let canRedo: Bool
                    switch composition.historyGateway.canRedo() {
                    case let .failure(failure):
                        return .failure(failure)
                    case let .success(value):
                        canRedo = value
                    }
                    return .history(
                        DocumentHistoryState(
                            canUndo: canUndo,
                            canRedo: canRedo
                        )
                    )
                case .undo:
                    return mutationOutcome(composition.historyGateway.undo().map { .completed })
                case .redo:
                    return mutationOutcome(composition.historyGateway.redo().map { .completed })
                }
            }
        }

        self.init(
            execute: executeClosure,
            observePresentation: {
                presentationBroadcaster.stream()
            }
        )
    }
}


public enum DocumentApplicationRuntimeFactory {
    public static func live(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentApplicationRuntime {
        DocumentApplicationRuntime(
            composition: DocumentEngineRuntimeCompositionFactory.live(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }

    public static func liveWorkflows(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentApplicationWorkflowRuntime {
        live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        ).workflows
    }
}

public enum DocumentRuntimeFactory {
    public static func live(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentRuntime {
        DocumentRuntime(
            composition: DocumentEngineRuntimeCompositionFactory.live(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }
}

public enum DocumentProjectPreviewLoader {
    public static func loadPreview(
        from url: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) throws -> PrimoDocumentRuntime.DocumentProjectPreview {
        try PrimoDocumentRuntime.DocumentProjectPreview(
            PrimoDocumentEngineInfrastructure.DocumentProjectPreviewLoader.loadPreview(
                from: url,
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }
}

private extension PrimoDocumentRuntime.DocumentProjectPreview {
    init(_ infrastructure: PrimoDocumentEngineInfrastructure.DocumentProjectPreview) {
        self.init(
            canvasSize: infrastructure.canvasSize,
            layerCount: infrastructure.layerCount,
            previewSurface: infrastructure.previewSurface
        )
    }
}

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
