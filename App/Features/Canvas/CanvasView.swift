import ComposableArchitecture
import PrimoBrushFileFormats
import PrimoCanvasPresentationDomain
import PrimoDocumentGPUContracts
import PrimoDocumentContracts
import PrimoDocumentDomain
import SwiftUI
import UIKit
import simd

struct CanvasView: UIViewRepresentable {
    @Dependency(\.canvasPreviewRenderer) var canvasPreviewRenderer
    @Dependency(\.layerTransformProcessor) var layerTransformProcessor

    let store: StoreOf<CanvasFeature>

    func makeUIView(context: Context) -> RasterCanvasContainerView {
        let view = RasterCanvasContainerView(
            previewRenderer: canvasPreviewRenderer,
            layerTransformProcessor: layerTransformProcessor
        )
        view.sendAction = { store.send($0) }
        return view
    }

    func updateUIView(_ uiView: RasterCanvasContainerView, context: Context) {
        uiView.update(CanvasPresentationState(canvas: store))
    }
}

final class RasterCanvasContainerView: UIView, InputHandlerDelegate, UIPencilInteractionDelegate {
    var documentSize: CGSize = .zero
    var sendAction: ((CanvasFeature.Action) -> Void)? {
        didSet {
            navigationGestureAdapter.sendAction = sendAction
            textTransformOverlayView.sendAction = sendAction
            eyedropperLoupeView.onSampledColor = { [weak self] sampledColor in
                self?.sendAction?(.colorSampled(sampledColor))
            }
        }
    }

    private let canvasRenderSurfaceView = CanvasRenderSurfaceView()
    private let inputHandler = InputHandler()
    private let previewRenderer: any CanvasPreviewRendering
    private let layerTransformProcessor: any LayerTransformProcessing
    private lazy var selectionOverlayView = CanvasSelectionOverlayView(previewRenderer: previewRenderer)
    private lazy var transformPreviewView = CanvasTransformPreviewView(
        previewRenderer: previewRenderer,
        layerTransformProcessor: layerTransformProcessor
    )
    private lazy var textTransformOverlayView = CanvasTextTransformOverlayView(
        previewRenderer: previewRenderer,
        layerTransformProcessor: layerTransformProcessor
    )
    private lazy var eyedropperLoupeView = CanvasEyedropperLoupeView(previewRenderer: previewRenderer)
    private let navigationGestureAdapter = CanvasNavigationGestureAdapter()
    private let pencilToggleFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let pencilToggleNotificationFeedbackGenerator = UINotificationFeedbackGenerator()

    private var viewportOffset: CGSize = .zero
    private var zoomScale: CGFloat = 1.0
    private var currentTool: StudioToolKind = .brush

    init(
        previewRenderer: any CanvasPreviewRendering,
        layerTransformProcessor: any LayerTransformProcessing
    ) {
        self.previewRenderer = previewRenderer
        self.layerTransformProcessor = layerTransformProcessor
        super.init(frame: .zero)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        clipsToBounds = true

        inputHandler.delegate = self
        inputHandler.pointMapper = { [weak self] location, view in
            guard let self else { return SIMD2(Float(location.x), Float(location.y)) }
            let point = self.canvasPoint(from: location, in: view)
            return SIMD2(Float(point.x), Float(point.y))
        }

        addSubview(canvasRenderSurfaceView)
        addSubview(selectionOverlayView)
        addSubview(transformPreviewView)
        addSubview(textTransformOverlayView)

        navigationGestureAdapter.sendAction = sendAction
        navigationGestureAdapter.shouldAllowSimultaneousRecognition = { [weak self] gesture, otherGesture in
            guard let self else { return true }
            if self.eyedropperLoupeView.ownsGesture(gesture) || self.eyedropperLoupeView.ownsGesture(otherGesture) {
                return false
            }
            if self.textTransformOverlayView.ownsGesture(gesture) || self.textTransformOverlayView.ownsGesture(otherGesture) {
                return false
            }
            return true
        }
        navigationGestureAdapter.shouldReceiveTouch = { [weak self] gesture, touch in
            guard let self else { return true }
            if self.textTransformOverlayView.ownsGesture(gesture) {
                return !self.textTransformOverlayView.containsInteractivePoint(touch.location(in: self))
            }
            return true
        }
        navigationGestureAdapter.install(on: self)

        eyedropperLoupeView.onSampledColor = { [weak self] sampledColor in
            self?.sendAction?(.colorSampled(sampledColor))
        }
        eyedropperLoupeView.onBeganSampling = { [weak self] in
            self?.navigationGestureAdapter.cancelPan()
        }
        eyedropperLoupeView.install(on: self)

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = self
        addInteraction(pencilInteraction)
        pencilToggleFeedbackGenerator.prepare()
        pencilToggleNotificationFeedbackGenerator.prepare()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        canvasRenderSurfaceView.frame = bounds
        selectionOverlayView.frame = bounds
        transformPreviewView.frame = bounds
        textTransformOverlayView.frame = bounds
    }

    func update(_ state: CanvasPresentationState) {
        documentSize = state.documentSize
        currentTool = state.currentTool
        viewportOffset = state.viewportOffset
        zoomScale = state.zoomScale

        let geometry = viewportGeometry
        canvasRenderSurfaceView.render(
            RenderFrameUpdate(
                snapshot: state.snapshot,
                activeLayerIndex: state.activeLayerIndex,
                incrementalUpdate: state.incrementalUpdate,
                documentSize: documentSize,
                viewportOffset: state.viewportOffset,
                zoomScale: state.zoomScale,
                paperStyle: state.paperStyle,
                previewResetNonce: state.previewResetNonce
            )
        )

        inputHandler.tool = state.currentTool
        inputHandler.selectionMode = state.selectionMode
        inputHandler.shapeMode = state.shapeMode
        inputHandler.eyedropperSamplingSource = state.eyedropperSamplingSource
        inputHandler.brushTipKind = state.previewStyle.tipKind
        inputHandler.brushSize = Float(state.previewStyle.radius * 2.0)
        inputHandler.brushColor = state.previewStyle.simdColor
        inputHandler.strokeStabilization = Float(state.previewStyle.stabilization)

        let shouldHideMoveOverlay = state.currentTool == .move && (
            abs(state.transformPreviewRotationDegrees) > 0.001 ||
            abs(state.transformPreviewScaleX - 1.0) > 0.001 ||
            abs(state.transformPreviewScaleY - 1.0) > 0.001
        )
        selectionOverlayView.update(
            selection: state.selection,
            previewPoints: state.selectionPreviewPoints,
            currentTool: state.currentTool,
            geometry: geometry,
            transformQuad: state.currentTool == .move
                ? { rect in
                    CanvasTransformGeometry.effectiveTransformQuad(
                        bounds: rect,
                        translation: state.transformPreviewOffset,
                        scaleX: state.transformPreviewScaleX,
                        scaleY: state.transformPreviewScaleY,
                        rotationDegrees: state.transformPreviewRotationDegrees,
                        pivot: state.transformPivot,
                        mode: state.transformMode,
                        quadOffsets: state.transformQuadOffsets
                    ).effective
                }
                : nil,
            hidesTransformedOverlayImage: shouldHideMoveOverlay
        )

        transformPreviewView.update(
            snapshot: state.snapshot,
            activeLayerIndex: state.activeLayerIndex,
            activeStroke: state.activeStroke,
            strokePreviewCompositePixelData: nil,
            adjustmentPreviewPixelData: state.adjustmentPreviewPixelData,
            selection: state.selection,
            paperStyle: state.paperStyle,
            previewStyle: state.previewStyle,
            currentTool: state.currentTool,
            transformPreviewOffset: state.transformPreviewOffset,
            transformPreviewScaleX: state.transformPreviewScaleX,
            transformPreviewScaleY: state.transformPreviewScaleY,
            transformPreviewRotationDegrees: state.transformPreviewRotationDegrees,
            transformPivot: state.transformPivot,
            transformMode: state.transformMode,
            transformQuadOffsets: state.transformQuadOffsets,
            activeTextLayer: state.activeTextLayer,
            geometry: geometry,
            renderSurfaceView: canvasRenderSurfaceView
        )

        textTransformOverlayView.update(
            context: CanvasTextTransformOverlayView.Context(
                snapshot: state.snapshot,
                activeLayerIndex: state.activeLayerIndex,
                currentTool: state.currentTool,
                selection: state.selection,
                transformPreviewOffset: state.transformPreviewOffset,
                transformPreviewScaleX: state.transformPreviewScaleX,
                transformPreviewScaleY: state.transformPreviewScaleY,
                transformPreviewRotationDegrees: state.transformPreviewRotationDegrees,
                transformPivot: state.transformPivot,
                transformMode: state.transformMode,
                transformLocksAspectRatio: state.transformLocksAspectRatio,
                transformQuadOffsets: state.transformQuadOffsets,
                activeTextLayer: state.activeTextLayer,
                geometry: geometry
            )
        )

        eyedropperLoupeView.update(
            context: CanvasEyedropperLoupeView.Context(
                snapshot: state.snapshot,
                activeLayerIndex: state.activeLayerIndex,
                paperStyle: state.paperStyle,
                source: state.eyedropperSamplingSource,
                geometry: geometry,
                shouldBlockSampling: { [weak self] point in
                    self?.textTransformOverlayView.containsInteractivePoint(point) ?? false
                }
            )
        )

        navigationGestureAdapter.update(
            context: CanvasNavigationGestureAdapter.Context(
                currentTool: state.currentTool,
                transformMode: state.transformMode,
                geometry: geometry
            )
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if shouldRouteTouchesToTransformOverlay(touches) { return }
        if eyedropperLoupeView.isActive { return }
        if navigationGestureAdapter.handlePanTouchesIfNeeded(touches, with: event, phase: .began) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if shouldRouteTouchesToTransformOverlay(touches) { return }
        if eyedropperLoupeView.isActive { return }
        if navigationGestureAdapter.handlePanTouchesIfNeeded(touches, with: event, phase: .moved) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if shouldRouteTouchesToTransformOverlay(touches) { return }
        if eyedropperLoupeView.isActive { return }
        if navigationGestureAdapter.handlePanTouchesIfNeeded(touches, with: event, phase: .ended) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if shouldRouteTouchesToTransformOverlay(touches) { return }
        if eyedropperLoupeView.isActive { return }
        if navigationGestureAdapter.handlePanTouchesIfNeeded(touches, with: event, phase: .cancelled) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    func didUpdateStroke(_ stroke: Stroke) {
        sendAction?(.strokeUpdated(stroke))
    }

    func didEndStroke(_ stroke: Stroke) {
        sendAction?(.strokeEnded(stroke))
    }

    func didCancelStroke() {
        sendAction?(.strokeCancelled)
    }

    func didRequestFill(at sample: StylusSample) {
        sendAction?(.fillRequested(sample))
    }

    func didRequestColorSample(at sample: StylusSample) {
        guard
            let sampledColor = eyedropperLoupeView.sampledColor(
                at: sample.point,
                source: inputHandler.eyedropperSamplingSource
            )
        else {
            return
        }
        sendAction?(.colorSampled(sampledColor))
    }

    func didUpdateSelectionPath(_ points: [CGPoint]) {
        sendAction?(.selectionPreviewUpdated(points))
    }

    func didEndSelectionPath(_ points: [CGPoint]) {
        sendAction?(.selectionPathEnded(points))
    }

    func didRequestAutoSelection(at sample: StylusSample) {
        sendAction?(.autoSelectionRequested(sample))
    }

    func didRequestTextPlacement(at point: CGPoint) {
        sendAction?(.textPlacementRequested(point))
    }

    func didBeginTransform() {
        sendAction?(.transformGestureBegan)
    }

    func didUpdateTransform(translation: CGSize) {
        sendAction?(.transformPreviewChanged(translation))
    }

    func didEndTransform(translation: CGSize) {
        sendAction?(.transformEnded(translation))
    }

    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        pencilToggleFeedbackGenerator.impactOccurred(intensity: 1.0)
        pencilToggleNotificationFeedbackGenerator.notificationOccurred(.success)
        pencilToggleFeedbackGenerator.prepare()
        pencilToggleNotificationFeedbackGenerator.prepare()
        sendAction?(.pencilInteractionToggleRequested)
    }

    private var viewportGeometry: CanvasViewportGeometry {
        CanvasViewportGeometry(
            bounds: bounds,
            documentSize: documentSize,
            viewportOffset: viewportOffset,
            zoomScale: zoomScale
        )
    }

    private func canvasPoint(from location: CGPoint, in view: UIView) -> CGPoint {
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let local = convert(location, from: view)
        return viewportGeometry.documentPoint(fromViewPoint: local)
    }

    private func shouldRouteTouchesToTransformOverlay(_ touches: Set<UITouch>) -> Bool {
        guard currentTool == .move else { return false }
        return touches.contains { touch in
            let location = touch.location(in: self)
            return textTransformOverlayView.containsInteractivePoint(location)
        }
    }
}

private extension PreviewStrokeStyle {
    var simdColor: SIMD4<Float> {
        guard let components = color.components else {
            return SIMD4(0, 0, 0, 1)
        }

        switch components.count {
        case 4:
            return SIMD4(Float(components[0]), Float(components[1]), Float(components[2]), Float(components[3]))
        case 2:
            return SIMD4(Float(components[0]), Float(components[0]), Float(components[0]), Float(components[1]))
        default:
            return SIMD4(0, 0, 0, 1)
        }
    }
}

private extension CanvasPresentationState {
    init(canvas store: StoreOf<CanvasFeature>) {
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
