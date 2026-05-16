import Foundation
import PrimoDocumentMutationContracts
import PrimoDocumentRuntime

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
        let previewServices = DocumentPreviewServices(composition: composition)
        let mutationServices = DocumentMutationServices(
            composition: composition,
            previewServices: previewServices
        )
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
                    return mutationOutcome(mutationServices.canvasCommands.createCanvas(size.width, size.height).map { .completed })
                case let .resizeSized(size):
                    return mutationOutcome(mutationServices.canvasCommands.resizeCanvas(size.width, size.height).map { .completed })
                case let .resizeExtentSized(size):
                    return mutationOutcome(mutationServices.canvasCommands.resizeCanvasExtent(size.width, size.height).map { .completed })
                case let .initializeImported(request, layerName):
                    return mutationOutcome(mutationServices.canvasCommands.initializeImportedCanvas(request, layerName).map { .completed })
                case .compositeSurface:
                    return mutationServices.canvasCommands.compositeSurface()
                        .map(DocumentCommandOutcome.compositeSurface)
                        .getOrFailureOutcome()
                case let .setPaperStyle(style):
                    return mutationOutcome(composition.persistenceGateway.setPaperStyle(style).map { .completed })
                }
            case let .layer(command):
                switch command {
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
