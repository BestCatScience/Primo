import Foundation

extension AppFeature.ApplicationState {
    mutating func beginStartup(language: AppLanguage) {
        isHydrating = true
        showsHome = true
        isLoadingHomeProjects = true
        appLanguage = language
    }

    mutating func beginHydration() {
        isHydrating = true
    }

    mutating func finishHydration(showingHome: Bool? = nil) {
        isHydrating = false
        if let showingHome {
            showsHome = showingHome
        }
    }

    mutating func failHydration(
        message: String,
        showingHome: Bool? = nil
    ) {
        finishHydration(showingHome: showingHome)
        presentBanner(message)
    }

    mutating func completeWorkspaceProjectLoad(
        bannerMessage: String? = nil
    ) {
        finishHydration(showingHome: false)
        if let bannerMessage {
            presentBanner(bannerMessage)
        }
    }

    mutating func showHome(section: HomeSidebarSection = .home) {
        showsHome = true
        homeSection = section
    }

    mutating func selectHomeSection(_ section: HomeSidebarSection) {
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

    mutating func updateLanguage(_ language: AppLanguage) {
        appLanguage = language
    }
}

extension AppFeature.RecoveryState {
    func item(id: WorkspaceItemID) -> AutosaveRecoveryItem? {
        items.first(where: { $0.id == id })
    }

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

    mutating func completeRestore(of id: WorkspaceItemID) {
        removeItem(id: id)
        dismiss()
    }
}

extension AppFeature.SaveHistoryState {
    mutating func beginPresentation() {
        isPresented = true
    }

    mutating func present(entries: [SaveHistoryEntry]) {
        self.entries = entries
        isPresented = true
    }

    mutating func dismiss() {
        isPresented = false
    }

    mutating func completeRestore() {
        dismiss()
    }
}

extension AppFeature.ExportState {
    mutating func presentShareSheet(_ shareExport: ShareExport) {
        shareSheet = shareExport
    }

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

extension AppFeature.NanoBananaState {
    var progress: Double? {
        guard isGenerating else { return nil }
        return 0.6
    }

    mutating func beginGeneration(
        request: NanoBananaGenerationRequest,
        jobID: UUID,
        createdAt: Date
    ) {
        isGenerating = true
        pendingRequest = request
        activeJobID = jobID
        jobs.insert(
            NanoBananaJob(
                id: jobID,
                request: request,
                createdAt: createdAt,
                status: .running,
                message: nil
            ),
            at: 0
        )
        jobs = Array(jobs.prefix(12))
    }

    func regenerationRequest() -> NanoBananaGenerationRequest? {
        pendingRequest
    }

    func retryRequest(for jobID: UUID) -> NanoBananaGenerationRequest? {
        jobs.first(where: { $0.id == jobID })?.request
    }

    mutating func recordSucceededGeneration(
        preview: NanoBananaPreviewState,
        historyID: UUID,
        createdAt: Date
    ) {
        isGenerating = false
        history.insert(
            NanoBananaHistoryItem(
                id: historyID,
                request: preview.request,
                createdAt: createdAt,
                previewImageData: preview.afterPreviewImageData
            ),
            at: 0
        )
        history = Array(history.prefix(12))
        if let activeJobID,
           let jobIndex = jobs.firstIndex(where: { $0.id == activeJobID }) {
            jobs[jobIndex].status = .succeeded
            jobs[jobIndex].message = nil
        }
    }

    mutating func completeAppliedEdit(request: NanoBananaGenerationRequest) {
        pendingRequest = request
        activeJobID = nil
    }

    mutating func markFailed(message: String) {
        isGenerating = false
        if let activeJobID,
           let jobIndex = jobs.firstIndex(where: { $0.id == activeJobID }) {
            jobs[jobIndex].status = .failed
            jobs[jobIndex].message = message
        }
    }

    mutating func markCanceled(localizedMessage: String) {
        isGenerating = false
        if let activeJobID,
           let jobIndex = jobs.firstIndex(where: { $0.id == activeJobID }) {
            jobs[jobIndex].status = .canceled
            jobs[jobIndex].message = localizedMessage
        }
    }
}
