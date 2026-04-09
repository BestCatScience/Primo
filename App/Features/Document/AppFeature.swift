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

struct StudioPanelLayoutState: Equatable {
    var isCollapsed: Bool = false
}

@Reducer
struct AppFeature {
    private static let startupLogger = Logger(subsystem: "com.atelierprime.app", category: "Startup")
    private enum CancelID {
        case deferredPresentationRefresh
        case startupPresentationLoad
        case timelapseExport
    }

    @ObservableState
    struct State: Equatable {
        var isHydrating = true
        var brushPalette = BrushPaletteFeature.State()
        var layerSidebar = LayerSidebarFeature.State()
        var canvas = CanvasFeature.State()
        var brushPanel = StudioPanelLayoutState()
        var layerPanel = StudioPanelLayoutState()
        var exportSheet: ShareExport?
        var bannerMessage: String?
        var timelapseExportPreview: TimelapseExportPreview?
        var appLanguage: AppLanguage = .load()

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
    }

    enum Action: Equatable {
        case task
        case bootstrapPresentationLoaded(PaintDocumentPresentation)
        case presentationLoaded(PaintDocumentPresentation)
        case loadPresentationAfterLaunch
        case deferredPresentationRefresh
        case refreshPresentationRequested
        case newCanvasRequested(width: Int, height: Int)
        case undoRequested
        case redoRequested
        case saveDocumentRequested
        case exportDocumentRequested
        case exportTimelapseRequested
        case openDocumentSelected(URL)
        case openDocumentLoaded(LoadedPaintProject)
        case openDocumentFailed(String)
        case timelapseExportProgressUpdated(Double, Data?)
        case timelapseExportSucceeded(URL)
        case timelapseExportFailed(String)
        case exportSheetDismissed
        case bannerDismissed
        case languageChanged(AppLanguage)
        case toolSelected(StudioToolKind)
        case toolLongPressed(StudioToolKind)
        case clearActiveLayerButtonTapped
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
        case activeLayerVisibilityToggled
        case selectPreviousLayer
        case selectNextLayer
        case panelCollapseToggled(StudioPanelKind)
        case brushPalette(BrushPaletteFeature.Action)
        case layerSidebar(LayerSidebarFeature.Action)
        case canvas(CanvasFeature.Action)
    }

    @Dependency(\.paintDocumentClient) var paintDocumentClient

    var body: some ReducerOf<Self> {
        Scope(state: \.brushPalette, action: \.brushPalette) {
            BrushPaletteFeature()
        }
        Scope(state: \.layerSidebar, action: \.layerSidebar) {
            LayerSidebarFeature()
        }
        Scope(state: \.canvas, action: \.canvas) {
            CanvasFeature()
        }

        Reduce { state, action in
            switch action {
            case .task:
                state.isHydrating = true
                state.appLanguage = .load()
                paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
                Self.startupLogger.debug("AppFeature.task started")
                return .run { [paintDocumentClient] send in
                    let startupClock = ContinuousClock()
                    let bootstrapStart = startupClock.now

                    Self.startupLogger.debug("Loading lightweight presentation")
                    let lightweightPresentation = paintDocumentClient.lightweightPresentation()
                    let bootstrapDuration = bootstrapStart.duration(to: startupClock.now)
                    Self.startupLogger.debug("Lightweight presentation loaded in \(String(describing: bootstrapDuration), privacy: .public)")
                    await send(.bootstrapPresentationLoaded(lightweightPresentation))
                    paintDocumentClient.prewarmDrawingResources()
                    await send(.loadPresentationAfterLaunch)
                }

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

            case let .presentationLoaded(presentation):
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
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .languageChanged(language):
                state.appLanguage = language
                language.persist()
                return .none

            case let .newCanvasRequested(width, height):
                let width = max(width, 1)
                let height = max(height, 1)
                paintDocumentClient.newCanvas(width, height)
                paintDocumentClient.prewarmDrawingResources()
                paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
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
                state.applyPresentation(paintDocumentClient.presentation())
                return .merge(
                    .cancel(id: CancelID.startupPresentationLoad),
                    .cancel(id: CancelID.deferredPresentationRefresh)
                )

            case .undoRequested:
                guard !state.canvas.isStrokeActive else {
                    state.bannerMessage = state.appLanguage.localized("Undo is unavailable while drawing")
                    return .none
                }
                guard paintDocumentClient.undo() else {
                    return .none
                }
                state.canvas.selection = nil
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
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
                    let url = try Self.projectURLInDocuments()
                    try paintDocumentClient.saveProject(url, state.resolvedPaperStyle())
                    state.exportSheet = ShareExport(url: url)
                    state.bannerMessage = StudioStrings.savedDocument(url.lastPathComponent, state.appLanguage)
                } catch {
                    state.bannerMessage = error.localizedDescription.isEmpty ? state.appLanguage.localized("Save failed") : error.localizedDescription
                }
                return .none

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
                state.isHydrating = true
                return .run { [paintDocumentClient] send in
                    do {
                        let loaded = try paintDocumentClient.loadProject(url)
                        await send(.openDocumentLoaded(loaded))
                    } catch {
                        await send(.openDocumentFailed(error.localizedDescription))
                    }
                    try? FileManager.default.removeItem(at: url)
                }

            case let .openDocumentLoaded(loaded):
                state.brushPalette.paper.color = Color(
                    red: Double(loaded.paperStyle.red),
                    green: Double(loaded.paperStyle.green),
                    blue: Double(loaded.paperStyle.blue),
                    opacity: Double(loaded.paperStyle.alpha)
                )
                state.brushPalette.paper.isTransparent = loaded.paperStyle.isTransparent
                state.canvas.selection = nil
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                state.canvas.adjustmentPreviewPixelData = nil
                state.applyPresentation(loaded.presentation)
                state.isHydrating = false
                state.bannerMessage = StudioStrings.openedDocument(loaded.presentation.layerRows.count, state.appLanguage)
                return .none

            case let .openDocumentFailed(message):
                state.isHydrating = false
                state.bannerMessage = message.isEmpty ? StudioStrings.openFailed(state.appLanguage) : message
                return .none

            case let .toolSelected(tool):
                state.canvas.currentTool = tool
                state.canvas.selectionMode = state.brushPalette.selection.toolMode
                state.canvas.shapeMode = state.brushPalette.shape.mode
                state.canvas.eyedropperSamplingSource = state.brushPalette.sampling.eyedropperSource
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                if tool != .select {
                    if tool != .move {
                        state.canvas.selection = nil
                    }
                }
                state.canvas.previewStyle = state.previewStrokeStyle()
                return .none

            case let .toolLongPressed(tool):
                state.canvas.currentTool = tool
                state.canvas.selectionMode = state.brushPalette.selection.toolMode
                state.canvas.eyedropperSamplingSource = state.brushPalette.sampling.eyedropperSource
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                if tool != .select {
                    if tool != .move {
                        state.canvas.selection = nil
                    }
                }
                if tool == .brush {
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
                return .none

            case .brushPalette(.delegate(.cancelTransform)):
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
                return .none

            case .brushPalette(.delegate(.applyTransform)):
                return applyTransform(state: &state)

            case .canvas(.delegate(.applyTransform)):
                return .none

            case .clearActiveLayerButtonTapped, .brushPalette(.delegate(.clearActiveLayer)):
                let activeLayerIndex = state.layerSidebar.activeLayerIndex
                paintDocumentClient.clearLayer(activeLayerIndex)
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                    state.canvas.localBufferRevision += 1
                }
                state.canvas.selection = nil
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .activeLayerVisibilityToggled:
                let activeLayerIndex = state.layerSidebar.activeLayerIndex
                guard let layer = state.layerSidebar.layers.first(where: { $0.index == activeLayerIndex }) else {
                    return .none
                }
                paintDocumentClient.setLayerVisibility(activeLayerIndex, !layer.visible)
                state.canvas.selection = nil
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.deleteFolder(folderID))):
                guard paintDocumentClient.deleteFolder(folderID) else {
                    return .none
                }
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.deleteLayer(index))):
                guard paintDocumentClient.deleteLayer(index) else {
                    return .none
                }
                state.canvas.selection = nil
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.moveLayer(index, destinationIndex))):
                guard paintDocumentClient.moveLayer(index, destinationIndex) else {
                    return .none
                }
                state.canvas.selection = nil
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.moveLayerToFolder(index, folderID))):
                guard paintDocumentClient.assignLayerToFolder(index, folderID) else {
                    return .none
                }
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.removeLayerFromFolder(index))):
                guard paintDocumentClient.assignLayerToFolder(index, -1) else {
                    return .none
                }
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.setOpacity(index, opacity))):
                paintDocumentClient.setLayerOpacity(index, opacity)
                state.canvas.selection = nil
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
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
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.renameFolder(folderID, name))):
                paintDocumentClient.setFolderName(folderID, name)
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.setBlendMode(index, blendMode))):
                paintDocumentClient.setLayerBlendMode(index, blendMode)
                state.canvas.selection = nil
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.renameLayer(index, name))):
                paintDocumentClient.setLayerName(index, name)
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .canvas(.delegate(.beginStroke(sample))):
                paintDocumentClient.setLayerVisibility(state.canvas.activeLayerIndex, true)
                state.canvas.selection = nil
                paintDocumentClient.beginStroke(sample, state.resolvedBrushSettings())
                if let update = paintDocumentClient.consumeDirtyUpdate() {
                    return .concatenate(
                        .cancel(id: CancelID.startupPresentationLoad),
                        .send(.canvas(.applyIncrementalUpdate(update)))
                    )
                }
                return .concatenate(
                    .cancel(id: CancelID.startupPresentationLoad),
                    .send(.presentationLoaded(paintDocumentClient.presentation()))
                )

            case let .canvas(.delegate(.appendSamples(samples))):
                for sample in samples {
                    paintDocumentClient.appendStroke(sample)
                }
                if let update = paintDocumentClient.consumeDirtyUpdate() {
                    return .send(.canvas(.applyIncrementalUpdate(update)))
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
                if let update = paintDocumentClient.consumeDirtyUpdate() {
                    return .concatenate(
                        .cancel(id: CancelID.startupPresentationLoad),
                        .send(.canvas(.applyIncrementalUpdate(update)))
                    )
                }
                return .concatenate(
                    .cancel(id: CancelID.startupPresentationLoad),
                    .send(.presentationLoaded(paintDocumentClient.presentation()))
                )

            case .canvas(.delegate(.commitPreviewShapeStroke)):
                paintDocumentClient.endStroke()
                return .send(.presentationLoaded(paintDocumentClient.presentation()))

            case .canvas(.delegate(.endStroke)):
                paintDocumentClient.endStroke()
                return .send(.presentationLoaded(paintDocumentClient.presentation()))

            case .canvas(.delegate(.cancelStroke)):
                paintDocumentClient.cancelStroke()
                if let update = paintDocumentClient.consumeDirtyUpdate() {
                    return .concatenate(
                        .cancel(id: CancelID.startupPresentationLoad),
                        .send(.canvas(.applyIncrementalUpdate(update)))
                    )
                }
                return .concatenate(
                    .cancel(id: CancelID.startupPresentationLoad),
                    .send(.presentationLoaded(paintDocumentClient.presentation()))
                )

            case let .canvas(.delegate(.commitStroke(samples))):
                guard let first = samples.first else { return .none }
                state.canvas.selection = nil
                paintDocumentClient.beginStroke(first, state.resolvedBrushSettings())
                for sample in samples.dropFirst() {
                    paintDocumentClient.appendStroke(sample)
                }
                paintDocumentClient.endStroke()
                return .send(.presentationLoaded(paintDocumentClient.presentation()))

            case let .canvas(.delegate(.blurSamples(samples))):
                guard !samples.isEmpty else { return .none }
                paintDocumentClient.revealLayerForEditing(state.canvas.activeLayerIndex)
                paintDocumentClient.blurStroke(samples, state.resolvedBrushSettings(), state.canvas.activeLayerIndex, false)
                state.canvas.selection = nil
                return .send(.presentationLoaded(paintDocumentClient.presentation()))

            case .canvas(.delegate(.endBlurStroke)):
                paintDocumentClient.endBlurStroke()
                return .send(.presentationLoaded(paintDocumentClient.presentation()))

            case let .canvas(.delegate(.fill(sample))):
                paintDocumentClient.setLayerVisibility(state.canvas.activeLayerIndex, true)
                paintDocumentClient.fill(sample, state.resolvedBrushSettings())
                state.canvas.selection = nil
                if let update = paintDocumentClient.consumeDirtyUpdate() {
                    return .concatenate(
                        .cancel(id: CancelID.startupPresentationLoad),
                        .send(.canvas(.applyIncrementalUpdate(update)))
                    )
                }
                return .concatenate(
                    .cancel(id: CancelID.startupPresentationLoad),
                    .send(.presentationLoaded(paintDocumentClient.presentation()))
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
                let nextTool: StudioToolKind = state.canvas.currentTool == .erase ? .brush : .erase
                state.canvas.currentTool = nextTool
                state.canvas.selectionMode = state.brushPalette.selection.toolMode
                state.canvas.eyedropperSamplingSource = state.brushPalette.sampling.eyedropperSource
                state.canvas.selectionPreviewPoints = []
                state.canvas.transformPreviewOffset = .zero
                state.canvas.transformPreviewScale = 1.0
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
