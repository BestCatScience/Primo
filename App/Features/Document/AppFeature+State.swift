import ComposableArchitecture
import Foundation
import PrimoDocumentDomain

extension AppFeature {
    struct ApplicationState: Equatable {
        var isHydrating = true
        var showsHome = true
        var homeSection: HomeSidebarSection = .home
        var homeProjects: [SavedProjectSummary] = []
        var isLoadingHomeProjects = true
        var bannerMessage: String?
        var appLanguage: AppLanguage = .japanese
    }

    typealias WorkspaceState = WorkspaceFeature.State

    struct RecoveryState: Equatable {
        var items: [AutosaveRecoveryItem] = []
        var isPresented = false
    }

    struct SaveHistoryState: Equatable {
        var entries: [SaveHistoryEntry] = []
        var isPresented = false
    }

    struct ExportState: Equatable {
        var shareSheet: ShareExport?
        var timelapsePreview: TimelapseExportPreview?
    }

    @ObservableState
    struct State: Equatable {
        var application = ApplicationState()
        var recovery = RecoveryState()
        var nanoBanana = NanoBananaState()
        var workspace = WorkspaceFeature.State()
        var document = DocumentFeature.State()
        var importExport = ImportExportFeature.State()

        var saveHistory: SaveHistoryState {
            get { importExport.saveHistory }
            set { importExport.saveHistory = newValue }
        }

        var export: ExportState {
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
