#if canImport(UIKit)
import PrimoCanvasPresentationDomain
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import UIKit
import simd

@MainActor
public final class CanvasPresentationContainerView: UIView, CanvasInputHandlingDelegate, UIPencilInteractionDelegate {
    public var documentSize: CGSize = .zero
    public var actionSink: CanvasPresentationActionSink? {
        didSet {
            navigationGestureAdapter.actionSink = actionSink
            textTransformOverlayView.actionSink = actionSink
            eyedropperLoupeView.onSampledColor = { [weak self] sampledColor in
                self?.actionSink?.send(.colorSampled(sampledColor))
            }
        }
    }

    private let canvasRenderSurfaceView = CanvasRenderSurfaceView()
    private let inputHandler = CanvasInputHandler()
    private let previewRenderer: any CanvasPreviewRendering
    private let eyedropperSampler: any CanvasEyedropperSampling
    private let selectionProcessor: any SelectionMaskProcessing
    private let layerTransformProcessor: any LayerTransformProcessing
    private lazy var selectionOverlayView = CanvasSelectionOverlayView(selectionProcessor: selectionProcessor)
    private lazy var transformPreviewView = CanvasTransformPreviewView(
        previewRenderer: previewRenderer,
        layerTransformProcessor: layerTransformProcessor
    )
    private lazy var textTransformOverlayView = CanvasTextTransformOverlayView(
        previewRenderer: previewRenderer,
        layerTransformProcessor: layerTransformProcessor
    )
    private lazy var eyedropperLoupeView = CanvasEyedropperLoupeView(
        previewRenderer: previewRenderer,
        eyedropperSampler: eyedropperSampler
    )
    private let navigationGestureAdapter = CanvasNavigationGestureAdapter()
    private let pencilToggleFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let pencilToggleNotificationFeedbackGenerator = UINotificationFeedbackGenerator()

    private var viewportOffset: CGSize = .zero
    private var zoomScale: CGFloat = 1.0
    private var currentTool: StudioToolKind = .brush

    public init(
        environment: CanvasPresentationEnvironment
    ) {
        self.previewRenderer = environment.previewRenderer
        self.eyedropperSampler = environment.eyedropperSampler
        self.selectionProcessor = environment.selectionProcessor
        self.layerTransformProcessor = environment.layerTransformProcessor
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

        navigationGestureAdapter.actionSink = actionSink
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
            self?.actionSink?.send(.colorSampled(sampledColor))
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

    public override func layoutSubviews() {
        super.layoutSubviews()
        canvasRenderSurfaceView.frame = bounds
        selectionOverlayView.frame = bounds
        transformPreviewView.frame = bounds
        textTransformOverlayView.frame = bounds
    }

    public func update(_ state: CanvasPresentationState) {
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

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if shouldRouteTouchesToTransformOverlay(touches) { return }
        if eyedropperLoupeView.isActive { return }
        if navigationGestureAdapter.handlePanTouchesIfNeeded(touches, with: event, phase: .began) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if shouldRouteTouchesToTransformOverlay(touches) { return }
        if eyedropperLoupeView.isActive { return }
        if navigationGestureAdapter.handlePanTouchesIfNeeded(touches, with: event, phase: .moved) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if shouldRouteTouchesToTransformOverlay(touches) { return }
        if eyedropperLoupeView.isActive { return }
        if navigationGestureAdapter.handlePanTouchesIfNeeded(touches, with: event, phase: .ended) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if shouldRouteTouchesToTransformOverlay(touches) { return }
        if eyedropperLoupeView.isActive { return }
        if navigationGestureAdapter.handlePanTouchesIfNeeded(touches, with: event, phase: .cancelled) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    public func didUpdateStroke(_ stroke: Stroke) {
        actionSink?.send(.strokeUpdated(stroke))
    }

    public func didEndStroke(_ stroke: Stroke) {
        actionSink?.send(.strokeEnded(stroke))
    }

    public func didCancelStroke() {
        actionSink?.send(.strokeCancelled)
    }

    public func didRequestFill(at sample: StylusSample) {
        actionSink?.send(.fillRequested(sample))
    }

    public func didRequestColorSample(at sample: StylusSample) {
        guard
            let sampledColor = eyedropperLoupeView.sampledColor(
                at: sample.point,
                source: inputHandler.eyedropperSamplingSource
            )
        else {
            return
        }
        actionSink?.send(.colorSampled(sampledColor))
    }

    public func didUpdateSelectionPath(_ points: [CGPoint]) {
        actionSink?.send(.selectionPreviewUpdated(points))
    }

    public func didEndSelectionPath(_ points: [CGPoint]) {
        actionSink?.send(.selectionPathEnded(points))
    }

    public func didRequestAutoSelection(at sample: StylusSample) {
        actionSink?.send(.autoSelectionRequested(sample))
    }

    public func didRequestTextPlacement(at point: CGPoint) {
        actionSink?.send(.textPlacementRequested(point))
    }

    public func didBeginTransform() {
        actionSink?.send(.transformGestureBegan)
    }

    public func didUpdateTransform(translation: CGSize) {
        actionSink?.send(.transformPreviewChanged(translation))
    }

    public func didEndTransform(translation: CGSize) {
        actionSink?.send(.transformEnded(translation))
    }

    public func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        pencilToggleFeedbackGenerator.impactOccurred(intensity: 1.0)
        pencilToggleNotificationFeedbackGenerator.notificationOccurred(.success)
        pencilToggleFeedbackGenerator.prepare()
        pencilToggleNotificationFeedbackGenerator.prepare()
        actionSink?.send(.pencilInteractionToggleRequested)
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
#endif
