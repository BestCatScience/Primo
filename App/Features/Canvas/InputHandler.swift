import PrimoBrushDomain
import PrimoCanvasInputDomain
import PrimoDocumentContracts
import PrimoDocumentDomain
import UIKit
import simd

protocol InputHandlerDelegate: AnyObject {
    func didUpdateStroke(_ stroke: Stroke)
    func didEndStroke(_ stroke: Stroke)
    func didCancelStroke()
    func didRequestFill(at sample: StylusSample)
    func didRequestColorSample(at sample: StylusSample)
    func didUpdateSelectionPath(_ points: [CGPoint])
    func didEndSelectionPath(_ points: [CGPoint])
    func didRequestAutoSelection(at sample: StylusSample)
    func didRequestTextPlacement(at point: CGPoint)
    func didBeginTransform()
    func didUpdateTransform(translation: CGSize)
    func didEndTransform(translation: CGSize)
}

final class InputHandler {
    weak var delegate: InputHandlerDelegate?

    var tool: StudioToolKind = .brush
    var selectionMode: SelectionToolMode = .lasso
    var shapeMode: ShapeToolMode = .line
    var eyedropperSamplingSource: EyedropperSamplingSource = .activeLayer
    var brushTipKind: BrushTipKind = .pencil
    var brushColor: SIMD4<Float> = SIMD4(0, 0, 0, 1)
    var brushSize: Float = 4.0
    var strokeStabilization: Float = 0.0
    var pointMapper: ((CGPoint, UIView) -> SIMD2<Float>)?

    private let inputReducer = CanvasInputReducer()
    private var inputState = CanvasInputReducer.State()
    private var currentStroke: Stroke?
    private var shapeStartPoint: StrokePoint?
    private var currentSelectionPoints: [CGPoint] = []
    private var transformStartPoint: CGPoint?

    func handleTouches(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        guard let touch = touches.first,
              (touch.type == .pencil || tool == .text) else { return }

        guard let phase = CanvasInputTouchPhase(touch.phase) else { return }
        let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
        let commands = inputReducer.reduce(
            phase: phase,
            sample: makeInputSample(touch, in: view),
            coalescedSamples: coalescedTouches.map { makeInputSample($0, in: view) },
            state: &inputState,
            configuration: CanvasInputConfiguration(
                tool: CanvasInputToolKind(tool),
                selectionMode: selectionMode,
                shapeMode: shapeMode,
                brushTipKind: brushTipKind,
                brushColor: brushColor,
                brushSize: brushSize,
                strokeStabilization: strokeStabilization
            )
        )
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
            case let .requestAutoSelection(sample):
                delegate?.didRequestAutoSelection(at: sample)
            case let .requestTextPlacement(point):
                delegate?.didRequestTextPlacement(at: point)
            case .beginTransform:
                delegate?.didBeginTransform()
            case let .updateTransform(translation):
                delegate?.didUpdateTransform(translation: translation)
            case let .endTransform(translation):
                delegate?.didEndTransform(translation: translation)
            }
        }
    }

    private func handleSelectionTouches(_ touch: UITouch, with event: UIEvent?, in view: UIView) {
        if selectionMode == .auto {
            guard touch.phase == .began else { return }
            delegate?.didRequestAutoSelection(at: makePoint(touch, in: view, predicted: false).stylusSample)
            currentSelectionPoints.removeAll()
            return
        }

        switch touch.phase {
        case .began:
            currentSelectionPoints = [makePoint(touch, in: view, predicted: false).cgPoint]
            delegate?.didUpdateSelectionPath(currentSelectionPoints)

        case .moved, .stationary:
            let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
            for candidateTouch in coalescedTouches {
                let point = makePoint(candidateTouch, in: view, predicted: false).cgPoint
                guard shouldAppendSelectionPoint(point) else { continue }
                currentSelectionPoints.append(point)
            }
            delegate?.didUpdateSelectionPath(currentSelectionPoints)

        case .ended, .cancelled:
            let finishingTouches = event?.coalescedTouches(for: touch) ?? [touch]
            for candidateTouch in finishingTouches {
                let point = makePoint(candidateTouch, in: view, predicted: false).cgPoint
                guard shouldAppendSelectionPoint(point) else { continue }
                currentSelectionPoints.append(point)
            }
            delegate?.didEndSelectionPath(currentSelectionPoints)
            currentSelectionPoints.removeAll()

        default:
            break
        }
    }

    private func shouldAppendSelectionPoint(_ point: CGPoint) -> Bool {
        guard let previous = currentSelectionPoints.last else { return true }
        return hypot(point.x - previous.x, point.y - previous.y) >= 2.0
    }

    private func handleTransformTouches(_ touch: UITouch, in view: UIView) {
        let point = makePoint(touch, in: view, predicted: false).cgPoint
        switch touch.phase {
        case .began:
            transformStartPoint = point
            delegate?.didBeginTransform()
            delegate?.didUpdateTransform(translation: .zero)

        case .moved, .stationary:
            guard let transformStartPoint else { return }
            delegate?.didUpdateTransform(
                translation: CGSize(
                    width: point.x - transformStartPoint.x,
                    height: point.y - transformStartPoint.y
                )
            )

        case .ended, .cancelled:
            guard let transformStartPoint else { return }
            delegate?.didEndTransform(
                translation: CGSize(
                    width: point.x - transformStartPoint.x,
                    height: point.y - transformStartPoint.y
                )
            )
            self.transformStartPoint = nil

        default:
            break
        }
    }

    private func makePoint(_ touch: UITouch, in view: UIView, predicted: Bool) -> StrokePoint {
        let location = touch.preciseLocation(in: view)
        let mappedPosition = pointMapper?(location, view) ?? SIMD2(Float(location.x), Float(location.y))
        let pressure = normalizedPressure(for: touch)

        return StrokePoint(
            position: mappedPosition,
            pressure: pressure,
            altitude: Float(touch.altitudeAngle),
            azimuth: Float(touch.azimuthAngle(in: view)),
            timestamp: touch.timestamp,
            isPredicted: predicted
        )
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

    private func appendFilteredPoints(from touches: [UITouch], to stroke: inout Stroke, in view: UIView, isFinishingStroke: Bool) {
        for touch in touches {
            var candidate = makePoint(touch, in: view, predicted: false)
            guard let previous = stroke.points.last else {
                stroke.points.append(candidate)
                continue
            }

            if candidate.pressure <= 0.001 {
                candidate.pressure = max(previous.pressure * 0.92, 0.12)
            }

            let delta = candidate.position - previous.position
            let distance = simd_length(delta)

            if !isFinishingStroke && distance <= duplicateSampleDistanceThreshold {
                stroke.points[stroke.points.count - 1] = StrokePoint(
                    position: previous.position,
                    pressure: candidate.pressure,
                    altitude: candidate.altitude,
                    azimuth: candidate.azimuth,
                    timestamp: candidate.timestamp,
                    isPredicted: false
                )
                continue
            }

            if isFinishingStroke && shouldRejectFinishingJump(candidate, previous: previous, distance: distance) {
                continue
            }

            let interpolationSpacing = preferredInterpolationSpacing(
                from: previous,
                to: candidate,
                distance: distance
            )
            if distance > interpolationSpacing {
                let steps = max(1, Int(ceil(distance / interpolationSpacing)))
                for step in 1...steps {
                    let t = Float(step) / Float(steps)
                    stroke.points.append(
                        StrokePoint(
                            position: previous.position + (delta * t),
                            pressure: previous.pressure + ((candidate.pressure - previous.pressure) * t),
                            altitude: previous.altitude + ((candidate.altitude - previous.altitude) * t),
                            azimuth: previous.azimuth + ((candidate.azimuth - previous.azimuth) * t),
                            timestamp: previous.timestamp + Double(Float(candidate.timestamp - previous.timestamp) * t),
                            isPredicted: false
                        )
                    )
                }
            } else {
                stroke.points.append(candidate)
            }
        }
    }

    private func shouldRejectFinishingJump(_ candidate: StrokePoint, previous: StrokePoint, distance: Float) -> Bool {
        // Lift-off samples can occasionally jump away from the nib while pressure drops rapidly.
        // Reject those trailing points to keep ink anchored under the pencil tip.
        let jumpThreshold = min(max(brushSize * 1.15, 10.0), 72.0)
        let pressureDropThreshold = max(0.08, previous.pressure * 0.72)
        let isPressureDropJump = distance > jumpThreshold && candidate.pressure < pressureDropThreshold
        let isExtremeJump = distance > jumpThreshold * 2.0
        return isPressureDropJump || isExtremeJump
    }

    private func preferredInterpolationSpacing(from previous: StrokePoint, to candidate: StrokePoint, distance: Float) -> Float {
        let normalizedBrushSize = max(brushSize, 1.0)
        let adaptiveSpacingFactor: Float
        switch normalizedBrushSize {
        case ..<24:
            adaptiveSpacingFactor = 0.05
        case ..<72:
            adaptiveSpacingFactor = 0.075
        case ..<160:
            adaptiveSpacingFactor = 0.11
        default:
            adaptiveSpacingFactor = 0.15
        }
        let baseSpacing = max(normalizedBrushSize * adaptiveSpacingFactor, 0.35)
        guard distance > 0.001 else { return baseSpacing }
        return baseSpacing
    }

    private var duplicateSampleDistanceThreshold: Float {
        let normalizedBrushSize = max(brushSize, 1.0)
        let thresholdFactor: Float = normalizedBrushSize >= 160 ? 0.035 : (normalizedBrushSize >= 72 ? 0.02 : 0.01)
        return max(normalizedBrushSize * thresholdFactor, 0.2)
    }

    private func interpolatedPoints(from start: StrokePoint, to end: StrokePoint, predicted: Bool) -> [StrokePoint] {
        let dx = end.position.x - start.position.x
        let dy = end.position.y - start.position.y
        let distance = simd_length(SIMD2<Float>(dx, dy))
        let steps = max(1, Int(ceil(distance / max(brushSize * 0.35, 1.0))))

        return (0...steps).map { step in
            let t = Float(step) / Float(steps)
            return StrokePoint(
                position: SIMD2<Float>(
                    start.position.x + dx * t,
                    start.position.y + dy * t
                ),
                pressure: start.pressure + (end.pressure - start.pressure) * t,
                altitude: start.altitude + (end.altitude - start.altitude) * t,
                azimuth: start.azimuth + (end.azimuth - start.azimuth) * t,
                timestamp: start.timestamp + Double(Float(end.timestamp - start.timestamp) * t),
                isPredicted: predicted
            )
        }
    }

    private func shapePoints(from start: StrokePoint, to end: StrokePoint, predicted: Bool) -> [StrokePoint] {
        switch shapeMode {
        case .line:
            return interpolatedPoints(from: start, to: end, predicted: predicted)
        case .rectangle:
            let vertices = rectangleVertices(from: start.position, to: end.position)
            return strokedPathPoints(vertices: vertices, closed: true, start: start, end: end, predicted: predicted)
        case .ellipse:
            return ellipsePoints(from: start, to: end, predicted: predicted)
        case .triangle:
            let vertices = regularPolygonVertices(sides: 3, from: start.position, to: end.position)
            return strokedPathPoints(vertices: vertices, closed: true, start: start, end: end, predicted: predicted)
        case .pentagon:
            let vertices = regularPolygonVertices(sides: 5, from: start.position, to: end.position)
            return strokedPathPoints(vertices: vertices, closed: true, start: start, end: end, predicted: predicted)
        case .hexagon:
            let vertices = regularPolygonVertices(sides: 6, from: start.position, to: end.position)
            return strokedPathPoints(vertices: vertices, closed: true, start: start, end: end, predicted: predicted)
        }
    }

    private func rectangleVertices(from start: SIMD2<Float>, to end: SIMD2<Float>) -> [SIMD2<Float>] {
        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)

        return [
            SIMD2(minX, minY),
            SIMD2(maxX, minY),
            SIMD2(maxX, maxY),
            SIMD2(minX, maxY)
        ]
    }

    private func regularPolygonVertices(sides: Int, from start: SIMD2<Float>, to end: SIMD2<Float>) -> [SIMD2<Float>] {
        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)
        let center = SIMD2<Float>((minX + maxX) * 0.5, (minY + maxY) * 0.5)
        let radiusX = max((maxX - minX) * 0.5, 0.5)
        let radiusY = max((maxY - minY) * 0.5, 0.5)

        return (0..<sides).map { index in
            let angle = Float(index) * (2.0 * .pi / Float(sides)) - (.pi / 2)
            return SIMD2<Float>(
                center.x + cos(angle) * radiusX,
                center.y + sin(angle) * radiusY
            )
        }
    }

    private func ellipsePoints(from start: StrokePoint, to end: StrokePoint, predicted: Bool) -> [StrokePoint] {
        let minX = min(start.position.x, end.position.x)
        let maxX = max(start.position.x, end.position.x)
        let minY = min(start.position.y, end.position.y)
        let maxY = max(start.position.y, end.position.y)
        let center = SIMD2<Float>((minX + maxX) * 0.5, (minY + maxY) * 0.5)
        let radiusX = max((maxX - minX) * 0.5, 0.5)
        let radiusY = max((maxY - minY) * 0.5, 0.5)
        let perimeterEstimate = 2.0 * Float.pi * sqrt(max((radiusX * radiusX + radiusY * radiusY) * 0.5, 0.25))
        let count = max(24, Int(ceil(perimeterEstimate / max(brushSize * 0.28, 1.0))))

        let vertices = (0..<count).map { index -> SIMD2<Float> in
            let angle = Float(index) * (2.0 * .pi / Float(count)) - (.pi / 2)
            return SIMD2<Float>(
                center.x + cos(angle) * radiusX,
                center.y + sin(angle) * radiusY
            )
        }

        return strokedPathPoints(vertices: vertices, closed: true, start: start, end: end, predicted: predicted)
    }

    private func strokedPathPoints(
        vertices: [SIMD2<Float>],
        closed: Bool,
        start: StrokePoint,
        end: StrokePoint,
        predicted: Bool
    ) -> [StrokePoint] {
        guard !vertices.isEmpty else { return [start, end] }
        if vertices.count == 1 {
            return [strokePoint(at: vertices[0], progress: 1, start: start, end: end, predicted: predicted)]
        }

        var path = vertices
        if closed, let first = vertices.first {
            path.append(first)
        }

        let segments = max(path.count - 1, 1)
        var result: [StrokePoint] = []

        for segmentIndex in 0..<segments {
            let segmentStart = path[segmentIndex]
            let segmentEnd = path[segmentIndex + 1]
            let distance = simd_length(segmentEnd - segmentStart)
            let steps = max(1, Int(ceil(distance / max(brushSize * 0.35, 1.0))))

            for step in 0...steps {
                if segmentIndex > 0 && step == 0 { continue }
                let t = Float(step) / Float(steps)
                let progress = (Float(segmentIndex) + t) / Float(segments)
                let position = segmentStart + ((segmentEnd - segmentStart) * t)
                result.append(
                    strokePoint(at: position, progress: progress, start: start, end: end, predicted: predicted)
                )
            }
        }

        return result
    }

    private func strokePoint(
        at position: SIMD2<Float>,
        progress: Float,
        start: StrokePoint,
        end: StrokePoint,
        predicted: Bool
    ) -> StrokePoint {
        StrokePoint(
            position: position,
            pressure: start.pressure + ((end.pressure - start.pressure) * progress),
            altitude: start.altitude + ((end.altitude - start.altitude) * progress),
            azimuth: start.azimuth + ((end.azimuth - start.azimuth) * progress),
            timestamp: start.timestamp + Double(Float(end.timestamp - start.timestamp) * progress),
            isPredicted: predicted
        )
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
        case .select:
            self = .select
        case .move:
            self = .move
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
