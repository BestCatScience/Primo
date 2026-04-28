import ComposableArchitecture
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoWorkspaceApplication
import PrimoWorkspaceInfrastructure
import os

protocol PrimoFeatureRuntimeReducer {
    static var startupLogger: Logger { get }
}

extension PrimoFeatureRuntimeReducer {
    static var startupLogger: Logger { PrimoRootFeature.startupLogger }

    typealias State = PrimoRootFeature.State
    typealias Action = PrimoRootFeature.Action
    typealias ApplicationAction = ApplicationFeature.Action
    typealias WorkspaceAction = WorkspaceFeature.Action
    typealias DocumentAction = DocumentFeature.Action
    typealias EditingAction = DocumentFeature.EditingAction
    typealias AppScenePhase = ApplicationFeature.ScenePhase
    typealias ApplicationFeedback = ApplicationFeature.Feedback
    typealias DocumentNamingPolicy = DocumentFeature.DocumentNamingPolicy
    typealias CancelID = ApplicationFeature.CancelID
    typealias WorkspaceTabClosureDisposition = PrimoRootFeature.WorkspaceTabClosureDisposition
    typealias WorkspacePaneActivationDisposition = PrimoRootFeature.WorkspacePaneActivationDisposition
    typealias WorkspaceTabClosureResult = PrimoRootFeature.WorkspaceTabClosureResult

    typealias CanvasDimensions = DocumentFeatureRuntimeReducer.CanvasDimensions
    typealias ImportedCanvasPlan = DocumentFeatureRuntimeReducer.ImportedCanvasPlan
    typealias FreshDocumentReplacementContract = DocumentFeatureRuntimeReducer.FreshDocumentReplacementContract
    typealias PendingWorkspaceTabReservation = DocumentFeatureRuntimeReducer.PendingWorkspaceTabReservation
    typealias PendingLoadedWorkspaceProject = DocumentFeatureRuntimeReducer.PendingLoadedWorkspaceProject
    typealias PendingFreshDocumentMutation = DocumentFeatureRuntimeReducer.PendingFreshDocumentMutation
    typealias LoadedWorkspacePresentation = DocumentFeatureRuntimeReducer.LoadedWorkspacePresentation
    typealias WorkspaceFeedbackMapper = DocumentFeatureRuntimeReducer.WorkspaceFeedbackMapper
    typealias WorkspaceLoadFailureContext = DocumentFeatureRuntimeReducer.WorkspaceLoadFailureContext

    typealias WorkspacePersistenceIssue = PrimoWorkspaceApplication.WorkspacePersistenceIssue
    typealias WorkspacePersistenceFailureReason = PrimoWorkspaceApplication.WorkspacePersistenceFailureReason
    typealias WorkspacePersistenceFailure = PrimoWorkspaceApplication.WorkspacePersistenceFailure
    typealias WorkspaceDirtyPresentationRequest = PrimoWorkspaceApplication.WorkspaceDirtyPresentationRequest
    typealias WorkspaceDocumentSavePurpose = PrimoWorkspaceApplication.WorkspaceDocumentSavePurpose
    typealias WorkspaceDocumentSaveRequest = PrimoWorkspaceApplication.WorkspaceDocumentSaveRequest
    typealias WorkspaceDocumentSaveResult = PrimoWorkspaceApplication.WorkspaceDocumentSaveResult
    typealias WorkspaceDocumentReplacementRequest = PrimoWorkspaceApplication.WorkspaceDocumentReplacementRequest
    typealias LoadedWorkspaceFollowUpPersistenceRequest = PrimoWorkspaceApplication.LoadedWorkspaceFollowUpPersistenceRequest
    typealias LoadedWorkspaceFollowUpPersistenceResult = PrimoWorkspaceApplication.LoadedWorkspaceFollowUpPersistenceResult
    typealias WorkspaceCloseTabsSaveRequest = PrimoWorkspaceApplication.WorkspaceCloseTabsSaveRequest
    typealias WorkspaceCloseTabsSaveResult = PrimoWorkspaceApplication.WorkspaceCloseTabsSaveResult
    typealias WorkspaceArtifactDiscardRequest = PrimoWorkspaceApplication.WorkspaceArtifactDiscardRequest
    typealias WorkspaceTabReservationRequest = PrimoWorkspaceApplication.WorkspaceTabReservationRequest
    typealias WorkspaceSavedProjectMoveRequest = PrimoWorkspaceApplication.WorkspaceSavedProjectMoveRequest
    typealias WorkspaceSavedProjectMoveResult = PrimoWorkspaceApplication.WorkspaceSavedProjectMoveResult
    typealias WorkspaceAutosaveEntryDiscardRequest = PrimoWorkspaceApplication.WorkspaceAutosaveEntryDiscardRequest
    typealias WorkspaceSaveHistoryLoadRequest = PrimoWorkspaceApplication.WorkspaceSaveHistoryLoadRequest
    typealias WorkspaceCatalogFailureReason = PrimoWorkspaceApplication.WorkspaceCatalogFailureReason
    typealias WorkspaceCatalogFailure = PrimoWorkspaceApplication.WorkspaceCatalogFailure
    typealias WorkspacePersistenceRequest = PrimoWorkspaceApplication.WorkspacePersistenceRequest
    typealias WorkspacePersistenceResult = PrimoWorkspaceApplication.WorkspacePersistenceResult
    typealias WorkspaceCatalogRequest = PrimoWorkspaceApplication.WorkspaceCatalogRequest
    typealias WorkspaceCatalogResult = PrimoWorkspaceApplication.WorkspaceCatalogResult
    typealias LoadedWorkspaceProjectPlan = PrimoWorkspaceApplication.LoadedWorkspaceProjectPlan
    typealias PreparedWorkspaceTab = PrimoWorkspaceApplication.PreparedWorkspaceTab
    typealias WorkspaceProjectLoadIssue = PrimoWorkspaceApplication.WorkspaceProjectLoadIssue
    typealias WorkspaceProjectLoadFailureReason = PrimoWorkspaceApplication.WorkspaceProjectLoadFailureReason
    typealias WorkspaceProjectLoadOperation = PrimoWorkspaceApplication.WorkspaceProjectLoadOperation
    typealias WorkspaceImportedProjectLoadOperation = PrimoWorkspaceApplication.WorkspaceImportedProjectLoadOperation
    typealias WorkspaceProjectLoadRequest = PrimoWorkspaceApplication.WorkspaceProjectLoadRequest
    typealias WorkspaceProjectLoadResult = PrimoWorkspaceApplication.WorkspaceProjectLoadResult<LoadedPaintProject>
    typealias WorkspaceProjectLoadFailure = PrimoWorkspaceApplication.WorkspaceProjectLoadFailure
    typealias WorkspaceProjectPreparationUseCase = PrimoWorkspaceApplication.WorkspaceProjectPreparationUseCase
    typealias WorkspaceProjectLoadUseCase = PrimoWorkspaceApplication.WorkspaceProjectLoadUseCase<LoadedPaintProject>
    typealias WorkspaceProjectLoadCommand = PrimoWorkspaceApplication.WorkspaceProjectLoadCommand
    typealias WorkspaceProjectLoadingService = PrimoWorkspaceApplication.WorkspaceProjectLoadingService<LoadedPaintProject>
}

struct ApplicationFeatureRuntimeReducer: Reducer, PrimoFeatureRuntimeReducer {
    @Dependency(\.appLanguageClient) var appLanguageClient
    @Dependency(\.documentPersistenceGateway) var documentPersistenceGateway
    @Dependency(\.documentQueryGateway) var documentQueryGateway
    @Dependency(\.processEnvironmentClient) var processEnvironmentClient
    @Dependency(\.uuidClient) var uuidClient

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        guard case let .application(applicationAction) = action else { return .none }
        return DocumentFeatureRuntimeReducer().routeApplicationAction(state: &state, action: applicationAction)
    }
}

struct WorkspaceFeatureRuntimeReducer: Reducer, PrimoFeatureRuntimeReducer {
    @Dependency(\.documentGpuOperationGateway) var documentGpuOperationGateway
    @Dependency(\.documentImportClient) var documentImportClient
    @Dependency(\.documentPersistenceGateway) var documentPersistenceGateway
    @Dependency(\.documentQueryGateway) var documentQueryGateway
    @Dependency(\.documentWorkspaceClient) var documentWorkspaceClient
    @Dependency(\.uuidClient) var uuidClient
    @Dependency(\.workspaceApplicationWorkflowService) var workspaceApplicationWorkflowService

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        guard case let .workspace(workspaceAction) = action else { return .none }
        return DocumentFeatureRuntimeReducer().routeWorkspaceAction(state: &state, action: workspaceAction)
    }
}

struct DocumentFeatureRuntimeReducer: Reducer, PrimoFeatureRuntimeReducer {
    @Dependency(\.appLanguageClient) var appLanguageClient
    @Dependency(\.canvasStrokeInteractionService) var canvasStrokeInteractionService
    @Dependency(\.dateClient) var dateClient
    @Dependency(\.documentCanvasCommandService) var documentCanvasCommandService
    @Dependency(\.documentEditingGateway) var documentEditingGateway
    @Dependency(\.documentExportGateway) var documentExportGateway
    @Dependency(\.documentGpuOperationGateway) var documentGpuOperationGateway
    @Dependency(\.documentHistoryCommandService) var documentHistoryCommandService
    @Dependency(\.documentHistoryGateway) var documentHistoryGateway
    @Dependency(\.documentLayerCommandService) var documentLayerCommandService
    @Dependency(\.documentLayerEffectsGateway) var documentLayerEffectsGateway
    @Dependency(\.documentMutationGateway) var documentMutationGateway
    @Dependency(\.documentMutationWorkflowService) var documentMutationWorkflowService
    @Dependency(\.documentPersistenceGateway) var documentPersistenceGateway
    @Dependency(\.documentQueryGateway) var documentQueryGateway
    @Dependency(\.documentStrokeCommandService) var documentStrokeCommandService
    @Dependency(\.documentStrokeSessionUseCase) var documentStrokeSessionUseCase
    @Dependency(\.documentImportClient) var documentImportClient
    @Dependency(\.documentWorkspaceClient) var documentWorkspaceClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.layerTransformProcessor) var layerTransformProcessor
    @Dependency(\.nanoBananaEditUseCase) var nanoBananaEditUseCase
    @Dependency(\.processEnvironmentClient) var processEnvironmentClient
    @Dependency(\.selectionWorkflowService) var selectionWorkflowService
    @Dependency(\.strokeInputGateway) var strokeInputGateway
    @Dependency(\.textLayerGateway) var textLayerGateway
    @Dependency(\.uuidClient) var uuidClient
    @Dependency(\.workspaceApplicationWorkflowService) var workspaceApplicationWorkflowService

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        guard case .document = action else { return .none }
        if let effect = routeDocumentEditorAction(state: &state, action: action) {
            return effect
        }
        if let effect = routeDocumentEditorEditingAction(state: &state, action: action) {
            return effect
        }
        return routeCanvasInteractionAction(state: &state, action: action) ?? .none
    }
}

struct ImportExportFeatureRuntimeReducer: Reducer, PrimoFeatureRuntimeReducer {
    @Dependency(\.dateClient) var dateClient
    @Dependency(\.documentExportGateway) var documentExportGateway
    @Dependency(\.documentGpuOperationGateway) var documentGpuOperationGateway
    @Dependency(\.documentPersistenceGateway) var documentPersistenceGateway
    @Dependency(\.documentQueryGateway) var documentQueryGateway
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.nanoBananaEditUseCase) var nanoBananaEditUseCase
    @Dependency(\.uuidClient) var uuidClient

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .importExport, .nanoBanana:
            return DocumentFeatureRuntimeReducer().routeAssetImportExportAction(state: &state, action: action) ?? .none
        default:
            return .none
        }
    }
}
