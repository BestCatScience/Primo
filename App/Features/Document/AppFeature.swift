import ComposableArchitecture
import Foundation
import os

@Reducer
struct AppFeature {
    static let startupLogger = Logger(subsystem: "com.primo.app", category: "Startup")

    typealias NanoBananaState = NanoBananaFeature.State

    enum CancelID {
        case deferredPresentationRefresh
        case startupPresentationLoad
        case workspaceProjectLoad
        case timelapseExport
        case nanoBananaEdit
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
    @Dependency(\.documentInteractionService) var documentInteractionService
    @Dependency(\.nanoBananaEditUseCase) var nanoBananaEditUseCase
    @Dependency(\.documentWorkspaceClient) var documentWorkspaceClient
    @Dependency(\.documentImportClient) var documentImportClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.processEnvironmentClient) var processEnvironmentClient
    @Dependency(\.dateClient) var dateClient
    @Dependency(\.uuidClient) var uuidClient
    @Dependency(\.appLanguageClient) var appLanguageClient

    var body: some ReducerOf<Self> {
        CombineReducers {
            WorkspaceShellFeature()
            DocumentEditorFeature()
            CanvasInteractionFeature()
            AssetImportExportFeature()

            Scope(state: \.nanoBanana, action: \.nanoBanana) {
                NanoBananaFeature()
            }
        }
    }
}
