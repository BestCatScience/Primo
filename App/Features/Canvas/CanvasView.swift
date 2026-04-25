import ComposableArchitecture
import PrimoBrushFileFormats
import PrimoDocumentGPUContracts
import PrimoDocumentContracts
import PrimoDocumentDomain
import SwiftUI
import UIKit
import simd

struct CanvasView: UIViewRepresentable {
    @Dependency(\.documentGpuOperationGateway) var documentGpuOperationGateway

    let store: StoreOf<CanvasFeature>

    func makeUIView(context: Context) -> RasterCanvasContainerView {
        let view = RasterCanvasContainerView()
        view.sendAction = { store.send($0) }
        return view
    }

    func updateUIView(_ uiView: RasterCanvasContainerView, context: Context) {
        uiView.documentSize = store.canvasSize
        uiView.documentGpuOperationGateway = documentGpuOperationGateway
        uiView.update(
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

final class RasterCanvasContainerView: UIView, InputHandlerDelegate, UIPencilInteractionDelegate {
    var documentSize: CGSize = .zero
    var documentGpuOperationGateway: DocumentGpuOperationGateway? {
        didSet {
            transformPreviewView.documentGpuOperationGateway = documentGpuOperationGateway
        }
    }
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
    private let canvasImageRenderer = CanvasImageRenderer.live
    private let inputHandler = InputHandler()
    private lazy var selectionOverlayView = CanvasSelectionOverlayView(canvasImageRenderer: canvasImageRenderer)
    private lazy var transformPreviewView = CanvasTransformPreviewView(canvasImageRenderer: canvasImageRenderer)
    private lazy var textTransformOverlayView = CanvasTextTransformOverlayView(canvasImageRenderer: canvasImageRenderer)
    private lazy var eyedropperLoupeView = CanvasEyedropperLoupeView(canvasImageRenderer: canvasImageRenderer)
    private let navigationGestureAdapter = CanvasNavigationGestureAdapter()
    private let pencilToggleFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let pencilToggleNotificationFeedbackGenerator = UINotificationFeedbackGenerator()

    private var viewportOffset: CGSize = .zero
    private var zoomScale: CGFloat = 1.0
    private var currentTool: StudioToolKind = .brush

    override init(frame: CGRect) {
        super.init(frame: frame)
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

    func update(
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        activeStroke: Stroke?,
        incrementalUpdate: IncrementalLayerUpdate?,
        adjustmentPreviewPixelData: Data?,
        paperStyle: CanvasPaperStyle,
        previewStyle: PreviewStrokeStyle,
        currentTool: StudioToolKind,
        selectionMode: SelectionToolMode,
        shapeMode: ShapeToolMode,
        eyedropperSamplingSource: EyedropperSamplingSource,
        selection: CanvasSelection?,
        selectionPreviewPoints: [CGPoint],
        transformPreviewOffset: CGSize,
        transformPreviewScaleX: CGFloat,
        transformPreviewScaleY: CGFloat,
        transformPreviewRotationDegrees: Double,
        transformPivot: CGPoint?,
        transformMode: CanvasTransformMode,
        transformLocksAspectRatio: Bool,
        transformQuadOffsets: TransformQuadOffsets,
        activeTextLayer: TextLayerData?,
        viewportOffset: CGSize,
        zoomScale: CGFloat,
        previewResetNonce: Int
    ) {
        self.currentTool = currentTool
        self.viewportOffset = viewportOffset
        self.zoomScale = zoomScale

        let geometry = viewportGeometry
        canvasRenderSurfaceView.render(
            RenderFrameUpdate(
                snapshot: snapshot,
                activeLayerIndex: activeLayerIndex,
                incrementalUpdate: incrementalUpdate,
                documentSize: documentSize,
                viewportOffset: viewportOffset,
                zoomScale: zoomScale,
                paperStyle: paperStyle,
                previewResetNonce: previewResetNonce
            )
        )

        inputHandler.tool = currentTool
        inputHandler.selectionMode = selectionMode
        inputHandler.shapeMode = shapeMode
        inputHandler.eyedropperSamplingSource = eyedropperSamplingSource
        inputHandler.brushTipKind = previewStyle.tipKind
        inputHandler.brushSize = Float(previewStyle.radius * 2.0)
        inputHandler.brushColor = previewStyle.simdColor
        inputHandler.strokeStabilization = Float(previewStyle.stabilization)

        let shouldHideMoveOverlay = currentTool == .move && (
            abs(transformPreviewRotationDegrees) > 0.001 ||
            abs(transformPreviewScaleX - 1.0) > 0.001 ||
            abs(transformPreviewScaleY - 1.0) > 0.001
        )
        selectionOverlayView.update(
            selection: selection,
            previewPoints: selectionPreviewPoints,
            currentTool: currentTool,
            geometry: geometry,
            transformQuad: currentTool == .move
                ? { rect in
                    AppFeature.effectiveTransformQuad(
                        bounds: rect,
                        translation: transformPreviewOffset,
                        scaleX: transformPreviewScaleX,
                        scaleY: transformPreviewScaleY,
                        rotationDegrees: transformPreviewRotationDegrees,
                        pivot: transformPivot,
                        mode: transformMode,
                        quadOffsets: transformQuadOffsets
                    ).effective
                }
                : nil,
            hidesTransformedOverlayImage: shouldHideMoveOverlay
        )

        transformPreviewView.update(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            activeStroke: activeStroke,
            strokePreviewCompositePixelData: nil,
            adjustmentPreviewPixelData: adjustmentPreviewPixelData,
            selection: selection,
            paperStyle: paperStyle,
            previewStyle: previewStyle,
            currentTool: currentTool,
            transformPreviewOffset: transformPreviewOffset,
            transformPreviewScaleX: transformPreviewScaleX,
            transformPreviewScaleY: transformPreviewScaleY,
            transformPreviewRotationDegrees: transformPreviewRotationDegrees,
            transformPivot: transformPivot,
            transformMode: transformMode,
            transformQuadOffsets: transformQuadOffsets,
            activeTextLayer: activeTextLayer,
            geometry: geometry,
            renderSurfaceView: canvasRenderSurfaceView
        )

        textTransformOverlayView.update(
            context: CanvasTextTransformOverlayView.Context(
                snapshot: snapshot,
                activeLayerIndex: activeLayerIndex,
                currentTool: currentTool,
                selection: selection,
                transformPreviewOffset: transformPreviewOffset,
                transformPreviewScaleX: transformPreviewScaleX,
                transformPreviewScaleY: transformPreviewScaleY,
                transformPreviewRotationDegrees: transformPreviewRotationDegrees,
                transformPivot: transformPivot,
                transformMode: transformMode,
                transformLocksAspectRatio: transformLocksAspectRatio,
                transformQuadOffsets: transformQuadOffsets,
                activeTextLayer: activeTextLayer,
                geometry: geometry
            )
        )

        eyedropperLoupeView.update(
            context: CanvasEyedropperLoupeView.Context(
                snapshot: snapshot,
                activeLayerIndex: activeLayerIndex,
                paperStyle: paperStyle,
                source: eyedropperSamplingSource,
                geometry: geometry,
                shouldBlockSampling: { [weak self] point in
                    self?.textTransformOverlayView.containsInteractivePoint(point) ?? false
                }
            )
        )

        navigationGestureAdapter.update(
            context: CanvasNavigationGestureAdapter.Context(
                currentTool: currentTool,
                transformMode: transformMode,
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
