import ComposableArchitecture
import Foundation

struct DocumentLifecycleReducer: Reducer {
    typealias State = DocumentEditingState
    typealias CanvasDimensions = DocumentFeature.CanvasDimensions
    typealias FreshDocumentMutationRequest = DocumentFeature.FreshDocumentMutationRequest
    typealias DocumentMutationContract = DocumentFeature.DocumentMutationContract
    typealias DocumentMutationFeedbackMapper = DocumentFeature.DocumentMutationFeedbackMapper
    typealias WorkspaceDocumentSnapshot = DocumentFeature.WorkspaceDocumentSnapshot

    @Dependency(\.documentCanvasCommandService) var documentCanvasCommandService
    @Dependency(\.documentExportGateway) var documentExportGateway
    @Dependency(\.documentRenderingWorkflow) var documentRenderingWorkflow
    @Dependency(\.documentHistoryCommandService) var documentHistoryCommandService
    @Dependency(\.documentPresentationReader) var documentPresentationReader

    enum Action: Equatable {
        case freshDocumentMutationRequested(DocumentFeature.FreshDocumentMutationRequest)
        case newCanvasRequested(width: Int, height: Int)
        case newCanvasPreparationCompleted(DocumentFeature.CanvasDimensions)
        case newCanvasFromImagePreparationCompleted(ImportExportFeature.ImportedCanvasPlan)
        case undoRequested
        case redoRequested
        case memoryPressureTrimRequested
        case resizeCanvasRequested(width: Int, height: Int)
        case resizeCanvasExtentRequested(width: Int, height: Int)
        case delegate(DocumentFeature.Action.Delegate)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .freshDocumentMutationRequested(request):
            return handleFreshDocumentMutationRequest(state: &state, request: request)

        case let .newCanvasRequested(width, height):
            guard let dimensions = validatedCanvasDimensions(width: width, height: height) else {
                return presentCanvasLifecycleFailure(.unsupportedCanvasSize)
            }
            return freshDocumentRequestEffect(dimensions)

        case let .newCanvasPreparationCompleted(dimensions):
            return freshDocumentRequestEffect(dimensions)

        case let .newCanvasFromImagePreparationCompleted(plan):
            return .send(
                .delegate(
                    .freshDocumentRequested(
                        DocumentFeature.FreshDocumentReplacementContract(
                            canvasSize: CGSize(width: plan.request.width, height: plan.request.height),
                            tabTitle: plan.layerName,
                            successFeedback: .canvasCreatedFromImage,
                            mutationFailureFeedback: .couldNotCreateCanvasFromImage(nil)
                        ),
                        .importedCanvas(plan)
                    )
                )
            )

        case let .resizeCanvasRequested(width, height):
            return handleResizeCanvasRequest(state: &state, width: width, height: height)

        case let .resizeCanvasExtentRequested(width, height):
            return handleResizeCanvasExtentRequest(state: &state, width: width, height: height)

        case .undoRequested:
            return handleUndoRequested(state: &state)

        case .redoRequested:
            return handleRedoRequested(state: &state)

        case .memoryPressureTrimRequested:
            documentHistoryCommandService.trimForMemoryPressure()
            return .none

        case .delegate:
            return .none
        }
    }

    private func freshDocumentRequestEffect(_ dimensions: DocumentFeature.CanvasDimensions) -> Effect<Action> {
        .send(
            .delegate(
                .freshDocumentRequested(
                    DocumentFeature.FreshDocumentReplacementContract(
                        canvasSize: dimensions.size,
                        tabTitle: "Untitled"
                    ),
                    .newCanvas(dimensions)
                )
            )
        )
    }
}
