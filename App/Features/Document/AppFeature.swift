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
        case timelapseExport
        case nanoBananaEdit
    }

    @Dependency(\.paintDocumentClient) var paintDocumentClient
    @Dependency(\.nanoBananaClient) var nanoBananaClient
    @Dependency(\.documentWorkspaceClient) var documentWorkspaceClient
    @Dependency(\.documentImportClient) var documentImportClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.dateClient) var dateClient
    @Dependency(\.uuidClient) var uuidClient
    @Dependency(\.appLanguageClient) var appLanguageClient

    var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.brushPalette, action: \.brushPalette) {
                BrushPaletteFeature()
            }
            Scope(state: \.nanoBanana, action: \.nanoBanana) {
                NanoBananaFeature()
            }
            Scope(state: \.layerSidebar, action: \.layerSidebar) {
                LayerSidebarFeature()
            }
            Scope(state: \.canvas, action: \.canvas) {
                CanvasFeature()
            }

            AppFeatureApplicationReducer(feature: self)
            AppFeatureWorkspaceReducer(feature: self)
            AppFeatureDocumentReducer(feature: self)
            AppFeatureEditingReducer(feature: self)
        }
    }
}
