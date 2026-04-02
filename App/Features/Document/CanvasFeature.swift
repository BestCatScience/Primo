import ComposableArchitecture
import CoreGraphics
import Foundation

@Reducer
struct CanvasFeature {
    static let defaultCanvasSize = CGSize(width: 1152, height: 1536)

    @ObservableState
    struct State: Equatable {
        var canvasSize: CGSize = CanvasFeature.defaultCanvasSize
        var renderSnapshot: MetalDocumentSnapshot?
        var lastCommittedRenderRevision: Int = -1
        var localBufferRevision: Int = 0
        var lastRenderedLocalBufferRevision: Int = -1
        var activeLayerIndex = 0
        var layerBuffers: [LayerCanvasBuffer] = [
            LayerCanvasBuffer(index: 0, name: "Layer 1", visible: true, opacity: 1.0)
        ]
        var activeStroke: Stroke?
        var isStrokeActive = false
        var isAwaitingCommittedRender = false
        var currentTool: StudioToolKind = .brush
        var selectionMode: SelectionToolMode = .lasso
        var selection: CanvasSelection?
        var selectionPreviewPoints: [CGPoint] = []
        var transformPreviewOffset: CGSize = .zero
        var transformGestureBaseOffset: CGSize = .zero
        var viewportOffset: CGSize = .zero
        var zoomScale: CGFloat = 1.0
        var paperStyle: CanvasPaperStyle = .default
        var previewStyle = PreviewStrokeStyle(
            tipKind: .pencil,
            isEraser: false,
            radius: 3.0,
            opacity: 0.9,
            hardness: 0.82,
            pressureSensitivity: 0.4,
            color: CGColor(red: 31.0 / 255.0, green: 31.0 / 255.0, blue: 34.0 / 255.0, alpha: 1.0)
        )
        var pendingIncrementalUpdate: IncrementalLayerUpdate?
    }

    enum Action: Equatable {
        case strokeUpdated(Stroke)
        case strokeEnded(Stroke)
        case fillRequested(StylusSample)
        case selectionPreviewUpdated([CGPoint])
        case selectionPathEnded([CGPoint])
        case autoSelectionRequested(StylusSample)
        case selectionUpdated(CanvasSelection?)
        case transformGestureBegan
        case transformPreviewChanged(CGSize)
        case transformEnded(CGSize)
        case transformPreviewCleared
        case applyIncrementalUpdate(IncrementalLayerUpdate)
        case requestLocalUndo
        case requestLocalRedo
        case viewportOffsetChanged(CGSize)
        case zoomScaleChanged(CGFloat)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case beginStroke(StylusSample)
        case appendSamples([StylusSample])
        case endStroke
        case commitStroke([StylusSample])
        case fill(StylusSample)
        case lassoSelect([CGPoint])
        case autoSelect(StylusSample)
        case applyTransform(CGSize)
        case requestUndo
        case requestRedo
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .applyIncrementalUpdate(update):
                state.pendingIncrementalUpdate = update
                return .none

            case let .fillRequested(sample):
                state.pendingIncrementalUpdate = nil
                return .send(.delegate(.fill(sample)))

            case let .selectionPreviewUpdated(points):
                state.selectionPreviewPoints = points
                return .none

            case let .selectionPathEnded(points):
                state.selectionPreviewPoints = []
                return .send(.delegate(.lassoSelect(points)))

            case let .autoSelectionRequested(sample):
                state.selectionPreviewPoints = []
                return .send(.delegate(.autoSelect(sample)))

            case let .selectionUpdated(selection):
                state.selection = selection
                state.selectionPreviewPoints = []
                state.transformPreviewOffset = .zero
                state.transformGestureBaseOffset = .zero
                return .none

            case .transformGestureBegan:
                state.transformGestureBaseOffset = state.transformPreviewOffset
                return .none

            case let .transformPreviewChanged(offset):
                state.transformPreviewOffset = CGSize(
                    width: state.transformGestureBaseOffset.width + offset.width,
                    height: state.transformGestureBaseOffset.height + offset.height
                )
                return .none

            case let .transformEnded(offset):
                state.transformPreviewOffset = CGSize(
                    width: state.transformGestureBaseOffset.width + offset.width,
                    height: state.transformGestureBaseOffset.height + offset.height
                )
                state.transformGestureBaseOffset = state.transformPreviewOffset
                return .none

            case .transformPreviewCleared:
                state.transformPreviewOffset = .zero
                state.transformGestureBaseOffset = .zero
                return .none

            case .requestLocalUndo:
                return .send(.delegate(.requestUndo))

            case .requestLocalRedo:
                return .send(.delegate(.requestRedo))

            case let .viewportOffsetChanged(offset):
                state.viewportOffset = offset
                return .none

            case let .zoomScaleChanged(scale):
                state.zoomScale = min(max(scale, 0.6), 4.0)
                return .none

            case let .strokeUpdated(stroke):
                let previousPointCount = state.activeStroke?.points.count ?? 0
                state.isStrokeActive = true
                state.isAwaitingCommittedRender = false
                state.pendingIncrementalUpdate = nil
                state.activeStroke = stroke

                if state.currentTool == .shape {
                    return .none
                }

                let appendedSamples = Array(stroke.points.dropFirst(previousPointCount)).map(\.stylusSample)

                guard !appendedSamples.isEmpty else { return .none }
                if previousPointCount == 0 {
                    let first = appendedSamples[0]
                    var effects: [Effect<Action>] = [
                        .send(.delegate(.beginStroke(first)))
                    ]
                    let remainder = Array(appendedSamples.dropFirst())
                    if !remainder.isEmpty {
                        effects.append(.send(.delegate(.appendSamples(remainder))))
                    }
                    return .concatenate(effects)
                }

                return .send(.delegate(.appendSamples(appendedSamples)))

            case let .strokeEnded(stroke):
                state.isStrokeActive = false
                state.isAwaitingCommittedRender = true
                if !stroke.points.isEmpty {
                    let track = PreviewStrokeTrack(
                        layerIndex: state.activeLayerIndex,
                        points: stroke.confirmedPreviewPoints,
                        style: state.previewStyle
                    )
                    if let bufferIndex = state.layerBuffers.firstIndex(where: { $0.index == state.activeLayerIndex }) {
                        state.layerBuffers[bufferIndex].strokes.append(track)
                    } else {
                        state.layerBuffers.append(
                            LayerCanvasBuffer(
                                index: state.activeLayerIndex,
                                name: "Layer \(state.activeLayerIndex + 1)",
                                visible: true,
                                opacity: 1.0,
                                strokes: [track]
                            )
                        )
                    }
                    state.localBufferRevision += 1
                }
                state.activeStroke = nil
                state.pendingIncrementalUpdate = nil
                if state.currentTool == .shape {
                    return .send(.delegate(.commitStroke(stroke.points.map(\.stylusSample))))
                }
                return .send(.delegate(.endStroke))
            case .delegate:
                return .none
            }
        }
    }
}
