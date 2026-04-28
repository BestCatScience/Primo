import ComposableArchitecture
import Foundation
import os

@Reducer
struct PrimoRootFeature {
    static let startupLogger = Logger(subsystem: "com.primo.app", category: "Startup")

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

            CrossFeatureIntegrationReducer()
        }
    }
}
