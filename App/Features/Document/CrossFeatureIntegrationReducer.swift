import ComposableArchitecture

struct CrossFeatureIntegrationReducer: Reducer {
    typealias State = PrimoRootFeature.State
    typealias Action = PrimoRootFeature.Action

    var body: some ReducerOf<Self> {
        CombineReducers {
            ApplicationWorkspaceBridge()
            WorkspaceDocumentBridge()
            ImportExportWorkspaceBridge()
            AIImageDocumentBridge()
            DocumentApplicationFeedbackBridge()
        }
    }
}
