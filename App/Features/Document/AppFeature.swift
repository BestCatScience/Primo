import AVFoundation
import ComposableArchitecture
import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import SwiftUI
import UIKit
import os

struct ShareExport: Equatable, Identifiable {
    let id = UUID()
    let url: URL
}

struct TimelapseExportPreview: Equatable {
    var progress: Double
    var previewImageData: Data?
}

enum StudioPanelKind: String, CaseIterable, Equatable {
    case brush
    case layers

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .brush:
            return language.localized("ブラシ")
        case .layers:
            return language.localized("レイヤー")
        }
    }
}

enum HomeSidebarSection: String, CaseIterable, Equatable {
    case home
    case learn

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .home:
            return language.localized("ホーム")
        case .learn:
            return language.localized("学ぶ")
        }
    }

    var iconSystemName: String {
        switch self {
        case .home:
            return "house.fill"
        case .learn:
            return "lightbulb"
        }
    }
}

struct StudioPanelLayoutState: Equatable {
    var isCollapsed: Bool = false
}

enum PendingCloseOperation: Equatable {
    case tab(OpenDocumentTab.ID)
    case closeOtherTabs(OpenDocumentTab.ID)
    case closeTabsToRight(OpenDocumentTab.ID)
}

struct PendingCloseConfirmationState: Equatable {
    let operation: PendingCloseOperation
    let tabIDs: [OpenDocumentTab.ID]
    let tabTitles: [String]
}

@Reducer
struct AppFeature {
    private static let startupLogger = Logger(subsystem: "com.primo.app", category: "Startup")

    private enum CancelID {
        case deferredPresentationRefresh
        case startupPresentationLoad
        case timelapseExport
        case nanoBananaEdit
    }

    @ObservableState
    struct State: Equatable {
        var isHydrating = true
        var showsHome = true
        var homeSection: HomeSidebarSection = .home
        var homeProjects: [SavedProjectSummary] = []
        var openTabs: [OpenDocumentTab] = []
        var activeTabID: OpenDocumentTab.ID?
        var primarySelectedTabID: OpenDocumentTab.ID?
        var secondarySelectedTabID: OpenDocumentTab.ID?
        var focusedWorkspacePane: WorkspacePane = .primary
        var workspaceLayout: WorkspaceLayoutMode = .single
        var isLoadingHomeProjects = true
        var brushPalette = BrushPaletteFeature.State()
        var layerSidebar = LayerSidebarFeature.State()
        var canvas = CanvasFeature.State()
        var brushPanel = StudioPanelLayoutState()
        var layerPanel = StudioPanelLayoutState()
        var exportSheet: ShareExport?
        var bannerMessage: String?
        var timelapseExportPreview: TimelapseExportPreview?
        var isNanoBananaGenerating = false
        var nanoBananaPreview: NanoBananaPreviewState?
        var nanoBananaJobs: [NanoBananaJob] = []
        var nanoBananaHistory: [NanoBananaHistoryItem] = []
        var pendingNanoBananaRequest: NanoBananaGenerationRequest?
        var activeNanoBananaJobID: UUID?
        var pendingNanoBananaOutputMode: NanoBananaOutputMode = .replaceCurrentLayer
        var appLanguage: AppLanguage = .load()
        var pendingCloseConfirmation: PendingCloseConfirmationState?
        var autosaveRecoveryItems: [AutosaveRecoveryItem] = []
        var isShowingAutosaveRecovery = false
        var saveHistoryEntries: [SaveHistoryEntry] = []
        var isShowingSaveHistory = false

        var nanoBananaProgress: Double? {
            guard isNanoBananaGenerating else { return nil }
            return 0.6
        }

        var activeTabIndex: Int? {
            guard let activeTabID else { return nil }
            return openTabs.firstIndex(where: { $0.id == activeTabID })
        }

        var activeTab: OpenDocumentTab? {
            guard let activeTabIndex else { return nil }
            return openTabs[activeTabIndex]
        }

        func selectedTabID(for pane: WorkspacePane) -> OpenDocumentTab.ID? {
            switch pane {
            case .primary:
                return primarySelectedTabID
            case .secondary:
                return secondarySelectedTabID
            }
        }

        mutating func setSelectedTabID(_ tabID: OpenDocumentTab.ID?, for pane: WorkspacePane) {
            switch pane {
            case .primary:
                primarySelectedTabID = tabID
            case .secondary:
                secondarySelectedTabID = tabID
            }
        }

        func tabs(in pane: WorkspacePane) -> [OpenDocumentTab] {
            openTabs.filter { $0.pane == pane }
        }

        func selectedTab(in pane: WorkspacePane) -> OpenDocumentTab? {
            guard let tabID = selectedTabID(for: pane) else { return nil }
            return openTabs.first(where: { $0.id == tabID })
        }

        func hasTabs(in pane: WorkspacePane) -> Bool {
            openTabs.contains(where: { $0.pane == pane })
        }

        func tabID(forSourceProjectURL sourceProjectURL: URL) -> OpenDocumentTab.ID? {
            let normalizedURL = sourceProjectURL.standardizedFileURL
            return openTabs.first { $0.sourceProjectURL?.standardizedFileURL == normalizedURL }?.id
        }

        mutating func applyPresentation(_ presentation: PaintDocumentPresentation) {
            canvas.canvasSize = presentation.canvasSize
            canvas.activeLayerIndex = presentation.activeLayerIndex
            let previousRevision = canvas.renderSnapshot?.revision ?? canvas.lastCommittedRenderRevision
            var nextBuffers: [LayerCanvasBuffer] = []
            let existingBuffers = Dictionary(uniqueKeysWithValues: canvas.layerBuffers.map { ($0.index, $0) })
            for row in presentation.layerRows.sorted(by: { $0.index < $1.index }) {
                var buffer = existingBuffers[row.index] ?? LayerCanvasBuffer(
                    index: row.index,
                    name: row.name,
                    visible: row.visible,
                    opacity: row.opacity,
                    blendMode: row.blendMode
                )
                buffer.name = row.name
                buffer.visible = row.visible
                buffer.opacity = row.opacity
                buffer.blendMode = row.blendMode
                nextBuffers.append(buffer)
            }
            canvas.layerBuffers = nextBuffers
            if let renderSnapshot = presentation.renderSnapshot {
                canvas.renderSnapshot = renderSnapshot
                canvas.lastCommittedRenderRevision = renderSnapshot.revision
                canvas.pendingIncrementalUpdate = nil
                canvas.activeStrokeBaseSnapshot = nil
                canvas.activeStrokePreviewLayerPixelData = nil
                isHydrating = false
                if !canvas.isStrokeActive &&
                    canvas.isAwaitingCommittedRender &&
                    renderSnapshot.revision > previousRevision {
                    canvas.isAwaitingCommittedRender = false
                    canvas.lastRenderedLocalBufferRevision = canvas.localBufferRevision
                }
            }
            layerSidebar.layers = presentation.layerRows
            layerSidebar.rows = presentation.layerSidebarRows
            layerSidebar.layerBuffers = canvas.layerBuffers
            layerSidebar.activeLayerIndex = presentation.activeLayerIndex
            layerSidebar.paperColor = brushPalette.paper.color
            layerSidebar.transparentPaper = brushPalette.paper.isTransparent
            canvas.previewStyle = previewStrokeStyle()
            canvas.selectionMode = brushPalette.selection.toolMode
            canvas.shapeMode = brushPalette.shape.mode
            canvas.eyedropperSamplingSource = brushPalette.sampling.eyedropperSource
            canvas.paperStyle = resolvedPaperStyle()
            canvas.activeTextLayer = presentation.layerRows.first(where: { $0.index == presentation.activeLayerIndex })?.textLayer
            syncTextEditorWithActiveLayer()
        }

        mutating func updateActiveTabMetadata(title: String? = nil, sourceProjectURL: URL? = nil, previewImageData: Data? = nil) {
            guard let activeTabIndex else { return }
            if let title {
                openTabs[activeTabIndex].title = title
            }
            if let sourceProjectURL {
                openTabs[activeTabIndex].sourceProjectURL = sourceProjectURL
            }
            if let previewImageData {
                openTabs[activeTabIndex].previewImageData = previewImageData
            }
            openTabs[activeTabIndex].canvasSize = canvas.canvasSize
        }

        mutating func applyNanoBananaPreview(
            _ preview: NanoBananaPreviewState,
            paintDocumentClient: PaintDocumentClient
        ) {
            let targetLayerIndex: Int
            switch preview.request.outputMode {
            case .replaceCurrentLayer:
                targetLayerIndex = preview.outputLayerIndex
            case .newLayer:
                paintDocumentClient.addLayer("Nano Banana \(layerSidebar.layers.count + 1)")
                targetLayerIndex = paintDocumentClient.presentation().activeLayerIndex
            }

            paintDocumentClient.setActiveLayer(targetLayerIndex)
            paintDocumentClient.replaceLayerPixels(targetLayerIndex, preview.pixelData)
            if let bufferIndex = canvas.layerBuffers.firstIndex(where: { $0.index == targetLayerIndex }) {
                canvas.layerBuffers[bufferIndex].strokes.removeAll()
            }
            canvas.selection = nil
            nanoBananaPreview = nil
            pendingNanoBananaRequest = preview.request
            activeNanoBananaJobID = nil
            pendingNanoBananaOutputMode = .replaceCurrentLayer
            applyPresentation(paintDocumentClient.presentation())
            bannerMessage = appLanguage.localized("Nano Banana edit applied")
        }

        mutating func setActiveTabDirty(_ isDirty: Bool) {
            guard let activeTabIndex else { return }
            openTabs[activeTabIndex].isDirty = isDirty
        }

        mutating func reorderTabs(moving movingID: OpenDocumentTab.ID, before targetID: OpenDocumentTab.ID) {
            guard
                let sourceIndex = openTabs.firstIndex(where: { $0.id == movingID }),
                let destinationIndex = openTabs.firstIndex(where: { $0.id == targetID }),
                sourceIndex != destinationIndex
            else {
                return
            }
            let tab = openTabs.remove(at: sourceIndex)
            let adjustedDestination = sourceIndex < destinationIndex ? max(destinationIndex - 1, 0) : destinationIndex
            openTabs.insert(tab, at: adjustedDestination)
        }

        mutating func moveTab(_ movingID: OpenDocumentTab.ID, to pane: WorkspacePane, before targetID: OpenDocumentTab.ID?) {
            guard let sourceIndex = openTabs.firstIndex(where: { $0.id == movingID }) else { return }
            let sourcePane = openTabs[sourceIndex].pane
            var tab = openTabs.remove(at: sourceIndex)
            tab.pane = pane

            if let targetID, let destinationIndex = openTabs.firstIndex(where: { $0.id == targetID }) {
                openTabs.insert(tab, at: destinationIndex)
            } else {
                openTabs.append(tab)
            }

            setSelectedTabID(tab.id, for: pane)
            if selectedTabID(for: sourcePane) == movingID {
                setSelectedTabID(tabs(in: sourcePane).first?.id, for: sourcePane)
            }
            if activeTabID == movingID {
                focusedWorkspacePane = pane
            }
            workspaceLayout = hasTabs(in: .secondary) ? .split : .single
        }

        mutating func ensureWorkspaceSelectionIntegrity() {
            if primarySelectedTabID != nil, openTabs.contains(where: { $0.id == primarySelectedTabID && $0.pane == .primary }) == false {
                primarySelectedTabID = tabs(in: .primary).first?.id
            }
            if secondarySelectedTabID != nil, openTabs.contains(where: { $0.id == secondarySelectedTabID && $0.pane == .secondary }) == false {
                secondarySelectedTabID = tabs(in: .secondary).first?.id
            }
            if primarySelectedTabID == nil {
                primarySelectedTabID = tabs(in: .primary).first?.id
            }
            if !hasTabs(in: .secondary) {
                secondarySelectedTabID = nil
                workspaceLayout = .single
                if focusedWorkspacePane == .secondary {
                    focusedWorkspacePane = .primary
                }
            }
        }

        mutating func applyLoadedProject(_ loaded: LoadedPaintProject) {
            brushPalette.paper.color = Color(
                red: Double(loaded.paperStyle.red),
                green: Double(loaded.paperStyle.green),
                blue: Double(loaded.paperStyle.blue),
                opacity: Double(loaded.paperStyle.alpha)
            )
            brushPalette.paper.isTransparent = loaded.paperStyle.isTransparent
            canvas.selection = nil
            canvas.selectionPreviewPoints = []
            canvas.transformPreviewOffset = .zero
            canvas.transformPreviewScale = 1.0
            canvas.transformPreviewRotationDegrees = 0
            canvas.adjustmentPreviewPixelData = nil
            applyPresentation(loaded.presentation)
            isHydrating = false
        }

        mutating func syncTextEditorWithActiveLayer() {
            guard let activeLayer = layerSidebar.layers.first(where: { $0.index == layerSidebar.activeLayerIndex }) else {
                brushPalette.text.targetLayerIndex = nil
                brushPalette.text.scale = 1.0
                brushPalette.text.rotationDegrees = 0
                return
            }
            if let textLayer = activeLayer.textLayer {
                brushPalette.text.content = textLayer.text
                brushPalette.text.fontSize = textLayer.fontSize
                brushPalette.text.position = textLayer.position
                brushPalette.text.scale = textLayer.scale
                brushPalette.text.rotationDegrees = textLayer.rotationDegrees
                brushPalette.text.targetLayerIndex = activeLayer.index
                brushPalette.text.selectedFontPostScriptName = textLayer.fontPostScriptName
                brushPalette.text.selectedFontDisplayName = textLayer.fontDisplayName
            } else {
                brushPalette.text.targetLayerIndex = nil
                brushPalette.text.scale = 1.0
                brushPalette.text.rotationDegrees = 0
            }
        }

        mutating func applyLiveCompositePixelData(_ compositePixelData: Data) {
            let width = canvas.renderSnapshot?.width ?? max(Int(canvas.canvasSize.width.rounded()), 1)
            let height = canvas.renderSnapshot?.height ?? max(Int(canvas.canvasSize.height.rounded()), 1)
            guard compositePixelData.count == width * height * 4 else {
                return
            }

            let layerSnapshots: [MetalLayerSnapshot]
            if let existingLayers = canvas.renderSnapshot?.layers, !existingLayers.isEmpty {
                layerSnapshots = existingLayers
            } else {
                layerSnapshots = canvas.layerBuffers.map { buffer in
                    MetalLayerSnapshot(
                        index: buffer.index,
                        opacity: Float(buffer.opacity),
                        visible: buffer.visible,
                        isClipped: false,
                        blendMode: buffer.blendMode,
                        thumbnailData: nil,
                        pixelData: Data()
                    )
                }
            }

            let nextRevision = max(canvas.renderSnapshot?.revision ?? 0, canvas.lastCommittedRenderRevision) + 1
            canvas.renderSnapshot = MetalDocumentSnapshot(
                width: width,
                height: height,
                revision: nextRevision,
                compositePixelData: compositePixelData,
                layers: layerSnapshots
            )
            canvas.pendingIncrementalUpdate = nil
            isHydrating = false
        }

        mutating func applyLiveStrokePreview(
            baseSnapshot: MetalDocumentSnapshot,
            activeLayerIndex: Int,
            adjustedActiveLayerPixels: Data
        ) {
            guard let composite = AppFeature.compositedPreviewPixelData(
                snapshot: baseSnapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerPixels: adjustedActiveLayerPixels
            ) else {
                return
            }

            let nextLayers = baseSnapshot.layers.map { layer in
                guard layer.index == activeLayerIndex else { return layer }
                return MetalLayerSnapshot(
                    index: layer.index,
                    opacity: layer.opacity,
                    visible: layer.visible,
                    isClipped: layer.isClipped,
                    blendMode: layer.blendMode,
                    thumbnailData: layer.thumbnailData,
                    pixelData: adjustedActiveLayerPixels
                )
            }

            let nextRevision = max(canvas.renderSnapshot?.revision ?? 0, canvas.lastCommittedRenderRevision) + 1
            canvas.renderSnapshot = MetalDocumentSnapshot(
                width: baseSnapshot.width,
                height: baseSnapshot.height,
                revision: nextRevision,
                compositePixelData: composite,
                layers: nextLayers
            )
            canvas.activeStrokePreviewLayerPixelData = adjustedActiveLayerPixels
            canvas.pendingIncrementalUpdate = nil
            isHydrating = false
        }

        func resolvedBrushSettings() -> BrushRuntimeSettings {
            var settings = brushPalette.runtimeSettings
            if settings.tipKind == .oil {
                settings.stabilization = max(settings.stabilization, 0.34)
            }
            if canvas.currentTool == .erase || (canvas.currentTool == .brush && brushPalette.brush.usesTransparentColor) {
                settings.isEraser = true
            }
            return settings
        }

        func previewStrokeStyle() -> PreviewStrokeStyle {
            let resolvedRuntimeSettings: BrushRuntimeSettings = {
                var settings = brushPalette.runtimeSettings
                if settings.tipKind == .oil {
                    settings.stabilization = max(settings.stabilization, 0.34)
                }
                return settings
            }()

            if canvas.currentTool == .erase || (canvas.currentTool == .brush && brushPalette.brush.usesTransparentColor) {
                return PreviewStrokeStyle(
                    tipKind: .ink,
                    isEraser: true,
                    radius: CGFloat(resolvedRuntimeSettings.radius),
                    opacity: 0.78,
                    flow: CGFloat(resolvedRuntimeSettings.flow),
                    hardness: 0.95,
                    roundness: CGFloat(resolvedRuntimeSettings.roundness),
                    angle: CGFloat(resolvedRuntimeSettings.angle),
                    followsStrokeAngle: resolvedRuntimeSettings.angleMode == .strokeDirection,
                    pressureSensitivity: CGFloat(resolvedRuntimeSettings.pressureSensitivity),
                    stabilization: CGFloat(resolvedRuntimeSettings.stabilization),
                    customTip: resolvedRuntimeSettings.customTip,
                    color: CGColor(
                        red: 0.92,
                        green: 0.95,
                        blue: 0.98,
                        alpha: 1.0
                    )
                )
            }

            return PreviewStrokeStyle(
                tipKind: resolvedRuntimeSettings.tipKind,
                isEraser: false,
                radius: CGFloat(resolvedRuntimeSettings.radius),
                opacity: CGFloat(resolvedRuntimeSettings.opacity),
                flow: CGFloat(resolvedRuntimeSettings.flow),
                hardness: CGFloat(resolvedRuntimeSettings.hardness),
                roundness: CGFloat(resolvedRuntimeSettings.roundness),
                angle: CGFloat(resolvedRuntimeSettings.angle),
                followsStrokeAngle: resolvedRuntimeSettings.angleMode == .strokeDirection,
                pressureSensitivity: CGFloat(resolvedRuntimeSettings.pressureSensitivity),
                stabilization: CGFloat(resolvedRuntimeSettings.stabilization),
                customTip: resolvedRuntimeSettings.customTip,
                color: CGColor(
                    red: CGFloat(resolvedRuntimeSettings.red) / 255.0,
                    green: CGFloat(resolvedRuntimeSettings.green) / 255.0,
                    blue: CGFloat(resolvedRuntimeSettings.blue) / 255.0,
                    alpha: 1.0
                )
            )
        }

        func resolvedPaperStyle() -> CanvasPaperStyle {
            let resolved = UIColor(brushPalette.paper.color)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return CanvasPaperStyle(
                red: Float(red),
                green: Float(green),
                blue: Float(blue),
                alpha: Float(alpha),
                isTransparent: brushPalette.paper.isTransparent
            )
        }

        func panelState(for panel: StudioPanelKind) -> StudioPanelLayoutState {
            switch panel {
            case .brush:
                return brushPanel
            case .layers:
                return layerPanel
            }
        }

        mutating func setPanelState(_ panelState: StudioPanelLayoutState, for panel: StudioPanelKind) {
            switch panel {
            case .brush:
                brushPanel = panelState
            case .layers:
                layerPanel = panelState
            }
        }

        mutating func toggleCollapse(for panel: StudioPanelKind) {
            var current = panelState(for: panel)
            current.isCollapsed.toggle()
            setPanelState(current, for: panel)
        }

        mutating func syncToolSpecificBrushSize() {
            brushPalette.brush.storeCurrentRadius(for: canvas.currentTool)
        }

        mutating func applyToolSpecificBrushSize(for tool: StudioToolKind) {
            brushPalette.brush.applyStoredRadius(for: tool)
        }
    }

    enum Action: Equatable {
        case task
        case bootstrapPresentationLoaded(PaintDocumentPresentation)
        case presentationLoaded(PaintDocumentPresentation)
        case loadPresentationAfterLaunch
        case homeProjectsLoadRequested
        case homeProjectsLoaded([SavedProjectSummary])
        case autosaveRecoveryLoadRequested
        case autosaveRecoveryLoaded([AutosaveRecoveryItem])
        case autosaveRecoveryRestoreRequested(String)
        case autosaveRecoveryOpened(LoadedPaintProject, AutosaveRecoveryItem)
        case autosaveRecoveryDiscardRequested(String)
        case autosaveRecoveryDismissed
        case homeSectionSelected(HomeSidebarSection)
        case tabSelected(OpenDocumentTab.ID)
        case tabCloseRequested(OpenDocumentTab.ID)
        case tabClosed(OpenDocumentTab.ID)
        case closeOtherTabsRequested(OpenDocumentTab.ID)
        case closeOtherTabs(OpenDocumentTab.ID)
        case closeTabsToRightRequested(OpenDocumentTab.ID)
        case closeTabsToRight(OpenDocumentTab.ID)
        case pendingCloseSaveConfirmed
        case pendingCloseDiscardConfirmed
        case pendingCloseCancelled
        case moveTabToSecondaryPane(OpenDocumentTab.ID)
        case tabReordered(moving: OpenDocumentTab.ID, before: OpenDocumentTab.ID)
        case tabDropped(moving: OpenDocumentTab.ID, toPane: WorkspacePane, before: OpenDocumentTab.ID?)
        case splitActiveTabIntoSecondaryPane
        case mergeWorkspacePanes
        case workspacePaneActivated(WorkspacePane)
        case homeProjectSelected(URL)
        case moveSavedProject(URL, String?)
        case homeReturnRequested
        case deferredPresentationRefresh
        case refreshPresentationRequested
        case newCanvasRequested(width: Int, height: Int)
        case undoRequested
        case redoRequested
        case saveHistoryRequested
        case saveHistoryLoaded([SaveHistoryEntry])
        case saveHistoryDismissed
        case saveHistoryRestoreRequested(URL, Bool)
        case saveHistoryOpened(LoadedPaintProject, URL, Bool)
        case saveDocumentRequested
        case saveDocumentCopyRequested
        case exportDocumentRequested
        case exportTimelapseRequested
        case nanoBananaEditRequested(NanoBananaGenerationRequest)
        case nanoBananaEditSucceeded(NanoBananaPreviewState)
        case nanoBananaEditFailed(String)
        case nanoBananaCancelRequested
        case nanoBananaPreviewAccepted
        case nanoBananaPreviewDiscarded
        case nanoBananaRegenerateRequested
        case nanoBananaRetryJob(UUID)
        case openDocumentSelected(URL)
        case openDocumentLoaded(LoadedPaintProject, URL)
        case openDocumentFailed(String)
        case photoImportReceived(name: String?, data: Data)
        case photoImportFailed(String)
        case timelapseExportProgressUpdated(Double, Data?)
        case timelapseExportSucceeded(URL)
        case timelapseExportFailed(String)
        case exportSheetDismissed
        case bannerDismissed
        case languageChanged(AppLanguage)
        case toolSelected(StudioToolKind)
        case toolLongPressed(StudioToolKind)
        case resizeCanvasRequested(width: Int, height: Int)
        case resizeCanvasExtentRequested(width: Int, height: Int)
        case newCanvasFromImageReceived(name: String?, data: Data)
        case newCanvasFromImageFailed(String)
        case clearActiveLayerButtonTapped
        case createLayerMaskFromSelectionRequested
        case clearLayerMaskRequested
        case applyLayerMaskRequested
        case gradientMapSelected(GradientMapPreset)
        case gradientMapPreviewChanged(GradientMapSettings?)
        case gradientMapApplied(GradientMapSettings)
        case hueSaturationBrightnessPreviewChanged(HueSaturationBrightnessSettings?)
        case hueSaturationBrightnessApplied(HueSaturationBrightnessSettings)
        case brightnessContrastPreviewChanged(BrightnessContrastSettings?)
        case brightnessContrastApplied(BrightnessContrastSettings)
        case levelsPreviewChanged(LevelsAdjustmentSettings?)
        case levelsApplied(LevelsAdjustmentSettings)
        case toneCurvePreviewChanged(ToneCurveSettings?)
        case toneCurveApplied(ToneCurveSettings)
        case colorBalancePreviewChanged(ColorBalanceSettings?)
        case colorBalanceApplied(ColorBalanceSettings)
        case thresholdPreviewChanged(ThresholdSettings?)
        case thresholdApplied(ThresholdSettings)
        case posterizePreviewChanged(PosterizeSettings?)
        case posterizeApplied(PosterizeSettings)
        case luminanceToAlphaRequested
        case activeLayerVisibilityToggled
        case selectPreviousLayer
        case selectNextLayer
        case panelCollapseToggled(StudioPanelKind)
        case brushPalette(BrushPaletteFeature.Action)
        case layerSidebar(LayerSidebarFeature.Action)
        case canvas(CanvasFeature.Action)
    }

    @Dependency(\.paintDocumentClient) var paintDocumentClient
    @Dependency(\.nanoBananaClient) var nanoBananaClient

    var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.brushPalette, action: \.brushPalette) {
                BrushPaletteFeature()
            }
            Scope(state: \.layerSidebar, action: \.layerSidebar) {
                LayerSidebarFeature()
            }
            Scope(state: \.canvas, action: \.canvas) {
                CanvasFeature()
            }

            Reduce { (state: inout State, action: Action) -> Effect<Action> in
                switch action {
            case .task:
                state.isHydrating = true
                state.showsHome = true
                state.isLoadingHomeProjects = true
                state.appLanguage = .load()
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

            case let .bootstrapPresentationLoaded(presentation):
                state.applyPresentation(presentation)
                state.isHydrating = false
                Self.startupLogger.debug("Bootstrap presentation applied; initial UI is ready")
                return .none

            case .loadPresentationAfterLaunch:
                return .run { [paintDocumentClient] send in
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

            case .homeProjectsLoadRequested:
                state.isLoadingHomeProjects = true
                return .run { send in
                    let projects = (try? Self.savedProjects()) ?? []
                    await send(.homeProjectsLoaded(projects))
                }

            case let .homeProjectsLoaded(projects):
                state.homeProjects = projects
                state.isLoadingHomeProjects = false
                return .none

            case .autosaveRecoveryLoadRequested:
                return .run { send in
                    let items = (try? Self.loadAutosaveRecoveryItems()) ?? []
                    await send(.autosaveRecoveryLoaded(items))
                }

            case let .autosaveRecoveryLoaded(items):
                state.autosaveRecoveryItems = items
                state.isShowingAutosaveRecovery = !items.isEmpty
                return .none

            case let .autosaveRecoveryRestoreRequested(autosaveID):
                guard let item = state.autosaveRecoveryItems.first(where: { $0.id == autosaveID }) else {
                    return .none
                }
                if !state.showsHome {
                    persistActiveTabToBackingStore(state: &state)
                }
                state.isHydrating = true
                state.isShowingAutosaveRecovery = false
                return .run { [paintDocumentClient] send in
                    do {
                        let loaded = try paintDocumentClient.loadProject(item.autosaveProjectURL)
                        await send(.autosaveRecoveryOpened(loaded, item))
                    } catch {
                        await send(.openDocumentFailed(error.localizedDescription))
                    }
                }

            case let .autosaveRecoveryOpened(loaded, item):
                try? Self.discardAutosaveEntry(id: item.id)
                state.applyLoadedProject(loaded)
                activateNewTab(
                    state: &state,
                    title: item.title,
                    sourceProjectURL: item.sourceProjectURL
                )
                state.setActiveTabDirty(true)
                persistActiveTabToBackingStore(state: &state)
                persistActiveTabAutosave(state: &state)
                state.isHydrating = false
                state.showsHome = false
                state.autosaveRecoveryItems.removeAll { $0.id == item.id }
                state.isShowingAutosaveRecovery = false
                state.bannerMessage = state.appLanguage.localized("自動保存から復元しました")
                return .none

            case let .autosaveRecoveryDiscardRequested(autosaveID):
                state.autosaveRecoveryItems.removeAll { $0.id == autosaveID }
                state.isShowingAutosaveRecovery = !state.autosaveRecoveryItems.isEmpty
                try? Self.discardAutosaveEntry(id: autosaveID)
                return .none

            case .autosaveRecoveryDismissed:
                state.isShowingAutosaveRecovery = false
                return .none

            case let .homeSectionSelected(section):
                state.homeSection = section
                return .none

            case let .tabSelected(tabID):
                guard let targetTab = state.openTabs.first(where: { $0.id == tabID }) else {
                    return .none
                }
                if !state.showsHome, state.activeTabID != tabID {
                    persistActiveTabToBackingStore(state: &state)
                }
                do {
                    let loaded = try paintDocumentClient.loadProject(targetTab.backingStoreURL)
                    state.activeTabID = tabID
                    state.setSelectedTabID(tabID, for: targetTab.pane)
                    state.focusedWorkspacePane = targetTab.pane
                    state.applyLoadedProject(loaded)
                    state.showsHome = false
                } catch {
                    state.bannerMessage = error.localizedDescription.isEmpty ? StudioStrings.openFailed(state.appLanguage) : error.localizedDescription
                }
                return .none

            case let .tabCloseRequested(tabID):
                return requestCloseOperation(state: &state, operation: .tab(tabID))

            case let .closeOtherTabsRequested(tabID):
                return requestCloseOperation(state: &state, operation: .closeOtherTabs(tabID))

            case let .closeTabsToRightRequested(tabID):
                return requestCloseOperation(state: &state, operation: .closeTabsToRight(tabID))

            case .pendingCloseSaveConfirmed:
                guard let confirmation = state.pendingCloseConfirmation else { return .none }
                do {
                    try saveTabsForClose(confirmation.tabIDs, state: &state)
                    state.pendingCloseConfirmation = nil
                    return performCloseOperation(state: &state, operation: confirmation.operation)
                } catch {
                    state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Save failed") : error.localizedDescription
                    state.pendingCloseConfirmation = nil
                    return .none
                }

            case .pendingCloseDiscardConfirmed:
                guard let confirmation = state.pendingCloseConfirmation else { return .none }
                state.pendingCloseConfirmation = nil
                return performCloseOperation(state: &state, operation: confirmation.operation)

            case .pendingCloseCancelled:
                state.pendingCloseConfirmation = nil
                return .none

            case let .tabClosed(tabID):
                guard let closingIndex = state.openTabs.firstIndex(where: { $0.id == tabID }) else {
                    return .none
                }
                let closingTab = state.openTabs[closingIndex]
                let wasActive = state.activeTabID == tabID
                state.openTabs.remove(at: closingIndex)
                clearAutosave(for: closingTab)
                try? FileManager.default.removeItem(at: closingTab.backingStoreURL)
                state.ensureWorkspaceSelectionIntegrity()

                if wasActive {
                    let replacement = state.selectedTab(in: closingTab.pane)
                        ?? state.selectedTab(in: closingTab.pane == .primary ? .secondary : .primary)
                    if let replacement {
                        do {
                            let loaded = try paintDocumentClient.loadProject(replacement.backingStoreURL)
                            state.activeTabID = replacement.id
                            state.focusedWorkspacePane = replacement.pane
                            state.applyLoadedProject(loaded)
                            state.showsHome = false
                        } catch {
                            state.activeTabID = nil
                            state.showsHome = true
                            state.bannerMessage = error.localizedDescription.isEmpty ? StudioStrings.openFailed(state.appLanguage) : error.localizedDescription
                        }
                    } else {
                        state.activeTabID = nil
                        state.showsHome = true
                    }
                }
                return .none

            case let .closeOtherTabs(tabID):
                let retainedTabs = state.openTabs.filter { $0.id == tabID }
                let removedTabs = state.openTabs.filter { $0.id != tabID }
                removedTabs.forEach {
                    clearAutosave(for: $0)
                    try? FileManager.default.removeItem(at: $0.backingStoreURL)
                }
                state.openTabs = retainedTabs
                state.primarySelectedTabID = retainedTabs.first(where: { $0.pane == .primary })?.id
                state.secondarySelectedTabID = retainedTabs.first(where: { $0.pane == .secondary })?.id
                if state.activeTabID != tabID {
                    return .send(.tabSelected(tabID))
                }
                state.ensureWorkspaceSelectionIntegrity()
                return .none

            case let .closeTabsToRight(tabID):
                guard let tabIndex = state.openTabs.firstIndex(where: { $0.id == tabID }) else { return .none }
                let tab = state.openTabs[tabIndex]
                let paneTabs = state.openTabs.enumerated().filter { $0.element.pane == tab.pane }
                guard let paneIndex = paneTabs.firstIndex(where: { $0.element.id == tabID }) else { return .none }
                let idsToRemove = Set(paneTabs.dropFirst(paneIndex + 1).map(\.element.id))
                let removedTabs = state.openTabs.filter { idsToRemove.contains($0.id) }
                removedTabs.forEach {
                    clearAutosave(for: $0)
                    try? FileManager.default.removeItem(at: $0.backingStoreURL)
                }
                state.openTabs.removeAll { idsToRemove.contains($0.id) }
                state.ensureWorkspaceSelectionIntegrity()
                return .none

            case let .moveTabToSecondaryPane(tabID):
                state.workspaceLayout = .split
                state.moveTab(tabID, to: .secondary, before: nil)
                state.ensureWorkspaceSelectionIntegrity()
                return .none

            case let .tabReordered(movingID, targetID):
                state.reorderTabs(moving: movingID, before: targetID)
                return .none

            case let .tabDropped(movingID, pane, targetID):
                state.moveTab(movingID, to: pane, before: targetID)
                return .none

            case .splitActiveTabIntoSecondaryPane:
                state.workspaceLayout = .split
                state.ensureWorkspaceSelectionIntegrity()
                return .none

            case .mergeWorkspacePanes:
                let secondaryTabs = state.tabs(in: .secondary).map(\.id)
                for tabID in secondaryTabs {
                    state.moveTab(tabID, to: .primary, before: nil)
                }
                state.workspaceLayout = .single
                state.secondarySelectedTabID = nil
                state.focusedWorkspacePane = .primary
                state.ensureWorkspaceSelectionIntegrity()
                return .none

            case let .workspacePaneActivated(pane):
                state.focusedWorkspacePane = pane
                guard let tabID = state.selectedTabID(for: pane) else { return .none }
                if state.activeTabID == tabID {
                    return .none
                }
                return .send(.tabSelected(tabID))

            case let .moveSavedProject(url, relativeFolderPath):
                do {
                    let destinationURL = try Self.moveSavedProject(at: url, toRelativeFolderPath: relativeFolderPath)
                    if let openTabIndex = state.openTabs.firstIndex(where: { $0.sourceProjectURL?.standardizedFileURL == url.standardizedFileURL }) {
                        state.openTabs[openTabIndex].sourceProjectURL = destinationURL
                    }
                    return .send(.homeProjectsLoadRequested)
                } catch {
                    state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Move failed") : error.localizedDescription
                    return .none
                }

            case .homeReturnRequested:
                do {
                    let url = try Self.projectURLInDocuments()
                    try paintDocumentClient.saveProject(url, state.resolvedPaperStyle())
                    state.updateActiveTabMetadata(
                        title: url.deletingPathExtension().lastPathComponent,
                        sourceProjectURL: url,
                        previewImageData: paintDocumentClient.compositePNGData(state.resolvedPaperStyle())
                    )
                    state.setActiveTabDirty(false)
                    if let activeTab = state.activeTab {
                        clearAutosave(for: activeTab)
                    }
                } catch {
                    state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Save failed") : error.localizedDescription
                }
                persistActiveTabToBackingStore(state: &state)
                if let activeTab = state.activeTab {
                    persistSaveHistorySnapshot(for: activeTab, trigger: .autoSave)
                }
                state.showsHome = true
                state.homeSection = .home
                return .send(.homeProjectsLoadRequested)

            case let .presentationLoaded(presentation):
                guard !state.canvas.isStrokeActive else {
                    return .none
                }
                state.applyPresentation(presentation)
                Self.startupLogger.debug("Full presentation applied")
                return .none

            case .deferredPresentationRefresh:
                return .run { [paintDocumentClient] send in
                    await send(.presentationLoaded(paintDocumentClient.presentation()))
                }
                .cancellable(id: CancelID.deferredPresentationRefresh, cancelInFlight: true)

            case .refreshPresentationRequested:
                paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
                applyDirtyPresentation(state: &state)
                return .none

            case let .languageChanged(language):
                state.appLanguage = language
                language.persist()
                return .none

            case let .newCanvasRequested(width, height):
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

            case let .resizeCanvasRequested(width, height):
                let width = max(width, 1)
                let height = max(height, 1)
                let currentWidth = max(Int(state.canvas.canvasSize.width.rounded()), 1)
                let currentHeight = max(Int(state.canvas.canvasSize.height.rounded()), 1)
                guard width != currentWidth || height != currentHeight else {
                    return .none
                }
                paintDocumentClient.resizeCanvas(width, height)
                state.canvas.selection = nil
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                state.canvas.transformPreviewRotationDegrees = 0
                state.canvas.adjustmentPreviewPixelData = nil
                applyDirtyPresentation(state: &state)
                state.bannerMessage = state.appLanguage.localized("Image resolution updated")
                return .none

            case let .resizeCanvasExtentRequested(width, height):
                let width = max(width, 1)
                let height = max(height, 1)
                let currentWidth = max(Int(state.canvas.canvasSize.width.rounded()), 1)
                let currentHeight = max(Int(state.canvas.canvasSize.height.rounded()), 1)
                guard width != currentWidth || height != currentHeight else {
                    return .none
                }
                paintDocumentClient.resizeCanvasExtent(width, height)
                state.canvas.selection = nil
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                state.canvas.transformPreviewRotationDegrees = 0
                state.canvas.adjustmentPreviewPixelData = nil
                applyDirtyPresentation(state: &state)
                state.bannerMessage = state.appLanguage.localized("Canvas size updated")
                return .none

            case let .newCanvasFromImageReceived(name, data):
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

            case let .newCanvasFromImageFailed(message):
                state.bannerMessage = message.isEmpty ? state.appLanguage.localized("Could not create canvas from image") : message
                return .none

            case .undoRequested:
                guard !state.canvas.isStrokeActive else {
                    state.bannerMessage = state.appLanguage.localized("Undo is unavailable while drawing")
                    return .none
                }
                guard paintDocumentClient.undo() else {
                    return .none
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case .redoRequested:
                guard !state.canvas.isStrokeActive else {
                    state.bannerMessage = state.appLanguage.localized("Redo is unavailable while drawing")
                    return .none
                }
                guard paintDocumentClient.redo() else {
                    return .none
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case .saveHistoryRequested:
                guard let activeTab = state.activeTab else { return .none }
                state.saveHistoryEntries = (try? Self.loadSaveHistoryEntries(for: activeTab)) ?? []
                state.isShowingSaveHistory = true
                return .none

            case let .saveHistoryLoaded(entries):
                state.saveHistoryEntries = entries
                state.isShowingSaveHistory = true
                return .none

            case .saveHistoryDismissed:
                state.isShowingSaveHistory = false
                return .none

            case let .saveHistoryRestoreRequested(projectURL, openInNewTab):
                if !state.showsHome {
                    persistActiveTabToBackingStore(state: &state)
                }
                state.isHydrating = true
                return .run { [paintDocumentClient] send in
                    do {
                        let loaded = try paintDocumentClient.loadProject(projectURL)
                        await send(.saveHistoryOpened(loaded, projectURL, openInNewTab))
                    } catch {
                        await send(.openDocumentFailed(error.localizedDescription))
                    }
                }

            case let .saveHistoryOpened(loaded, projectURL, openInNewTab):
                let restoredTitle = projectURL.deletingPathExtension().lastPathComponent
                if openInNewTab || state.activeTab == nil {
                    state.applyLoadedProject(loaded)
                    activateNewTab(
                        state: &state,
                        title: "\(restoredTitle) Snapshot",
                        sourceProjectURL: nil
                    )
                } else {
                    let existingSourceURL = state.activeTab?.sourceProjectURL
                    let existingTitle = state.activeTab?.title ?? restoredTitle
                    state.applyLoadedProject(loaded)
                    state.updateActiveTabMetadata(
                        title: existingTitle,
                        sourceProjectURL: existingSourceURL,
                        previewImageData: paintDocumentClient.compositePNGData(state.resolvedPaperStyle())
                    )
                }
                state.setActiveTabDirty(true)
                persistActiveTabToBackingStore(state: &state)
                persistActiveTabAutosave(state: &state)
                state.isHydrating = false
                state.showsHome = false
                state.isShowingSaveHistory = false
                state.bannerMessage = state.appLanguage.localized("保存履歴を復元しました")
                return .none

            case let .gradientMapSelected(preset):
                state.canvas.adjustmentPreviewPixelData = nil
                guard paintDocumentClient.applyLayerProcessing(state.canvas.activeLayerIndex, .gradientMap(preset)) else {
                    state.bannerMessage = state.appLanguage.localized("Could not apply gradient map")
                    return .none
                }
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .gradientMapPreviewChanged(settings):
                guard
                    let settings,
                    let snapshot = state.canvas.renderSnapshot,
                    let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                    let adjusted = Self.gradientMappedLayerPixels(source: layer.pixelData, settings: settings),
                    let composite = Self.compositedPreviewPixelData(
                        snapshot: snapshot,
                        activeLayerIndex: state.canvas.activeLayerIndex,
                        adjustedActiveLayerPixels: adjusted
                    )
                else {
                    state.canvas.adjustmentPreviewPixelData = nil
                    return .none
                }
                state.canvas.adjustmentPreviewPixelData = composite
                return .none

            case let .gradientMapApplied(settings):
                state.canvas.adjustmentPreviewPixelData = nil
                guard
                    let snapshot = state.canvas.renderSnapshot,
                    let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                    let adjusted = Self.gradientMappedLayerPixels(source: layer.pixelData, settings: settings)
                else {
                    state.bannerMessage = state.appLanguage.localized("Could not apply gradient map")
                    return .none
                }
                paintDocumentClient.replaceLayerPixels(state.canvas.activeLayerIndex, adjusted)
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .hueSaturationBrightnessPreviewChanged(settings):
                guard
                    let settings,
                    let snapshot = state.canvas.renderSnapshot,
                    let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                    let adjusted = Self.hueSaturationBrightnessAdjustedLayerPixels(source: layer.pixelData, settings: settings),
                    let composite = Self.compositedPreviewPixelData(
                        snapshot: snapshot,
                        activeLayerIndex: state.canvas.activeLayerIndex,
                        adjustedActiveLayerPixels: adjusted
                    )
                else {
                    state.canvas.adjustmentPreviewPixelData = nil
                    return .none
                }
                state.canvas.adjustmentPreviewPixelData = composite
                return .none

            case let .hueSaturationBrightnessApplied(settings):
                state.canvas.adjustmentPreviewPixelData = nil
                guard paintDocumentClient.applyLayerProcessing(state.canvas.activeLayerIndex, .hueSaturationBrightness(settings)) else {
                    state.bannerMessage = state.appLanguage.localized("Could not apply color adjustment")
                    return .none
                }
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .brightnessContrastPreviewChanged(settings):
                guard
                    let settings,
                    let snapshot = state.canvas.renderSnapshot,
                    let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                    let adjusted = Self.brightnessContrastAdjustedLayerPixels(source: layer.pixelData, settings: settings),
                    let composite = Self.compositedPreviewPixelData(
                        snapshot: snapshot,
                        activeLayerIndex: state.canvas.activeLayerIndex,
                        adjustedActiveLayerPixels: adjusted
                    )
                else {
                    state.canvas.adjustmentPreviewPixelData = nil
                    return .none
                }
                state.canvas.adjustmentPreviewPixelData = composite
                return .none

            case let .brightnessContrastApplied(settings):
                state.canvas.adjustmentPreviewPixelData = nil
                guard paintDocumentClient.applyLayerProcessing(state.canvas.activeLayerIndex, .brightnessContrast(settings)) else {
                    state.bannerMessage = state.appLanguage.localized("Could not apply color adjustment")
                    return .none
                }
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .levelsPreviewChanged(settings):
                guard
                    let settings,
                    let snapshot = state.canvas.renderSnapshot,
                    let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                    let adjusted = Self.levelsAdjustedLayerPixels(source: layer.pixelData, settings: settings),
                    let composite = Self.compositedPreviewPixelData(
                        snapshot: snapshot,
                        activeLayerIndex: state.canvas.activeLayerIndex,
                        adjustedActiveLayerPixels: adjusted
                    )
                else {
                    state.canvas.adjustmentPreviewPixelData = nil
                    return .none
                }
                state.canvas.adjustmentPreviewPixelData = composite
                return .none

            case let .levelsApplied(settings):
                state.canvas.adjustmentPreviewPixelData = nil
                guard paintDocumentClient.applyLayerProcessing(state.canvas.activeLayerIndex, .levels(settings)) else {
                    state.bannerMessage = state.appLanguage.localized("Could not apply color adjustment")
                    return .none
                }
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .toneCurvePreviewChanged(settings):
                guard
                    let settings,
                    let snapshot = state.canvas.renderSnapshot,
                    let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                    let adjusted = Self.toneCurveAdjustedLayerPixels(source: layer.pixelData, settings: settings),
                    let composite = Self.compositedPreviewPixelData(
                        snapshot: snapshot,
                        activeLayerIndex: state.canvas.activeLayerIndex,
                        adjustedActiveLayerPixels: adjusted
                    )
                else {
                    state.canvas.adjustmentPreviewPixelData = nil
                    return .none
                }
                state.canvas.adjustmentPreviewPixelData = composite
                return .none

            case let .toneCurveApplied(settings):
                state.canvas.adjustmentPreviewPixelData = nil
                guard paintDocumentClient.applyLayerProcessing(state.canvas.activeLayerIndex, .toneCurve(settings)) else {
                    state.bannerMessage = state.appLanguage.localized("Could not apply color adjustment")
                    return .none
                }
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .colorBalancePreviewChanged(settings):
                guard
                    let settings,
                    let snapshot = state.canvas.renderSnapshot,
                    let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                    let adjusted = Self.colorBalanceAdjustedLayerPixels(source: layer.pixelData, settings: settings),
                    let composite = Self.compositedPreviewPixelData(
                        snapshot: snapshot,
                        activeLayerIndex: state.canvas.activeLayerIndex,
                        adjustedActiveLayerPixels: adjusted
                    )
                else {
                    state.canvas.adjustmentPreviewPixelData = nil
                    return .none
                }
                state.canvas.adjustmentPreviewPixelData = composite
                return .none

            case let .colorBalanceApplied(settings):
                state.canvas.adjustmentPreviewPixelData = nil
                guard paintDocumentClient.applyLayerProcessing(state.canvas.activeLayerIndex, .colorBalance(settings)) else {
                    state.bannerMessage = state.appLanguage.localized("Could not apply color adjustment")
                    return .none
                }
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .thresholdPreviewChanged(settings):
                guard
                    let settings,
                    let snapshot = state.canvas.renderSnapshot,
                    let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                    let adjusted = Self.thresholdAdjustedLayerPixels(source: layer.pixelData, settings: settings),
                    let composite = Self.compositedPreviewPixelData(
                        snapshot: snapshot,
                        activeLayerIndex: state.canvas.activeLayerIndex,
                        adjustedActiveLayerPixels: adjusted
                    )
                else {
                    state.canvas.adjustmentPreviewPixelData = nil
                    return .none
                }
                state.canvas.adjustmentPreviewPixelData = composite
                return .none

            case let .thresholdApplied(settings):
                state.canvas.adjustmentPreviewPixelData = nil
                guard paintDocumentClient.applyLayerProcessing(state.canvas.activeLayerIndex, .threshold(settings)) else {
                    state.bannerMessage = state.appLanguage.localized("Could not apply color adjustment")
                    return .none
                }
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .posterizePreviewChanged(settings):
                guard
                    let settings,
                    let snapshot = state.canvas.renderSnapshot,
                    let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                    let adjusted = Self.posterizedLayerPixels(source: layer.pixelData, settings: settings),
                    let composite = Self.compositedPreviewPixelData(
                        snapshot: snapshot,
                        activeLayerIndex: state.canvas.activeLayerIndex,
                        adjustedActiveLayerPixels: adjusted
                    )
                else {
                    state.canvas.adjustmentPreviewPixelData = nil
                    return .none
                }
                state.canvas.adjustmentPreviewPixelData = composite
                return .none

            case let .posterizeApplied(settings):
                state.canvas.adjustmentPreviewPixelData = nil
                guard paintDocumentClient.applyLayerProcessing(state.canvas.activeLayerIndex, .posterize(settings)) else {
                    state.bannerMessage = state.appLanguage.localized("Could not apply color adjustment")
                    return .none
                }
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case .luminanceToAlphaRequested:
                guard
                    let snapshot = state.canvas.renderSnapshot,
                    let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                    let adjusted = Self.luminanceToAlphaLayerPixels(source: layer.pixelData)
                else {
                    state.bannerMessage = state.appLanguage.localized("Could not apply color adjustment")
                    return .none
                }
                paintDocumentClient.replaceLayerPixels(state.canvas.activeLayerIndex, adjusted)
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case .exportDocumentRequested:
                guard let pngData = paintDocumentClient.compositePNGData(state.resolvedPaperStyle()) else {
                    state.bannerMessage = state.appLanguage.localized("Export failed")
                    return .none
                }
                do {
                    let url = try Self.writePNGToTemporaryDirectory(data: pngData)
                    state.exportSheet = ShareExport(url: url)
                } catch {
                    state.bannerMessage = state.appLanguage.localized("Export failed")
                }
                return .none

            case .saveDocumentRequested:
                do {
                    let url = try state.activeTab?.sourceProjectURL ?? Self.projectURLInDocuments()
                    try paintDocumentClient.saveProject(url, state.resolvedPaperStyle())
                    state.bannerMessage = StudioStrings.savedDocument(url.lastPathComponent, state.appLanguage)
                    state.updateActiveTabMetadata(
                        title: url.deletingPathExtension().lastPathComponent,
                        sourceProjectURL: url,
                        previewImageData: paintDocumentClient.compositePNGData(state.resolvedPaperStyle())
                    )
                    state.setActiveTabDirty(false)
                    if let activeTab = state.activeTab {
                        clearAutosave(for: activeTab)
                    }
                    persistActiveTabToBackingStore(state: &state)
                    if let activeTab = state.activeTab {
                        persistSaveHistorySnapshot(for: activeTab, trigger: .manualSave)
                    }
                } catch {
                    state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Save failed") : error.localizedDescription
                }
                return .send(.homeProjectsLoadRequested)

            case .saveDocumentCopyRequested:
                do {
                    let url = try Self.projectURLInDocuments()
                    try paintDocumentClient.saveProject(url, state.resolvedPaperStyle())
                    state.bannerMessage = StudioStrings.savedDocument(url.lastPathComponent, state.appLanguage)
                    state.updateActiveTabMetadata(
                        title: url.deletingPathExtension().lastPathComponent,
                        sourceProjectURL: url,
                        previewImageData: paintDocumentClient.compositePNGData(state.resolvedPaperStyle())
                    )
                    state.setActiveTabDirty(false)
                    if let activeTab = state.activeTab {
                        clearAutosave(for: activeTab)
                    }
                    persistActiveTabToBackingStore(state: &state)
                    if let activeTab = state.activeTab {
                        persistSaveHistorySnapshot(for: activeTab, trigger: .manualSave)
                    }
                } catch {
                    state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Save failed") : error.localizedDescription
                }
                return .send(.homeProjectsLoadRequested)

            case .exportTimelapseRequested:
                guard let capture = paintDocumentClient.timelapseCapture() else {
                    state.bannerMessage = state.appLanguage.localized("Not enough drawing history for timelapse yet")
                    return .none
                }
                state.timelapseExportPreview = TimelapseExportPreview(progress: 0, previewImageData: capture.previewImageData)
                let failureMessage = state.appLanguage.localized("Timelapse export failed")
                return .run { send in
                    do {
                        let url = try TimelapseExporter.exportVideo(
                            from: capture,
                            to: Self.timelapseTemporaryDirectory()
                        ) { progress, previewURL in
                            let previewData = try? Data(contentsOf: previewURL)
                            Task {
                                await send(.timelapseExportProgressUpdated(progress, previewData))
                            }
                        }
                        await send(.timelapseExportSucceeded(url))
                    } catch {
                        await send(.timelapseExportFailed(failureMessage))
                    }
                }
                .cancellable(id: CancelID.timelapseExport, cancelInFlight: true)

            case let .nanoBananaEditRequested(request):
                let trimmedPrompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedCredential = request.config.credential.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedEndpoint = request.config.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedPrompt.isEmpty else {
                    state.bannerMessage = state.appLanguage.localized("Enter a prompt for Nano Banana")
                    return .none
                }
                guard
                    request.config.accessMode == .appManaged ||
                    !trimmedCredential.isEmpty
                else {
                    state.bannerMessage = state.appLanguage.localized("Enter your Gemini API key")
                    return .none
                }
                guard
                    request.config.accessMode == .userAPIKey ||
                    !trimmedEndpoint.isEmpty
                else {
                    state.bannerMessage = state.appLanguage.localized("Enter your app server endpoint")
                    return .none
                }
                guard
                    let snapshot = state.canvas.renderSnapshot,
                    let layer = snapshot.layers.first(where: { $0.index == request.inputLayerIndex })
                else {
                    state.bannerMessage = state.appLanguage.localized("Could not prepare the active layer for Nano Banana")
                    return .none
                }

                let adjustedSelection = request.editScope == .selectedArea
                    ? Self.adjustedSelection(
                        state.canvas.selection,
                        canvasSize: state.canvas.canvasSize,
                        expansion: request.maskSettings.expansion,
                        isInverted: request.maskSettings.isInverted
                    )
                    : nil
                if request.editScope == .selectedArea, adjustedSelection?.isEmpty != false {
                    state.bannerMessage = state.appLanguage.localized("Create a selection to use inpaint")
                    return .none
                }

                let outputLayerIndex = request.outputMode == .replaceCurrentLayer
                    ? request.inputLayerIndex
                    : state.canvas.activeLayerIndex
                let canvasWidth = snapshot.width
                let canvasHeight = snapshot.height
                let appLanguage = state.appLanguage
                let sourceLayerPixelData = layer.pixelData
                let beforePreviewImageData = Self.pngData(
                    fromLayerPixelData: request.outputMode == .replaceCurrentLayer
                        ? sourceLayerPixelData
                        : Data(repeating: 0, count: canvasWidth * canvasHeight * 4),
                    width: canvasWidth,
                    height: canvasHeight
                )
                let normalizedRequest = NanoBananaGenerationRequest(
                    prompt: trimmedPrompt,
                    config: NanoBananaRequestConfig(
                        accessMode: request.config.accessMode,
                        credential: trimmedCredential,
                        endpoint: trimmedEndpoint
                    ),
                    model: request.model,
                    inputLayerIndex: request.inputLayerIndex,
                    editScope: request.editScope,
                    outputMode: request.outputMode,
                    maskSettings: request.maskSettings
                )
                let jobID = UUID()
                state.isNanoBananaGenerating = true
                state.nanoBananaPreview = nil
                state.pendingNanoBananaRequest = normalizedRequest
                state.activeNanoBananaJobID = jobID
                state.pendingNanoBananaOutputMode = request.outputMode
                state.nanoBananaJobs.insert(
                    NanoBananaJob(
                        id: jobID,
                        request: normalizedRequest,
                        createdAt: Date(),
                        status: .running,
                        message: nil
                    ),
                    at: 0
                )
                state.nanoBananaJobs = Array(state.nanoBananaJobs.prefix(12))

                return .run { [nanoBananaClient] send in
                        do {
                            let requestPrompt = normalizedRequest.editScope == .selectedArea
                                ? "Only edit the selected region. Keep everything outside the selected region unchanged.\n\n\(trimmedPrompt)"
                                : trimmedPrompt

                            let finalPixelData: Data?
                            switch normalizedRequest.editScope {
                            case .wholeLayer:
                                guard let inputPNGData = Self.pngData(
                                    fromLayerPixelData: sourceLayerPixelData,
                                    width: canvasWidth,
                                    height: canvasHeight
                                ) else {
                                    finalPixelData = nil
                                    break
                                }
                                let outputPNGData = try await nanoBananaClient.editImage(inputPNGData, requestPrompt, normalizedRequest.config, normalizedRequest.model)
                                finalPixelData = Self.rawLayerPixelData(
                                    fromPNGData: outputPNGData,
                                    width: canvasWidth,
                                    height: canvasHeight
                                )

                            case .selectedArea:
                                guard
                                    let adjustedSelection,
                                    let crop = Self.inpaintCrop(
                                        source: sourceLayerPixelData,
                                        canvasWidth: canvasWidth,
                                        canvasHeight: canvasHeight,
                                        selection: adjustedSelection
                                    ),
                                    let cropPNGData = Self.pngData(
                                        fromLayerPixelData: crop.pixelData,
                                        width: crop.width,
                                        height: crop.height
                                    )
                                else {
                                    finalPixelData = nil
                                    break
                                }

                                let outputPNGData = try await nanoBananaClient.editImage(cropPNGData, requestPrompt, normalizedRequest.config, normalizedRequest.model)
                                guard let editedCropPixelData = Self.rawLayerPixelData(
                                    fromPNGData: outputPNGData,
                                    width: crop.width,
                                    height: crop.height
                                ) else {
                                    finalPixelData = nil
                                    break
                                }

                                let baseLayerPixelData = normalizedRequest.outputMode == .replaceCurrentLayer
                                    ? sourceLayerPixelData
                                    : Data(repeating: 0, count: canvasWidth * canvasHeight * 4)
                                finalPixelData = Self.applyingInpaintCrop(
                                    editedCropPixelData,
                                    to: baseLayerPixelData,
                                    canvasWidth: canvasWidth,
                                    canvasHeight: canvasHeight,
                                    crop: crop
                                )
                            }

                            guard let finalPixelData else {
                                await send(.nanoBananaEditFailed("Nano Banana returned an unsupported image."))
                                return
                            }
                            let preview = NanoBananaPreviewState(
                                request: normalizedRequest,
                                outputLayerIndex: outputLayerIndex,
                                pixelData: finalPixelData,
                                beforePreviewImageData: beforePreviewImageData,
                                afterPreviewImageData: Self.pngData(
                                    fromLayerPixelData: finalPixelData,
                                    width: canvasWidth,
                                    height: canvasHeight
                                )
                            )
                            await send(.nanoBananaEditSucceeded(preview))
                        } catch {
                            await send(.nanoBananaEditFailed(Self.localizedNanoBananaErrorMessage(error.localizedDescription, language: appLanguage)))
                        }
                    }
                    .cancellable(id: CancelID.nanoBananaEdit, cancelInFlight: true)

            case let .nanoBananaEditSucceeded(preview):
                state.isNanoBananaGenerating = false
                state.nanoBananaHistory.insert(
                    NanoBananaHistoryItem(
                        id: UUID(),
                        request: preview.request,
                        createdAt: Date(),
                        previewImageData: preview.afterPreviewImageData
                    ),
                    at: 0
                )
                state.nanoBananaHistory = Array(state.nanoBananaHistory.prefix(12))
                if let activeJobID = state.activeNanoBananaJobID,
                   let jobIndex = state.nanoBananaJobs.firstIndex(where: { $0.id == activeJobID }) {
                    state.nanoBananaJobs[jobIndex].status = .succeeded
                    state.nanoBananaJobs[jobIndex].message = nil
                }
                state.applyNanoBananaPreview(preview, paintDocumentClient: paintDocumentClient)
                return .none

            case let .nanoBananaEditFailed(message):
                state.isNanoBananaGenerating = false
                if let activeJobID = state.activeNanoBananaJobID,
                   let jobIndex = state.nanoBananaJobs.firstIndex(where: { $0.id == activeJobID }) {
                    state.nanoBananaJobs[jobIndex].status = .failed
                    state.nanoBananaJobs[jobIndex].message = message
                }
                state.bannerMessage = message.isEmpty ? state.appLanguage.localized("Nano Banana edit failed") : message
                return .none

            case .nanoBananaCancelRequested:
                state.isNanoBananaGenerating = false
                if let activeJobID = state.activeNanoBananaJobID,
                   let jobIndex = state.nanoBananaJobs.firstIndex(where: { $0.id == activeJobID }) {
                    state.nanoBananaJobs[jobIndex].status = .canceled
                    state.nanoBananaJobs[jobIndex].message = state.appLanguage.localized("Nano Banana generation canceled")
                }
                state.bannerMessage = state.appLanguage.localized("Nano Banana generation canceled")
                return .merge(
                    .cancel(id: CancelID.nanoBananaEdit)
                )

            case .nanoBananaPreviewAccepted:
                guard let preview = state.nanoBananaPreview else { return .none }
                state.applyNanoBananaPreview(preview, paintDocumentClient: paintDocumentClient)
                return .none

            case .nanoBananaPreviewDiscarded:
                state.nanoBananaPreview = nil
                state.activeNanoBananaJobID = nil
                return .none

            case .nanoBananaRegenerateRequested:
                guard let request = state.nanoBananaPreview?.request ?? state.pendingNanoBananaRequest else { return .none }
                state.nanoBananaPreview = nil
                return .send(.nanoBananaEditRequested(request))

            case let .nanoBananaRetryJob(jobID):
                guard let job = state.nanoBananaJobs.first(where: { $0.id == jobID }) else { return .none }
                return .send(.nanoBananaEditRequested(job.request))

            case let .timelapseExportProgressUpdated(progress, previewData):
                state.timelapseExportPreview = TimelapseExportPreview(progress: progress, previewImageData: previewData ?? state.timelapseExportPreview?.previewImageData)
                return .none

            case let .timelapseExportSucceeded(url):
                state.timelapseExportPreview = nil
                state.exportSheet = ShareExport(url: url)
                return .none

            case let .timelapseExportFailed(message):
                state.timelapseExportPreview = nil
                state.bannerMessage = message
                return .none

            case .exportSheetDismissed:
                state.exportSheet = nil
                return .none

            case .bannerDismissed:
                state.bannerMessage = nil
                return .none

            case let .openDocumentSelected(url):
                if let existingTabID = state.tabID(forSourceProjectURL: url) {
                    state.isHydrating = false
                    return .send(.tabSelected(existingTabID))
                }
                if !state.showsHome {
                    persistActiveTabToBackingStore(state: &state)
                }
                state.isHydrating = true
                return .run { [paintDocumentClient] send in
                    do {
                        let loaded = try paintDocumentClient.loadProject(url)
                        await send(.openDocumentLoaded(loaded, url))
                    } catch {
                        await send(.openDocumentFailed(error.localizedDescription))
                    }
                    try? FileManager.default.removeItem(at: url)
                }

            case let .homeProjectSelected(url):
                if let existingTabID = state.tabID(forSourceProjectURL: url) {
                    state.showsHome = false
                    state.isHydrating = false
                    return .send(.tabSelected(existingTabID))
                }
                if !state.showsHome {
                    persistActiveTabToBackingStore(state: &state)
                }
                state.isHydrating = true
                return .run { [paintDocumentClient] send in
                    do {
                        let loaded = try paintDocumentClient.loadProject(url)
                        await send(.openDocumentLoaded(loaded, url))
                    } catch {
                        await send(.openDocumentFailed(error.localizedDescription))
                    }
                }

            case let .openDocumentLoaded(loaded, sourceURL):
                if let existingTabID = state.tabID(forSourceProjectURL: sourceURL) {
                    state.activeTabID = existingTabID
                    state.isHydrating = false
                    state.showsHome = false
                    return .send(.tabSelected(existingTabID))
                }
                state.applyLoadedProject(loaded)
                let title = sourceURL.deletingPathExtension().lastPathComponent
                activateNewTab(
                    state: &state,
                    title: title,
                    sourceProjectURL: sourceURL
                )
                state.isHydrating = false
                state.showsHome = false
                state.bannerMessage = StudioStrings.openedDocument(loaded.presentation.layerRows.count, state.appLanguage)
                return .none

            case let .openDocumentFailed(message):
                state.isHydrating = false
                state.bannerMessage = message.isEmpty ? StudioStrings.openFailed(state.appLanguage) : message
                return .none

            case let .photoImportReceived(name, data):
                guard let importedPixelData = Self.fittedLayerPixelData(fromImageData: data, canvasSize: state.canvas.canvasSize) else {
                    state.bannerMessage = state.appLanguage.localized("Could not import photo")
                    return .none
                }
                let nextNumber = state.layerSidebar.layers.count + 1
                let fallbackName = state.appLanguage == .japanese ? "写真 \(nextNumber)" : "Photo \(nextNumber)"
                let layerName = {
                    let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return trimmed.isEmpty ? fallbackName : trimmed
                }()
                paintDocumentClient.addLayer(layerName)
                let targetLayerIndex = state.layerSidebar.layers.count
                paintDocumentClient.replaceLayerPixels(targetLayerIndex, importedPixelData)
                paintDocumentClient.setActiveLayer(targetLayerIndex)
                state.canvas.activeLayerIndex = targetLayerIndex
                state.canvas.selection = nil
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                state.canvas.transformPreviewRotationDegrees = 0
                applyDirtyPresentation(state: &state)
                state.bannerMessage = state.appLanguage.localized("Photo imported to a new layer")
                return .none

            case let .photoImportFailed(message):
                state.bannerMessage = message.isEmpty ? state.appLanguage.localized("Could not import photo") : message
                return .none

            case let .toolSelected(tool):
                state.syncToolSpecificBrushSize()
                state.canvas.currentTool = tool
                state.applyToolSpecificBrushSize(for: tool)
                state.canvas.selectionMode = state.brushPalette.selection.toolMode
                state.canvas.shapeMode = state.brushPalette.shape.mode
                state.canvas.eyedropperSamplingSource = state.brushPalette.sampling.eyedropperSource
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                state.canvas.transformPreviewRotationDegrees = 0
                if tool != .select {
                    if tool != .move {
                        state.canvas.selection = nil
                    }
                }
                if tool == .text {
                    state.brushPanel.isCollapsed = false
                    if state.brushPalette.text.position == nil {
                        state.brushPalette.text.position = CGPoint(
                            x: state.canvas.canvasSize.width * 0.12,
                            y: state.canvas.canvasSize.height * 0.12
                        )
                    }
                    state.syncTextEditorWithActiveLayer()
                }
                state.canvas.previewStyle = state.previewStrokeStyle()
                return .none

            case let .toolLongPressed(tool):
                state.syncToolSpecificBrushSize()
                state.canvas.currentTool = tool
                state.applyToolSpecificBrushSize(for: tool)
                state.canvas.selectionMode = state.brushPalette.selection.toolMode
                state.canvas.eyedropperSamplingSource = state.brushPalette.sampling.eyedropperSource
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                state.canvas.transformPreviewRotationDegrees = 0
                if tool != .select {
                    if tool != .move {
                        state.canvas.selection = nil
                    }
                }
                if tool == .brush || tool == .erase {
                    state.brushPanel.isCollapsed = false
                    state.brushPalette.ui.showsBrushSettingsPopover = true
                }
                state.canvas.previewStyle = state.previewStrokeStyle()
                return .none

            case let .panelCollapseToggled(panel):
                state.toggleCollapse(for: panel)
                return .none

            case .brushPalette(.delegate(.clearSelection)):
                state.canvas.selection = nil
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                state.canvas.transformPreviewRotationDegrees = 0
                return .none

            case .brushPalette(.delegate(.invertSelection)):
                state.canvas.selection = Self.invertedSelection(
                    state.canvas.selection,
                    canvasSize: state.canvas.canvasSize,
                    mode: state.canvas.selectionMode
                )
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                state.canvas.transformPreviewRotationDegrees = 0
                return .none

            case let .brushPalette(.delegate(.expandSelection(expansion))):
                guard state.canvas.selection != nil else { return .none }
                state.canvas.selection = Self.adjustedSelection(
                    state.canvas.selection,
                    canvasSize: state.canvas.canvasSize,
                    expansion: max(expansion, 1),
                    isInverted: false
                )
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                state.canvas.transformPreviewRotationDegrees = 0
                return .none

            case let .brushPalette(.delegate(.contractSelection(contraction))):
                guard state.canvas.selection != nil else { return .none }
                state.canvas.selection = Self.adjustedSelection(
                    state.canvas.selection,
                    canvasSize: state.canvas.canvasSize,
                    expansion: -max(contraction, 1),
                    isInverted: false
                )
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                state.canvas.transformPreviewRotationDegrees = 0
                return .none

            case .brushPalette(.delegate(.cancelTransform)):
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                state.canvas.transformPreviewRotationDegrees = 0
                return .none

            case .brushPalette(.delegate(.applyTransform)):
                return applyTransform(state: &state)

            case let .brushPalette(.delegate(.applyText(draft))):
                let fontOption = state.brushPalette.text.availableFonts.first(where: { $0.postScriptName == draft.fontPostScriptName })
                    ?? state.brushPalette.text.availableFonts.first
                guard let position = draft.position else { return .none }
                let uiColor = UIColor(state.brushPalette.brush.activeOpaqueColor)
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                let textLayer = TextLayerData(
                    text: draft.text,
                    positionX: position.x,
                    positionY: position.y,
                    fontPostScriptName: fontOption?.postScriptName ?? draft.fontPostScriptName ?? UIFont.systemFont(ofSize: draft.fontSize).fontName,
                    fontDisplayName: fontOption?.displayName ?? draft.fontDisplayName ?? UIFont.systemFont(ofSize: draft.fontSize).fontName,
                    fontSize: draft.fontSize,
                    scale: draft.scale,
                    rotationDegrees: draft.rotationDegrees,
                    red: red,
                    green: green,
                    blue: blue,
                    alpha: alpha
                )

                let targetLayerIndex: Int
                if let existingIndex = draft.targetLayerIndex {
                    targetLayerIndex = existingIndex
                } else {
                    let layerName = draft.text.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let resolvedName = (layerName?.isEmpty == false ? layerName! : (state.appLanguage == .japanese ? "テキスト" : "Text"))
                    paintDocumentClient.addLayer(resolvedName)
                    targetLayerIndex = state.layerSidebar.layers.count
                }

                guard paintDocumentClient.setTextLayer(targetLayerIndex, textLayer) else {
                    state.bannerMessage = state.appLanguage.localized("テキストをレイヤーに適用できませんでした")
                    return .none
                }
                paintDocumentClient.setActiveLayer(targetLayerIndex)
                state.canvas.activeLayerIndex = targetLayerIndex
                state.canvas.currentTool = .text
                state.brushPalette.text.targetLayerIndex = targetLayerIndex
                applyDirtyPresentation(state: &state)
                return .none

            case .canvas(.delegate(.applyTransform)):
                return .none

            case let .canvas(.delegate(.placeText(point))):
                state.brushPalette.text.position = point
                state.brushPanel.isCollapsed = false
                return .none

            case .clearActiveLayerButtonTapped, .brushPalette(.delegate(.clearActiveLayer)):
                let activeLayerIndex = state.layerSidebar.activeLayerIndex
                paintDocumentClient.clearLayer(activeLayerIndex)
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                    state.canvas.localBufferRevision += 1
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case .createLayerMaskFromSelectionRequested:
                let activeLayerIndex = state.layerSidebar.activeLayerIndex
                guard let maskData = Self.layerMaskData(from: state.canvas.selection, canvasSize: state.canvas.canvasSize) else {
                    state.bannerMessage = state.appLanguage.localized("選択範囲を作成してからマスクを追加してください")
                    return .none
                }
                guard paintDocumentClient.replaceLayerMask(activeLayerIndex, maskData) else {
                    state.bannerMessage = state.appLanguage.localized("レイヤーマスクを作成できませんでした")
                    return .none
                }
                applyDirtyPresentation(state: &state)
                return .none

            case .clearLayerMaskRequested:
                let activeLayerIndex = state.layerSidebar.activeLayerIndex
                guard paintDocumentClient.clearLayerMask(activeLayerIndex) else {
                    return .none
                }
                applyDirtyPresentation(state: &state)
                return .none

            case .applyLayerMaskRequested:
                let activeLayerIndex = state.layerSidebar.activeLayerIndex
                guard paintDocumentClient.applyLayerMask(activeLayerIndex) else {
                    state.bannerMessage = state.appLanguage.localized("レイヤーマスクを適用できませんでした")
                    return .none
                }
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                    state.canvas.localBufferRevision += 1
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case .activeLayerVisibilityToggled:
                let activeLayerIndex = state.layerSidebar.activeLayerIndex
                guard let layer = state.layerSidebar.layers.first(where: { $0.index == activeLayerIndex }) else {
                    return .none
                }
                paintDocumentClient.setLayerVisibility(activeLayerIndex, !layer.visible)
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case .selectPreviousLayer:
                guard
                    let currentPosition = state.layerSidebar.layers.firstIndex(where: { $0.index == state.layerSidebar.activeLayerIndex }),
                    currentPosition > 0
                else {
                    return .none
                }
                let targetIndex = state.layerSidebar.layers[currentPosition - 1].index
                paintDocumentClient.setActiveLayer(targetIndex)
                state.canvas.activeLayerIndex = targetIndex
                state.canvas.selection = nil
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .selectNextLayer:
                guard
                    let currentPosition = state.layerSidebar.layers.firstIndex(where: { $0.index == state.layerSidebar.activeLayerIndex }),
                    currentPosition < state.layerSidebar.layers.count - 1
                else {
                    return .none
                }
                let targetIndex = state.layerSidebar.layers[currentPosition + 1].index
                paintDocumentClient.setActiveLayer(targetIndex)
                state.canvas.activeLayerIndex = targetIndex
                state.canvas.selection = nil
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .brushPalette:
                state.syncToolSpecificBrushSize()
                state.canvas.selectionMode = state.brushPalette.selection.toolMode
                state.canvas.shapeMode = state.brushPalette.shape.mode
                state.canvas.eyedropperSamplingSource = state.brushPalette.sampling.eyedropperSource
                state.canvas.previewStyle = state.previewStrokeStyle()
                state.canvas.paperStyle = state.resolvedPaperStyle()
                state.layerSidebar.paperColor = state.brushPalette.paper.color
                state.layerSidebar.transparentPaper = state.brushPalette.paper.isTransparent
                paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
                return .none

            case .layerSidebar(.binding(\.paperColor)):
                state.brushPalette.paper.color = state.layerSidebar.paperColor
                state.canvas.paperStyle = state.resolvedPaperStyle()
                paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
                return .none

            case .layerSidebar(.binding(\.transparentPaper)):
                state.brushPalette.paper.isTransparent = state.layerSidebar.transparentPaper
                state.canvas.paperStyle = state.resolvedPaperStyle()
                paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
                return .none

            case .layerSidebar(.delegate(.addLayer)):
                paintDocumentClient.addLayer("Layer \(state.layerSidebar.layers.count + 1)")
                state.canvas.activeLayerIndex = state.layerSidebar.layers.count
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case .layerSidebar(.delegate(.addFolder)):
                let nextFolderNumber = state.layerSidebar.rows.reduce(into: 0) { partialResult, row in
                    if case .folder = row {
                        partialResult += 1
                    }
                } + 1
                _ = paintDocumentClient.createFolder(
                    StudioStrings.folderName(nextFolderNumber, state.appLanguage),
                    state.layerSidebar.activeLayerIndex
                )
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.deleteFolder(folderID))):
                guard paintDocumentClient.deleteFolder(folderID) else {
                    return .none
                }
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.deleteLayer(index))):
                guard paintDocumentClient.deleteLayer(index) else {
                    return .none
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.duplicateLayer(index))):
                guard let layer = state.layerSidebar.layers.first(where: { $0.index == index }) else {
                    return .none
                }
                let duplicateName = state.appLanguage == .japanese ? "\(layer.name) のコピー" : "\(layer.name) Copy"
                guard paintDocumentClient.duplicateLayer(index, duplicateName) >= 0 else {
                    return .none
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.moveLayer(index, destinationIndex))):
                guard paintDocumentClient.moveLayer(index, destinationIndex) else {
                    return .none
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.moveLayerToFolder(index, folderID))):
                guard paintDocumentClient.assignLayerToFolder(index, folderID) else {
                    return .none
                }
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.removeLayerFromFolder(index))):
                guard paintDocumentClient.assignLayerToFolder(index, -1) else {
                    return .none
                }
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.setOpacity(index, opacity))):
                paintDocumentClient.setLayerOpacity(index, opacity)
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.toggleLayerLock(index))):
                guard let layer = state.layerSidebar.layers.first(where: { $0.index == index }) else {
                    return .none
                }
                paintDocumentClient.setLayerLocked(index, !layer.isLocked)
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.toggleAlphaLock(index))):
                guard let layer = state.layerSidebar.layers.first(where: { $0.index == index }) else {
                    return .none
                }
                paintDocumentClient.setLayerAlphaLocked(index, !layer.isAlphaLocked)
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.toggleClippingMask(index))):
                guard let layer = state.layerSidebar.layers.first(where: { $0.index == index }) else {
                    return .none
                }
                guard layer.isClipped || index > 0 else {
                    return .none
                }
                paintDocumentClient.setLayerClipped(index, !layer.isClipped)
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.mergeDown(index))):
                guard paintDocumentClient.mergeLayerDown(index) else {
                    return .none
                }
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.selectLayer(index))):
                paintDocumentClient.setActiveLayer(index)
                state.canvas.activeLayerIndex = index
                state.canvas.selection = nil
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.toggleVisibility(index))):
                guard let layer = state.layerSidebar.layers.first(where: { $0.index == index }) else {
                    return .none
                }
                paintDocumentClient.setLayerVisibility(index, !layer.visible)
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.setFolderExpanded(folderID, isExpanded))):
                paintDocumentClient.setFolderExpanded(folderID, isExpanded)
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.toggleFolderVisibility(folderID))):
                guard let folder = state.layerSidebar.rows.compactMap({ row -> LayerFolderModel? in
                    if case let .folder(folder) = row, folder.id == folderID {
                        return folder
                    }
                    return nil
                }).first else {
                    return .none
                }
                paintDocumentClient.setFolderVisibility(folderID, !folder.visible)
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.renameFolder(folderID, name))):
                paintDocumentClient.setFolderName(folderID, name)
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.setBlendMode(index, blendMode))):
                paintDocumentClient.setLayerBlendMode(index, blendMode)
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case let .layerSidebar(.delegate(.renameLayer(index, name))):
                paintDocumentClient.setLayerName(index, name)
                applyDirtyPresentation(state: &state)
                return .none

            case let .canvas(.delegate(.beginStroke(sample))):
                guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
                    return .none
                }
                paintDocumentClient.setLayerVisibility(state.canvas.activeLayerIndex, true)
                state.canvas.selection = nil
                paintDocumentClient.cancelStroke()
                if state.canvas.activeStrokeBaseSnapshot == nil {
                    if state.canvas.renderSnapshot == nil {
                        state.applyPresentation(paintDocumentClient.presentation())
                    }
                    state.canvas.activeStrokeBaseSnapshot = state.canvas.renderSnapshot
                }
                let brush = state.resolvedBrushSettings()
                var previewBrush = brush
                previewBrush.taperIn = 0
                previewBrush.taperOut = 0
                if
                    let baseSnapshot = state.canvas.activeStrokeBaseSnapshot,
                    let baseLayer = baseSnapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                    let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                        basePixelData: baseLayer.pixelData,
                        canvasWidth: baseSnapshot.width,
                        canvasHeight: baseSnapshot.height,
                        samples: [sample],
                        brush: previewBrush,
                        preserveAlphaLockedPixels: activeLayer.isAlphaLocked
                    )
                {
                    state.canvas.activeStrokePreviewLayerPixelData = adjustedPixels
                    if
                        Self.shouldUseIncrementalPreviewUpdate(for: previewBrush),
                        let dirtyRect = Self.strokePreviewDirtyRect(
                            samples: [sample],
                            brush: previewBrush,
                            canvasWidth: baseSnapshot.width,
                            canvasHeight: baseSnapshot.height
                        ),
                        let incrementalUpdate = Self.compositedPreviewIncrementalUpdate(
                            snapshot: baseSnapshot,
                            activeLayerIndex: state.canvas.activeLayerIndex,
                            adjustedActiveLayerPixels: adjustedPixels,
                            dirtyRect: dirtyRect
                        )
                    {
                        state.canvas.pendingIncrementalUpdate = incrementalUpdate
                    } else {
                        state.applyLiveStrokePreview(
                            baseSnapshot: baseSnapshot,
                            activeLayerIndex: state.canvas.activeLayerIndex,
                            adjustedActiveLayerPixels: adjustedPixels
                        )
                    }
                }
                return .concatenate(
                    .cancel(id: CancelID.startupPresentationLoad),
                    .cancel(id: CancelID.deferredPresentationRefresh)
                )

            case let .canvas(.delegate(.appendSamples(samples))):
                guard !samples.isEmpty else { return .none }
                guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
                    return .none
                }
                let brush = state.resolvedBrushSettings()
                var previewBrush = brush
                previewBrush.taperIn = 0
                previewBrush.taperOut = 0
                if
                    let baseSnapshot = state.canvas.activeStrokeBaseSnapshot,
                    let baseLayer = baseSnapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex })
                {
                    let fullSamples = state.canvas.activeStroke?.points.map(\.stylusSample) ?? samples
                    let anchorIndex = max(fullSamples.count - samples.count - 1, 0)
                    let anchor = fullSamples.indices.contains(anchorIndex) ? fullSamples[anchorIndex] : nil
                    let deltaSamples = anchor.map { [$0] + samples } ?? samples
                    let previewSamples = deltaSamples
                    let basePixelData = state.canvas.activeStrokePreviewLayerPixelData ?? baseLayer.pixelData
                    guard let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                        basePixelData: basePixelData,
                        canvasWidth: baseSnapshot.width,
                        canvasHeight: baseSnapshot.height,
                        samples: previewSamples,
                        brush: previewBrush,
                        preserveAlphaLockedPixels: activeLayer.isAlphaLocked
                    ) else {
                        return .none
                    }
                    state.canvas.activeStrokePreviewLayerPixelData = adjustedPixels
                    if
                        Self.shouldUseIncrementalPreviewUpdate(for: previewBrush),
                        let dirtyRect = Self.strokePreviewDirtyRect(
                            samples: previewSamples,
                            brush: previewBrush,
                            canvasWidth: baseSnapshot.width,
                            canvasHeight: baseSnapshot.height
                        ),
                        let incrementalUpdate = Self.compositedPreviewIncrementalUpdate(
                            snapshot: baseSnapshot,
                            activeLayerIndex: state.canvas.activeLayerIndex,
                            adjustedActiveLayerPixels: adjustedPixels,
                            dirtyRect: dirtyRect
                        )
                    {
                        state.canvas.pendingIncrementalUpdate = incrementalUpdate
                    } else {
                        state.applyLiveStrokePreview(
                            baseSnapshot: baseSnapshot,
                            activeLayerIndex: state.canvas.activeLayerIndex,
                            adjustedActiveLayerPixels: adjustedPixels
                        )
                    }
                } else if let snapshot = state.canvas.renderSnapshot,
                    let baseLayer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                    let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                        basePixelData: baseLayer.pixelData,
                        canvasWidth: snapshot.width,
                        canvasHeight: snapshot.height,
                        samples: samples,
                        brush: previewBrush,
                        preserveAlphaLockedPixels: activeLayer.isAlphaLocked
                    )
                {
                    state.canvas.activeStrokeBaseSnapshot = snapshot
                    state.canvas.activeStrokePreviewLayerPixelData = adjustedPixels
                    if
                        Self.shouldUseIncrementalPreviewUpdate(for: previewBrush),
                        let dirtyRect = Self.strokePreviewDirtyRect(
                            samples: samples,
                            brush: previewBrush,
                            canvasWidth: snapshot.width,
                            canvasHeight: snapshot.height
                        ),
                        let incrementalUpdate = Self.compositedPreviewIncrementalUpdate(
                            snapshot: snapshot,
                            activeLayerIndex: state.canvas.activeLayerIndex,
                            adjustedActiveLayerPixels: adjustedPixels,
                            dirtyRect: dirtyRect
                        )
                    {
                        state.canvas.pendingIncrementalUpdate = incrementalUpdate
                    } else {
                        state.applyLiveStrokePreview(
                            baseSnapshot: snapshot,
                            activeLayerIndex: state.canvas.activeLayerIndex,
                            adjustedActiveLayerPixels: adjustedPixels
                        )
                    }
                }
                return .none

            case let .canvas(.delegate(.previewShapeStroke(samples))):
                guard let first = samples.first else { return .none }
                paintDocumentClient.setLayerVisibility(state.canvas.activeLayerIndex, true)
                state.canvas.selection = nil
                paintDocumentClient.cancelStroke()
                paintDocumentClient.beginStroke(first, state.resolvedBrushSettings())
                for sample in samples.dropFirst() {
                    paintDocumentClient.appendStroke(sample)
                }
                state.applyLiveCompositePixelData(paintDocumentClient.compositePixelData())
                return .concatenate(
                    .cancel(id: CancelID.startupPresentationLoad),
                    .cancel(id: CancelID.deferredPresentationRefresh)
                )

            case .canvas(.delegate(.commitPreviewShapeStroke)):
                paintDocumentClient.endStroke()
                applyDirtyPresentation(state: &state)
                return .concatenate(
                    .cancel(id: CancelID.startupPresentationLoad),
                    .cancel(id: CancelID.deferredPresentationRefresh)
                )

            case let .canvas(.delegate(.endStroke(samples))):
                guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
                    state.canvas.activeStrokeBaseSnapshot = nil
                    state.canvas.activeStrokePreviewLayerPixelData = nil
                    state.canvas.pendingIncrementalUpdate = nil
                    return .none
                }
                let brush = state.resolvedBrushSettings()
                let shouldApplyTaperOnCommit = brush.taperIn > 0.001 || brush.taperOut > 0.001
                if let previewPixels = state.canvas.activeStrokePreviewLayerPixelData, !shouldApplyTaperOnCommit {
                    paintDocumentClient.replaceLayerPixels(state.canvas.activeLayerIndex, previewPixels)
                } else {
                    let didCommit = paintDocumentClient.applySoftwareStroke(
                        samples,
                        brush,
                        state.canvas.activeLayerIndex
                    )
                    if !didCommit,
                        let baseSnapshot = state.canvas.activeStrokeBaseSnapshot,
                        let baseLayer = baseSnapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                        let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                            basePixelData: baseLayer.pixelData,
                            canvasWidth: baseSnapshot.width,
                            canvasHeight: baseSnapshot.height,
                            samples: samples,
                            brush: brush,
                            preserveAlphaLockedPixels: activeLayer.isAlphaLocked
                        ) {
                        paintDocumentClient.replaceLayerPixels(state.canvas.activeLayerIndex, adjustedPixels)
                    }
                }
                state.canvas.activeStrokeBaseSnapshot = nil
                state.canvas.activeStrokePreviewLayerPixelData = nil
                state.canvas.pendingIncrementalUpdate = nil
                applyDirtyPresentation(state: &state)
                return .concatenate(
                    .cancel(id: CancelID.startupPresentationLoad),
                    .cancel(id: CancelID.deferredPresentationRefresh)
                )

            case .canvas(.delegate(.cancelStroke)):
                if state.canvas.currentTool == .shape {
                    paintDocumentClient.cancelStroke()
                }
                state.canvas.activeStrokeBaseSnapshot = nil
                state.canvas.activeStrokePreviewLayerPixelData = nil
                state.canvas.pendingIncrementalUpdate = nil
                state.applyPresentation(paintDocumentClient.presentation())
                return .concatenate(
                    .cancel(id: CancelID.startupPresentationLoad),
                    .cancel(id: CancelID.deferredPresentationRefresh)
                )

            case let .canvas(.delegate(.commitStroke(samples))):
                guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
                    state.canvas.activeStrokeBaseSnapshot = nil
                    state.canvas.activeStrokePreviewLayerPixelData = nil
                    state.canvas.pendingIncrementalUpdate = nil
                    return .none
                }
                let brush = state.resolvedBrushSettings()
                let shouldApplyTaperOnCommit = brush.taperIn > 0.001 || brush.taperOut > 0.001
                paintDocumentClient.setLayerVisibility(state.canvas.activeLayerIndex, true)
                state.canvas.selection = nil
                if let previewPixels = state.canvas.activeStrokePreviewLayerPixelData, !shouldApplyTaperOnCommit {
                    paintDocumentClient.replaceLayerPixels(state.canvas.activeLayerIndex, previewPixels)
                } else {
                    let didCommit = paintDocumentClient.applySoftwareStroke(
                        samples,
                        brush,
                        state.canvas.activeLayerIndex
                    )
                    if !didCommit {
                        if state.canvas.renderSnapshot == nil {
                            state.applyPresentation(paintDocumentClient.presentation())
                        }
                        let fallbackSnapshot = state.canvas.activeStrokeBaseSnapshot ?? state.canvas.renderSnapshot
                        if let snapshot = fallbackSnapshot,
                            let baseLayer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
                            let adjustedPixels = Self.layerPixelDataByApplyingCommittedStroke(
                                basePixelData: baseLayer.pixelData,
                                canvasWidth: snapshot.width,
                                canvasHeight: snapshot.height,
                                samples: samples,
                                brush: brush,
                                preserveAlphaLockedPixels: activeLayer.isAlphaLocked
                            ) {
                            paintDocumentClient.replaceLayerPixels(state.canvas.activeLayerIndex, adjustedPixels)
                        }
                    }
                }
                state.canvas.activeStrokeBaseSnapshot = nil
                state.canvas.activeStrokePreviewLayerPixelData = nil
                state.canvas.pendingIncrementalUpdate = nil
                state.applyPresentation(paintDocumentClient.presentation())
                return .concatenate(
                    .cancel(id: CancelID.startupPresentationLoad),
                    .cancel(id: CancelID.deferredPresentationRefresh)
                )

            case let .canvas(.delegate(.blurSamples(samples))):
                guard !samples.isEmpty else { return .none }
                guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
                    return .none
                }
                paintDocumentClient.revealLayerForEditing(state.canvas.activeLayerIndex)
                paintDocumentClient.blurStroke(samples, state.resolvedBrushSettings(), state.canvas.activeLayerIndex, false)
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .none

            case .canvas(.delegate(.endBlurStroke)):
                paintDocumentClient.endBlurStroke()
                applyDirtyPresentation(state: &state)
                return .none

            case let .canvas(.delegate(.fill(sample))):
                guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.canvas.activeLayerIndex }), !activeLayer.isLocked else {
                    return .none
                }
                paintDocumentClient.setLayerVisibility(state.canvas.activeLayerIndex, true)
                paintDocumentClient.fill(sample, state.resolvedBrushSettings())
                state.canvas.selection = nil
                applyDirtyPresentation(state: &state)
                return .concatenate(
                    .cancel(id: CancelID.startupPresentationLoad),
                    .cancel(id: CancelID.deferredPresentationRefresh)
                )

            case let .canvas(.delegate(.lassoSelect(points))):
                let incomingSelection = Self.makeLassoSelection(
                    from: points,
                    canvasSize: state.canvas.canvasSize
                )
                let selection = Self.combinedSelection(
                    existing: state.canvas.selection,
                    incoming: incomingSelection,
                    mode: state.brushPalette.selection.combineMode,
                    canvasSize: state.canvas.canvasSize
                )
                return .send(.canvas(.selectionUpdated(selection)))

            case let .canvas(.delegate(.autoSelect(sample))):
                let incomingSelection = Self.makeAutoSelection(
                    at: sample.point,
                    snapshot: state.canvas.renderSnapshot,
                    layerIndex: state.canvas.activeLayerIndex,
                    thresholdMode: state.brushPalette.selection.thresholdMode,
                    opacityTolerance: state.brushPalette.selection.opacityTolerance,
                    colorTolerance: state.brushPalette.selection.colorTolerance,
                    expansion: Int(state.brushPalette.selection.expansion.rounded())
                )
                let selection = Self.combinedSelection(
                    existing: state.canvas.selection,
                    incoming: incomingSelection,
                    mode: state.brushPalette.selection.combineMode,
                    canvasSize: state.canvas.canvasSize
                )
                return .send(.canvas(.selectionUpdated(selection)))

            case .canvas(.delegate(.requestUndo)):
                return .send(.undoRequested)

            case .canvas(.delegate(.requestRedo)):
                return .send(.redoRequested)

            case .canvas(.delegate(.toggleBrushAndEraser)):
                state.syncToolSpecificBrushSize()
                let nextTool: StudioToolKind = state.canvas.currentTool == .erase ? .brush : .erase
                state.canvas.currentTool = nextTool
                state.applyToolSpecificBrushSize(for: nextTool)
                state.canvas.selectionMode = state.brushPalette.selection.toolMode
                state.canvas.eyedropperSamplingSource = state.brushPalette.sampling.eyedropperSource
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                state.canvas.transformPreviewRotationDegrees = 0
                if nextTool != .select && nextTool != .move {
                    state.canvas.selection = nil
                }
                state.canvas.previewStyle = state.previewStrokeStyle()
                return .none

            case let .canvas(.colorSampled(sampledColor)):
                let sampled = Self.color(from: sampledColor)
                if state.brushPalette.brush.selectedColorSlot == .transparent {
                    state.brushPalette.brush.selectedColorSlot = .primary
                }
                state.brushPalette.brush.setSelectedSlotColor(sampled)
                state.brushPalette.library.selectedBrush = nil
                state.canvas.previewStyle = state.previewStrokeStyle()
                return .none

                case .layerSidebar, .canvas:
                    return .none
                }
            }
        }
    }
}
