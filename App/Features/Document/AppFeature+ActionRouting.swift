import ComposableArchitecture
import Foundation

struct WorkspaceShellFeature: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action

    private let feature = AppFeature()

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .application(applicationAction):
            return feature.routeApplicationAction(state: &state, action: applicationAction)

        case let .workspace(workspaceAction):
            return feature.routeWorkspaceAction(state: &state, action: workspaceAction)

        default:
            return .none
        }
    }
}

struct DocumentEditorFeature: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action

    private let feature = AppFeature()

    var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.brushPalette, action: \.brushPalette) {
                BrushPaletteFeature()
            }

            Scope(state: \.layerSidebar, action: \.layerSidebar) {
                LayerSidebarFeature()
            }

            Reduce { state, action in
                if let effect = feature.routeDocumentEditorAction(state: &state, action: action) {
                    return effect
                }
                return feature.routeDocumentEditorEditingAction(state: &state, action: action) ?? .none
            }
        }
    }
}

struct CanvasInteractionFeature: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action

    private let feature = AppFeature()

    var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.canvas, action: \.canvas) {
                CanvasFeature()
            }

            Reduce { state, action in
                feature.routeCanvasInteractionAction(state: &state, action: action) ?? .none
            }
        }
    }
}

struct AssetImportExportFeature: Reducer {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action

    private let feature = AppFeature()

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        feature.routeAssetImportExportAction(state: &state, action: action) ?? .none
    }
}
