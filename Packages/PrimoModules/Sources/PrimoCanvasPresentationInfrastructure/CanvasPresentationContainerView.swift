#if canImport(UIKit)
import PrimoCanvasPresentationDomain
import PrimoDocumentPresentationContracts
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
            eyedropperLoupeView.onSampledColor = { [weak self] sampledColor in
                self?.actionSink?.send(.colorSampled(sampledColor))
            }
        }
    }

    private let canvasRenderSurfaceView = CanvasRenderSurfaceView()
    private let shapePreviewSurfaceView = CanvasPixelSurfaceView()
    private let inputHandler = CanvasInputHandler()
    private let previewRenderer: any CanvasPreviewRendering
    private let eyedropperSampler: any CanvasEyedropperSampling
    private let selectionProcessor: any SelectionMaskProcessing
    private lazy var selectionOverlayView = CanvasSelectionOverlayView(selectionProcessor: selectionProcessor)
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
        addSubview(shapePreviewSurfaceView)
        addSubview(selectionOverlayView)

        navigationGestureAdapter.actionSink = actionSink
        navigationGestureAdapter.shouldAllowSimultaneousRecognition = { [weak self] gesture, otherGesture in
            guard let self else { return true }
            if self.eyedropperLoupeView.ownsGesture(gesture) || self.eyedropperLoupeView.ownsGesture(otherGesture) {
                return false
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
        shapePreviewSurfaceView.frame = bounds
        selectionOverlayView.frame = bounds
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
        inputHandler.allowsFingerTouchInput = state.allowsFingerTouchInput
        inputHandler.selectionMode = state.selectionMode
        inputHandler.shapeMode = state.shapeMode
        inputHandler.eyedropperSamplingSource = state.eyedropperSamplingSource
        inputHandler.brushTipKind = state.previewStyle.tipKind
        inputHandler.brushSize = Float(state.previewStyle.radius * 2.0)
        inputHandler.brushColor = state.previewStyle.simdColor
        inputHandler.strokeStabilization = Float(state.previewStyle.stabilization)

        selectionOverlayView.update(
            selection: state.selection,
            previewPoints: state.selectionPreviewPoints,
            currentTool: state.currentTool,
            geometry: geometry
        )

        updateShapePreview(
            stroke: state.activeStroke,
            style: state.previewStyle,
            currentTool: state.currentTool,
            snapshot: state.snapshot,
            geometry: geometry
        )

        eyedropperLoupeView.update(
            context: CanvasEyedropperLoupeView.Context(
                snapshot: state.snapshot,
                activeLayerIndex: state.activeLayerIndex,
                paperStyle: state.paperStyle,
                source: state.eyedropperSamplingSource,
                geometry: geometry,
                shouldBlockSampling: { _ in false }
            )
        )

        navigationGestureAdapter.update(
            context: CanvasNavigationGestureAdapter.Context(
                currentTool: state.currentTool,
                geometry: geometry
            )
        )
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if eyedropperLoupeView.isActive { return }
        if navigationGestureAdapter.handlePanTouchesIfNeeded(touches, with: event, phase: .began) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if eyedropperLoupeView.isActive { return }
        if navigationGestureAdapter.handlePanTouchesIfNeeded(touches, with: event, phase: .moved) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if eyedropperLoupeView.isActive { return }
        if navigationGestureAdapter.handlePanTouchesIfNeeded(touches, with: event, phase: .ended) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
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

    private func updateShapePreview(
        stroke: Stroke?,
        style: PreviewStrokeStyle,
        currentTool: StudioToolKind,
        snapshot: MetalDocumentSnapshot?,
        geometry viewport: CanvasViewportGeometry
    ) {
        guard let stroke, currentTool == .shape, stroke.points.count >= 2 else {
            shapePreviewSurfaceView.update(surface: nil)
            return
        }
        guard let snapshot,
              let surface = previewRenderer.shapePreviewSurface(
                stroke: stroke,
                style: style,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height
              ) else {
            shapePreviewSurfaceView.update(surface: nil)
            return
        }
        shapePreviewSurfaceView.update(surface: surface)
        shapePreviewSurfaceView.frame = viewport.contentRect
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
        case 3:
            return SIMD4(Float(components[0]), Float(components[1]), Float(components[2]), Float(color.alpha))
        case 2:
            return SIMD4(Float(components[0]), Float(components[0]), Float(components[0]), Float(components[1]))
        default:
            return SIMD4(0, 0, 0, 1)
        }
    }
}
#endif
