import ComposableArchitecture
import CoreGraphics
import Foundation

extension AppFeature {
    func handleTask(state: inout State) -> Effect<Action> {
        state.isHydrating = true
        state.showsHome = true
        state.isLoadingHomeProjects = true
        state.appLanguage = appLanguageClient.load()
        paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
        Self.startupLogger.debug("AppFeature.task started")
        return .merge(
            .run { [paintDocumentClient] send in
                let startupClock = ContinuousClock()
                let bootstrapStart = startupClock.now

                Self.startupLogger.debug("Loading lightweight presentation")
                let lightweightPresentation = paintDocumentClient.lightweightPresentation()
                let bootstrapDuration = bootstrapStart.duration(to: startupClock.now)
                Self.startupLogger.debug("Lightweight presentation loaded in \(String(describing: bootstrapDuration), privacy: .public)")
                await send(.bootstrapPresentationLoaded(lightweightPresentation))
                paintDocumentClient.prewarmDrawingResources()
                await send(.loadPresentationAfterLaunch)
            },
            .send(.homeProjectsLoadRequested),
            .send(.autosaveRecoveryLoadRequested)
        )
    }

    func handleLoadPresentationAfterLaunch() -> Effect<Action> {
        .run { [paintDocumentClient] send in
            let clock = ContinuousClock()
            try? await Task.sleep(for: .milliseconds(600))

            let presentationStart = clock.now
            Self.startupLogger.debug("Loading full presentation after initial launch")
            let presentation = paintDocumentClient.presentation()
            let presentationDuration = presentationStart.duration(to: clock.now)
            Self.startupLogger.debug("Full presentation loaded in \(String(describing: presentationDuration), privacy: .public)")
            await send(.presentationLoaded(presentation))
        }
        .cancellable(id: CancelID.startupPresentationLoad, cancelInFlight: true)
    }

    func handleHomeProjectsLoadRequest(state: inout State) -> Effect<Action> {
        state.isLoadingHomeProjects = true
        return .run { [documentWorkspaceClient] send in
            let projects = (try? documentWorkspaceClient.loadSavedProjects()) ?? []
            await send(.homeProjectsLoaded(projects))
        }
    }

    func handleHomeProjectsLoaded(
        state: inout State,
        projects: [SavedProjectSummary]
    ) {
        state.homeProjects = projects
        state.isLoadingHomeProjects = false
    }

    func handleHomeReturnRequest(state: inout State) -> Effect<Action> {
        if state.activeTab != nil {
            guard persistActiveProjectToWorkspace(
                state: &state,
                preferredDestinationURL: state.activeTab?.sourceProjectURL
            ) != nil else {
                return .none
            }
            if let activeTab = state.activeTab {
                persistSaveHistorySnapshot(for: activeTab, trigger: .autoSave)
            }
        }
        state.showsHome = true
        state.homeSection = .home
        return .send(.homeProjectsLoadRequested)
    }

    func handleDeferredPresentationRefresh() -> Effect<Action> {
        .run { [paintDocumentClient] send in
            await send(.presentationLoaded(paintDocumentClient.presentation()))
        }
        .cancellable(id: CancelID.deferredPresentationRefresh, cancelInFlight: true)
    }

    func handleRefreshPresentationRequest(state: inout State) {
        paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
        applyDirtyPresentation(state: &state)
    }

    func handleLanguageChanged(
        state: inout State,
        language: AppLanguage
    ) {
        state.appLanguage = language
        appLanguageClient.persist(language)
    }

    func handleNewCanvasRequest(
        state: inout State,
        width: Int,
        height: Int
    ) -> Effect<Action> {
        if !state.showsHome {
            persistActiveTabToBackingStore(state: &state)
        }
        let width = max(width, 1)
        let height = max(height, 1)
        paintDocumentClient.newCanvas(width, height)
        paintDocumentClient.prewarmDrawingResources()
        state.showsHome = false
        state.canvas = CanvasFeature.State()
        state.canvas.canvasSize = CGSize(width: width, height: height)
        state.layerSidebar = LayerSidebarFeature.State()
        state.brushPalette = BrushPaletteFeature.State()
        state.brushPanel = StudioPanelLayoutState()
        state.layerPanel = StudioPanelLayoutState()
        state.canvas.adjustmentPreviewPixelData = nil
        state.exportSheet = nil
        state.bannerMessage = nil
        state.isHydrating = false
        paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
        state.applyPresentation(paintDocumentClient.presentation())
        activateNewTab(
            state: &state,
            title: Self.nextUntitledTabTitle(existingTabs: state.openTabs),
            sourceProjectURL: nil
        )
        return .merge(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleResizeCanvasRequest(
        state: inout State,
        width: Int,
        height: Int
    ) {
        let width = max(width, 1)
        let height = max(height, 1)
        let currentWidth = max(Int(state.canvas.canvasSize.width.rounded()), 1)
        let currentHeight = max(Int(state.canvas.canvasSize.height.rounded()), 1)
        guard width != currentWidth || height != currentHeight else {
            return
        }
        paintDocumentClient.resizeCanvas(width, height)
        state.canvas.selection = nil
        state.canvas.selectionPreviewPoints = []
        state.canvas.resetTransformPreview()
        state.canvas.adjustmentPreviewPixelData = nil
        applyDirtyPresentation(state: &state)
        state.bannerMessage = state.appLanguage.localized("Image resolution updated")
    }

    func handleResizeCanvasExtentRequest(
        state: inout State,
        width: Int,
        height: Int
    ) {
        let width = max(width, 1)
        let height = max(height, 1)
        let currentWidth = max(Int(state.canvas.canvasSize.width.rounded()), 1)
        let currentHeight = max(Int(state.canvas.canvasSize.height.rounded()), 1)
        guard width != currentWidth || height != currentHeight else {
            return
        }
        paintDocumentClient.resizeCanvasExtent(width, height)
        state.canvas.selection = nil
        state.canvas.selectionPreviewPoints = []
        state.canvas.resetTransformPreview()
        state.canvas.adjustmentPreviewPixelData = nil
        applyDirtyPresentation(state: &state)
        state.bannerMessage = state.appLanguage.localized("Canvas size updated")
    }

    func handleNewCanvasFromImageReceived(
        state: inout State,
        name: String?,
        data: Data
    ) -> Effect<Action> {
        if !state.showsHome {
            persistActiveTabToBackingStore(state: &state)
        }
        guard let importedImage = Self.importedCanvasImage(from: data) else {
            state.bannerMessage = state.appLanguage.localized("Could not create canvas from image")
            return .none
        }
        let width = importedImage.width
        let height = importedImage.height
        guard (64...8192).contains(width), (64...8192).contains(height) else {
            state.bannerMessage = state.appLanguage.localized("Image size is not supported")
            return .none
        }

        paintDocumentClient.newCanvas(width, height)
        paintDocumentClient.prewarmDrawingResources()
        state.showsHome = false
        state.canvas = CanvasFeature.State()
        state.canvas.canvasSize = CGSize(width: width, height: height)
        state.layerSidebar = LayerSidebarFeature.State()
        state.brushPalette = BrushPaletteFeature.State()
        state.brushPanel = StudioPanelLayoutState()
        state.layerPanel = StudioPanelLayoutState()
        state.canvas.adjustmentPreviewPixelData = nil
        state.exportSheet = nil
        state.bannerMessage = nil
        state.isHydrating = false
        paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
        paintDocumentClient.replaceLayerPixels(0, importedImage.pixelData)
        let nextName = {
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? (state.appLanguage == .japanese ? "画像 1" : "Image 1") : trimmed
        }()
        paintDocumentClient.setLayerName(0, nextName)
        paintDocumentClient.setActiveLayer(0)
        state.applyPresentation(paintDocumentClient.presentation())
        activateNewTab(
            state: &state,
            title: nextName,
            sourceProjectURL: nil
        )
        state.bannerMessage = state.appLanguage.localized("Canvas created from image")
        return .merge(
            .cancel(id: CancelID.startupPresentationLoad),
            .cancel(id: CancelID.deferredPresentationRefresh)
        )
    }

    func handleUndoRequested(state: inout State) {
        guard !state.canvas.isStrokeActive else {
            state.bannerMessage = state.appLanguage.localized("Undo is unavailable while drawing")
            return
        }
        guard paintDocumentClient.undo() else {
            return
        }
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
    }

    func handleRedoRequested(state: inout State) {
        guard !state.canvas.isStrokeActive else {
            state.bannerMessage = state.appLanguage.localized("Redo is unavailable while drawing")
            return
        }
        guard paintDocumentClient.redo() else {
            return
        }
        state.canvas.selection = nil
        applyDirtyPresentation(state: &state)
    }

    func handleExportDocumentRequest(state: inout State) {
        guard let pngData = paintDocumentClient.compositePNGData(state.resolvedPaperStyle()) else {
            state.bannerMessage = state.appLanguage.localized("Export failed")
            return
        }
        do {
            let url = try documentWorkspaceClient.writePNGToTemporaryDirectory(pngData)
            state.exportSheet = makeShareExport(url: url)
        } catch {
            state.bannerMessage = state.appLanguage.localized("Export failed")
        }
    }

    func makeShareExport(url: URL) -> ShareExport {
        ShareExport(id: uuidClient.generate(), url: url)
    }
}
