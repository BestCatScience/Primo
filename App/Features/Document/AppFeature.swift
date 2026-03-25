import ComposableArchitecture
import CoreGraphics
import Foundation
import os

enum StudioPanelKind: String, CaseIterable, Equatable {
    case brush
    case layers

    var title: String {
        switch self {
        case .brush:
            return "Brush"
        case .layers:
            return "Layers"
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
                    opacity: row.opacity
                )
                buffer.name = row.name
                buffer.visible = row.visible
                buffer.opacity = row.opacity
                nextBuffers.append(buffer)
            }
            canvas.layerBuffers = nextBuffers
            if let renderSnapshot = presentation.renderSnapshot {
                canvas.renderSnapshot = renderSnapshot
                canvas.lastCommittedRenderRevision = renderSnapshot.revision
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
            canvas.previewStyle = PreviewStrokeStyle(
                radius: CGFloat(brushPalette.runtimeSettings.radius),
                opacity: CGFloat(brushPalette.runtimeSettings.opacity),
                color: CGColor(
                    red: CGFloat(brushPalette.runtimeSettings.red) / 255.0,
                    green: CGFloat(brushPalette.runtimeSettings.green) / 255.0,
                    blue: CGFloat(brushPalette.runtimeSettings.blue) / 255.0,
                    alpha: 1.0
                )
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
        case clearActiveLayerButtonTapped
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
                Self.startupLogger.debug("AppFeature.task started")
                return .run { [paintDocumentClient] send in
                    let startupClock = ContinuousClock()
                    let bootstrapStart = startupClock.now

                    Self.startupLogger.debug("Loading lightweight presentation")
                    let lightweightPresentation = paintDocumentClient.lightweightPresentation()
                    let bootstrapDuration = bootstrapStart.duration(to: startupClock.now)
                    Self.startupLogger.debug("Lightweight presentation loaded in \(String(describing: bootstrapDuration), privacy: .public)")
                    await send(.bootstrapPresentationLoaded(lightweightPresentation))
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
                    try? await Task.sleep(for: .milliseconds(150))

                    let presentationStart = clock.now
                    Self.startupLogger.debug("Loading full presentation after initial launch")
                    let presentation = paintDocumentClient.presentation()
                    let presentationDuration = presentationStart.duration(to: clock.now)
                    Self.startupLogger.debug("Full presentation loaded in \(String(describing: presentationDuration), privacy: .public)")
                    await send(.presentationLoaded(presentation))
                }

            case let .presentationLoaded(presentation):
                state.applyPresentation(presentation)
                Self.startupLogger.debug("Full presentation applied")
                return .none

            case .deferredPresentationRefresh:
                return .run { [paintDocumentClient] send in
                    await send(.presentationLoaded(paintDocumentClient.presentation()))
                }
                .cancellable(id: CancelID.deferredPresentationRefresh, cancelInFlight: true)

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

            case .clearActiveLayerButtonTapped, .brushPalette(.delegate(.clearActiveLayer)):
                let activeLayerIndex = state.layerSidebar.activeLayerIndex
                paintDocumentClient.clearLayer(activeLayerIndex)
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                    state.canvas.localBufferRevision += 1
                }
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .brushPalette:
                state.canvas.previewStyle = PreviewStrokeStyle(
                    radius: CGFloat(state.brushPalette.runtimeSettings.radius),
                    opacity: CGFloat(state.brushPalette.runtimeSettings.opacity),
                    color: CGColor(
                        red: CGFloat(state.brushPalette.runtimeSettings.red) / 255.0,
                        green: CGFloat(state.brushPalette.runtimeSettings.green) / 255.0,
                        blue: CGFloat(state.brushPalette.runtimeSettings.blue) / 255.0,
                        alpha: 1.0
                    )
                )
                return .none

            case .layerSidebar(.delegate(.addLayer)):
                paintDocumentClient.addLayer("Layer \(state.layerSidebar.layers.count + 1)")
                state.canvas.activeLayerIndex = state.layerSidebar.layers.count
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.selectLayer(index))):
                paintDocumentClient.setActiveLayer(index)
                state.canvas.activeLayerIndex = index
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.toggleVisibility(index))):
                guard let layer = state.layerSidebar.layers.first(where: { $0.index == index }) else {
                    return .none
                }
                paintDocumentClient.setLayerVisibility(index, !layer.visible)
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .canvas(.delegate(.beginStroke(sample))):
                paintDocumentClient.beginStroke(sample, state.brushPalette.runtimeSettings)
                return .send(.deferredPresentationRefresh)

            case let .canvas(.delegate(.appendSamples(samples))):
                for sample in samples {
                    paintDocumentClient.appendStroke(sample)
                }
                return .run { send in
                    try? await Task.sleep(for: .milliseconds(16))
                    await send(.deferredPresentationRefresh)
                }
                .cancellable(id: CancelID.deferredPresentationRefresh, cancelInFlight: true)

            case .canvas(.delegate(.endStroke)):
                paintDocumentClient.endStroke()
                return .concatenate(
                    .cancel(id: CancelID.deferredPresentationRefresh),
                    .send(.presentationLoaded(paintDocumentClient.presentation()))
                )

            case .layerSidebar, .canvas:
                return .none
            }
        }
    }
}
