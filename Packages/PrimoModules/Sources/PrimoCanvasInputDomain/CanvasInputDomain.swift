import CoreGraphics
import Foundation
import PrimoBrushDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain
import simd

public enum CanvasInputTouchPhase: Equatable, Sendable {
    case began
    case moved
    case stationary
    case ended
    case cancelled
}

public enum CanvasInputToolKind: Equatable, Sendable {
    case brush
    case erase
    case blur
    case fill
    case eyedropper
    case select
    case move
    case shape
    case text
}

public struct CanvasStrokePoint: Equatable, Sendable {
    public var position: SIMD2<Float>
    public var pressure: Float
    public var altitude: Float
    public var azimuth: Float
    public var timestamp: TimeInterval
    public var isPredicted: Bool

    public init(
        position: SIMD2<Float>,
        pressure: Float,
        altitude: Float,
        azimuth: Float,
        timestamp: TimeInterval,
        isPredicted: Bool = false
    ) {
        self.position = position
        self.pressure = pressure
        self.altitude = altitude
        self.azimuth = azimuth
        self.timestamp = timestamp
        self.isPredicted = isPredicted
    }

    public var cgPoint: CGPoint {
        CGPoint(x: CGFloat(position.x), y: CGFloat(position.y))
    }

    public var stylusSample: StylusSample {
        StylusSample(
            point: cgPoint,
            pressure: CGFloat(pressure),
            altitude: CGFloat(altitude),
            azimuth: CGFloat(azimuth),
            timestamp: timestamp
        )
    }
}

public struct CanvasInputStroke: Equatable, Sendable {
    public var points: [CanvasStrokePoint]
    public var predictedPoints: [CanvasStrokePoint]
    public var color: SIMD4<Float>
    public var brushSize: Float

    public init(
        points: [CanvasStrokePoint] = [],
        predictedPoints: [CanvasStrokePoint] = [],
        color: SIMD4<Float>,
        brushSize: Float
    ) {
        self.points = points
        self.predictedPoints = predictedPoints
        self.color = color
        self.brushSize = brushSize
    }
}

public struct CanvasInputSample: Equatable, Sendable {
    public var point: CGPoint
    public var pressure: Float
    public var altitude: Float
    public var azimuth: Float
    public var timestamp: TimeInterval

    public init(
        point: CGPoint,
        pressure: Float,
        altitude: Float,
        azimuth: Float,
        timestamp: TimeInterval
    ) {
        self.point = point
        self.pressure = pressure
        self.altitude = altitude
        self.azimuth = azimuth
        self.timestamp = timestamp
    }

    public var strokePoint: CanvasStrokePoint {
        CanvasStrokePoint(
            position: SIMD2(Float(point.x), Float(point.y)),
            pressure: pressure,
            altitude: altitude,
            azimuth: azimuth,
            timestamp: timestamp,
            isPredicted: false
        )
    }

    public var stylusSample: StylusSample {
        strokePoint.stylusSample
    }
}

public enum CanvasInputCommand: Equatable, Sendable {
    case updateStroke(CanvasInputStroke)
    case endStroke(CanvasInputStroke)
    case cancelStroke
    case requestFill(StylusSample)
    case requestColorSample(StylusSample)
    case updateSelectionPath([CGPoint])
    case endSelectionPath([CGPoint])
    case requestAutoSelection(StylusSample)
    case requestTextPlacement(CGPoint)
    case beginTransform
    case updateTransform(CGSize)
    case endTransform(CGSize)
}

public struct CanvasInputConfiguration: Equatable, Sendable {
    public var tool: CanvasInputToolKind
    public var selectionMode: SelectionToolMode
    public var shapeMode: ShapeToolMode
    public var brushTipKind: BrushTipKind
    public var brushColor: SIMD4<Float>
    public var brushSize: Float
    public var strokeStabilization: Float

    public init(
        tool: CanvasInputToolKind = .brush,
        selectionMode: SelectionToolMode = .lasso,
        shapeMode: ShapeToolMode = .line,
        brushTipKind: BrushTipKind = .pencil,
        brushColor: SIMD4<Float> = SIMD4(0, 0, 0, 1),
        brushSize: Float = 4,
        strokeStabilization: Float = 0
    ) {
        self.tool = tool
        self.selectionMode = selectionMode
        self.shapeMode = shapeMode
        self.brushTipKind = brushTipKind
        self.brushColor = brushColor
        self.brushSize = brushSize
        self.strokeStabilization = strokeStabilization
    }
}

public struct CanvasInputReducer: Sendable {
    public struct State: Equatable, Sendable {
        public var currentStroke: CanvasInputStroke?
        public var shapeStartPoint: CanvasStrokePoint?
        public var currentSelectionPoints: [CGPoint] = []
        public var transformStartPoint: CGPoint?

        public init() {}
    }

    public init() {}

    public func reduce(
        phase: CanvasInputTouchPhase,
        sample: CanvasInputSample,
        coalescedSamples: [CanvasInputSample],
        state: inout State,
        configuration: CanvasInputConfiguration
    ) -> [CanvasInputCommand] {
        switch configuration.tool {
        case .select:
            return reduceSelection(phase: phase, sample: sample, coalescedSamples: coalescedSamples, state: &state, configuration: configuration)
        case .move:
            return reduceTransform(phase: phase, sample: sample, state: &state)
        case .text:
            guard phase == .began else { return [] }
            state.currentStroke = nil
            state.shapeStartPoint = nil
            return [.requestTextPlacement(sample.point)]
        case .fill:
            guard phase == .began else { return [] }
            state.currentStroke = nil
            state.shapeStartPoint = nil
            return [.requestFill(sample.stylusSample)]
        case .eyedropper:
            switch phase {
            case .began, .moved, .stationary:
                return [.requestColorSample(sample.stylusSample)]
            case .ended, .cancelled:
                state.currentStroke = nil
                state.shapeStartPoint = nil
                return [.requestColorSample(sample.stylusSample)]
            }
        default:
            return reduceStroke(phase: phase, sample: sample, coalescedSamples: coalescedSamples, state: &state, configuration: configuration)
        }
    }

    private func reduceStroke(
        phase: CanvasInputTouchPhase,
        sample: CanvasInputSample,
        coalescedSamples: [CanvasInputSample],
        state: inout State,
        configuration: CanvasInputConfiguration
    ) -> [CanvasInputCommand] {
        switch phase {
        case .began:
            let firstPoint = sample.strokePoint
            state.shapeStartPoint = firstPoint
            let stroke = CanvasInputStroke(points: [firstPoint], predictedPoints: [], color: configuration.brushColor, brushSize: configuration.brushSize)
            state.currentStroke = stroke
            return [.updateStroke(stroke)]
        case .moved:
            guard var stroke = state.currentStroke else { return [] }
            if configuration.tool == .shape, let shapeStartPoint = state.shapeStartPoint {
                stroke.points = CanvasStrokeGeometryFactory.shapePoints(
                    from: shapeStartPoint,
                    to: sample.strokePoint,
                    shapeMode: configuration.shapeMode,
                    brushSize: configuration.brushSize,
                    predicted: false
                )
            } else {
                appendFilteredPoints(coalescedSamples.map(\.strokePoint), to: &stroke, isFinishingStroke: false, brushSize: configuration.brushSize)
            }
            stroke.predictedPoints.removeAll()
            state.currentStroke = stroke
            return [.updateStroke(stroke)]
        case .stationary:
            return []
        case .ended:
            guard var stroke = state.currentStroke else { return [] }
            if configuration.tool == .shape, let shapeStartPoint = state.shapeStartPoint {
                stroke.points = CanvasStrokeGeometryFactory.shapePoints(
                    from: shapeStartPoint,
                    to: sample.strokePoint,
                    shapeMode: configuration.shapeMode,
                    brushSize: configuration.brushSize,
                    predicted: false
                )
            } else {
                appendFilteredPoints(coalescedSamples.map(\.strokePoint), to: &stroke, isFinishingStroke: true, brushSize: configuration.brushSize)
            }
            stroke.predictedPoints.removeAll()
            state.currentStroke = nil
            state.shapeStartPoint = nil
            return [.endStroke(stroke)]
        case .cancelled:
            state.currentStroke = nil
            state.shapeStartPoint = nil
            return [.cancelStroke]
        }
    }

    private func reduceSelection(
        phase: CanvasInputTouchPhase,
        sample: CanvasInputSample,
        coalescedSamples: [CanvasInputSample],
        state: inout State,
        configuration: CanvasInputConfiguration
    ) -> [CanvasInputCommand] {
        if configuration.selectionMode == .auto {
            guard phase == .began else { return [] }
            state.currentSelectionPoints.removeAll()
            return [.requestAutoSelection(sample.stylusSample)]
        }

        switch phase {
        case .began:
            state.currentSelectionPoints = [sample.point]
            return [.updateSelectionPath(state.currentSelectionPoints)]
        case .moved, .stationary:
            appendSelectionPoints(coalescedSamples.map(\.point), to: &state.currentSelectionPoints)
            return [.updateSelectionPath(state.currentSelectionPoints)]
        case .ended, .cancelled:
            appendSelectionPoints(coalescedSamples.map(\.point), to: &state.currentSelectionPoints)
            let points = state.currentSelectionPoints
            state.currentSelectionPoints.removeAll()
            return [.endSelectionPath(points)]
        }
    }

    private func reduceTransform(
        phase: CanvasInputTouchPhase,
        sample: CanvasInputSample,
        state: inout State
    ) -> [CanvasInputCommand] {
        switch phase {
        case .began:
            state.transformStartPoint = sample.point
            return [.beginTransform, .updateTransform(.zero)]
        case .moved, .stationary:
            guard let start = state.transformStartPoint else { return [] }
            return [.updateTransform(CGSize(width: sample.point.x - start.x, height: sample.point.y - start.y))]
        case .ended, .cancelled:
            guard let start = state.transformStartPoint else { return [] }
            state.transformStartPoint = nil
            return [.endTransform(CGSize(width: sample.point.x - start.x, height: sample.point.y - start.y))]
        }
    }

    private func appendSelectionPoints(_ points: [CGPoint], to currentSelectionPoints: inout [CGPoint]) {
        for point in points {
            guard let previous = currentSelectionPoints.last else {
                currentSelectionPoints.append(point)
                continue
            }
            guard hypot(point.x - previous.x, point.y - previous.y) >= 2.0 else { continue }
            currentSelectionPoints.append(point)
        }
    }

    private func appendFilteredPoints(
        _ points: [CanvasStrokePoint],
        to stroke: inout CanvasInputStroke,
        isFinishingStroke: Bool,
        brushSize: Float
    ) {
        for rawPoint in points {
            var candidate = rawPoint
            guard let previous = stroke.points.last else {
                stroke.points.append(candidate)
                continue
            }

            if candidate.pressure <= 0.001 {
                candidate.pressure = max(previous.pressure * 0.92, 0.12)
            }

            let delta = candidate.position - previous.position
            let distance = simd_length(delta)

            if !isFinishingStroke && distance <= duplicateSampleDistanceThreshold(brushSize: brushSize) {
                stroke.points[stroke.points.count - 1] = CanvasStrokePoint(
                    position: previous.position,
                    pressure: candidate.pressure,
                    altitude: candidate.altitude,
                    azimuth: candidate.azimuth,
                    timestamp: candidate.timestamp,
                    isPredicted: false
                )
                continue
            }

            if isFinishingStroke && shouldRejectFinishingJump(candidate, previous: previous, distance: distance, brushSize: brushSize) {
                continue
            }

            let interpolationSpacing = preferredInterpolationSpacing(brushSize: brushSize)
            if distance > interpolationSpacing {
                let steps = max(1, Int(ceil(distance / interpolationSpacing)))
                for step in 1...steps {
                    let t = Float(step) / Float(steps)
                    stroke.points.append(
                        CanvasStrokePoint(
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

    private func shouldRejectFinishingJump(_ candidate: CanvasStrokePoint, previous: CanvasStrokePoint, distance: Float, brushSize: Float) -> Bool {
        let jumpThreshold = min(max(brushSize * 1.15, 10.0), 72.0)
        let pressureDropThreshold = max(0.08, previous.pressure * 0.72)
        return (distance > jumpThreshold && candidate.pressure < pressureDropThreshold) || distance > jumpThreshold * 2.0
    }

    private func preferredInterpolationSpacing(brushSize: Float) -> Float {
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
        return max(normalizedBrushSize * adaptiveSpacingFactor, 0.35)
    }

    private func duplicateSampleDistanceThreshold(brushSize: Float) -> Float {
        let normalizedBrushSize = max(brushSize, 1.0)
        let thresholdFactor: Float = normalizedBrushSize >= 160 ? 0.035 : (normalizedBrushSize >= 72 ? 0.02 : 0.01)
        return max(normalizedBrushSize * thresholdFactor, 0.2)
    }
}

public enum CanvasStrokeGeometryFactory {
    public static func shapePoints(
        from start: CanvasStrokePoint,
        to end: CanvasStrokePoint,
        shapeMode: ShapeToolMode,
        brushSize: Float,
        predicted: Bool
    ) -> [CanvasStrokePoint] {
        switch shapeMode {
        case .line:
            return interpolatedPoints(from: start, to: end, brushSize: brushSize, predicted: predicted)
        case .rectangle:
            return strokedPathPoints(vertices: rectangleVertices(from: start.position, to: end.position), closed: true, start: start, end: end, brushSize: brushSize, predicted: predicted)
        case .ellipse:
            return ellipsePoints(from: start, to: end, brushSize: brushSize, predicted: predicted)
        case .triangle:
            return strokedPathPoints(vertices: regularPolygonVertices(sides: 3, from: start.position, to: end.position), closed: true, start: start, end: end, brushSize: brushSize, predicted: predicted)
        case .pentagon:
            return strokedPathPoints(vertices: regularPolygonVertices(sides: 5, from: start.position, to: end.position), closed: true, start: start, end: end, brushSize: brushSize, predicted: predicted)
        case .hexagon:
            return strokedPathPoints(vertices: regularPolygonVertices(sides: 6, from: start.position, to: end.position), closed: true, start: start, end: end, brushSize: brushSize, predicted: predicted)
        }
    }

    private static func interpolatedPoints(from start: CanvasStrokePoint, to end: CanvasStrokePoint, brushSize: Float, predicted: Bool) -> [CanvasStrokePoint] {
        let delta = end.position - start.position
        let distance = simd_length(delta)
        let steps = max(1, Int(ceil(distance / max(brushSize * 0.35, 1.0))))
        return (0...steps).map { step in
            let t = Float(step) / Float(steps)
            return strokePoint(at: start.position + (delta * t), progress: t, start: start, end: end, predicted: predicted)
        }
    }

    private static func rectangleVertices(from start: SIMD2<Float>, to end: SIMD2<Float>) -> [SIMD2<Float>] {
        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)
        return [SIMD2(minX, minY), SIMD2(maxX, minY), SIMD2(maxX, maxY), SIMD2(minX, maxY)]
    }

    private static func regularPolygonVertices(sides: Int, from start: SIMD2<Float>, to end: SIMD2<Float>) -> [SIMD2<Float>] {
        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)
        let center = SIMD2<Float>((minX + maxX) * 0.5, (minY + maxY) * 0.5)
        let radiusX = max((maxX - minX) * 0.5, 0.5)
        let radiusY = max((maxY - minY) * 0.5, 0.5)
        return (0..<sides).map { index in
            let angle = Float(index) * (2.0 * .pi / Float(sides)) - (.pi / 2)
            return SIMD2<Float>(center.x + cos(angle) * radiusX, center.y + sin(angle) * radiusY)
        }
    }

    private static func ellipsePoints(from start: CanvasStrokePoint, to end: CanvasStrokePoint, brushSize: Float, predicted: Bool) -> [CanvasStrokePoint] {
        let minX = min(start.position.x, end.position.x)
        let maxX = max(start.position.x, end.position.x)
        let minY = min(start.position.y, end.position.y)
        let maxY = max(start.position.y, end.position.y)
        let center = SIMD2<Float>((minX + maxX) * 0.5, (minY + maxY) * 0.5)
        let radiusX = max((maxX - minX) * 0.5, 0.5)
        let radiusY = max((maxY - minY) * 0.5, 0.5)
        let perimeterEstimate = 2.0 * Float.pi * sqrt(max((radiusX * radiusX + radiusY * radiusY) * 0.5, 0.25))
        let count = max(24, Int(ceil(perimeterEstimate / max(brushSize * 0.28, 1.0))))
        let vertices = (0..<count).map { index in
            let angle = Float(index) * (2.0 * .pi / Float(count)) - (.pi / 2)
            return SIMD2<Float>(center.x + cos(angle) * radiusX, center.y + sin(angle) * radiusY)
        }
        return strokedPathPoints(vertices: vertices, closed: true, start: start, end: end, brushSize: brushSize, predicted: predicted)
    }

    private static func strokedPathPoints(
        vertices: [SIMD2<Float>],
        closed: Bool,
        start: CanvasStrokePoint,
        end: CanvasStrokePoint,
        brushSize: Float,
        predicted: Bool
    ) -> [CanvasStrokePoint] {
        guard !vertices.isEmpty else { return [start, end] }
        if vertices.count == 1 {
            return [strokePoint(at: vertices[0], progress: 1, start: start, end: end, predicted: predicted)]
        }

        var path = vertices
        if closed, let first = vertices.first {
            path.append(first)
        }

        let segments = max(path.count - 1, 1)
        var result: [CanvasStrokePoint] = []
        for segmentIndex in 0..<segments {
            let segmentStart = path[segmentIndex]
            let segmentEnd = path[segmentIndex + 1]
            let distance = simd_length(segmentEnd - segmentStart)
            let steps = max(1, Int(ceil(distance / max(brushSize * 0.35, 1.0))))
            for step in 0...steps {
                if segmentIndex > 0 && step == 0 { continue }
                let t = Float(step) / Float(steps)
                let progress = (Float(segmentIndex) + t) / Float(segments)
                result.append(strokePoint(at: segmentStart + ((segmentEnd - segmentStart) * t), progress: progress, start: start, end: end, predicted: predicted))
            }
        }
        return result
    }

    private static func strokePoint(
        at position: SIMD2<Float>,
        progress: Float,
        start: CanvasStrokePoint,
        end: CanvasStrokePoint,
        predicted: Bool
    ) -> CanvasStrokePoint {
        CanvasStrokePoint(
            position: position,
            pressure: start.pressure + ((end.pressure - start.pressure) * progress),
            altitude: start.altitude + ((end.altitude - start.altitude) * progress),
            azimuth: start.azimuth + ((end.azimuth - start.azimuth) * progress),
            timestamp: start.timestamp + Double(Float(end.timestamp - start.timestamp) * progress),
            isPredicted: predicted
        )
    }
}
