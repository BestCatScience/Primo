import UIKit
import simd

protocol InputHandlerDelegate: AnyObject {
    func didUpdateStroke(_ stroke: Stroke)
    func didEndStroke(_ stroke: Stroke)
}

final class InputHandler {
    weak var delegate: InputHandlerDelegate?

    var tool: StudioToolKind = .brush
    var brushColor: SIMD4<Float> = SIMD4(0, 0, 0, 1)
    var brushSize: Float = 4.0
    var pointMapper: ((CGPoint, UIView) -> SIMD2<Float>)?

    private var currentStroke: Stroke?
    private var shapeStartPoint: StrokePoint?

    func handleTouches(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        guard let touch = touches.first,
              touch.type == .pencil else { return }

        guard tool != .select && tool != .move else { return }

        switch touch.phase {
        case .began:
            let firstPoint = makePoint(touch, in: view, predicted: false)
            shapeStartPoint = firstPoint
            currentStroke = Stroke(points: [firstPoint], predictedPoints: [], color: brushColor, brushSize: brushSize)
            fallthrough

        case .moved, .stationary:
            guard var stroke = currentStroke else { return }

            if tool == .shape, let shapeStartPoint {
                let currentPoint = makePoint(touch, in: view, predicted: false)
                stroke.points = interpolatedPoints(from: shapeStartPoint, to: currentPoint, predicted: false)
                stroke.predictedPoints.removeAll()
            } else {
                let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
                appendFilteredPoints(from: coalescedTouches, to: &stroke, in: view, isFinishingStroke: false)
                stroke.predictedPoints.removeAll()
            }

            currentStroke = stroke
            delegate?.didUpdateStroke(stroke)

        case .ended, .cancelled:
            if var stroke = currentStroke {
                if tool == .shape, let shapeStartPoint {
                    let finalPoint = makePoint(touch, in: view, predicted: false)
                    stroke.points = interpolatedPoints(from: shapeStartPoint, to: finalPoint, predicted: false)
                } else {
                    let finishingTouches = event?.coalescedTouches(for: touch) ?? [touch]
                    appendFilteredPoints(from: finishingTouches, to: &stroke, in: view, isFinishingStroke: true)
                }

                var finalStroke = stroke
                finalStroke.predictedPoints.removeAll()
                delegate?.didEndStroke(finalStroke)
            }
            currentStroke = nil
            shapeStartPoint = nil

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
                if isFinishingStroke {
                    continue
                }
                candidate.pressure = max(previous.pressure * 0.92, 0.12)
            }

            let delta = candidate.position - previous.position
            let distance = simd_length(delta)

            if isFinishingStroke && shouldRejectFinishingJump(candidate, previous: previous, distance: distance) {
                continue
            }

            if shouldReject(candidate, to: stroke.points, distance: distance) {
                continue
            }

            let interpolationSpacing = max(brushSize * 0.35, 1.5)
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
        let jumpThreshold = max(brushSize * 3.0, 12.0)
        let pressureDropThreshold = max(0.08, previous.pressure * 0.5)
        return distance > jumpThreshold && candidate.pressure < pressureDropThreshold
    }

    private func shouldReject(_ candidate: StrokePoint, to points: [StrokePoint], distance: Float) -> Bool {
        guard let previous = points.last else { return true }
        if distance < 0.01 {
            return true
        }

        let absurdJumpDistance = max(brushSize * 14.0, 220.0)
        if distance > absurdJumpDistance {
            return true
        }

        guard points.count >= 2 else { return false }
        let beforePrevious = points[points.count - 2]
        let previousDelta = previous.position - beforePrevious.position
        let previousDistance = simd_length(previousDelta)
        guard previousDistance > 0.001 else { return false }

        let normalizedPrevious = previousDelta / previousDistance
        let normalizedCurrent = (candidate.position - previous.position) / max(distance, 0.001)
        let alignment = simd_dot(normalizedPrevious, normalizedCurrent)

        let hookThreshold = max(brushSize * 1.8, 24.0)
        if alignment < -0.75 && distance > hookThreshold {
            return true
        }

        return false
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
}
