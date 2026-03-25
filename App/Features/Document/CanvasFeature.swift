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
        var predictedPreview: [PreviewStrokePoint] = []
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
                state.predictedPreview = []
                return .send(.delegate(.beginStroke(sample)))
            case let .strokeSamples(samples):
                return .send(.delegate(.appendSamples(samples)))
            case let .predictedPreviewUpdated(samples):
                state.predictedPreview = samples.map {
                    PreviewStrokePoint(point: $0.point, pressure: min(max($0.pressure, 0.15), 1.0))
                }
                return .none
            case .strokeEnded:
                state.predictedPreview = []
                return .send(.delegate(.endStroke))
            case .delegate:
                return .none
            }
        }
    }
}
