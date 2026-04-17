import Foundation

extension AppFeature {
    enum ApplicationFeedback: Equatable {
        case message(String)
        case saveFailed(String?)
        case openFailed(String?)
        case moveFailed(String?)
        case autosaveRestoreFailed(String?)
        case saveHistoryRestoreFailed(String?)
        case couldNotCreateCanvasFromImage(String?)
        case couldNotImportPhoto(String?)
        case photoImportedToNewLayer
        case textLayerApplyFailed
        case createLayerMaskNeedsSelection
        case createLayerMaskFailed
        case applyLayerMaskFailed
        case exportFailed
        case timelapseHistoryUnavailable
        case timelapseExportFailed(String?)
        case nanoBananaEditFailed(String?)
        case nanoBananaGenerationCanceled
        case nanoBananaEditApplied
        case couldNotCreateTab
        case canvasSizeUnsupported
        case imageResolutionUpdated
        case canvasSizeUpdated
        case imageSizeUnsupported
        case canvasCreatedFromImage
        case undoUnavailableWhileDrawing
        case redoUnavailableWhileDrawing
        case openedDocument(Int)
        case savedDocument(String)
        case restoredSaveHistory
        case restoredAutosave
    }
}

extension AppFeature.ApplicationFeedback {
    func message(for language: AppLanguage) -> String {
        switch self {
        case let .message(message):
            return message
        case let .saveFailed(message):
            return (message?.isEmpty == false) ? message! : language.localized("Save failed")
        case let .openFailed(message):
            return (message?.isEmpty == false) ? message! : StudioStrings.openFailed(language)
        case let .moveFailed(message):
            return (message?.isEmpty == false) ? message! : language.localized("Move failed")
        case let .autosaveRestoreFailed(message):
            return (message?.isEmpty == false)
                ? message!
                : language.localized("Could not restore autosave")
        case let .saveHistoryRestoreFailed(message):
            return (message?.isEmpty == false)
                ? message!
                : language.localized("Could not restore save history")
        case let .couldNotCreateCanvasFromImage(message):
            return (message?.isEmpty == false) ? message! : language.localized("Could not create canvas from image")
        case let .couldNotImportPhoto(message):
            return (message?.isEmpty == false) ? message! : language.localized("Could not import photo")
        case .photoImportedToNewLayer:
            return language.localized("Photo imported to a new layer")
        case .textLayerApplyFailed:
            return language == .japanese
                ? "テキストをレイヤーに適用できませんでした"
                : "Could not apply text to the layer"
        case .createLayerMaskNeedsSelection:
            return language == .japanese
                ? "選択範囲を作成してからマスクを追加してください"
                : "Create a selection before adding a mask"
        case .createLayerMaskFailed:
            return language == .japanese
                ? "レイヤーマスクを作成できませんでした"
                : "Could not create the layer mask"
        case .applyLayerMaskFailed:
            return language == .japanese
                ? "レイヤーマスクを適用できませんでした"
                : "Could not apply the layer mask"
        case .exportFailed:
            return language.localized("Export failed")
        case .timelapseHistoryUnavailable:
            return language.localized("Not enough drawing history for timelapse yet")
        case let .timelapseExportFailed(message):
            return (message?.isEmpty == false) ? message! : language.localized("Timelapse export failed")
        case let .nanoBananaEditFailed(message):
            return (message?.isEmpty == false) ? message! : language.localized("Nano Banana edit failed")
        case .nanoBananaGenerationCanceled:
            return language.localized("Nano Banana generation canceled")
        case .nanoBananaEditApplied:
            return language.localized("Nano Banana edit applied")
        case .couldNotCreateTab:
            return language.localized("Could not create a tab")
        case .canvasSizeUnsupported:
            return language.localized("Canvas size is not supported")
        case .imageResolutionUpdated:
            return language.localized("Image resolution updated")
        case .canvasSizeUpdated:
            return language.localized("Canvas size updated")
        case .imageSizeUnsupported:
            return language.localized("Image size is not supported")
        case .canvasCreatedFromImage:
            return language.localized("Canvas created from image")
        case .undoUnavailableWhileDrawing:
            return language.localized("Undo is unavailable while drawing")
        case .redoUnavailableWhileDrawing:
            return language.localized("Redo is unavailable while drawing")
        case let .openedDocument(layerCount):
            return StudioStrings.openedDocument(layerCount, language)
        case let .savedDocument(fileName):
            return StudioStrings.savedDocument(fileName, language)
        case .restoredSaveHistory:
            return language == .japanese
                ? "保存履歴を復元しました"
                : "Restored from save history"
        case .restoredAutosave:
            return language == .japanese
                ? "自動保存から復元しました"
                : "Restored from autosave"
        }
    }
}

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

    mutating func failHydration(
        feedback: AppFeature.ApplicationFeedback,
        showingHome: Bool? = nil
    ) {
        finishHydration(showingHome: showingHome)
        presentFeedback(feedback)
    }

    mutating func completeWorkspaceProjectLoad(
        feedback: AppFeature.ApplicationFeedback? = nil
    ) {
        finishHydration(showingHome: false)
        if let feedback {
            presentFeedback(feedback)
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

    mutating func presentFeedback(_ feedback: AppFeature.ApplicationFeedback) {
        presentBanner(feedback.message(for: appLanguage))
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
