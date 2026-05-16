#if canImport(UIKit)
import PrimoCanvasPresentationDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain
import QuartzCore
import UIKit

@MainActor
final class CanvasNavigationGestureAdapter: NSObject, UIGestureRecognizerDelegate {
    private weak var hostView: UIView?
    private var context: Context?
    private var panStartLocation: CGPoint?
    private var panStartOffset: CGSize = .zero
    private var panDidMove = false
    private var isCanvasPanGestureActive = false
    private var pinchStartScale: CGFloat = 1.0
    private var pinchAnchorDocumentPoint: CGPoint?
    private var isPinchGestureActive = false
    private var lastNavigationGestureEndedAt: CFTimeInterval = 0

    var actionSink: CanvasPresentationActionSink?
    var shouldAllowSimultaneousRecognition: ((UIGestureRecognizer, UIGestureRecognizer) -> Bool)?
    var shouldReceiveTouch: ((UIGestureRecognizer, UITouch) -> Bool)?

    func install(on hostView: UIView) {
        self.hostView = hostView

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchRecognizer.delegate = self
        pinchRecognizer.cancelsTouchesInView = false
        hostView.addGestureRecognizer(pinchRecognizer)

        let rotationRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotationRecognizer.delegate = self
        rotationRecognizer.cancelsTouchesInView = false
        hostView.addGestureRecognizer(rotationRecognizer)

        let undoTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerUndoTap(_:)))
        undoTapRecognizer.numberOfTouchesRequired = 2
        undoTapRecognizer.numberOfTapsRequired = 1
        undoTapRecognizer.cancelsTouchesInView = false
        undoTapRecognizer.delegate = self
        undoTapRecognizer.require(toFail: pinchRecognizer)
        hostView.addGestureRecognizer(undoTapRecognizer)

        let redoTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleThreeFingerRedoTap(_:)))
        redoTapRecognizer.numberOfTouchesRequired = 3
        redoTapRecognizer.numberOfTapsRequired = 1
        redoTapRecognizer.cancelsTouchesInView = false
        redoTapRecognizer.delegate = self
        redoTapRecognizer.require(toFail: pinchRecognizer)
        hostView.addGestureRecognizer(redoTapRecognizer)
    }

    func update(context: Context) {
        self.context = context
    }

    func cancelPan() {
        panStartLocation = nil
        panDidMove = false
        isCanvasPanGestureActive = false
    }

    func handlePanTouchesIfNeeded(_ touches: Set<UITouch>, with event: UIEvent?, phase: PanPhase) -> Bool {
        guard let context, let hostView else { return false }
        guard context.currentTool != .select, context.currentTool != .move else { return false }
        guard let touch = touches.first, touch.type != .pencil else {
            if phase == .ended || phase == .cancelled {
                cancelPan()
            }
            return false
        }

        let nonPencilTouchCount = event?.allTouches?.filter { $0.type != .pencil }.count ?? 1
        if isPinchGestureActive || nonPencilTouchCount > 1 {
            if phase == .ended || phase == .cancelled {
                cancelPan()
            }
            return false
        }

        let location = touch.preciseLocation(in: hostView)
        switch phase {
        case .began:
            panStartLocation = location
            panStartOffset = context.geometry.viewportOffset
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
            actionSink?.send(.viewportOffsetChanged(context.geometry.clampedViewportOffset(nextOffset)))
        case .ended, .cancelled:
            if panDidMove {
                lastNavigationGestureEndedAt = CACurrentMediaTime()
            }
            cancelPan()
        }
        return true
    }

    private func shouldSuppressHistoryTap() -> Bool {
        if isPinchGestureActive || isCanvasPanGestureActive || pinchAnchorDocumentPoint != nil {
            return true
        }
        return (CACurrentMediaTime() - lastNavigationGestureEndedAt) < 0.22
    }

    @objc
    private func handleTwoFingerUndoTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard !shouldSuppressHistoryTap() else { return }
        actionSink?.send(.requestLocalUndo)
    }

    @objc
    private func handleThreeFingerRedoTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard !shouldSuppressHistoryTap() else { return }
        actionSink?.send(.requestLocalRedo)
    }

    @objc
    private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let context, context.geometry.documentSize.width > 0, context.geometry.documentSize.height > 0 else { return }

        let location = recognizer.location(in: hostView)
        switch recognizer.state {
        case .began:
            isPinchGestureActive = true
            pinchStartScale = context.geometry.zoomScale
            pinchAnchorDocumentPoint = context.geometry.documentPoint(fromViewPoint: location)

        case .changed:
            guard let pinchAnchorDocumentPoint else { return }
            let newScale = min(max(pinchStartScale * recognizer.scale, 0.6), 4.0)
            let newOffset = context.geometry.offsetKeepingDocumentPointStable(
                pinchAnchorDocumentPoint,
                at: location,
                zoomScale: newScale
            )
            actionSink?.send(.zoomScaleChanged(newScale))
            actionSink?.send(.viewportOffsetChanged(newOffset))

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

    @objc
    private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        return
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        shouldAllowSimultaneousRecognition?(gestureRecognizer, otherGestureRecognizer) ?? true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        shouldReceiveTouch?(gestureRecognizer, touch) ?? true
    }
}

extension CanvasNavigationGestureAdapter {
    enum PanPhase {
        case began
        case moved
        case ended
        case cancelled
    }

    struct Context {
        let currentTool: StudioToolKind
        let geometry: CanvasViewportGeometry
    }
}
#endif
