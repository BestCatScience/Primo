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

    struct WorkspaceState: Equatable {
        var openTabs: [OpenDocumentTab] = []
        var activeTabID: OpenDocumentTab.ID?
        var primarySelectedTabID: OpenDocumentTab.ID?
        var secondarySelectedTabID: OpenDocumentTab.ID?
        var focusedWorkspacePane: WorkspacePane = .primary
        var workspaceLayout: WorkspaceLayoutMode = .single
        var pendingCloseConfirmation: PendingCloseConfirmationState?
        var pendingWorkspaceTabReservation: PendingWorkspaceTabReservation?
    }

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
        var workspace = WorkspaceState()
        var recovery = RecoveryState()
        var saveHistory = SaveHistoryState()
        var export = ExportState()
        var nanoBanana = NanoBananaState()
        var brushPalette = BrushPaletteFeature.State()
        var layerSidebar = LayerSidebarFeature.State()
        var canvas = CanvasFeature.State()
        var brushPanel = StudioPanelLayoutState()
        var layerPanel = StudioPanelLayoutState()
    }
}
