import ComposableArchitecture
import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain

extension RootFeatureWorkflowReducer {
    enum CanvasLifecycleContractFailure: Error, Equatable, Sendable, FailureReason {
        case unsupportedCanvasSize
        case invalidImageData
        case unsupportedImageSize
        case undoUnavailableWhileDrawing
        case redoUnavailableWhileDrawing
    }

    typealias CanvasDimensions = DocumentFeature.CanvasDimensions
    typealias ImportedCanvasPlan = ImportExportFeature.ImportedCanvasPlan

    typealias FreshDocumentReplacementContract = DocumentFeature.FreshDocumentReplacementContract

    struct PreparedFreshDocumentReplacement {
        let contract: FreshDocumentReplacementContract
        let preparedTab: PreparedWorkspaceTab
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
            cancelEffects: () -> Effect<Action>,
            mapFailureMessage: (WorkspacePersistenceFailure, AppLanguage) -> String?
        ) -> Effect<Action> {
            let activationSucceeded: Bool
            let failureEffect: Effect<Action>
            if case let .failure(failure) = activatePreparedTab(
                preparedReplacement.preparedTab,
                &state
            ) {
                failureEffect = .send(.application(.bannerPresented(
                    mapFailureMessage(failure, state.application.appLanguage)
                )))
                activationSucceeded = false
            } else {
                failureEffect = .none
                activationSucceeded = true
            }
            let successEffect: Effect<Action>
            if activationSucceeded, let successFeedback = preparedReplacement.contract.successFeedback {
                successEffect = .send(.application(.feedbackPresented(successFeedback)))
            } else {
                successEffect = .none
            }
            return .merge(cancelEffects(), failureEffect, successEffect)
        }
    }

    struct CanvasLifecycleFeedbackMapper: Sendable {
        func feedback(for failure: CanvasLifecycleContractFailure) -> ApplicationFeedback {
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

    var freshDocumentWorkspaceCoordinator: FreshDocumentWorkspaceCoordinator {
        FreshDocumentWorkspaceCoordinator()
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

    var freshDocumentActivationCoordinator: FreshDocumentActivationCoordinator {
        FreshDocumentActivationCoordinator()
    }

    func validatedCanvasDimensions(
        width: Int,
        height: Int
    ) -> CanvasDimensions? {
        CanvasDimensions(width: width, height: height)
    }

    func cancelStartupPresentationEffects() -> Effect<Action> {
        .merge(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh),
            .cancel(id: CancelID.workspaceProjectLoad)
        )
    }

    static func importedCanvasRequest(from imageData: Data) -> Result<ImportedCanvasRequest, CanvasLifecycleContractFailure> {
        guard let importedImage = DocumentFeature.importedCanvasImage(from: imageData) else {
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
                width: dimensions.width,
                height: dimensions.height,
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

    func presentCanvasLifecycleFailure(
        _ failure: CanvasLifecycleContractFailure,
        state: inout State
    ) -> Effect<Action> {
        .send(.application(.feedbackPresented(canvasLifecycleFeedbackMapper.feedback(for: failure))))
    }

    func applyFreshDocumentWorkspaceState(
        _ preparedReplacement: PreparedFreshDocumentReplacement,
        state: inout State
    ) {
        freshDocumentWorkspaceCoordinator.apply(
            preparedReplacement,
            to: &state,
            prepareFreshDocument: { canvasSize, state in
                state.document.canvas = CanvasFeature.State()
                state.document.canvas.setCanvasSize(canvasSize)
                state.document.layerSidebar = LayerSidebarFeature.State()
                state.document.brushPalette = BrushPaletteFeature.State()
                DocumentFeature.toolPanelStateCoordinator.resetPanels(in: &state.document)
                state.importExport.export.clearOutputs()
            },
            applyCurrentPresentation: { state in
                _ = applyPresentation(documentQueryGateway.presentation(), state: &state)
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
            .workspace(.persistenceRequested(
                .reserveNewTabBackingStore(
                    WorkspaceTabReservationRequest(
                        title: contract.tabTitle,
                        sourceProjectURL: nil,
                        pane: state.workspace.focusedWorkspacePane
                    )
                )
            ))
        )
    }

    func performFreshDocumentMutation(
        _ pendingMutation: PendingFreshDocumentMutation
    ) -> DocumentMutationResult {
        switch pendingMutation.operation {
        case let .newCanvas(dimensions):
            return createCanvas(dimensions)
        case let .importedCanvas(plan):
            return initializeImportedCanvas(
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
                return .send(.application(.feedbackPresented(feedback)))
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
                .workspace(.persistenceRequested(
                    .prepareDocumentReplacement(request)
                ))
            )
        case let .failure(failure):
            persistenceEffect = .send(.application(.bannerPresented(
                workspaceFeedbackMapper.message(
                    for: workspaceFeedbackMapper.feedback(for: failure),
                    language: state.application.appLanguage
                )
            )))
        }

        return .merge(
            .send(.application(.showWorkspaceRequested)),
            .send(.application(.bannerDismissed)),
            .send(.application(.hydrationFinished())),
            freshDocumentActivationCoordinator.activate(
                preparedReplacement,
                state: &state,
                activatePreparedTab: { preparedTab, state in
                    activatePreparedTab(preparedTab, state: &state)
                },
                cancelEffects: {
                    cancelStartupPresentationEffects()
                },
                mapFailureMessage: { failure, language in
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: language
                    )
                }
            ),
            .send(.document(.paperStyleSyncRequested(resolvedPaperStyle(for: state)))),
            persistenceEffect
        )
    }

    func handleNewCanvasRequest(
        state: inout State,
        width: Int,
        height: Int
    ) -> Effect<Action> {
        guard let dimensions = validatedCanvasDimensions(width: width, height: height) else {
            return presentCanvasLifecycleFailure(.unsupportedCanvasSize, state: &state)
        }
        let prepareRequest: WorkspaceDocumentReplacementRequest?
        if state.application.showsHome {
            prepareRequest = nil
        } else {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                prepareRequest = request
            case let .failure(failure):
                return .send(.application(.bannerPresented(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                )))
            }
        }
        return documentReplacementPreparationEffect(
            request: prepareRequest,
            onPrepared: { .document(.newCanvasPreparationCompleted(dimensions)) },
            onFailure: { .workspace(.persistenceFailed($0)) }
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

    func handleNewCanvasFromImageReceived(
        state: inout State,
        name: String?,
        data: Data
    ) -> Effect<Action> {
        let namingPolicy = DocumentFeature.DocumentNamingPolicy(language: state.application.appLanguage)
        let importedPlan: ImportedCanvasPlan
        switch Self.importedCanvasPlan(
            name: name,
            data: data,
            namingPolicy: namingPolicy
        ) {
        case let .success(plan):
            importedPlan = plan
        case let .failure(error):
            return presentCanvasLifecycleFailure(error, state: &state)
        }
        let prepareRequest: WorkspaceDocumentReplacementRequest?
        if state.application.showsHome {
            prepareRequest = nil
        } else {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                prepareRequest = request
            case let .failure(failure):
                return .send(.application(.bannerPresented(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                )))
            }
        }
        return documentReplacementPreparationEffect(
            request: prepareRequest,
            onPrepared: { .importExport(.newCanvasFromImagePreparationCompleted(importedPlan)) },
            onFailure: { .workspace(.persistenceFailed($0)) }
        )
    }

    func handleNewCanvasFromImagePreparationCompleted(
        state: inout State,
        plan: ImportedCanvasPlan
    ) -> Effect<Action> {
        return beginFreshDocumentTabReservation(
            state: &state,
            contract: FreshDocumentReplacementContract(
                canvasSize: CGSize(width: plan.request.width, height: plan.request.height),
                tabTitle: plan.layerName,
                successFeedback: .canvasCreatedFromImage,
                mutationFailureFeedback: .couldNotCreateCanvasFromImage(nil)
            ),
            operation: .importedCanvas(plan)
        )
    }
}
