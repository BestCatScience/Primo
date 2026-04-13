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
        var adjustmentPreviewPixelData: Data?
        var lastCommittedRenderRevision: Int = -1
        var localBufferRevision: Int = 0
        var lastRenderedLocalBufferRevision: Int = -1
        var activeLayerIndex = 0
        var activeStrokeBaseSnapshot: MetalDocumentSnapshot?
        var activeStrokePreviewLayerPixelData: Data?
        var layerBuffers: [LayerCanvasBuffer] = [
            LayerCanvasBuffer(index: 0, name: "Layer 1", visible: true, opacity: 1.0)
        ]
        var activeStroke: Stroke?
        var activeStrokeCommittedPointCount = 0
        var shapePreviewIsLive = false
        var isStrokeActive = false
        var isAwaitingCommittedRender = false
        var currentTool: StudioToolKind = .brush
        var selectionMode: SelectionToolMode = .lasso
        var shapeMode: ShapeToolMode = .line
        var eyedropperSamplingSource: EyedropperSamplingSource = .activeLayer
        var selection: CanvasSelection?
        var selectionPreviewPoints: [CGPoint] = []
        var transformPreviewOffset: CGSize = .zero
        var transformGestureBaseOffset: CGSize = .zero
        var transformPreviewScale: CGFloat = 1.0
        var transformGestureBaseScale: CGFloat = 1.0
        var transformPreviewRotationDegrees: Double = 0
        var transformGestureBaseRotationDegrees: Double = 0
        var activeTextLayer: TextLayerData?
        var viewportOffset: CGSize = .zero
        var zoomScale: CGFloat = 1.0
        var paperStyle: CanvasPaperStyle = .default
        var previewStyle = PreviewStrokeStyle(
            tipKind: .pencil,
            isEraser: false,
            radius: 3.0,
            opacity: 0.9,
            flow: 0.9,
            hardness: 0.82,
            roundness: 0.9,
            angle: 0.0,
            followsStrokeAngle: true,
            pressureSensitivity: 0.4,
            stabilization: 0.0,
            customTip: nil,
            color: CGColor(red: 31.0 / 255.0, green: 31.0 / 255.0, blue: 34.0 / 255.0, alpha: 1.0)
        )
        var pendingIncrementalUpdate: IncrementalLayerUpdate?
    }

    enum Action: Equatable {
        case strokeUpdated(Stroke)
        case strokeEnded(Stroke)
        case strokeCancelled
        case pencilInteractionToggleRequested
        case fillRequested(StylusSample)
        case colorSampled(SampledColor)
        case selectionPreviewUpdated([CGPoint])
        case selectionPathEnded([CGPoint])
        case autoSelectionRequested(StylusSample)
        case textPlacementRequested(CGPoint)
        case selectionUpdated(CanvasSelection?)
        case transformGestureBegan
        case transformPreviewChanged(CGSize)
        case transformEnded(CGSize)
        case transformScaleGestureBegan
        case transformScaleChanged(CGFloat)
        case transformScaleEnded(CGFloat)
        case transformRotationGestureBegan
        case transformRotationChanged(CGFloat)
        case transformRotationEnded(CGFloat)
        case transformPreviewCleared
        case requestLocalUndo
        case requestLocalRedo
        case viewportOffsetChanged(CGSize)
        case zoomScaleChanged(CGFloat)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case beginStroke(StylusSample)
        case appendSamples([StylusSample])
        case previewShapeStroke([StylusSample])
        case commitPreviewShapeStroke
        case endStroke([StylusSample])
        case cancelStroke
        case commitStroke([StylusSample])
        case blurSamples([StylusSample])
        case endBlurStroke
        case fill(StylusSample)
        case lassoSelect([CGPoint])
        case autoSelect(StylusSample)
        case placeText(CGPoint)
        case applyTransform(CGSize)
        case toggleBrushAndEraser
        case requestUndo
        case requestRedo
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .fillRequested(sample):
                return .send(.delegate(.fill(sample)))

            case .pencilInteractionToggleRequested:
                return .send(.delegate(.toggleBrushAndEraser))

            case .colorSampled:
                return .none

            case let .selectionPreviewUpdated(points):
                state.selectionPreviewPoints = points
                return .none

            case let .selectionPathEnded(points):
                state.selectionPreviewPoints = []
                return .send(.delegate(.lassoSelect(points)))

            case let .autoSelectionRequested(sample):
                state.selectionPreviewPoints = []
                return .send(.delegate(.autoSelect(sample)))

            case let .textPlacementRequested(point):
                return .send(.delegate(.placeText(point)))

            case let .selectionUpdated(selection):
                state.selection = selection
                state.selectionPreviewPoints = []
                state.transformPreviewOffset = .zero
                state.transformGestureBaseOffset = .zero
                state.transformPreviewScale = 1.0
                state.transformGestureBaseScale = 1.0
                state.transformPreviewRotationDegrees = 0
                state.transformGestureBaseRotationDegrees = 0
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

            case .transformScaleGestureBegan:
                state.transformGestureBaseScale = state.transformPreviewScale
                return .none

            case let .transformScaleChanged(scale):
                state.transformPreviewScale = min(max(state.transformGestureBaseScale * scale, 0.2), 6.0)
                return .none

            case let .transformScaleEnded(scale):
                state.transformPreviewScale = min(max(state.transformGestureBaseScale * scale, 0.2), 6.0)
                state.transformGestureBaseScale = state.transformPreviewScale
                return .none

            case .transformRotationGestureBegan:
                state.transformGestureBaseRotationDegrees = state.transformPreviewRotationDegrees
                return .none

            case let .transformRotationChanged(rotation):
                state.transformPreviewRotationDegrees = state.transformGestureBaseRotationDegrees + (Double(rotation) * 180.0 / .pi)
                return .none

            case let .transformRotationEnded(rotation):
                state.transformPreviewRotationDegrees = state.transformGestureBaseRotationDegrees + (Double(rotation) * 180.0 / .pi)
                state.transformGestureBaseRotationDegrees = state.transformPreviewRotationDegrees
                return .none

            case .transformPreviewCleared:
                state.transformPreviewOffset = .zero
                state.transformGestureBaseOffset = .zero
                state.transformPreviewScale = 1.0
                state.transformGestureBaseScale = 1.0
                state.transformPreviewRotationDegrees = 0
                state.transformGestureBaseRotationDegrees = 0
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
                state.isStrokeActive = true
                state.isAwaitingCommittedRender = false
                if state.currentTool == .shape {
                    state.activeStroke = nil
                    guard stroke.points.count >= 2 else { return .none }
                    state.shapePreviewIsLive = true
                    return .send(.delegate(.previewShapeStroke(stroke.points.map(\.stylusSample))))
                }

                let previousPointCount = state.activeStroke?.points.count ?? 0
                state.activeStroke = stroke
                let appendedSamples = Array(stroke.points.dropFirst(previousPointCount)).map(\.stylusSample)
                if state.currentTool == .blur {
                    guard !appendedSamples.isEmpty else { return .none }
                    return .send(.delegate(.blurSamples(appendedSamples)))
                }
                if state.activeStrokeCommittedPointCount == 0 {
                    guard let firstPoint = stroke.points.first else { return .none }
                    state.activeStrokeCommittedPointCount = stroke.points.count
                    var effects: [Effect<Action>] = [
                        .send(.delegate(.beginStroke(firstPoint.stylusSample)))
                    ]
                    let remainder = Array(stroke.points.dropFirst()).map(\.stylusSample)
                    if !remainder.isEmpty {
                        effects.append(.send(.delegate(.appendSamples(remainder))))
                    }
                    return .concatenate(effects)
                }

                state.activeStrokeCommittedPointCount = max(state.activeStrokeCommittedPointCount, stroke.points.count)
                guard !appendedSamples.isEmpty else { return .none }
                return .send(.delegate(.appendSamples(appendedSamples)))

            case let .strokeEnded(stroke):
                state.isStrokeActive = false
                state.isAwaitingCommittedRender = true
                if state.currentTool == .shape {
                    let hadLivePreview = state.shapePreviewIsLive
                    state.activeStroke = nil
                    state.activeStrokeCommittedPointCount = 0
                    state.shapePreviewIsLive = false
                    if hadLivePreview {
                        return .send(.delegate(.commitPreviewShapeStroke))
                    }
                    return .send(.delegate(.commitStroke(stroke.points.map(\.stylusSample))))
                }
                if state.currentTool == .blur {
                    state.activeStroke = nil
                    state.activeStrokeCommittedPointCount = 0
                    return .send(.delegate(.endBlurStroke))
                }
                let previousPointCount = state.activeStroke?.points.count ?? 0
                let appendedSamples = Array(stroke.points.dropFirst(previousPointCount)).map(\.stylusSample)
                state.activeStroke = nil
                let didCommitStroke = state.activeStrokeCommittedPointCount > 0
                state.activeStrokeCommittedPointCount = 0
                if didCommitStroke {
                    var effects: [Effect<Action>] = []
                    if !appendedSamples.isEmpty {
                        effects.append(.send(.delegate(.appendSamples(appendedSamples))))
                    }
                    effects.append(.send(.delegate(.endStroke(stroke.points.map(\.stylusSample)))))
                    return .concatenate(effects)
                }
                if !stroke.points.isEmpty {
                    return .send(.delegate(.commitStroke(stroke.points.map(\.stylusSample))))
                }
                return .none

            case .strokeCancelled:
                let cancelledStroke = state.activeStroke
                state.isStrokeActive = false
                state.isAwaitingCommittedRender = false
                state.activeStroke = nil
                let didCommitStroke = state.activeStrokeCommittedPointCount > 0
                state.activeStrokeCommittedPointCount = 0
                state.shapePreviewIsLive = false
                if state.currentTool == .blur {
                    return .send(.delegate(.endBlurStroke))
                }
                if state.currentTool == .brush || state.currentTool == .erase,
                   didCommitStroke,
                   let cancelledStroke,
                   !cancelledStroke.points.isEmpty {
                    return .send(.delegate(.commitStroke(cancelledStroke.points.map(\.stylusSample))))
                }
                return .send(.delegate(.cancelStroke))

            case .delegate:
                return .none
            }
        }
    }

}
