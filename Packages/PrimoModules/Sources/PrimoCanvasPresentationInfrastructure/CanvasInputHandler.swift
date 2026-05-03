#if canImport(UIKit)
import CoreGraphics
import Foundation
import PrimoBrushDomain
import PrimoCanvasInputDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain
import UIKit
import simd

@MainActor
public protocol CanvasInputHandlingDelegate: AnyObject {
    func didUpdateStroke(_ stroke: Stroke)
    func didEndStroke(_ stroke: Stroke)
    func didCancelStroke()
    func didRequestFill(at sample: StylusSample)
    func didRequestColorSample(at sample: StylusSample)
    func didUpdateSelectionPath(_ points: [CGPoint])
    func didEndSelectionPath(_ points: [CGPoint])
    func didBeginSelectionMove(at point: CGPoint)
    func didUpdateSelectionMove(offset: CGSize)
    func didEndSelectionMove(offset: CGSize)
    func didCancelSelectionMove()
    func didRequestAutoSelection(at sample: StylusSample)
    func didRequestTextPlacement(at point: CGPoint)
}

@MainActor
public final class CanvasInputHandler {
    public weak var delegate: CanvasInputHandlingDelegate?

    public var tool: StudioToolKind = .brush
    public var selectionMode: SelectionToolMode = .lasso
    public var selectionContext: CanvasInputSelectionContext?
    public var layerMoveContext: CanvasInputLayerMoveContext?
    public var shapeMode: ShapeToolMode = .line
    public var eyedropperSamplingSource: EyedropperSamplingSource = .activeLayer
    public var brushTipKind: BrushTipKind = .pencil
    public var brushColor: SIMD4<Float> = SIMD4(0, 0, 0, 1)
    public var brushSize: Float = 4.0
    public var strokeStabilization: Float = 0.5
    public var allowsFingerTouchInput = false
    public var pointMapper: ((CGPoint, UIView) -> SIMD2<Float>)?

    private let inputReducer = CanvasInputReducer()
    private var inputState = CanvasInputReducer.State()
    private var activeTouch: UITouch?

    public init() {}

    public func handleTouches(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        guard let touch = touchForCurrentInput(from: touches) else { return }
        guard let phase = CanvasInputTouchPhase(touch.phase) else { return }

        if !isAllowedInputTouch(touch) {
            cancelActiveInput(with: touch, in: view)
            return
        }

        if shouldDeferToNavigationGesture(for: touch, touches: touches, event: event) {
            cancelActiveInput(with: touch, in: view)
            return
        }

        if phase == .began {
            activeTouch = touch
        }

        let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
        let predictedTouches = event?.predictedTouches(for: touch) ?? []
        let commands = inputReducer.reduce(
            phase: phase,
            sample: makeInputSample(touch, in: view),
            coalescedSamples: coalescedTouches.map { makeInputSample($0, in: view) },
            predictedSamples: predictedTouches.map { makeInputSample($0, in: view) },
            state: &inputState,
            configuration: CanvasInputConfiguration(
                tool: CanvasInputToolKind(tool),
                selectionMode: selectionMode,
                selectionContext: selectionContext,
                layerMoveContext: layerMoveContext,
                shapeMode: shapeMode,
                brushTipKind: brushTipKind,
                brushColor: brushColor,
                brushSize: brushSize,
                strokeStabilization: strokeStabilization
            )
        )
        dispatch(commands)

        if phase == .ended || phase == .cancelled {
            activeTouch = nil
        }
    }

    private func touchForCurrentInput(from touches: Set<UITouch>) -> UITouch? {
        if let activeTouch, touches.contains(where: { $0 === activeTouch }) {
            return activeTouch
        }
        guard activeTouch == nil else { return nil }
        return touches.first(where: isAllowedInputTouch)
    }

    private func isAllowedInputTouch(_ touch: UITouch) -> Bool {
        if tool == .select || tool == .move {
            return true
        }
        return allowsFingerTouchInput || touch.type != .direct
    }

    private func shouldDeferToNavigationGesture(for touch: UITouch, touches: Set<UITouch>, event: UIEvent?) -> Bool {
        guard touch.type != .pencil else { return false }
        let touchCount = event?.allTouches?.count ?? touches.count
        return touchCount > 1
    }

    private func cancelActiveInput(with touch: UITouch, in view: UIView) {
        guard activeTouch != nil else { return }
        let commands = inputReducer.reduce(
            phase: .cancelled,
            sample: makeInputSample(touch, in: view),
            coalescedSamples: [makeInputSample(touch, in: view)],
            state: &inputState,
            configuration: CanvasInputConfiguration(
                tool: CanvasInputToolKind(tool),
                selectionMode: selectionMode,
                selectionContext: selectionContext,
                layerMoveContext: layerMoveContext,
                shapeMode: shapeMode,
                brushTipKind: brushTipKind,
                brushColor: brushColor,
                brushSize: brushSize,
                strokeStabilization: strokeStabilization
            )
        )
        activeTouch = nil
        dispatch(commands)
    }

    private func dispatch(_ commands: [CanvasInputCommand]) {
        for command in commands {
            switch command {
            case let .updateStroke(stroke):
                delegate?.didUpdateStroke(Stroke(stroke))
            case let .endStroke(stroke):
                delegate?.didEndStroke(Stroke(stroke))
            case .cancelStroke:
                delegate?.didCancelStroke()
            case let .requestFill(sample):
                delegate?.didRequestFill(at: sample)
            case let .requestColorSample(sample):
                delegate?.didRequestColorSample(at: sample)
            case let .updateSelectionPath(points):
                delegate?.didUpdateSelectionPath(points)
            case let .endSelectionPath(points):
                delegate?.didEndSelectionPath(points)
            case let .beginSelectionMove(point):
                delegate?.didBeginSelectionMove(at: point)
            case let .updateSelectionMove(offset):
                delegate?.didUpdateSelectionMove(offset: offset)
            case let .endSelectionMove(offset):
                delegate?.didEndSelectionMove(offset: offset)
            case .cancelSelectionMove:
                delegate?.didCancelSelectionMove()
            case let .requestAutoSelection(sample):
                delegate?.didRequestAutoSelection(at: sample)
            case let .requestTextPlacement(point):
                delegate?.didRequestTextPlacement(at: point)
            }
        }
    }

    private func makeInputSample(_ touch: UITouch, in view: UIView) -> CanvasInputSample {
        let location = touch.preciseLocation(in: view)
        let mappedPosition = pointMapper?(location, view) ?? SIMD2(Float(location.x), Float(location.y))
        return CanvasInputSample(
            point: CGPoint(x: CGFloat(mappedPosition.x), y: CGFloat(mappedPosition.y)),
            pressure: normalizedPressure(for: touch),
            altitude: Float(touch.altitudeAngle),
            azimuth: Float(touch.azimuthAngle(in: view)),
            timestamp: touch.timestamp
        )
    }

    private func normalizedPressure(for touch: UITouch) -> Float {
        guard touch.type == .pencil || touch.maximumPossibleForce > 0 else { return 0.65 }
        guard touch.maximumPossibleForce > 0 else { return 0.65 }
        let normalized = Float(touch.force / touch.maximumPossibleForce)
        return max(0.08, min(normalized, 1.0))
    }
}

private extension CanvasInputTouchPhase {
    init?(_ phase: UITouch.Phase) {
        switch phase {
        case .began:
            self = .began
        case .moved:
            self = .moved
        case .stationary:
            self = .stationary
        case .ended:
            self = .ended
        case .cancelled:
            self = .cancelled
        @unknown default:
            return nil
        }
    }
}

private extension CanvasInputToolKind {
    init(_ tool: StudioToolKind) {
        switch tool {
        case .brush:
            self = .brush
        case .erase:
            self = .erase
        case .blur:
            self = .blur
        case .fill:
            self = .fill
        case .eyedropper:
            self = .eyedropper
        case .move:
            self = .move
        case .select:
            self = .select
        case .shape:
            self = .shape
        case .text:
            self = .text
        }
    }
}

private extension Stroke {
    init(_ stroke: CanvasInputStroke) {
        self.init(
            points: stroke.points.map(StrokePoint.init(_:)),
            predictedPoints: stroke.predictedPoints.map(StrokePoint.init(_:)),
            color: stroke.color,
            brushSize: stroke.brushSize
        )
    }
}

private extension StrokePoint {
    init(_ point: CanvasStrokePoint) {
        self.init(
            position: point.position,
            pressure: point.pressure,
            altitude: point.altitude,
            azimuth: point.azimuth,
            timestamp: point.timestamp,
            isPredicted: point.isPredicted
        )
    }
}
#endif
