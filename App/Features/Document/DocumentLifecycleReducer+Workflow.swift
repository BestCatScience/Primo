import ComposableArchitecture
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts

extension DocumentLifecycleReducer {
    func workspaceDocumentSnapshot(state: State) -> WorkspaceDocumentSnapshot {
        DocumentFeature.workspaceSnapshotCoordinator.snapshot(
            state: state,
            documentExportGateway: documentExportGateway,
            documentGpuOperationGateway: documentGpuOperationGateway
        )
    }

    enum CanvasLifecycleContractFailure: Error, Equatable, Sendable, FailureReason {
        case unsupportedCanvasSize
        case invalidImageData
        case unsupportedImageSize
        case undoUnavailableWhileDrawing
        case redoUnavailableWhileDrawing
    }

    struct CanvasResizePlan: Equatable {
        let dimensions: CanvasDimensions
        let successFeedback: ApplicationFeature.Feedback
    }

    enum CanvasResizeValidation: Equatable {
        case invalid(CanvasLifecycleContractFailure)
        case unchanged
        case valid(CanvasResizePlan)
    }

    enum CanvasHistoryOperation: Equatable {
        case undo
        case redo
    }

    struct CanvasLifecycleFeedbackMapper: Sendable {
        func feedback(for failure: CanvasLifecycleContractFailure) -> ApplicationFeature.Feedback {
            switch failure {
            case .unsupportedCanvasSize:
                return .canvasSizeUnsupported
            case .invalidImageData:
                return .couldNotCreateCanvasFromImage(nil)
            case .unsupportedImageSize:
                return .imageSizeUnsupported
            case .undoUnavailableWhileDrawing:
                return .undoUnavailableWhileDrawing
            case .redoUnavailableWhileDrawing:
                return .redoUnavailableWhileDrawing
            }
        }
    }

    var canvasLifecycleFeedbackMapper: CanvasLifecycleFeedbackMapper {
        CanvasLifecycleFeedbackMapper()
    }

    func resizeCanvas(_ dimensions: CanvasDimensions) -> DocumentMutationResult {
        documentCanvasCommandService.resizeCanvas(
            dimensions.width,
            dimensions.height
        )
    }

    func resizeCanvasExtent(_ dimensions: CanvasDimensions) -> DocumentMutationResult {
        documentCanvasCommandService.resizeCanvasExtent(
            dimensions.width,
            dimensions.height
        )
    }

    func undoCanvasMutation() -> DocumentMutationResult {
        documentHistoryCommandService.undo()
    }

    func redoCanvasMutation() -> DocumentMutationResult {
        documentHistoryCommandService.redo()
    }

    func createCanvas(_ dimensions: CanvasDimensions) -> DocumentMutationResult {
        documentCanvasCommandService.createCanvas(
            dimensions.width,
            dimensions.height
        )
    }

    func initializeImportedCanvas(
        _ request: ImportedCanvasRequest,
        layerName: String
    ) -> DocumentMutationResult {
        documentCanvasCommandService.initializeImportedCanvas(
            request,
            layerName
        )
    }

    func validatedCanvasDimensions(
        width: Int,
        height: Int
    ) -> CanvasDimensions? {
        CanvasDimensions(width: width, height: height)
    }

    func currentCanvasDimensions(state: State) -> CanvasDimensions? {
        CanvasDimensions(
            width: Int(state.canvas.canvasSize.width.rounded()),
            height: Int(state.canvas.canvasSize.height.rounded())
        )
    }

    func validatedResizePlan(
        currentDimensions: CanvasDimensions?,
        width: Int,
        height: Int,
        successFeedback: ApplicationFeature.Feedback
    ) -> CanvasResizeValidation {
        guard let dimensions = validatedCanvasDimensions(width: width, height: height) else {
            return .invalid(.unsupportedCanvasSize)
        }
        guard let currentDimensions else {
            return .invalid(.unsupportedCanvasSize)
        }
        guard dimensions != currentDimensions else {
            return .unchanged
        }
        return .valid(
            CanvasResizePlan(
                dimensions: dimensions,
                successFeedback: successFeedback
            )
        )
    }

    func presentCanvasLifecycleFailure(
        _ failure: CanvasLifecycleContractFailure
    ) -> Effect<Action> {
        .send(.delegate(.documentMutationFeedback(canvasLifecycleFeedbackMapper.feedback(for: failure))))
    }

    func handleHistoryMutationRequest(
        state: inout State,
        operation: CanvasHistoryOperation,
        performMutation: () -> DocumentMutationResult
    ) -> Effect<Action> {
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(
                canvasMutation: .clearSelection,
                refresh: .current
            ),
            mutation: performMutation,
            onSuccess: { _, state in
                state.canvas.resetTransientEditingState()
            }
        )
    }

    func handleResizeCanvasRequest(
        state: inout State,
        width: Int,
        height: Int
    ) -> Effect<Action> {
        switch validatedResizePlan(
            currentDimensions: currentCanvasDimensions(state: state),
            width: width,
            height: height,
            successFeedback: .imageResolutionUpdated
        ) {
        case let .invalid(error):
            return presentCanvasLifecycleFailure(error)
        case .unchanged:
            return .none
        case let .valid(plan):
            return performDocumentMutation(
                state: &state,
                contract: DocumentMutationContract(
                    canvasMutation: .resetTransientEditingState,
                    successFeedback: plan.successFeedback
                ),
                mutation: {
                    resizeCanvas(plan.dimensions)
                }
            )
        }
    }

    func handleResizeCanvasExtentRequest(
        state: inout State,
        width: Int,
        height: Int
    ) -> Effect<Action> {
        switch validatedResizePlan(
            currentDimensions: currentCanvasDimensions(state: state),
            width: width,
            height: height,
            successFeedback: .canvasSizeUpdated
        ) {
        case let .invalid(error):
            return presentCanvasLifecycleFailure(error)
        case .unchanged:
            return .none
        case let .valid(plan):
            return performDocumentMutation(
                state: &state,
                contract: DocumentMutationContract(
                    canvasMutation: .resetTransientEditingState,
                    successFeedback: plan.successFeedback
                ),
                mutation: {
                    resizeCanvasExtent(plan.dimensions)
                }
            )
        }
    }

    func handleUndoRequested(state: inout State) -> Effect<Action> {
        handleHistoryMutationRequest(
            state: &state,
            operation: .undo,
            performMutation: { undoCanvasMutation() }
        )
    }

    func handleRedoRequested(state: inout State) -> Effect<Action> {
        handleHistoryMutationRequest(
            state: &state,
            operation: .redo,
            performMutation: { redoCanvasMutation() }
        )
    }

    func handleFreshDocumentMutationRequest(
        state: inout State,
        request: FreshDocumentMutationRequest
    ) -> Effect<Action> {
        let result: DocumentMutationResult
        switch request.operation {
        case let .newCanvas(dimensions):
            result = createCanvas(dimensions)
        case let .importedCanvas(plan):
            result = initializeImportedCanvas(plan.request, layerName: plan.layerName)
        }

        switch result {
        case .success:
            state.canvas = CanvasFeature.State()
            state.canvas.setCanvasSize(request.contract.canvasSize)
            state.layerSidebar = LayerSidebarFeature.State()
            state.brushPalette = BrushPaletteFeature.State()
            DocumentFeature.toolPanelStateCoordinator.resetPanels(in: &state)
            _ = documentMutationWorkflowSupport.applyPresentation(documentQueryGateway.presentation(), to: &state)
            return .send(
                .delegate(
                    .freshDocumentMutationSucceeded(
                        request.preparedTab,
                        request.contract,
                        workspaceDocumentSnapshot(state: state)
                    )
                )
            )

        case let .failure(failure):
            let feedback = DocumentMutationFeedbackMapper().feedback(
                for: failure,
                default: request.contract.mutationFailureFeedback
            )
            return .send(.delegate(.freshDocumentMutationFailed(feedback)))
        }
    }
}
