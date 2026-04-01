import AVFoundation
import ComposableArchitecture
import QuartzCore
import SwiftUI
import UIKit
import simd

struct CanvasView: UIViewRepresentable {
    let store: StoreOf<CanvasFeature>

    func makeUIView(context: Context) -> RasterCanvasContainerView {
        let view = RasterCanvasContainerView()
        view.sendAction = { store.send($0) }
        return view
    }

    func updateUIView(_ uiView: RasterCanvasContainerView, context: Context) {
        uiView.documentSize = store.canvasSize
        uiView.update(
            snapshot: store.renderSnapshot,
            incrementalUpdate: store.pendingIncrementalUpdate,
            previewStyle: store.previewStyle,
            currentTool: store.currentTool,
            viewportOffset: store.viewportOffset,
            zoomScale: store.zoomScale,
        )
    }
}

final class RasterCanvasContainerView: UIView, InputHandlerDelegate, UIGestureRecognizerDelegate {
    var documentSize: CGSize = .zero
    var sendAction: ((CanvasFeature.Action) -> Void)?

    private let metalCanvasView = MetalCanvasView()
    private let inputHandler = InputHandler()

    private var viewportOffset: CGSize = .zero
    private var zoomScale: CGFloat = 1.0
    private var currentTool: StudioToolKind = .brush
    private var panStartLocation: CGPoint?
    private var panStartOffset: CGSize = .zero
    private var panDidMove = false
    private var isCanvasPanGestureActive = false
    private var pinchStartScale: CGFloat = 1.0
    private var pinchAnchorDocumentPoint: CGPoint?
    private var isPinchGestureActive = false
    private var lastNavigationGestureEndedAt: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
        isMultipleTouchEnabled = true
        clipsToBounds = true

        inputHandler.delegate = self
        inputHandler.pointMapper = { [weak self] location, view in
            guard let self else { return SIMD2(Float(location.x), Float(location.y)) }
            let point = self.canvasPoint(from: location, in: view)
            return SIMD2(Float(point.x), Float(point.y))
        }

        metalCanvasView.isUserInteractionEnabled = false
        addSubview(metalCanvasView)

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchRecognizer.delegate = self
        pinchRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(pinchRecognizer)

        let undoTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerUndoTap(_:)))
        undoTapRecognizer.numberOfTouchesRequired = 2
        undoTapRecognizer.numberOfTapsRequired = 1
        undoTapRecognizer.cancelsTouchesInView = false
        undoTapRecognizer.delegate = self
        undoTapRecognizer.require(toFail: pinchRecognizer)
        addGestureRecognizer(undoTapRecognizer)

        let redoTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleThreeFingerRedoTap(_:)))
        redoTapRecognizer.numberOfTouchesRequired = 3
        redoTapRecognizer.numberOfTapsRequired = 1
        redoTapRecognizer.cancelsTouchesInView = false
        redoTapRecognizer.delegate = self
        redoTapRecognizer.require(toFail: pinchRecognizer)
        addGestureRecognizer(redoTapRecognizer)

        addInteraction(UIPencilInteraction())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        metalCanvasView.frame = bounds
    }

    func update(
        snapshot: MetalDocumentSnapshot?,
        incrementalUpdate: IncrementalLayerUpdate?,
        previewStyle: PreviewStrokeStyle,
        currentTool: StudioToolKind,
        viewportOffset: CGSize,
        zoomScale: CGFloat
    ) {
        self.currentTool = currentTool
        self.viewportOffset = viewportOffset
        self.zoomScale = zoomScale
        metalCanvasView.updateDocumentSize(documentSize)
        metalCanvasView.update(snapshot: snapshot, viewportOffset: viewportOffset, zoomScale: zoomScale)
        if let incrementalUpdate {
            metalCanvasView.applyIncrementalUpdate(incrementalUpdate)
        }
        inputHandler.tool = currentTool
        inputHandler.brushSize = Float(previewStyle.radius * 2.0)
        inputHandler.brushColor = previewStyle.simdColor
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, phase: .began) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, phase: .moved) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, phase: .ended) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, phase: .cancelled) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    func didUpdateStroke(_ stroke: Stroke) {
        sendAction?(.strokeUpdated(stroke))
    }

    func didEndStroke(_ stroke: Stroke) {
        sendAction?(.strokeEnded(stroke))
    }

    private func canvasPoint(from location: CGPoint, in view: UIView) -> CGPoint {
        let fitted = contentRect()
        guard fitted.width > 0, fitted.height > 0, documentSize.width > 0, documentSize.height > 0 else { return .zero }

        let local = convert(location, from: view)
        let x = ((local.x - fitted.minX) / fitted.width) * documentSize.width
        let y = ((local.y - fitted.minY) / fitted.height) * documentSize.height
        return CGPoint(
            x: min(max(0, x), documentSize.width - 1),
            y: min(max(0, y), documentSize.height - 1)
        )
    }

    private func contentRect() -> CGRect {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let fittedRect = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledSize = CGSize(width: fittedRect.width * zoomScale, height: fittedRect.height * zoomScale)
        return CGRect(
            x: fittedRect.midX - (scaledSize.width / 2) + viewportOffset.width,
            y: fittedRect.midY - (scaledSize.height / 2) + viewportOffset.height,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }

    private enum PanPhase {
        case began
        case moved
        case ended
        case cancelled
    }

    private func handlePanTouchesIfNeeded(_ touches: Set<UITouch>, phase: PanPhase) -> Bool {
        guard currentTool == .move, let touch = touches.first else {
            if phase == .ended || phase == .cancelled {
                panStartLocation = nil
                panDidMove = false
                isCanvasPanGestureActive = false
            }
            return false
        }

        let location = touch.preciseLocation(in: self)
        switch phase {
        case .began:
            panStartLocation = location
            panStartOffset = viewportOffset
            panDidMove = false
            isCanvasPanGestureActive = true
        case .moved:
            guard let panStartLocation else { return true }
            let deltaX = location.x - panStartLocation.x
            let deltaY = location.y - panStartLocation.y
            if hypot(deltaX, deltaY) > 3.0 {
                panDidMove = true
            }
            let nextOffset = CGSize(
                width: panStartOffset.width + deltaX,
                height: panStartOffset.height + deltaY
            )
            let clampedOffset = clampedViewportOffset(nextOffset)
            sendAction?(.viewportOffsetChanged(clampedOffset))
        case .ended, .cancelled:
            if panDidMove {
                lastNavigationGestureEndedAt = CACurrentMediaTime()
            }
            panStartLocation = nil
            panDidMove = false
            isCanvasPanGestureActive = false
        }
        return true
    }

    private func shouldSuppressHistoryTap() -> Bool {
        if isPinchGestureActive || isCanvasPanGestureActive || pinchAnchorDocumentPoint != nil {
            return true
        }
        return (CACurrentMediaTime() - lastNavigationGestureEndedAt) < 0.22
    }

    private func clampedViewportOffset(_ proposedOffset: CGSize) -> CGSize {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        let fitted = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledWidth = fitted.width * zoomScale
        let scaledHeight = fitted.height * zoomScale
        let horizontalLimit = max(0, (scaledWidth - drawableRect.width) / 2 + 120)
        let verticalLimit = max(0, (scaledHeight - drawableRect.height) / 2 + 120)
        return CGSize(
            width: min(max(proposedOffset.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposedOffset.height, -verticalLimit), verticalLimit)
        )
    }

    @objc
    private func handleTwoFingerUndoTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard !shouldSuppressHistoryTap() else { return }
        sendAction?(.requestLocalUndo)
    }

    @objc
    private func handleThreeFingerRedoTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard !shouldSuppressHistoryTap() else { return }
        sendAction?(.requestLocalRedo)
    }

    @objc
    private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard documentSize.width > 0, documentSize.height > 0 else { return }

        let location = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            isPinchGestureActive = true
            pinchStartScale = zoomScale
            pinchAnchorDocumentPoint = documentPoint(at: location, in: contentRect())

        case .changed:
            guard let pinchAnchorDocumentPoint else { return }
            let newScale = min(max(pinchStartScale * recognizer.scale, 0.6), 4.0)
            let newOffset = offsetKeepingDocumentPointStable(
                pinchAnchorDocumentPoint,
                at: location,
                zoomScale: newScale
            )
            sendAction?(.zoomScaleChanged(newScale))
            sendAction?(.viewportOffsetChanged(newOffset))

        case .ended, .cancelled, .failed:
            if isPinchGestureActive {
                lastNavigationGestureEndedAt = CACurrentMediaTime()
            }
            isPinchGestureActive = false
            pinchAnchorDocumentPoint = nil

        default:
            break
        }
    }

    private func documentPoint(at viewPoint: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: ((viewPoint.x - rect.minX) / max(rect.width, 1)) * documentSize.width,
            y: ((viewPoint.y - rect.minY) / max(rect.height, 1)) * documentSize.height
        )
    }

    private func offsetKeepingDocumentPointStable(_ documentPoint: CGPoint, at viewPoint: CGPoint, zoomScale: CGFloat) -> CGSize {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        let fittedRect = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledSize = CGSize(width: fittedRect.width * zoomScale, height: fittedRect.height * zoomScale)
        let normalizedX = documentPoint.x / max(documentSize.width, 1)
        let normalizedY = documentPoint.y / max(documentSize.height, 1)
        let desiredOrigin = CGPoint(
            x: viewPoint.x - (normalizedX * scaledSize.width),
            y: viewPoint.y - (normalizedY * scaledSize.height)
        )
        let baseOrigin = CGPoint(
            x: fittedRect.midX - (scaledSize.width / 2),
            y: fittedRect.midY - (scaledSize.height / 2)
        )
        return clampedViewportOffset(
            CGSize(width: desiredOrigin.x - baseOrigin.x, height: desiredOrigin.y - baseOrigin.y),
            zoomScale: zoomScale
        )
    }

    private func clampedViewportOffset(_ proposedOffset: CGSize, zoomScale: CGFloat) -> CGSize {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        let fitted = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledWidth = fitted.width * zoomScale
        let scaledHeight = fitted.height * zoomScale
        let horizontalLimit = max(0, (scaledWidth - drawableRect.width) / 2 + 120)
        let verticalLimit = max(0, (scaledHeight - drawableRect.height) / 2 + 120)
        return CGSize(
            width: min(max(proposedOffset.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposedOffset.height, -verticalLimit), verticalLimit)
        )
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
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
