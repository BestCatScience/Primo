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

    struct CanvasDimensions: Equatable, Sendable {
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

    struct ImportedCanvasRequest: Equatable, Sendable {
        let dimensions: CanvasDimensions
        let pixelData: Data
    }

    struct ImportedCanvasPlan: Equatable, Sendable {
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

    struct FreshDocumentReplacementContract: Equatable, Sendable {
        let canvasSize: CGSize
        let tabTitle: String
        var successFeedback: ApplicationFeedback? = nil
        var mutationFailureFeedback: ApplicationFeedback? = nil
    }

    struct PreparedFreshDocumentReplacement {
        let contract: FreshDocumentReplacementContract
        let preparedTab: PreparedWorkspaceTab
    }

    struct FreshDocumentReservationCoordinator {
        func prepare(
            contract: FreshDocumentReplacementContract,
            state: inout State,
            reserveTab: (String, DocumentProjectPath?, State) -> Result<PreparedWorkspaceTab, WorkspacePersistenceFailure>
        ) -> PreparedFreshDocumentReplacement? {
            switch reserveTab(
                contract.tabTitle,
                nil,
                state
            ) {
            case let .success(preparedTab):
                return PreparedFreshDocumentReplacement(
                    contract: contract,
                    preparedTab: preparedTab
                )
            case let .failure(failure):
                state.application.presentFeedback(failure.feedback)
                return nil
            }
        }
    }

    struct FreshDocumentWorkspaceCoordinator {
        func apply(
            _ preparedReplacement: PreparedFreshDocumentReplacement,
            to state: inout State,
            prepareFreshDocument: (CGSize, inout State) -> Void,
            applyCurrentPresentation: (inout State) -> Void
        ) {
            prepareFreshDocument(
                preparedReplacement.contract.canvasSize,
                &state
            )
            applyCurrentPresentation(&state)
        }
    }

    struct FreshDocumentActivationCoordinator {
        func activate(
            _ preparedReplacement: PreparedFreshDocumentReplacement,
            state: inout State,
            activatePreparedTab: (PreparedWorkspaceTab, inout State) -> Result<Void, WorkspacePersistenceFailure>,
            cancelEffects: () -> Effect<Action>
        ) -> Effect<Action> {
            let activationSucceeded: Bool
            if case let .failure(failure) = activatePreparedTab(
                preparedReplacement.preparedTab,
                &state
            ) {
                state.application.presentFeedback(failure.feedback)
                activationSucceeded = false
            } else {
                activationSucceeded = true
            }
            if activationSucceeded, let successFeedback = preparedReplacement.contract.successFeedback {
                state.application.presentFeedback(successFeedback)
            }
            return cancelEffects()
        }
    }

    struct FreshDocumentReplacementCoordinator {
        func complete(
            state: inout State,
            contract: FreshDocumentReplacementContract,
            documentMutation: () -> DocumentMutationResult,
            prepareReplacement: (FreshDocumentReplacementContract, inout State) -> PreparedFreshDocumentReplacement?,
            applyWorkspaceState: (PreparedFreshDocumentReplacement, inout State) -> Void,
            activateReplacement: (PreparedFreshDocumentReplacement, inout State) -> Effect<Action>,
            mapMutationFailureFeedback: (DocumentMutationFailure, ApplicationFeedback?) -> ApplicationFeedback?
        ) -> Effect<Action> {
            guard let preparedReplacement = prepareReplacement(
                contract,
                &state
            ) else {
                return .none
            }
            switch documentMutation() {
            case .success:
                break
            case let .failure(failure):
                if let feedback = mapMutationFailureFeedback(
                    failure,
                    preparedReplacement.contract.mutationFailureFeedback
                ) {
                    state.application.presentFeedback(feedback)
                }
                return .none
            }
            applyWorkspaceState(preparedReplacement, &state)
            return activateReplacement(preparedReplacement, &state)
        }
    }

    struct CanvasLifecycleService {
        let paintDocumentClient: PaintDocumentClient

        func createCanvas(_ dimensions: CanvasDimensions) -> DocumentMutationResult {
            paintDocumentClient.newCanvas(dimensions.width, dimensions.height)
            paintDocumentClient.prewarmDrawingResources()
            return .success(())
        }

        func resizeCanvas(_ dimensions: CanvasDimensions) -> DocumentMutationResult {
            paintDocumentClient.resizeCanvas(dimensions.width, dimensions.height)
        }

        func resizeCanvasExtent(_ dimensions: CanvasDimensions) -> DocumentMutationResult {
            paintDocumentClient.resizeCanvasExtent(dimensions.width, dimensions.height)
        }

        func initializeImportedCanvas(
            _ request: ImportedCanvasRequest,
            layerName: String
        ) -> DocumentMutationResult {
            switch createCanvas(request.dimensions) {
            case .success:
                break
            case let .failure(failure):
                return .failure(failure)
            }
            switch paintDocumentClient.replaceLayerPixels(0, request.pixelData) {
            case .success:
                break
            case let .failure(failure):
                return .failure(failure)
            }
            switch paintDocumentClient.setLayerName(0, layerName) {
            case .success:
                break
            case let .failure(failure):
                return .failure(failure)
            }
            return paintDocumentClient.setActiveLayer(0)
        }

        func undo() -> DocumentMutationResult {
            paintDocumentClient.undo()
        }

        func redo() -> DocumentMutationResult {
            paintDocumentClient.redo()
        }
    }

    var canvasLifecycleService: CanvasLifecycleService {
        CanvasLifecycleService(paintDocumentClient: paintDocumentClient)
    }

    var freshDocumentReservationCoordinator: FreshDocumentReservationCoordinator {
        FreshDocumentReservationCoordinator()
    }

    var freshDocumentWorkspaceCoordinator: FreshDocumentWorkspaceCoordinator {
        FreshDocumentWorkspaceCoordinator()
    }

    var freshDocumentActivationCoordinator: FreshDocumentActivationCoordinator {
        FreshDocumentActivationCoordinator()
    }

    var freshDocumentReplacementCoordinator: FreshDocumentReplacementCoordinator {
        FreshDocumentReplacementCoordinator()
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

    func applyFreshDocumentWorkspaceState(
        _ preparedReplacement: PreparedFreshDocumentReplacement,
        state: inout State
    ) {
        freshDocumentWorkspaceCoordinator.apply(
            preparedReplacement,
            to: &state,
            prepareFreshDocument: { canvasSize, state in
                AppFeature.canvasPresentationStateCoordinator.prepareFreshDocument(
                    canvasSize: canvasSize,
                    to: &state
                )
            },
            applyCurrentPresentation: { state in
                applyPresentation(documentPresentationQueryService.presentation(), state: &state)
            }
        )
    }

    func beginFreshDocumentTabReservation(
        state: inout State,
        contract: FreshDocumentReplacementContract,
        operation: PendingFreshDocumentMutation.Operation
    ) -> Effect<Action> {
        state.workspace.pendingWorkspaceTabReservation = .freshDocument(
            PendingFreshDocumentMutation(
                contract: contract,
                operation: operation
            )
        )
        return .send(
            .workspacePersistenceRequested(
                .reserveNewTabBackingStore(
                    WorkspaceTabReservationRequest(
                        title: contract.tabTitle,
                        sourceProjectURL: nil,
                        pane: state.workspace.focusedWorkspacePane
                    )
                )
            )
        )
    }

    func performFreshDocumentMutation(
        _ pendingMutation: PendingFreshDocumentMutation
    ) -> DocumentMutationResult {
        switch pendingMutation.operation {
        case let .newCanvas(dimensions):
            return canvasLifecycleService.createCanvas(dimensions)
        case let .importedCanvas(plan):
            return canvasLifecycleService.initializeImportedCanvas(
                plan.request,
                layerName: plan.layerName
            )
        }
    }

    func completeReservedFreshDocumentMutation(
        _ pendingMutation: PendingFreshDocumentMutation,
        preparedTab: PreparedWorkspaceTab,
        state: inout State
    ) -> Effect<Action> {
        let preparedReplacement = PreparedFreshDocumentReplacement(
            contract: pendingMutation.contract,
            preparedTab: preparedTab
        )
        switch performFreshDocumentMutation(pendingMutation) {
        case .success:
            break
        case let .failure(failure):
            if let feedback = documentMutationFeedbackMapper.feedback(
                for: failure,
                default: pendingMutation.contract.mutationFailureFeedback
            ) {
                state.application.presentFeedback(feedback)
            }
            return .none
        }
        applyFreshDocumentWorkspaceState(
            preparedReplacement,
            state: &state
        )
        return activateFreshDocumentReplacement(
            preparedReplacement,
            state: &state
        )
    }

    func activateFreshDocumentReplacement(
        _ preparedReplacement: PreparedFreshDocumentReplacement,
        state: inout State
    ) -> Effect<Action> {
        let persistenceEffect: Effect<Action>
        switch documentReplacementRequest(state: &state) {
        case let .success(request):
            persistenceEffect = .send(
                .workspacePersistenceRequested(
                    .prepareDocumentReplacement(request)
                )
            )
        case let .failure(failure):
            state.application.presentFeedback(failure.feedback)
            persistenceEffect = .none
        }

        return .merge(
            freshDocumentActivationCoordinator.activate(
                preparedReplacement,
                state: &state,
                activatePreparedTab: { preparedTab, state in
                    activatePreparedTab(preparedTab, state: &state)
                },
                cancelEffects: {
                    cancelStartupPresentationEffects()
                }
            ),
            documentPaperStyleSyncClient.synchronizeEffect(
                resolvedPaperStyle(for: state)
            ),
            persistenceEffect
        )
    }

    func handleHistoryMutationRequest(
        state: inout State,
        operation: CanvasHistoryOperation,
        performMutation: () -> DocumentMutationResult
    ) -> Effect<Action> {
        if state.canvas.isStrokeActive {
            presentCanvasLifecycleFailure(
                operation == .undo ? .undoUnavailableWhileDrawing : .redoUnavailableWhileDrawing,
                state: &state
            )
            return .none
        }
        return performDocumentMutation(
            state: &state,
            contract: DocumentMutationContract(canvasMutation: .clearSelection),
            mutation: performMutation
        )
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
        let prepareRequest: WorkspaceDocumentReplacementRequest?
        if state.application.showsHome {
            prepareRequest = nil
        } else {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                prepareRequest = request
            case let .failure(failure):
                state.application.presentFeedback(failure.feedback)
                return .none
            }
        }
        return documentReplacementPreparationEffect(
            request: prepareRequest,
            onPrepared: { .newCanvasPreparationCompleted(dimensions) },
            onFailure: { .workspacePersistenceFailed($0) }
        )
    }

    func handleNewCanvasPreparationCompleted(
        state: inout State,
        dimensions: CanvasDimensions
    ) -> Effect<Action> {
        return beginFreshDocumentTabReservation(
            state: &state,
            contract: FreshDocumentReplacementContract(
                canvasSize: dimensions.size,
                tabTitle: Self.nextUntitledTabTitle(existingTabs: state.workspace.openTabs)
            ),
            operation: .newCanvas(dimensions)
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
            presentCanvasLifecycleFailure(error, state: &state)
            return .none
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
                    canvasLifecycleService.resizeCanvas(plan.dimensions)
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
            presentCanvasLifecycleFailure(error, state: &state)
            return .none
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
                    canvasLifecycleService.resizeCanvasExtent(plan.dimensions)
                }
            )
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
        let prepareRequest: WorkspaceDocumentReplacementRequest?
        if state.application.showsHome {
            prepareRequest = nil
        } else {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                prepareRequest = request
            case let .failure(failure):
                state.application.presentFeedback(failure.feedback)
                return .none
            }
        }
        return documentReplacementPreparationEffect(
            request: prepareRequest,
            onPrepared: { .newCanvasFromImagePreparationCompleted(importedPlan) },
            onFailure: { .workspacePersistenceFailed($0) }
        )
    }

    func handleNewCanvasFromImagePreparationCompleted(
        state: inout State,
        plan: ImportedCanvasPlan
    ) -> Effect<Action> {
        return beginFreshDocumentTabReservation(
            state: &state,
            contract: FreshDocumentReplacementContract(
                canvasSize: plan.request.dimensions.size,
                tabTitle: plan.layerName,
                successFeedback: .canvasCreatedFromImage,
                mutationFailureFeedback: .couldNotCreateCanvasFromImage(nil)
            ),
            operation: .importedCanvas(plan)
        )
    }

    func handleUndoRequested(state: inout State) -> Effect<Action> {
        handleHistoryMutationRequest(
            state: &state,
            operation: .undo,
            performMutation: { canvasLifecycleService.undo() }
        )
    }

    func handleRedoRequested(state: inout State) -> Effect<Action> {
        handleHistoryMutationRequest(
            state: &state,
            operation: .redo,
            performMutation: { canvasLifecycleService.redo() }
        )
    }
}
