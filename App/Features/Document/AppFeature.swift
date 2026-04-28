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

    var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.workspace, action: \.workspace) {
                WorkspaceFeature()
            }

            Scope(state: \.document, action: \.document) {
                DocumentFeature()
            }

            Scope(state: \.importExport, action: \.importExport) {
                ImportExportFeature()
            }

            Scope(state: \.nanoBanana, action: \.nanoBanana) {
                NanoBananaFeature()
            }

            AppIntegrationFeature()
        }
    }
}
