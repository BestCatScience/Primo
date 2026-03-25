import UIKit
import simd

protocol InputHandlerDelegate: AnyObject {
    func didUpdateStroke(_ stroke: Stroke)
    func didEndStroke(_ stroke: Stroke)
}

final class InputHandler {
    weak var delegate: InputHandlerDelegate?

    var brushColor: SIMD4<Float> = SIMD4(0, 0, 0, 1)
    var brushSize: Float = 4.0
    var pointMapper: ((CGPoint, UIView) -> SIMD2<Float>)?

    private var currentStroke: Stroke?

    func handleTouches(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        guard let touch = touches.first,
              touch.type == .pencil else { return }

        switch touch.phase {
        case .began:
            currentStroke = Stroke(
                points: [],
                predictedPoints: [],
                color: brushColor,
                brushSize: brushSize
            )
            fallthrough

        case .moved, .stationary:
            guard var stroke = currentStroke else { return }

            let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
            for coalescedTouch in coalescedTouches {
                stroke.points.append(makePoint(coalescedTouch, in: view, predicted: false))
            }

            stroke.predictedPoints.removeAll()
            let predictedTouches = event?.predictedTouches(for: touch) ?? []
            for predictedTouch in predictedTouches {
                stroke.predictedPoints.append(makePoint(predictedTouch, in: view, predicted: true))
            }

            currentStroke = stroke
            delegate?.didUpdateStroke(stroke)

        case .ended, .cancelled:
            if var stroke = currentStroke {
                let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
                for coalescedTouch in coalescedTouches {
                    stroke.points.append(makePoint(coalescedTouch, in: view, predicted: false))
                }

                var finalStroke = stroke
                finalStroke.predictedPoints.removeAll()
                delegate?.didEndStroke(finalStroke)
            }
            currentStroke = nil

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
}
