import Foundation

extension AppFeature.ApplicationState {
    mutating func beginStartup(language: AppLanguage) {
        isHydrating = true
        showsHome = true
        isLoadingHomeProjects = true
        appLanguage = language
    }

    mutating func finishHydration(showingHome: Bool? = nil) {
        isHydrating = false
        if let showingHome {
            showsHome = showingHome
        }
    }

    mutating func showHome(section: HomeSidebarSection = .home) {
        showsHome = true
        homeSection = section
    }

    mutating func showWorkspace() {
        showsHome = false
    }

    mutating func beginLoadingHomeProjects() {
        isLoadingHomeProjects = true
    }

    mutating func finishLoadingHomeProjects(_ projects: [SavedProjectSummary]) {
        homeProjects = projects
        isLoadingHomeProjects = false
    }

    mutating func presentBanner(_ message: String?) {
        bannerMessage = message
    }

    mutating func clearBanner() {
        bannerMessage = nil
    }
}

extension AppFeature.RecoveryState {
    mutating func present(items: [AutosaveRecoveryItem]) {
        self.items = items
        isPresented = !items.isEmpty
    }

    mutating func dismiss() {
        isPresented = false
    }

    mutating func removeItem(id: WorkspaceItemID) {
        items.removeAll { $0.id == id }
        isPresented = !items.isEmpty
    }
}

extension AppFeature.SaveHistoryState {
    mutating func present(entries: [SaveHistoryEntry]) {
        self.entries = entries
        isPresented = true
    }

    mutating func dismiss() {
        isPresented = false
    }
}

extension AppFeature.ExportState {
    mutating func clearOutputs() {
        shareSheet = nil
        timelapsePreview = nil
    }

    mutating func startTimelapsePreview(from capture: TimelapseCapture) {
        timelapsePreview = TimelapseExportPreview(
            progress: 0,
            previewImageData: capture.previewImageData
        )
    }

    mutating func updateTimelapsePreview(
        progress: Double,
        previewData: Data?
    ) {
        timelapsePreview = TimelapseExportPreview(
            progress: progress,
            previewImageData: previewData ?? timelapsePreview?.previewImageData
        )
    }

    mutating func completeTimelapseExport(with shareExport: ShareExport) {
        timelapsePreview = nil
        shareSheet = shareExport
    }

    mutating func failTimelapseExport() {
        timelapsePreview = nil
    }

    mutating func dismissShareSheet() {
        shareSheet = nil
    }
}
