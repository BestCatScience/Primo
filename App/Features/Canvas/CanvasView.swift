import ComposableArchitecture
import PrimoCanvasPresentationDomain
import PrimoCanvasPresentationInfrastructure
import PrimoDocumentContracts
import PrimoDocumentDomain
import SwiftUI

struct CanvasView: UIViewRepresentable {
    @Dependency(\.canvasPresentationEnvironment) var canvasPresentationEnvironment

    let store: StoreOf<CanvasFeature>
    var allowsFingerTouchInput = false

    func makeUIView(context: Context) -> CanvasPresentationContainerView {
        let view = CanvasPresentationContainerView(environment: canvasPresentationEnvironment)
        view.actionSink = CanvasPresentationActionSink { action in
            store.send(CanvasFeature.Action(action))
        }
        return view
    }

    func updateUIView(_ uiView: CanvasPresentationContainerView, context: Context) {
        uiView.update(CanvasPresentationState(canvas: store, allowsFingerTouchInput: allowsFingerTouchInput))
    }
}

private extension CanvasFeature.Action {
    init(_ action: CanvasPresentationAction) {
        switch action {
        case let .strokeUpdated(stroke):
            self = .strokeUpdated(stroke)
        case let .strokeEnded(stroke):
            self = .strokeEnded(stroke)
        case .strokeCancelled:
            self = .strokeCancelled
        case let .fillRequested(sample):
            self = .fillRequested(sample)
        case let .colorSampled(color):
            self = .colorSampled(color)
        case let .selectionPreviewUpdated(points):
            self = .selectionPreviewUpdated(points)
        case let .selectionPathEnded(points):
            self = .selectionPathEnded(points)
        case let .autoSelectionRequested(sample):
            self = .autoSelectionRequested(sample)
        case let .textPlacementRequested(point):
            self = .textPlacementRequested(point)
        case .transformGestureBegan:
            self = .transformGestureBegan
        case let .transformPreviewChanged(offset):
            self = .transformPreviewChanged(offset)
        case let .transformEnded(offset):
            self = .transformEnded(offset)
        case .transformScaleGestureBegan:
            self = .transformScaleGestureBegan
        case let .transformScaleChanged(scale):
            self = .transformScaleChanged(scale)
        case let .transformScaleEnded(scale):
            self = .transformScaleEnded(scale)
        case let .transformScaleSet(x, y):
            self = .transformScaleSet(x: x, y: y)
        case .transformRotationGestureBegan:
            self = .transformRotationGestureBegan
        case let .transformRotationChanged(rotation):
            self = .transformRotationChanged(rotation)
        case let .transformRotationEnded(rotation):
            self = .transformRotationEnded(rotation)
        case let .transformPivotSet(point):
            self = .transformPivotSet(point)
        case let .transformQuadOffsetsSet(offsets):
            self = .transformQuadOffsetsSet(offsets)
        case let .viewportOffsetChanged(offset):
            self = .viewportOffsetChanged(offset)
        case let .zoomScaleChanged(scale):
            self = .zoomScaleChanged(scale)
        case .requestLocalUndo:
            self = .requestLocalUndo
        case .requestLocalRedo:
            self = .requestLocalRedo
        case .pencilInteractionToggleRequested:
            self = .pencilInteractionToggleRequested
        }
    }
}

private extension CanvasPresentationState {
    @MainActor
    init(canvas store: StoreOf<CanvasFeature>, allowsFingerTouchInput: Bool) {
        self.init(
            documentSize: store.canvasSize,
            snapshot: store.renderSnapshot,
            activeLayerIndex: store.activeLayerIndex,
            activeStroke: store.activeStroke,
            incrementalUpdate: store.strokeSession.pendingIncrementalUpdate,
            adjustmentPreviewPixelData: store.adjustmentPreviewPixelData,
            paperStyle: store.paperStyle,
            previewStyle: store.previewStyle,
            currentTool: store.currentTool,
            allowsFingerTouchInput: allowsFingerTouchInput,
            selectionMode: store.selectionMode,
            shapeMode: store.shapeMode,
            eyedropperSamplingSource: store.eyedropperSamplingSource,
            selection: store.selection,
            selectionPreviewPoints: store.selectionPreviewPoints,
            transformPreviewOffset: store.transformPreviewOffset,
            transformPreviewScaleX: store.transformPreviewScaleX,
            transformPreviewScaleY: store.transformPreviewScaleY,
            transformPreviewRotationDegrees: store.transformPreviewRotationDegrees,
            transformPivot: store.transformPivot,
            transformMode: store.transformMode,
            transformLocksAspectRatio: store.transformLocksAspectRatio,
            transformQuadOffsets: store.transformQuadOffsets,
            activeTextLayer: store.activeTextLayer,
            viewportOffset: store.viewportOffset,
            zoomScale: store.zoomScale,
            previewResetNonce: store.previewResetNonce
        )
    }
}
