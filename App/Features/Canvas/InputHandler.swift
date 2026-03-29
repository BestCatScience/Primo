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
            currentStroke = Stroke(points: [], predictedPoints: [], color: brushColor, brushSize: brushSize)
            fallthrough

        case .moved, .stationary:
            guard var stroke = currentStroke else { return }

            if tool == .shape, let shapeStartPoint {
                let currentPoint = makePoint(touch, in: view, predicted: false)
                stroke.points = interpolatedPoints(from: shapeStartPoint, to: currentPoint, predicted: false)
                let predictedTouch = (event?.predictedTouches(for: touch) ?? []).last
                if let predictedTouch {
                    let predictedPoint = makePoint(predictedTouch, in: view, predicted: true)
                    stroke.predictedPoints = interpolatedPoints(from: shapeStartPoint, to: predictedPoint, predicted: true)
                } else {
                    stroke.predictedPoints.removeAll()
                }
            } else {
                let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
                for coalescedTouch in coalescedTouches {
                    stroke.points.append(makePoint(coalescedTouch, in: view, predicted: false))
                }

                stroke.predictedPoints.removeAll()
                let predictedTouches = event?.predictedTouches(for: touch) ?? []
                for predictedTouch in predictedTouches {
                    stroke.predictedPoints.append(makePoint(predictedTouch, in: view, predicted: true))
                }
            }

            currentStroke = stroke
            delegate?.didUpdateStroke(stroke)

        case .ended, .cancelled:
            if var stroke = currentStroke {
                if tool == .shape, let shapeStartPoint {
                    let finalPoint = makePoint(touch, in: view, predicted: false)
                    stroke.points = interpolatedPoints(from: shapeStartPoint, to: finalPoint, predicted: false)
                } else {
                    let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
                    for coalescedTouch in coalescedTouches {
                        stroke.points.append(makePoint(coalescedTouch, in: view, predicted: false))
                    }
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
        return Float(touch.force / touch.maximumPossibleForce)
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
