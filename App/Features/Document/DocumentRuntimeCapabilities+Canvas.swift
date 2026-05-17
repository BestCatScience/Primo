import CoreGraphics
import Foundation
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime

struct DocumentCanvasMutationCapability: Sendable {
    let canvasMutationRuntime: CanvasMutationRuntime
    let presentationRuntime: DocumentPresentationRuntime
    let persistenceRuntime: DocumentPersistenceRuntime
}

protocol CanvasEditingExecuting: Sendable {
    func execute(_ command: CanvasEditingCommand, state context: CanvasEditingContext) -> CanvasEditingOutcome
}

protocol CanvasTransformPort: CanvasEditingExecuting, LayerTransformProcessing {}

protocol CanvasEditingPresentationPort: Sendable {
    var renderingWorkflow: DocumentRenderingWorkflow { get }
    var presentationReader: DocumentPresentationReader { get }
}
