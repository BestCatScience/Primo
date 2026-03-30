import ComposableArchitecture
import CoreGraphics
import Foundation
import simd

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
        var pendingCommittedStroke: Stroke?
        var isStrokeActive = false
        var isAwaitingCommittedRender = false
        var currentTool: StudioToolKind = .brush
        var viewportOffset: CGSize = .zero
        var zoomScale: CGFloat = 1.0
        var previewStyle = PreviewStrokeStyle(
            radius: 3.0,
            opacity: 0.9,
            color: CGColor(red: 31.0 / 255.0, green: 31.0 / 255.0, blue: 34.0 / 255.0, alpha: 1.0)
        )
    }

    enum Action: Equatable {
        case strokeUpdated(Stroke)
        case strokeEnded(Stroke)
        case viewportOffsetChanged(CGSize)
        case zoomScaleChanged(CGFloat)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case beginStroke(StylusSample)
        case appendSamples([StylusSample])
        case endStroke
        case commitStroke([StylusSample])
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
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
                state.pendingCommittedStroke = nil
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
                state.pendingCommittedStroke = stroke.points.isEmpty ? nil : stroke
                if state.currentTool == .erase,
                   let bufferIndex = state.layerBuffers.firstIndex(where: { $0.index == state.activeLayerIndex }) {
                    state.layerBuffers[bufferIndex].strokes.removeAll()
                    state.localBufferRevision += 1
                }
                if shouldPersistCommittedTrack(
                    for: stroke,
                    tool: state.currentTool,
                    previewRadius: Float(state.previewStyle.radius)
                ) {
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
                if state.currentTool == .shape {
                    return .send(.delegate(.commitStroke(stroke.points.map(\.stylusSample))))
                }
                return .send(.delegate(.endStroke))
            case .delegate:
                return .none
            }
        }
    }

    private func shouldPersistCommittedTrack(for stroke: Stroke, tool: StudioToolKind, previewRadius: Float) -> Bool {
        guard !stroke.points.isEmpty else { return false }
        guard tool != .erase else { return false }
        if tool == .shape {
            return true
        }

        guard stroke.points.count >= 2 else { return false }
        let pathLength = zip(stroke.points, stroke.points.dropFirst()).reduce(Float.zero) { partialResult, pair in
            partialResult + simd_length(pair.1.position - pair.0.position)
        }
        return pathLength >= max(previewRadius * 0.35, 1.5)
    }
}
