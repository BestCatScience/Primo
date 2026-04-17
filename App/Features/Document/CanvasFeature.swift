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
        var transformPreviewScaleX: CGFloat = 1.0
        var transformPreviewScaleY: CGFloat = 1.0
        var transformGestureBaseScaleX: CGFloat = 1.0
        var transformGestureBaseScaleY: CGFloat = 1.0
        var transformPreviewRotationDegrees: Double = 0
        var transformGestureBaseRotationDegrees: Double = 0
        var transformPivot: CGPoint?
        var transformMode: CanvasTransformMode = .standard
        var transformLocksAspectRatio = true
        var transformQuadOffsets = TransformQuadOffsets.zero
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

        var transformPreviewScale: CGFloat {
            get { transformPreviewScaleX }
            set {
                transformPreviewScaleX = newValue
                transformPreviewScaleY = newValue
            }
        }

        var transformHasPreview: Bool {
            transformPreviewOffset != .zero ||
            abs(transformPreviewScaleX - 1.0) > 0.001 ||
            abs(transformPreviewScaleY - 1.0) > 0.001 ||
            abs(transformPreviewRotationDegrees) > 0.001 ||
            !transformQuadOffsets.isZero
        }

        mutating func resetTransformPreview() {
            transformPreviewOffset = .zero
            transformGestureBaseOffset = .zero
            transformPreviewScaleX = 1.0
            transformPreviewScaleY = 1.0
            transformGestureBaseScaleX = 1.0
            transformGestureBaseScaleY = 1.0
            transformPreviewRotationDegrees = 0
            transformGestureBaseRotationDegrees = 0
            transformPivot = nil
            transformMode = .standard
            transformQuadOffsets = .zero
        }

        mutating func setCanvasSize(_ size: CGSize) {
            canvasSize = size
        }

        mutating func activateLayer(_ index: Int) {
            activeLayerIndex = index
        }

        mutating func activateLayerForEditing(_ index: Int) {
            activeLayerIndex = index
            clearSelection()
        }

        mutating func activateLayerForNewContent(_ index: Int) {
            activeLayerIndex = index
            clearSelectionState()
        }

        mutating func replaceLayerBuffers(_ layerBuffers: [LayerCanvasBuffer]) {
            self.layerBuffers = layerBuffers
        }

        mutating func activateTool(_ tool: StudioToolKind) {
            currentTool = tool
        }

        mutating func selectTool(
            _ tool: StudioToolKind,
            selectionMode: SelectionToolMode,
            shapeMode: ShapeToolMode,
            eyedropperSamplingSource: EyedropperSamplingSource
        ) {
            activateTool(tool)
            updateInteractionModes(
                selectionMode: selectionMode,
                shapeMode: shapeMode,
                eyedropperSamplingSource: eyedropperSamplingSource
            )
            clearSelectionPreview()
            resetTransformPreview()
            if tool != .select && tool != .move {
                clearSelection()
            }
        }

        mutating func setSelection(_ selection: CanvasSelection?) {
            self.selection = selection
        }

        mutating func clearSelection() {
            selection = nil
        }

        mutating func replaceSelection(_ selection: CanvasSelection?) {
            self.selection = selection
            clearSelectionPreview()
            resetTransformPreview()
        }

        mutating func clearSelectionPreview() {
            selectionPreviewPoints = []
        }

        mutating func clearSelectionState() {
            selection = nil
            selectionPreviewPoints = []
            resetTransformPreview()
        }

        mutating func clearAdjustmentPreview() {
            adjustmentPreviewPixelData = nil
        }

        mutating func setAdjustmentPreviewPixelData(_ pixelData: Data?) {
            adjustmentPreviewPixelData = pixelData
        }

        mutating func resetTransientEditingState() {
            clearSelectionState()
            clearAdjustmentPreview()
        }

        mutating func captureStrokeBaseSnapshot(_ snapshot: MetalDocumentSnapshot) {
            activeStrokeBaseSnapshot = snapshot
        }

        mutating func setStrokePreviewLayerPixelData(_ pixelData: Data?) {
            activeStrokePreviewLayerPixelData = pixelData
        }

        mutating func setPendingIncrementalUpdate(_ update: IncrementalLayerUpdate?) {
            pendingIncrementalUpdate = update
        }

        mutating func clearPendingIncrementalUpdate() {
            pendingIncrementalUpdate = nil
        }

        mutating func applyCommittedRenderSnapshot(
            _ renderSnapshot: MetalDocumentSnapshot,
            previousRevision: Int
        ) {
            self.renderSnapshot = renderSnapshot
            lastCommittedRenderRevision = renderSnapshot.revision
            resetStrokePreview()
            if !isStrokeActive &&
                isAwaitingCommittedRender &&
                renderSnapshot.revision > previousRevision {
                isAwaitingCommittedRender = false
                lastRenderedLocalBufferRevision = localBufferRevision
            }
        }

        mutating func applyPreviewRenderSnapshot(
            _ renderSnapshot: MetalDocumentSnapshot,
            previewLayerPixelData: Data? = nil
        ) {
            self.renderSnapshot = renderSnapshot
            if let previewLayerPixelData {
                setStrokePreviewLayerPixelData(previewLayerPixelData)
            }
            clearPendingIncrementalUpdate()
        }

        mutating func resetStrokePreview() {
            activeStrokeBaseSnapshot = nil
            activeStrokePreviewLayerPixelData = nil
            pendingIncrementalUpdate = nil
        }

        mutating func setActiveTextLayer(_ textLayer: TextLayerData?) {
            activeTextLayer = textLayer
        }

        mutating func updateInteractionModes(
            selectionMode: SelectionToolMode,
            shapeMode: ShapeToolMode,
            eyedropperSamplingSource: EyedropperSamplingSource
        ) {
            self.selectionMode = selectionMode
            self.shapeMode = shapeMode
            self.eyedropperSamplingSource = eyedropperSamplingSource
        }

        mutating func updateInteractionStyle(
            previewStyle: PreviewStrokeStyle,
            paperStyle: CanvasPaperStyle
        ) {
            self.previewStyle = previewStyle
            self.paperStyle = paperStyle
        }

        mutating func updatePreviewStyle(_ previewStyle: PreviewStrokeStyle) {
            self.previewStyle = previewStyle
        }

        mutating func updatePaperStyle(_ paperStyle: CanvasPaperStyle) {
            self.paperStyle = paperStyle
        }

        mutating func discardBufferedStrokes(
            for layerIndex: Int,
            incrementsRevision: Bool = false
        ) {
            guard let bufferIndex = layerBuffers.firstIndex(where: { $0.index == layerIndex }) else {
                return
            }
            layerBuffers[bufferIndex].strokes.removeAll()
            if incrementsRevision {
                localBufferRevision += 1
            }
        }

        mutating func finalizeLayerMutation(
            at layerIndex: Int,
            incrementsRevision: Bool = false,
            clearsSelection: Bool = true
        ) {
            discardBufferedStrokes(for: layerIndex, incrementsRevision: incrementsRevision)
            if clearsSelection {
                clearSelection()
            }
        }

        mutating func completeTransformMutation(
            at layerIndex: Int,
            selection: CanvasSelection?
        ) {
            discardBufferedStrokes(for: layerIndex, incrementsRevision: true)
            setSelection(selection)
            resetTransformPreview()
        }
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
        case transformScaleSet(x: CGFloat, y: CGFloat)
        case transformRotationGestureBegan
        case transformRotationChanged(CGFloat)
        case transformRotationEnded(CGFloat)
        case transformRotationSet(Double)
        case transformOffsetSet(CGSize)
        case transformPivotSet(CGPoint?)
        case transformModeChanged(CanvasTransformMode)
        case transformAspectRatioLockChanged(Bool)
        case transformQuadOffsetsSet(TransformQuadOffsets)
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
                state.clearSelectionPreview()
                return .send(.delegate(.lassoSelect(points)))

            case let .autoSelectionRequested(sample):
                state.clearSelectionPreview()
                return .send(.delegate(.autoSelect(sample)))

            case let .textPlacementRequested(point):
                return .send(.delegate(.placeText(point)))

            case let .selectionUpdated(selection):
                state.replaceSelection(selection)
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
                state.transformGestureBaseScaleX = state.transformPreviewScaleX
                state.transformGestureBaseScaleY = state.transformPreviewScaleY
                return .none

            case let .transformScaleChanged(scale):
                let nextScale = min(max(scale, 0.2), 6.0)
                state.transformPreviewScaleX = min(max(state.transformGestureBaseScaleX * nextScale, 0.2), 6.0)
                state.transformPreviewScaleY = min(max(state.transformGestureBaseScaleY * nextScale, 0.2), 6.0)
                return .none

            case let .transformScaleEnded(scale):
                let nextScale = min(max(scale, 0.2), 6.0)
                state.transformPreviewScaleX = min(max(state.transformGestureBaseScaleX * nextScale, 0.2), 6.0)
                state.transformPreviewScaleY = min(max(state.transformGestureBaseScaleY * nextScale, 0.2), 6.0)
                state.transformGestureBaseScaleX = state.transformPreviewScaleX
                state.transformGestureBaseScaleY = state.transformPreviewScaleY
                return .none

            case let .transformScaleSet(x, y):
                state.transformPreviewScaleX = min(max(x, 0.2), 6.0)
                state.transformPreviewScaleY = min(max(y, 0.2), 6.0)
                state.transformGestureBaseScaleX = state.transformPreviewScaleX
                state.transformGestureBaseScaleY = state.transformPreviewScaleY
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

            case let .transformRotationSet(rotationDegrees):
                state.transformPreviewRotationDegrees = rotationDegrees
                state.transformGestureBaseRotationDegrees = rotationDegrees
                return .none

            case let .transformOffsetSet(offset):
                state.transformPreviewOffset = offset
                state.transformGestureBaseOffset = offset
                return .none

            case let .transformPivotSet(point):
                state.transformPivot = point
                return .none

            case let .transformModeChanged(mode):
                state.transformMode = mode
                if mode == .standard {
                    state.transformQuadOffsets = .zero
                }
                return .none

            case let .transformAspectRatioLockChanged(isLocked):
                state.transformLocksAspectRatio = isLocked
                return .none

            case let .transformQuadOffsetsSet(offsets):
                state.transformQuadOffsets = offsets
                return .none

            case .transformPreviewCleared:
                state.resetTransformPreview()
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
