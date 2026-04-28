import ComposableArchitecture
import Foundation
import os

struct CrossFeatureIntegrationReducer: Reducer {
    static let startupLogger = PrimoRootFeature.startupLogger

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

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .application(applicationAction):
            return routeApplicationAction(state: &state, action: applicationAction)

        case let .workspace(workspaceAction):
            return routeWorkspaceAction(state: &state, action: workspaceAction)

        case .document:
            if let effect = routeDocumentEditorAction(state: &state, action: action) {
                return effect
            }
            if let effect = routeDocumentEditorEditingAction(state: &state, action: action) {
                return effect
            }
            return routeCanvasInteractionAction(state: &state, action: action) ?? .none

        case .importExport:
            return routeAssetImportExportAction(state: &state, action: action) ?? .none

        case .nanoBanana:
            return routeAssetImportExportAction(state: &state, action: action) ?? .none
        }
    }

    @Dependency(\.documentQueryGateway) var documentQueryGateway
    @Dependency(\.documentMutationGateway) var documentMutationGateway
    @Dependency(\.strokeInputGateway) var strokeInputGateway
    @Dependency(\.documentHistoryGateway) var documentHistoryGateway
    @Dependency(\.documentPersistenceGateway) var documentPersistenceGateway
    @Dependency(\.documentExportGateway) var documentExportGateway
    @Dependency(\.textLayerGateway) var textLayerGateway
    @Dependency(\.documentLayerEffectsGateway) var documentLayerEffectsGateway
    @Dependency(\.documentEditingGateway) var documentEditingGateway
    @Dependency(\.documentStrokeSessionUseCase) var documentStrokeSessionUseCase
    @Dependency(\.documentGpuOperationGateway) var documentGpuOperationGateway
    @Dependency(\.layerTransformProcessor) var layerTransformProcessor
    @Dependency(\.documentCanvasCommandService) var documentCanvasCommandService
    @Dependency(\.documentLayerCommandService) var documentLayerCommandService
    @Dependency(\.documentStrokeCommandService) var documentStrokeCommandService
    @Dependency(\.canvasStrokeInteractionService) var canvasStrokeInteractionService
    @Dependency(\.documentHistoryCommandService) var documentHistoryCommandService
    @Dependency(\.documentMutationWorkflowService) var documentMutationWorkflowService
    @Dependency(\.selectionWorkflowService) var selectionWorkflowService
    @Dependency(\.workspaceApplicationWorkflowService) var workspaceApplicationWorkflowService
    @Dependency(\.nanoBananaEditUseCase) var nanoBananaEditUseCase
    @Dependency(\.documentWorkspaceClient) var documentWorkspaceClient
    @Dependency(\.documentImportClient) var documentImportClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.processEnvironmentClient) var processEnvironmentClient
    @Dependency(\.dateClient) var dateClient
    @Dependency(\.uuidClient) var uuidClient
    @Dependency(\.appLanguageClient) var appLanguageClient
}
