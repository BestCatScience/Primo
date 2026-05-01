import ComposableArchitecture
import PrimoCanvasPresentationDomain
import PrimoDocumentRuntime
import PrimoDocumentDomain
import SwiftUI

struct CanvasView: UIViewRepresentable {
    @Dependency(\.canvasPresentationEnvironment) var canvasPresentationEnvironment

    let store: StoreOf<CanvasFeature>
    var allowsFingerTouchInput = false

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> CanvasPresentationContainerView {
        let view = CanvasPresentationContainerView(environment: canvasPresentationEnvironment)
        view.actionSink = CanvasPresentationActionSink { action in
            context.coordinator.store.send(CanvasFeature.Action(action))
        }
        return view
    }

    func updateUIView(_ uiView: CanvasPresentationContainerView, context: Context) {
        context.coordinator.store = store
        uiView.update(CanvasPresentationState(canvas: store, allowsFingerTouchInput: allowsFingerTouchInput))
    }

    final class Coordinator {
        var store: StoreOf<CanvasFeature>

        init(store: StoreOf<CanvasFeature>) {
            self.store = store
        }
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
            activeTextLayer: store.activeTextLayer,
            viewportOffset: store.viewportOffset,
            zoomScale: store.zoomScale,
            previewResetNonce: store.previewResetNonce
        )
    }
}
