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
        var liveStroke: [PreviewStrokePoint] = []
        var predictedPreview: [PreviewStrokePoint] = []
        var isStrokeActive = false
        var isAwaitingCommittedRender = false
        var previewStyle = PreviewStrokeStyle(
            radius: 3.0,
            opacity: 0.9,
            color: CGColor(red: 31.0 / 255.0, green: 31.0 / 255.0, blue: 34.0 / 255.0, alpha: 1.0)
        )
    }

    enum Action: Equatable {
        case strokeBegan(StylusSample)
        case strokeSamples([StylusSample])
        case predictedPreviewUpdated([StylusSample])
        case strokeEnded
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case beginStroke(StylusSample)
        case appendSamples([StylusSample])
        case endStroke
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .strokeBegan(sample):
                state.isStrokeActive = true
                state.isAwaitingCommittedRender = false
                state.predictedPreview = []
                state.liveStroke = [
                    PreviewStrokePoint(point: sample.point, pressure: min(max(sample.pressure, 0.15), 1.0))
                ]
                return .send(.delegate(.beginStroke(sample)))
            case let .strokeSamples(samples):
                state.liveStroke.append(contentsOf: samples.map {
                    PreviewStrokePoint(point: $0.point, pressure: min(max($0.pressure, 0.15), 1.0))
                })
                return .send(.delegate(.appendSamples(samples)))
            case let .predictedPreviewUpdated(samples):
                state.predictedPreview = samples.map {
                    PreviewStrokePoint(point: $0.point, pressure: min(max($0.pressure, 0.15), 1.0))
                }
                return .none
            case .strokeEnded:
                state.isStrokeActive = false
                state.isAwaitingCommittedRender = true
                if !state.liveStroke.isEmpty {
                    let track = PreviewStrokeTrack(
                        layerIndex: state.activeLayerIndex,
                        points: state.liveStroke,
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
                state.liveStroke = []
                state.predictedPreview = []
                return .send(.delegate(.endStroke))
            case .delegate:
                return .none
            }
        }
    }
}
