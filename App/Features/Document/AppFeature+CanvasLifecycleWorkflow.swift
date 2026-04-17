import ComposableArchitecture
import CoreGraphics
import Foundation

extension AppFeature {
    enum CanvasLifecycleContractFailure: Error, Equatable {
        case unsupportedCanvasSize
        case invalidImageData
        case unsupportedImageSize
        case undoUnavailableWhileDrawing
        case redoUnavailableWhileDrawing

        var feedback: ApplicationFeedback {
            switch self {
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

    struct CanvasDimensions: Equatable {
        let width: Int
        let height: Int

        init?(width: Int, height: Int) {
            guard width > 0, height > 0 else { return nil }
            self.width = width
            self.height = height
        }

        func isWithin(_ supportedRange: ClosedRange<Int>) -> Bool {
            supportedRange.contains(width) && supportedRange.contains(height)
        }

        var size: CGSize {
            CGSize(width: width, height: height)
        }
    }

    struct ImportedCanvasRequest: Equatable {
        let dimensions: CanvasDimensions
        let pixelData: Data
    }

    struct ImportedCanvasPlan: Equatable {
        let request: ImportedCanvasRequest
        let layerName: String
    }

    struct CanvasResizePlan: Equatable {
        let dimensions: CanvasDimensions
        let successFeedback: ApplicationFeedback
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

    struct CanvasLifecycleService {
        let paintDocumentClient: PaintDocumentClient

        func createCanvas(_ dimensions: CanvasDimensions) {
            paintDocumentClient.newCanvas(dimensions.width, dimensions.height)
            paintDocumentClient.prewarmDrawingResources()
        }

        func resizeCanvas(_ dimensions: CanvasDimensions) {
            paintDocumentClient.resizeCanvas(dimensions.width, dimensions.height)
        }

        func resizeCanvasExtent(_ dimensions: CanvasDimensions) {
            paintDocumentClient.resizeCanvasExtent(dimensions.width, dimensions.height)
        }

        func initializeImportedCanvas(
            _ request: ImportedCanvasRequest,
            layerName: String
        ) {
            createCanvas(request.dimensions)
            paintDocumentClient.replaceLayerPixels(0, request.pixelData)
            paintDocumentClient.setLayerName(0, layerName)
            paintDocumentClient.setActiveLayer(0)
        }

        func undo() -> Bool {
            paintDocumentClient.undo()
        }

        func redo() -> Bool {
            paintDocumentClient.redo()
        }
    }

    var canvasLifecycleService: CanvasLifecycleService {
        CanvasLifecycleService(paintDocumentClient: paintDocumentClient)
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

    func cancelStartupPresentationEffects() -> Effect<Action> {
        .merge(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    static func importedCanvasRequest(from imageData: Data) -> Result<ImportedCanvasRequest, CanvasLifecycleContractFailure> {
        guard let importedImage = importedCanvasImage(from: imageData) else {
            return .failure(.invalidImageData)
        }
        guard let dimensions = CanvasDimensions(
            width: importedImage.width,
            height: importedImage.height
        ) else {
            return .failure(.invalidImageData)
        }
        guard dimensions.isWithin(64...8192) else {
            return .failure(.unsupportedImageSize)
        }
        return .success(
            ImportedCanvasRequest(
                dimensions: dimensions,
                pixelData: importedImage.pixelData
            )
        )
    }

    static func importedCanvasPlan(
        name: String?,
        data: Data,
        namingPolicy: DocumentNamingPolicy
    ) -> Result<ImportedCanvasPlan, CanvasLifecycleContractFailure> {
        switch importedCanvasRequest(from: data) {
        case let .success(request):
            return .success(
                ImportedCanvasPlan(
                    request: request,
                    layerName: namingPolicy.importedCanvasLayerName(from: name)
                )
            )
        case let .failure(error):
            return .failure(error)
        }
    }

    func validatedResizePlan(
        currentDimensions: CanvasDimensions?,
        width: Int,
        height: Int,
        successFeedback: ApplicationFeedback
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
        _ failure: CanvasLifecycleContractFailure,
        state: inout State
    ) {
        state.application.presentFeedback(failure.feedback)
    }

    func completeFreshDocumentReplacement(
        state: inout State,
        canvasSize: CGSize,
        tabTitle: String,
        successFeedback: ApplicationFeedback? = nil,
        documentMutation: () -> Void
    ) -> Effect<Action> {
        let preparedTab: PreparedWorkspaceTab
        switch prepareNewTabReservation(
            title: tabTitle,
            sourceProjectURL: nil,
            state: state
        ) {
        case let .success(tab):
            preparedTab = tab
        case let .failure(failure):
            state.application.presentFeedback(failure.feedback)
            return .none
        }
        documentMutation()
        AppFeature.canvasPresentationStateCoordinator.prepareFreshDocument(
            canvasSize: canvasSize,
            to: &state
        )
        syncPaperStyleToDocument(state: &state)
        applyCurrentDocumentPresentation(state: &state)
        let activationSucceeded: Bool
        if case let .failure(failure) = activatePreparedTab(preparedTab, state: &state) {
            state.application.presentFeedback(failure.feedback)
            activationSucceeded = false
        } else {
            activationSucceeded = true
        }
        if activationSucceeded, let successFeedback {
            state.application.presentFeedback(successFeedback)
        }
        return cancelStartupPresentationEffects()
    }

    func handleHistoryMutationRequest(
        state: inout State,
        operation: CanvasHistoryOperation,
        performMutation: () -> Bool
    ) {
        if state.canvas.isStrokeActive {
            presentCanvasLifecycleFailure(
                operation == .undo ? .undoUnavailableWhileDrawing : .redoUnavailableWhileDrawing,
                state: &state
            )
            return
        }
        guard performMutation() else {
            return
        }
        state.canvas.clearSelection()
        applyDirtyPresentation(state: &state)
    }

    func handleNewCanvasRequest(
        state: inout State,
        width: Int,
        height: Int
    ) -> Effect<Action> {
        guard let dimensions = validatedCanvasDimensions(width: width, height: height) else {
            presentCanvasLifecycleFailure(.unsupportedCanvasSize, state: &state)
            return .none
        }
        switch prepareForDocumentReplacement(state: &state) {
        case .success:
            break
        case let .failure(failure):
            state.application.presentFeedback(failure.feedback)
            return .none
        }
        return completeFreshDocumentReplacement(
            state: &state,
            canvasSize: dimensions.size,
            tabTitle: Self.nextUntitledTabTitle(existingTabs: state.workspace.openTabs),
            documentMutation: { canvasLifecycleService.createCanvas(dimensions) }
        )
    }

    func handleResizeCanvasRequest(
        state: inout State,
        width: Int,
        height: Int
    ) {
        switch validatedResizePlan(
            currentDimensions: currentCanvasDimensions(state: state),
            width: width,
            height: height,
            successFeedback: .imageResolutionUpdated
        ) {
        case let .invalid(error):
            presentCanvasLifecycleFailure(error, state: &state)
        case .unchanged:
            return
        case let .valid(plan):
            canvasLifecycleService.resizeCanvas(plan.dimensions)
            state.canvas.resetTransientEditingState()
            applyDirtyPresentation(state: &state)
            state.application.presentFeedback(plan.successFeedback)
        }
    }

    func handleResizeCanvasExtentRequest(
        state: inout State,
        width: Int,
        height: Int
    ) {
        switch validatedResizePlan(
            currentDimensions: currentCanvasDimensions(state: state),
            width: width,
            height: height,
            successFeedback: .canvasSizeUpdated
        ) {
        case let .invalid(error):
            presentCanvasLifecycleFailure(error, state: &state)
        case .unchanged:
            return
        case let .valid(plan):
            canvasLifecycleService.resizeCanvasExtent(plan.dimensions)
            state.canvas.resetTransientEditingState()
            applyDirtyPresentation(state: &state)
            state.application.presentFeedback(plan.successFeedback)
        }
    }

    func handleNewCanvasFromImageReceived(
        state: inout State,
        name: String?,
        data: Data
    ) -> Effect<Action> {
        let namingPolicy = namingPolicy(for: state)
        let importedPlan: ImportedCanvasPlan
        switch Self.importedCanvasPlan(
            name: name,
            data: data,
            namingPolicy: namingPolicy
        ) {
        case let .success(plan):
            importedPlan = plan
        case let .failure(error):
            presentCanvasLifecycleFailure(error, state: &state)
            return .none
        }
        switch prepareForDocumentReplacement(state: &state) {
        case .success:
            break
        case let .failure(failure):
            state.application.presentFeedback(failure.feedback)
            return .none
        }
        return completeFreshDocumentReplacement(
            state: &state,
            canvasSize: importedPlan.request.dimensions.size,
            tabTitle: importedPlan.layerName,
            successFeedback: .canvasCreatedFromImage,
            documentMutation: {
                canvasLifecycleService.initializeImportedCanvas(
                    importedPlan.request,
                    layerName: importedPlan.layerName
                )
            }
        )
    }

    func handleUndoRequested(state: inout State) {
        handleHistoryMutationRequest(
            state: &state,
            operation: .undo,
            performMutation: { canvasLifecycleService.undo() }
        )
    }

    func handleRedoRequested(state: inout State) {
        handleHistoryMutationRequest(
            state: &state,
            operation: .redo,
            performMutation: { canvasLifecycleService.redo() }
        )
    }
}
