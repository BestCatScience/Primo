#if canImport(UIKit)
import PrimoCanvasInputDomain
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
    private let shapePreviewLayer = CAShapeLayer()
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
        shapePreviewSurfaceView.isHidden = true
        layer.addSublayer(shapePreviewLayer)
        addSubview(selectionOverlayView)
        shapePreviewLayer.fillColor = UIColor.clear.cgColor
        shapePreviewLayer.lineCap = .round
        shapePreviewLayer.lineJoin = .round
        shapePreviewLayer.isHidden = true
        shapePreviewLayer.contentsScale = UIScreen.main.scale

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
        shapePreviewLayer.frame = bounds
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
        inputHandler.selectionContext = CanvasInputSelectionContext(state.selection)
        inputHandler.layerMoveContext = layerMoveContext(for: state)
        inputHandler.shapeMode = state.shapeMode
        inputHandler.eyedropperSamplingSource = state.eyedropperSamplingSource
        inputHandler.brushTipKind = state.previewStyle.tipKind
        inputHandler.brushSize = Float(state.previewStyle.radius * 2.0)
        inputHandler.brushColor = state.previewStyle.simdColor
        inputHandler.strokeStabilization = Float(state.previewStyle.stabilization)

        selectionOverlayView.update(
            selection: state.selection,
            previewPoints: state.selectionPreviewPoints,
            moveOffset: state.selectionMoveOffset,
            currentTool: state.currentTool,
            selectionMode: state.selectionMode,
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

    public func didBeginSelectionMove(at point: CGPoint) {
        actionSink?.send(.selectionMoveBegan(point))
    }

    public func didUpdateSelectionMove(offset: CGSize) {
        actionSink?.send(.selectionMoveUpdated(offset))
    }

    public func didEndSelectionMove(offset: CGSize) {
        actionSink?.send(.selectionMoveEnded(offset))
    }

    public func didCancelSelectionMove() {
        actionSink?.send(.selectionMoveCancelled)
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

    private func layerMoveContext(for state: CanvasPresentationState) -> CanvasInputLayerMoveContext? {
        guard state.selection == nil,
              let snapshot = state.snapshot,
              let layer = snapshot.layers.first(where: { $0.index == state.activeLayerIndex }),
              layer.visible
        else {
            return nil
        }
        return CanvasInputLayerMoveContext(
            bounds: CGRect(x: 0, y: 0, width: snapshot.width, height: snapshot.height),
            width: snapshot.width,
            height: snapshot.height,
            pixelData: layer.pixelData
        )
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
            shapePreviewLayer.path = nil
            shapePreviewLayer.isHidden = true
            return
        }
        guard snapshot != nil else {
            shapePreviewSurfaceView.update(surface: nil)
            shapePreviewLayer.path = nil
            shapePreviewLayer.isHidden = true
            return
        }
        shapePreviewSurfaceView.update(surface: nil)
        shapePreviewLayer.path = Self.shapePreviewPath(stroke: stroke, viewport: viewport)
        shapePreviewLayer.strokeColor = style.color.copy(alpha: Self.shapePreviewAlpha(style: style))
        shapePreviewLayer.lineWidth = Self.shapePreviewLineWidth(style: style, viewport: viewport)
        shapePreviewLayer.isHidden = false
        shapePreviewLayer.setNeedsDisplay()
    }

    private static func shapePreviewPath(stroke: Stroke, viewport: CanvasViewportGeometry) -> CGPath {
        let path = CGMutablePath()
        for (index, point) in stroke.points.enumerated() {
            let viewPoint = viewport.viewPoint(
                fromDocumentPoint: CGPoint(
                    x: CGFloat(point.position.x),
                    y: CGFloat(point.position.y)
                )
            )
            if index == 0 {
                path.move(to: viewPoint)
            } else {
                path.addLine(to: viewPoint)
            }
        }
        return path
    }

    private static func shapePreviewLineWidth(
        style: PreviewStrokeStyle,
        viewport: CanvasViewportGeometry
    ) -> CGFloat {
        guard viewport.documentSize.width > 0 else { return max(1, style.radius * 2.0) }
        let scale = viewport.contentRect.width / viewport.documentSize.width
        let textureWidthFactor: CGFloat
        switch style.tipKind {
        case .pencil:
            textureWidthFactor = 0.64
        case .airbrush:
            textureWidthFactor = 0.82
        case .oil, .ink:
            textureWidthFactor = 1.0
        }
        return max(1, style.radius * 2.0 * scale * textureWidthFactor)
    }

    private static func shapePreviewAlpha(style: PreviewStrokeStyle) -> CGFloat {
        let baseAlpha = style.color.alpha * style.opacity * style.flow
        let textureFactor: CGFloat
        switch style.tipKind {
        case .pencil:
            textureFactor = 0.22
        case .airbrush:
            textureFactor = 0.28
        case .oil:
            textureFactor = 0.56
        case .ink:
            textureFactor = 1.0
        }
        return max(0.025, min(1.0, baseAlpha * textureFactor))
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
