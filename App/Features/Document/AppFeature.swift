import AVFoundation
import ComposableArchitecture
import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
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
            return language == .japanese ? "ブラシ" : "Brush"
        case .layers:
            return language == .japanese ? "レイヤー" : "Layers"
        }
    }
}

enum StudioPanelSide: String, Equatable {
    case leading
    case trailing
}

struct StudioPanelLayoutState: Equatable {
    var side: StudioPanelSide
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
        var brushPanel = StudioPanelLayoutState(side: .leading)
        var layerPanel = StudioPanelLayoutState(side: .trailing)
        var stackedPanelOrder: [StudioPanelKind] = [.brush, .layers]
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
            layerSidebar.layerBuffers = canvas.layerBuffers
            layerSidebar.activeLayerIndex = presentation.activeLayerIndex
            layerSidebar.paperColor = brushPalette.paperColor
            layerSidebar.transparentPaper = brushPalette.transparentPaper
            canvas.previewStyle = previewStrokeStyle()
            canvas.selectionMode = brushPalette.selectionToolMode
            canvas.paperStyle = resolvedPaperStyle()
        }

        func resolvedBrushSettings() -> BrushRuntimeSettings {
            var settings = brushPalette.runtimeSettings
            if canvas.currentTool == .erase {
                settings.isEraser = true
            }
            return settings
        }

        func previewStrokeStyle() -> PreviewStrokeStyle {
            if canvas.currentTool == .erase {
                return PreviewStrokeStyle(
                    tipKind: .ink,
                    isEraser: true,
                    radius: CGFloat(brushPalette.runtimeSettings.radius),
                    opacity: 0.78,
                    hardness: 0.95,
                    pressureSensitivity: CGFloat(brushPalette.runtimeSettings.pressureSensitivity),
                    stabilization: CGFloat(brushPalette.runtimeSettings.stabilization),
                    color: CGColor(
                        red: 0.92,
                        green: 0.95,
                        blue: 0.98,
                        alpha: 1.0
                    )
                )
            }

            return PreviewStrokeStyle(
                tipKind: brushPalette.runtimeSettings.tipKind,
                isEraser: false,
                radius: CGFloat(brushPalette.runtimeSettings.radius),
                opacity: CGFloat(brushPalette.runtimeSettings.opacity),
                hardness: CGFloat(brushPalette.runtimeSettings.hardness),
                pressureSensitivity: CGFloat(brushPalette.runtimeSettings.pressureSensitivity),
                stabilization: CGFloat(brushPalette.runtimeSettings.stabilization),
                color: CGColor(
                    red: CGFloat(brushPalette.runtimeSettings.red) / 255.0,
                    green: CGFloat(brushPalette.runtimeSettings.green) / 255.0,
                    blue: CGFloat(brushPalette.runtimeSettings.blue) / 255.0,
                    alpha: 1.0
                )
            )
        }

        func resolvedPaperStyle() -> CanvasPaperStyle {
            let resolved = UIColor(brushPalette.paperColor)
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
                isTransparent: brushPalette.transparentPaper
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

        mutating func movePanel(_ panel: StudioPanelKind, to side: StudioPanelSide) {
            var current = panelState(for: panel)
            current.side = side
            current.isCollapsed = false
            setPanelState(current, for: panel)
        }

        mutating func movePanelIntoStack(_ panel: StudioPanelKind) {
            let companion = panel == .brush ? StudioPanelKind.layers : .brush
            movePanel(panel, to: panelState(for: companion).side)
        }

        mutating func unstackPanel(_ panel: StudioPanelKind) {
            let defaultSide: StudioPanelSide = panel == .brush ? .leading : .trailing
            movePanel(panel, to: defaultSide)
        }

        mutating func swapStackOrder() {
            guard stackedPanelOrder.count == 2 else { return }
            stackedPanelOrder.swapAt(0, 1)
        }

        func panels(on side: StudioPanelSide) -> [StudioPanelKind] {
            stackedPanelOrder.filter { panelState(for: $0).side == side }
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
        case timelapseExportProgressUpdated(Double, Data?)
        case timelapseExportSucceeded(URL)
        case timelapseExportFailed(String)
        case exportSheetDismissed
        case bannerDismissed
        case languageChanged(AppLanguage)
        case toolSelected(StudioToolKind)
        case clearActiveLayerButtonTapped
        case activeLayerVisibilityToggled
        case selectPreviousLayer
        case selectNextLayer
        case panelCollapseToggled(StudioPanelKind)
        case panelMoved(StudioPanelKind, StudioPanelSide)
        case panelStackToggled(StudioPanelKind)
        case panelStackOrderSwapRequested
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
                state.brushPanel = StudioPanelLayoutState(side: .leading)
                state.layerPanel = StudioPanelLayoutState(side: .trailing)
                state.stackedPanelOrder = [.brush, .layers]
                state.exportSheet = nil
                state.bannerMessage = nil
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .undoRequested:
                guard !state.canvas.isStrokeActive else {
                    state.bannerMessage = state.appLanguage == .japanese ? "描画中は取り消しできません" : "Undo is unavailable while drawing"
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
                    state.bannerMessage = state.appLanguage == .japanese ? "描画中はやり直しできません" : "Redo is unavailable while drawing"
                    return .none
                }
                guard paintDocumentClient.redo() else {
                    return .none
                }
                state.canvas.selection = nil
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .saveDocumentRequested:
                guard let pngData = paintDocumentClient.compositePNGData(state.resolvedPaperStyle()) else {
                    state.bannerMessage = state.appLanguage == .japanese ? "保存に失敗しました" : "Save failed"
                    return .none
                }
                do {
                    let url = try Self.writePNGToDocuments(data: pngData)
                    state.bannerMessage = state.appLanguage == .japanese ? "保存しました: \(url.lastPathComponent)" : "Saved: \(url.lastPathComponent)"
                } catch {
                    state.bannerMessage = state.appLanguage == .japanese ? "保存に失敗しました" : "Save failed"
                }
                return .none

            case .exportDocumentRequested:
                guard let pngData = paintDocumentClient.compositePNGData(state.resolvedPaperStyle()) else {
                    state.bannerMessage = state.appLanguage == .japanese ? "書き出しに失敗しました" : "Export failed"
                    return .none
                }
                do {
                    let url = try Self.writePNGToTemporaryDirectory(data: pngData)
                    state.exportSheet = ShareExport(url: url)
                } catch {
                    state.bannerMessage = state.appLanguage == .japanese ? "書き出しに失敗しました" : "Export failed"
                }
                return .none

            case .exportTimelapseRequested:
                guard let capture = paintDocumentClient.timelapseCapture() else {
                    state.bannerMessage = state.appLanguage == .japanese ? "タイムラプス用の描画履歴がまだ足りません" : "Not enough drawing history for timelapse yet"
                    return .none
                }
                state.timelapseExportPreview = TimelapseExportPreview(progress: 0, previewImageData: capture.frames.last.flatMap { try? Data(contentsOf: $0.imageURL) })
                let failureMessage = state.appLanguage == .japanese ? "タイムラプスの書き出しに失敗しました" : "Timelapse export failed"
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

            case let .toolSelected(tool):
                state.canvas.currentTool = tool
                state.canvas.selectionMode = state.brushPalette.selectionToolMode
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

            case let .panelCollapseToggled(panel):
                state.toggleCollapse(for: panel)
                return .none

            case let .panelMoved(panel, side):
                state.movePanel(panel, to: side)
                return .none

            case let .panelStackToggled(panel):
                let companion = panel == .brush ? StudioPanelKind.layers : .brush
                if state.panelState(for: panel).side == state.panelState(for: companion).side {
                    state.unstackPanel(panel)
                } else {
                    state.movePanelIntoStack(panel)
                }
                return .none

            case .panelStackOrderSwapRequested:
                state.swapStackOrder()
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
                state.canvas.selectionMode = state.brushPalette.selectionToolMode
                state.canvas.previewStyle = state.previewStrokeStyle()
                state.canvas.paperStyle = state.resolvedPaperStyle()
                state.layerSidebar.paperColor = state.brushPalette.paperColor
                state.layerSidebar.transparentPaper = state.brushPalette.transparentPaper
                paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
                return .none

            case .layerSidebar(.binding(\.paperColor)):
                state.brushPalette.paperColor = state.layerSidebar.paperColor
                state.canvas.paperStyle = state.resolvedPaperStyle()
                paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
                return .none

            case .layerSidebar(.binding(\.transparentPaper)):
                state.brushPalette.transparentPaper = state.layerSidebar.transparentPaper
                state.canvas.paperStyle = state.resolvedPaperStyle()
                paintDocumentClient.setPaperStyle(state.resolvedPaperStyle())
                return .none

            case .layerSidebar(.delegate(.addLayer)):
                paintDocumentClient.addLayer("Layer \(state.layerSidebar.layers.count + 1)")
                state.canvas.activeLayerIndex = state.layerSidebar.layers.count
                state.canvas.selection = nil
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

            case let .layerSidebar(.delegate(.setBlendMode(index, blendMode))):
                paintDocumentClient.setLayerBlendMode(index, blendMode)
                state.canvas.selection = nil
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
                return .send(.presentationLoaded(paintDocumentClient.presentation()))

            case .canvas(.delegate(.endStroke)):
                paintDocumentClient.endStroke()
                return .send(.presentationLoaded(paintDocumentClient.presentation()))

            case let .canvas(.delegate(.commitStroke(samples))):
                guard let first = samples.first else { return .none }
                state.canvas.selection = nil
                paintDocumentClient.beginStroke(first, state.resolvedBrushSettings())
                for sample in samples.dropFirst() {
                    paintDocumentClient.appendStroke(sample)
                }
                paintDocumentClient.endStroke()
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
                    mode: state.brushPalette.selectionCombineMode,
                    canvasSize: state.canvas.canvasSize
                )
                return .send(.canvas(.selectionUpdated(selection)))

            case let .canvas(.delegate(.autoSelect(sample))):
                let incomingSelection = Self.makeAutoSelection(
                    at: sample.point,
                    snapshot: state.canvas.renderSnapshot,
                    layerIndex: state.canvas.activeLayerIndex,
                    thresholdMode: state.brushPalette.selectionThresholdMode,
                    opacityTolerance: state.brushPalette.selectionOpacityTolerance,
                    colorTolerance: state.brushPalette.selectionColorTolerance,
                    expansion: Int(state.brushPalette.selectionExpansion.rounded())
                )
                let selection = Self.combinedSelection(
                    existing: state.canvas.selection,
                    incoming: incomingSelection,
                    mode: state.brushPalette.selectionCombineMode,
                    canvasSize: state.canvas.canvasSize
                )
                return .send(.canvas(.selectionUpdated(selection)))

            case .canvas(.delegate(.requestUndo)):
                return .send(.undoRequested)

            case .canvas(.delegate(.requestRedo)):
                return .send(.redoRequested)

            case .layerSidebar, .canvas:
                return .none
            }
        }
    }
}

private extension AppFeature {
    func applyTransform(state: inout State) -> Effect<Action> {
        let translation = CGSize(
            width: state.canvas.transformPreviewOffset.width.rounded(),
            height: state.canvas.transformPreviewOffset.height.rounded()
        )
        let scale = state.canvas.transformPreviewScale
        guard translation != .zero || abs(scale - 1.0) > 0.001 else { return .none }
        guard
            let snapshot = state.canvas.renderSnapshot,
            let layer = snapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex })
        else {
            state.canvas.transformPreviewOffset = .zero
            state.canvas.transformPreviewScale = 1.0
            return .none
        }
        guard let transformed = Self.transformedLayerPixels(
            source: layer.pixelData,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            selection: state.canvas.selection,
            translation: translation,
            scale: scale
        ) else {
            state.canvas.transformPreviewOffset = .zero
            state.canvas.transformPreviewScale = 1.0
            return .none
        }
        paintDocumentClient.replaceLayerPixels(state.canvas.activeLayerIndex, transformed)
        if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == state.canvas.activeLayerIndex }) {
            state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
            state.canvas.localBufferRevision += 1
        }
        state.canvas.selection = Self.transformedSelection(
            state.canvas.selection,
            translation: translation,
            scale: scale,
            canvasSize: state.canvas.canvasSize
        )
        state.canvas.transformPreviewOffset = .zero
        state.canvas.transformPreviewScale = 1.0
        state.applyPresentation(paintDocumentClient.presentation())
        return .none
    }

    static func combinedSelection(
        existing: CanvasSelection?,
        incoming: CanvasSelection?,
        mode: SelectionCombineMode,
        canvasSize: CGSize
    ) -> CanvasSelection? {
        switch mode {
        case .replace:
            return incoming
        case .add, .subtract:
            guard let incoming else { return existing }
            guard let existing else {
                return mode == .add ? incoming : nil
            }

            let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
            let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
            var baseMask = expandedMask(from: existing, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
            let incomingMask = expandedMask(from: incoming, canvasWidth: canvasWidth, canvasHeight: canvasHeight)

            for index in 0..<baseMask.count {
                switch mode {
                case .replace:
                    break
                case .add:
                    baseMask[index] = max(baseMask[index], incomingMask[index])
                case .subtract:
                    if incomingMask[index] != 0 {
                        baseMask[index] = 0
                    }
                }
            }

            return croppedSelection(from: baseMask, width: canvasWidth, height: canvasHeight, mode: incoming.mode)
        }
    }

    static func expandedMask(from selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
        let originX = max(Int(selection.bounds.minX.rounded(.down)), 0)
        let originY = max(Int(selection.bounds.minY.rounded(.down)), 0)
        let width = min(selection.maskWidth, canvasWidth - originX)
        let height = min(selection.maskHeight, canvasHeight - originY)
        guard width > 0, height > 0 else { return result }

        selection.maskData.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let sourceIndex = (y * selection.maskWidth) + x
                    let destinationIndex = ((originY + y) * canvasWidth) + (originX + x)
                    result[destinationIndex] = source[sourceIndex]
                }
            }
        }
        return result
    }

    static func transformedLayerPixels(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection?,
        translation: CGSize,
        scale: CGFloat
    ) -> Data? {
        let dx = Int(translation.width.rounded())
        let dy = Int(translation.height.rounded())
        let clampedScale = min(max(scale, 0.2), 6.0)
        guard dx != 0 || dy != 0 || abs(clampedScale - 1.0) > 0.001 else { return nil }

        let expectedCount = canvasWidth * canvasHeight * 4
        guard source.count == expectedCount else { return nil }

        let sourceBytes = [UInt8](source)
        let mask = selection.map { expandedMask(from: $0, canvasWidth: canvasWidth, canvasHeight: canvasHeight) }
            ?? Self.alphaMask(from: sourceBytes, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        guard let bounds = Self.transformationBounds(selection: selection, sourceBytes: sourceBytes, canvasWidth: canvasWidth, canvasHeight: canvasHeight) else {
            return nil
        }

        var destination = sourceBytes
        for index in 0..<(canvasWidth * canvasHeight) where mask[index] != 0 {
            let pixelOffset = index * 4
            destination[pixelOffset] = 0
            destination[pixelOffset + 1] = 0
            destination[pixelOffset + 2] = 0
            destination[pixelOffset + 3] = 0
        }

        let anchor = CGPoint(x: bounds.midX, y: bounds.midY)
        for y in 0..<canvasHeight {
            for x in 0..<canvasWidth {
                let destinationPoint = CGPoint(
                    x: CGFloat(x) - translation.width,
                    y: CGFloat(y) - translation.height
                )
                let sourceX = ((destinationPoint.x - anchor.x) / clampedScale) + anchor.x
                let sourceY = ((destinationPoint.y - anchor.y) / clampedScale) + anchor.y
                let sourcePixelX = Int(sourceX.rounded())
                let sourcePixelY = Int(sourceY.rounded())
                guard sourcePixelX >= 0, sourcePixelX < canvasWidth, sourcePixelY >= 0, sourcePixelY < canvasHeight else {
                    continue
                }

                let sourceIndex = (sourcePixelY * canvasWidth) + sourcePixelX
                guard mask[sourceIndex] != 0 else { continue }
                let sourceOffset = sourceIndex * 4
                guard sourceBytes[sourceOffset + 3] != 0 else { continue }

                let destinationOffset = ((y * canvasWidth) + x) * 4
                destination[destinationOffset] = sourceBytes[sourceOffset]
                destination[destinationOffset + 1] = sourceBytes[sourceOffset + 1]
                destination[destinationOffset + 2] = sourceBytes[sourceOffset + 2]
                destination[destinationOffset + 3] = sourceBytes[sourceOffset + 3]
            }
        }

        return Data(destination)
    }

    static func transformedSelection(_ selection: CanvasSelection?, translation: CGSize, scale: CGFloat, canvasSize: CGSize) -> CanvasSelection? {
        guard let selection else { return nil }
        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
        let mask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        let bounds = selection.bounds
        let anchor = CGPoint(x: bounds.midX, y: bounds.midY)
        let clampedScale = min(max(scale, 0.2), 6.0)
        var transformed = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)

        for y in 0..<canvasHeight {
            for x in 0..<canvasWidth {
                let destinationPoint = CGPoint(
                    x: CGFloat(x) - translation.width,
                    y: CGFloat(y) - translation.height
                )
                let sourceX = ((destinationPoint.x - anchor.x) / clampedScale) + anchor.x
                let sourceY = ((destinationPoint.y - anchor.y) / clampedScale) + anchor.y
                let sourcePixelX = Int(sourceX.rounded())
                let sourcePixelY = Int(sourceY.rounded())
                guard sourcePixelX >= 0, sourcePixelX < canvasWidth, sourcePixelY >= 0, sourcePixelY < canvasHeight else {
                    continue
                }

                let sourceIndex = (sourcePixelY * canvasWidth) + sourcePixelX
                guard mask[sourceIndex] != 0 else { continue }
                transformed[(y * canvasWidth) + x] = 255
            }
        }

        return croppedSelection(from: transformed, width: canvasWidth, height: canvasHeight, mode: selection.mode)
    }

    static func alphaMask(from sourceBytes: [UInt8], canvasWidth: Int, canvasHeight: Int) -> [UInt8] {
        var mask = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
        for index in 0..<(canvasWidth * canvasHeight) {
            if sourceBytes[index * 4 + 3] != 0 {
                mask[index] = 255
            }
        }
        return mask
    }

    static func transformationBounds(
        selection: CanvasSelection?,
        sourceBytes: [UInt8],
        canvasWidth: Int,
        canvasHeight: Int
    ) -> CGRect? {
        if let selection, !selection.isEmpty {
            return selection.bounds
        }

        var minX = canvasWidth
        var minY = canvasHeight
        var maxX = -1
        var maxY = -1
        for y in 0..<canvasHeight {
            for x in 0..<canvasWidth {
                if sourceBytes[((y * canvasWidth) + x) * 4 + 3] == 0 { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    static func makeLassoSelection(from points: [CGPoint], canvasSize: CGSize) -> CanvasSelection? {
        guard points.count >= 3 else { return nil }

        let polygon = closedPolygon(points, canvasSize: canvasSize)
        guard polygon.count >= 3 else { return nil }

        let path = CGMutablePath()
        path.addLines(between: polygon)
        path.closeSubpath()
        let bounds = path.boundingBoxOfPath.integral
        guard !bounds.isNull, !bounds.isEmpty else { return nil }

        let minX = max(0, Int(bounds.minX.rounded(.down)))
        let minY = max(0, Int(bounds.minY.rounded(.down)))
        let maxX = max(minX + 1, Int(bounds.maxX.rounded(.up)))
        let maxY = max(minY + 1, Int(bounds.maxY.rounded(.up)))
        let width = maxX - minX
        let height = maxY - minY
        guard width > 0, height > 0 else { return nil }

        var mask = Data(count: width * height)
        mask.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let samplePoint = CGPoint(x: CGFloat(minX + x) + 0.5, y: CGFloat(minY + y) + 0.5)
                    if path.contains(samplePoint) {
                        base[(y * width) + x] = 255
                    }
                }
            }
        }

        let bytes = [UInt8](mask)
        return croppedSelection(from: bytes, width: width, height: height, mode: .lasso).map {
            CanvasSelection(
                bounds: CGRect(
                    x: CGFloat(minX) + $0.bounds.minX,
                    y: CGFloat(minY) + $0.bounds.minY,
                    width: $0.bounds.width,
                    height: $0.bounds.height
                ),
                maskWidth: $0.maskWidth,
                maskHeight: $0.maskHeight,
                maskData: $0.maskData,
                mode: .lasso
            )
        }
    }

    static func makeAutoSelection(
        at point: CGPoint,
        snapshot: MetalDocumentSnapshot?,
        layerIndex: Int,
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Int
    ) -> CanvasSelection? {
        guard
            let snapshot,
            let layer = snapshot.layers.first(where: { $0.index == layerIndex })
        else {
            return nil
        }

        let width = snapshot.width
        let height = snapshot.height
        guard width > 0, height > 0 else { return nil }

        let startX = min(max(Int(point.x.rounded()), 0), width - 1)
        let startY = min(max(Int(point.y.rounded()), 0), height - 1)
        let expectedCount = width * height * 4
        guard layer.pixelData.count == expectedCount else { return nil }

        var selected = [UInt8](repeating: 0, count: width * height)
        var queue: [(Int, Int)] = [(startX, startY)]
        var head = 0
        var minX = startX
        var minY = startY
        var maxX = startX
        var maxY = startY

        layer.pixelData.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let startOffset = ((startY * width) + startX) * 4
            let targetR = base[startOffset]
            let targetG = base[startOffset + 1]
            let targetB = base[startOffset + 2]
            let targetA = base[startOffset + 3]

            func matches(_ x: Int, _ y: Int) -> Bool {
                let offset = ((y * width) + x) * 4
                if thresholdMode == .color {
                    let dr = (Double(base[offset]) - Double(targetR)) / 255.0
                    let dg = (Double(base[offset + 1]) - Double(targetG)) / 255.0
                    let db = (Double(base[offset + 2]) - Double(targetB)) / 255.0
                    let distance = sqrt((dr * dr) + (dg * dg) + (db * db)) / sqrt(3.0)
                    return distance <= min(max(colorTolerance, 0.0), 1.0)
                }
                let sameColor =
                    base[offset] == targetR &&
                    base[offset + 1] == targetG &&
                    base[offset + 2] == targetB
                let alphaDistance = abs(Double(base[offset + 3]) - Double(targetA)) / 255.0
                return sameColor && alphaDistance <= min(max(opacityTolerance, 0.0), 1.0)
            }

            while head < queue.count {
                let (x, y) = queue[head]
                head += 1
                guard x >= 0, x < width, y >= 0, y < height else { continue }
                let index = (y * width) + x
                guard selected[index] == 0, matches(x, y) else { continue }

                selected[index] = 255
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)

                queue.append((x - 1, y))
                queue.append((x + 1, y))
                queue.append((x, y - 1))
                queue.append((x, y + 1))
            }
        }

        guard minX <= maxX, minY <= maxY else { return nil }
        let expandedMask = expandedSelectionMask(
            selected,
            width: width,
            height: height,
            expansion: max(0, expansion)
        )
        return croppedSelection(
            from: expandedMask,
            width: width,
            height: height,
            mode: .auto
        )
    }

    static func expandedSelectionMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8] {
        guard expansion > 0 else { return source }
        var result = source
        let selectedPoints = source.enumerated().compactMap { index, value -> (Int, Int)? in
            guard value != 0 else { return nil }
            return (index % width, index / width)
        }

        for (seedX, seedY) in selectedPoints {
            for dy in -expansion...expansion {
                for dx in -expansion...expansion {
                    guard abs(dx) + abs(dy) <= expansion else { continue }
                    let x = seedX + dx
                    let y = seedY + dy
                    guard x >= 0, x < width, y >= 0, y < height else { continue }
                    result[(y * width) + x] = 255
                }
            }
        }
        return result
    }

    static func croppedSelection(from source: [UInt8], width: Int, height: Int, mode: SelectionToolMode) -> CanvasSelection? {
        guard let first = source.firstIndex(where: { $0 != 0 }) else { return nil }
        var minX = first % width
        var maxX = minX
        var minY = first / width
        var maxY = minY

        for index in source.indices where source[index] != 0 {
            let x = index % width
            let y = index / width
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }

        let croppedWidth = (maxX - minX) + 1
        let croppedHeight = (maxY - minY) + 1
        guard croppedWidth > 0, croppedHeight > 0 else { return nil }

        var cropped = Data(count: croppedWidth * croppedHeight)
        cropped.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<croppedHeight {
                for x in 0..<croppedWidth {
                    let sourceIndex = ((minY + y) * width) + (minX + x)
                    base[(y * croppedWidth) + x] = source[sourceIndex]
                }
            }
        }

        return CanvasSelection(
            bounds: CGRect(x: minX, y: minY, width: croppedWidth, height: croppedHeight),
            maskWidth: croppedWidth,
            maskHeight: croppedHeight,
            maskData: cropped,
            mode: mode
        )
    }

    static func closedPolygon(_ points: [CGPoint], canvasSize: CGSize) -> [CGPoint] {
        let clamped = points.map {
            CGPoint(
                x: min(max($0.x, 0), max(canvasSize.width - 1, 0)),
                y: min(max($0.y, 0), max(canvasSize.height - 1, 0))
            )
        }
        guard let first = clamped.first, let last = clamped.last else { return [] }
        if hypot(first.x - last.x, first.y - last.y) <= 4 {
            return clamped
        }
        return clamped + [first]
    }

    static func writePNGToDocuments(data: Data) throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportsDirectory = documentsDirectory.appendingPathComponent("atelierprime", isDirectory: true)
        try FileManager.default.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)
        let url = exportsDirectory.appendingPathComponent(exportFilename())
        try data.write(to: url, options: .atomic)
        return url
    }

    static func writePNGToTemporaryDirectory(data: Data) throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("atelierprime-export", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let url = temporaryDirectory.appendingPathComponent(exportFilename())
        try data.write(to: url, options: .atomic)
        return url
    }

    static func timelapseTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("atelierprime-export", isDirectory: true)
            .appendingPathComponent("timelapse", isDirectory: true)
    }

    static func exportFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "atelierprime-\(formatter.string(from: Date())).png"
    }
}

private enum TimelapseExporter {
    static func exportVideo(
        from capture: TimelapseCapture,
        to directory: URL,
        progress: ((Double, URL) -> Void)? = nil
    ) throws -> URL {
        guard capture.frames.count >= 2 else {
            throw TimelapseExportError.insufficientFrames
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let outputURL = directory.appendingPathComponent(exportFilename())
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let targetSize = videoDimensions(for: capture)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: targetSize.width,
            AVVideoHeightKey: targetSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 5_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(targetSize.width),
            kCVPixelBufferHeightKey as String: Int(targetSize.height),
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourceAttributes
        )

        guard writer.canAdd(input) else {
            throw TimelapseExportError.cannotAddWriterInput
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? TimelapseExportError.failedToStartWriting
        }
        writer.startSession(atSourceTime: .zero)

        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw TimelapseExportError.exportFailed
        }

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(capture.framesPerSecond, 1)))
        let holdFrameCount = max(capture.framesPerSecond * 2, 1)
        let totalFrameCount = capture.frames.count + holdFrameCount
        for (index, frame) in capture.frames.enumerated() {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.002)
            }

            guard let image = decodedImage(from: frame.imageURL) else {
                throw TimelapseExportError.invalidFrameData
            }

            var maybeBuffer: CVPixelBuffer?
            let creationStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &maybeBuffer)
            guard creationStatus == kCVReturnSuccess, let buffer = maybeBuffer else {
                throw TimelapseExportError.exportFailed
            }

            guard render(image: image, into: buffer, targetSize: targetSize) else {
                throw TimelapseExportError.exportFailed
            }

            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))
            guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? TimelapseExportError.exportFailed
            }
            progress?(Double(index + 1) / Double(totalFrameCount), frame.imageURL)
        }

        guard let finalFrame = capture.frames.last,
              let finalImage = decodedImage(from: finalFrame.imageURL) else {
            throw TimelapseExportError.invalidFrameData
        }
        for holdIndex in 1...holdFrameCount {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.002)
            }

            var maybeBuffer: CVPixelBuffer?
            let creationStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &maybeBuffer)
            guard creationStatus == kCVReturnSuccess, let buffer = maybeBuffer else {
                throw TimelapseExportError.exportFailed
            }

            guard render(image: finalImage, into: buffer, targetSize: targetSize) else {
                throw TimelapseExportError.exportFailed
            }

            let presentationTime = CMTimeMultiply(
                frameDuration,
                multiplier: Int32(capture.frames.count - 1 + holdIndex)
            )
            guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? TimelapseExportError.exportFailed
            }
            progress?(Double(capture.frames.count + holdIndex) / Double(totalFrameCount), finalFrame.imageURL)
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        var completionError: Error?
        writer.finishWriting {
            completionError = writer.error
            semaphore.signal()
        }
        semaphore.wait()

        if let completionError {
            throw completionError
        }
        if writer.status != .completed {
            throw writer.error ?? TimelapseExportError.exportFailed
        }

        return outputURL
    }

    private static func decodedImage(from url: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }

    private static func render(image: CGImage, into pixelBuffer: CVPixelBuffer, targetSize: CGSize) -> Bool {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return false
        }

        context.setFillColor(CGColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: targetSize))

        let imageRect = AVMakeRect(
            aspectRatio: CGSize(width: image.width, height: image.height),
            insideRect: CGRect(origin: .zero, size: targetSize)
        )
        context.draw(image, in: imageRect)
        return true
    }

    private static func videoDimensions(for capture: TimelapseCapture) -> CGSize {
        let width = max(Int(capture.canvasSize.width.rounded()), 2)
        let height = max(Int(capture.canvasSize.height.rounded()), 2)
        let evenWidth = width.isMultiple(of: 2) ? width : width + 1
        let evenHeight = height.isMultiple(of: 2) ? height : height + 1
        return CGSize(width: evenWidth, height: evenHeight)
    }

    private static func exportFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "atelierprime-timelapse-\(formatter.string(from: Date())).mp4"
    }
}

private enum TimelapseExportError: Error {
    case insufficientFrames
    case cannotAddWriterInput
    case failedToStartWriting
    case invalidFrameData
    case exportFailed
}
