import ComposableArchitecture
import Foundation
import PrimoDocumentDomain

extension PrimoRootFeature {
    typealias WorkspaceState = WorkspaceFeature.State

    @ObservableState
    struct State: Equatable {
        var application = ApplicationFeature.State()
        var recovery = ApplicationFeature.RecoveryState()
        var nanoBanana = NanoBananaFeature.State()
        var workspace = WorkspaceFeature.State()
        var document = DocumentFeature.State()
        var importExport = ImportExportFeature.State()

        var saveHistory: ImportExportFeature.SaveHistoryState {
            get { importExport.saveHistory }
            set { importExport.saveHistory = newValue }
        }

        var export: ImportExportFeature.ExportState {
            get { importExport.export }
            set { importExport.export = newValue }
        }

        var brushPalette: BrushPaletteFeature.State {
            get { document.brushPalette }
            set { document.brushPalette = newValue }
        }

        var layerSidebar: LayerSidebarFeature.State {
            get { document.layerSidebar }
            set { document.layerSidebar = newValue }
        }

        var canvas: CanvasFeature.State {
            get { document.canvas }
            set { document.canvas = newValue }
        }

        var brushPanel: StudioPanelLayoutState {
            get { document.brushPanel }
            set { document.brushPanel = newValue }
        }

        var layerPanel: StudioPanelLayoutState {
            get { document.layerPanel }
            set { document.layerPanel = newValue }
        }
    }
}
