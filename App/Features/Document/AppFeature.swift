import ComposableArchitecture
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
            if let renderSnapshot = presentation.renderSnapshot {
                canvas.renderSnapshot = renderSnapshot
                isHydrating = false
            }
            layerSidebar.layers = presentation.layerRows
            layerSidebar.activeLayerIndex = presentation.activeLayerIndex
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

            case .brushPalette(.delegate(.clearActiveLayer)):
                paintDocumentClient.clearLayer(state.layerSidebar.activeLayerIndex)
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .layerSidebar(.delegate(.addLayer)):
                paintDocumentClient.addLayer("Layer \(state.layerSidebar.layers.count + 1)")
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.selectLayer(index))):
                paintDocumentClient.setActiveLayer(index)
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
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .canvas(.delegate(.appendSamples(samples))):
                for sample in samples {
                    paintDocumentClient.appendStroke(sample)
                }
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .canvas(.delegate(.endStroke)):
                paintDocumentClient.endStroke()
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .brushPalette, .layerSidebar, .canvas:
                return .none
            }
        }
    }
}
