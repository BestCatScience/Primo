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
    case move
    case select
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
    case beginSelectionMove(CGPoint)
    case updateSelectionMove(CGSize)
    case endSelectionMove(CGSize)
    case cancelSelectionMove
    case requestAutoSelection(StylusSample)
    case requestTextPlacement(CGPoint)
}

public struct CanvasInputSelectionContext: Equatable, Sendable {
    public var bounds: CGRect
    public var maskWidth: Int
    public var maskHeight: Int
    public var maskData: Data

    public init(bounds: CGRect, maskWidth: Int, maskHeight: Int, maskData: Data) {
        self.bounds = bounds
        self.maskWidth = maskWidth
        self.maskHeight = maskHeight
        self.maskData = maskData
    }

    public init?(_ selection: CanvasSelection?) {
        guard let selection, !selection.isEmpty else { return nil }
        self.init(
            bounds: selection.bounds,
            maskWidth: selection.maskWidth,
            maskHeight: selection.maskHeight,
            maskData: selection.maskData
        )
    }

    public func contains(_ point: CGPoint) -> Bool {
        guard !bounds.isNull, !bounds.isEmpty, bounds.contains(point) else { return false }
        guard maskWidth > 0, maskHeight > 0, maskData.count == maskWidth * maskHeight else {
            return true
        }
        let maskX = Int((point.x - bounds.minX).rounded(.down))
        let maskY = Int((point.y - bounds.minY).rounded(.down))
        guard (0..<maskWidth).contains(maskX), (0..<maskHeight).contains(maskY) else {
            return false
        }
        return maskData[(maskY * maskWidth) + maskX] > 0
    }
}

public struct CanvasInputLayerMoveContext: Equatable, Sendable {
    public var bounds: CGRect
    public var width: Int
    public var height: Int
    public var pixelData: Data
    public var alphaThreshold: UInt8

    public init(
        bounds: CGRect,
        width: Int,
        height: Int,
        pixelData: Data,
        alphaThreshold: UInt8 = 0
    ) {
        self.bounds = bounds
        self.width = width
        self.height = height
        self.pixelData = pixelData
        self.alphaThreshold = alphaThreshold
    }

    public func contains(_ point: CGPoint) -> Bool {
        guard !bounds.isNull, !bounds.isEmpty, bounds.contains(point) else { return false }
        guard width > 0, height > 0, pixelData.count == width * height * 4 else {
            return false
        }
        let pixelX = Int((point.x - bounds.minX).rounded(.down))
        let pixelY = Int((point.y - bounds.minY).rounded(.down))
        guard (0..<width).contains(pixelX), (0..<height).contains(pixelY) else {
            return false
        }
        let alphaIndex = ((pixelY * width) + pixelX) * 4 + 3
        return pixelData[alphaIndex] > alphaThreshold
    }
}

public struct CanvasInputConfiguration: Equatable, Sendable {
    public var tool: CanvasInputToolKind
    public var selectionMode: SelectionToolMode
    public var selectionContext: CanvasInputSelectionContext?
    public var layerMoveContext: CanvasInputLayerMoveContext?
    public var shapeMode: ShapeToolMode
    public var brushTipKind: BrushTipKind
    public var brushColor: SIMD4<Float>
    public var brushSize: Float
    public var strokeStabilization: Float

    public init(
        tool: CanvasInputToolKind = .brush,
        selectionMode: SelectionToolMode = .lasso,
        selectionContext: CanvasInputSelectionContext? = nil,
        layerMoveContext: CanvasInputLayerMoveContext? = nil,
        shapeMode: ShapeToolMode = .line,
        brushTipKind: BrushTipKind = .pencil,
        brushColor: SIMD4<Float> = SIMD4(0, 0, 0, 1),
        brushSize: Float = 4,
        strokeStabilization: Float = 0.5
    ) {
        self.tool = tool
        self.selectionMode = selectionMode
        self.selectionContext = selectionContext
        self.layerMoveContext = layerMoveContext
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
        public var stabilizerAnchor: CanvasStrokePoint?
        public var rawStrokePoints: [CanvasStrokePoint] = []
        public var currentSelectionPoints: [CGPoint] = []
        public var selectionMoveStartPoint: CGPoint?

        public init() {}
    }

    public init() {}

    public func reduce(
        phase: CanvasInputTouchPhase,
        sample: CanvasInputSample,
        coalescedSamples: [CanvasInputSample],
        predictedSamples: [CanvasInputSample] = [],
        state: inout State,
        configuration: CanvasInputConfiguration
    ) -> [CanvasInputCommand] {
        switch configuration.tool {
        case .move:
            return reduceMove(phase: phase, sample: sample, state: &state, configuration: configuration)
        case .select:
            return reduceSelection(phase: phase, sample: sample, coalescedSamples: coalescedSamples, state: &state, configuration: configuration)
        case .text:
            guard phase == .began else { return [] }
            resetStrokeState(&state)
            return [.requestTextPlacement(sample.point)]
        case .fill:
            guard phase == .began else { return [] }
            resetStrokeState(&state)
            return [.requestFill(sample.stylusSample)]
        case .eyedropper:
            switch phase {
            case .began, .moved, .stationary:
                return [.requestColorSample(sample.stylusSample)]
            case .ended, .cancelled:
                resetStrokeState(&state)
                return [.requestColorSample(sample.stylusSample)]
            }
        default:
            return reduceStroke(
                phase: phase,
                sample: sample,
                coalescedSamples: coalescedSamples,
                predictedSamples: predictedSamples,
                state: &state,
                configuration: configuration
            )
        }
    }

    private func reduceStroke(
        phase: CanvasInputTouchPhase,
        sample: CanvasInputSample,
        coalescedSamples: [CanvasInputSample],
        predictedSamples: [CanvasInputSample],
        state: inout State,
        configuration: CanvasInputConfiguration
    ) -> [CanvasInputCommand] {
        switch phase {
        case .began:
            let firstPoint = sample.strokePoint
            state.shapeStartPoint = firstPoint
            state.rawStrokePoints = [firstPoint]
            state.stabilizerAnchor = firstPoint
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
                appendFilteredPoints(
                    coalescedSamples.map(\.strokePoint),
                    to: &stroke,
                    state: &state,
                    isFinishingStroke: false,
                    brushSize: configuration.brushSize,
                    stabilization: configuration.strokeStabilization
                )
            }
            stroke.predictedPoints = predictedStrokePoints(
                predictedSamples.map(\.strokePoint),
                after: stroke,
                anchor: state.stabilizerAnchor,
                brushSize: configuration.brushSize,
                stabilization: configuration.strokeStabilization
            )
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
                appendFilteredPoints(
                    coalescedSamples.map(\.strokePoint),
                    to: &stroke,
                    state: &state,
                    isFinishingStroke: true,
                    brushSize: configuration.brushSize,
                    stabilization: configuration.strokeStabilization
                )
            }
            stroke.predictedPoints.removeAll()
            state.currentStroke = nil
            state.shapeStartPoint = nil
            state.stabilizerAnchor = nil
            state.rawStrokePoints.removeAll()
            return [.endStroke(stroke)]
        case .cancelled:
            resetStrokeState(&state)
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
            state.selectionMoveStartPoint = nil
            return [.requestAutoSelection(sample.stylusSample)]
        }

        switch phase {
        case .began:
            if configuration.selectionContext?.contains(sample.point) == true ||
                configuration.layerMoveContext?.contains(sample.point) == true
            {
                state.currentSelectionPoints.removeAll()
                state.selectionMoveStartPoint = sample.point
                return [.beginSelectionMove(sample.point)]
            }
            state.currentSelectionPoints = [sample.point]
            state.selectionMoveStartPoint = nil
            return [.updateSelectionPath(state.currentSelectionPoints)]
        case .moved, .stationary:
            if let startPoint = state.selectionMoveStartPoint {
                return [.updateSelectionMove(selectionMoveOffset(from: startPoint, to: sample.point))]
            }
            if configuration.selectionMode == .rectangle {
                updateSelectionRectangle(to: sample.point, state: &state)
                return [.updateSelectionPath(state.currentSelectionPoints)]
            }
            appendSelectionPoints(coalescedSamples.map(\.point), to: &state.currentSelectionPoints)
            return [.updateSelectionPath(state.currentSelectionPoints)]
        case .ended:
            if let startPoint = state.selectionMoveStartPoint {
                state.selectionMoveStartPoint = nil
                return [.endSelectionMove(selectionMoveOffset(from: startPoint, to: sample.point))]
            }
            if configuration.selectionMode == .rectangle {
                updateSelectionRectangle(to: sample.point, state: &state)
            } else {
                appendSelectionPoints(coalescedSamples.map(\.point), to: &state.currentSelectionPoints)
            }
            let points = state.currentSelectionPoints
            state.currentSelectionPoints.removeAll()
            return [.endSelectionPath(points)]
        case .cancelled:
            if state.selectionMoveStartPoint != nil {
                state.selectionMoveStartPoint = nil
                state.currentSelectionPoints.removeAll()
                return [.cancelSelectionMove]
            }
            appendSelectionPoints(coalescedSamples.map(\.point), to: &state.currentSelectionPoints)
            let points = state.currentSelectionPoints
            state.currentSelectionPoints.removeAll()
            return [.endSelectionPath(points)]
        }
    }

    private func reduceMove(
        phase: CanvasInputTouchPhase,
        sample: CanvasInputSample,
        state: inout State,
        configuration: CanvasInputConfiguration
    ) -> [CanvasInputCommand] {
        switch phase {
        case .began:
            guard configuration.selectionContext?.contains(sample.point) == true ||
                configuration.layerMoveContext?.contains(sample.point) == true
            else {
                state.currentSelectionPoints.removeAll()
                state.selectionMoveStartPoint = nil
                return []
            }
            state.currentSelectionPoints.removeAll()
            state.selectionMoveStartPoint = sample.point
            return [.beginSelectionMove(sample.point)]
        case .moved, .stationary:
            guard let startPoint = state.selectionMoveStartPoint else { return [] }
            return [.updateSelectionMove(selectionMoveOffset(from: startPoint, to: sample.point))]
        case .ended:
            guard let startPoint = state.selectionMoveStartPoint else { return [] }
            state.selectionMoveStartPoint = nil
            return [.endSelectionMove(selectionMoveOffset(from: startPoint, to: sample.point))]
        case .cancelled:
            guard state.selectionMoveStartPoint != nil else { return [] }
            state.selectionMoveStartPoint = nil
            state.currentSelectionPoints.removeAll()
            return [.cancelSelectionMove]
        }
    }

    private func selectionMoveOffset(from startPoint: CGPoint, to point: CGPoint) -> CGSize {
        CGSize(width: point.x - startPoint.x, height: point.y - startPoint.y)
    }

    private func updateSelectionRectangle(to point: CGPoint, state: inout State) {
        guard let startPoint = state.currentSelectionPoints.first else {
            state.currentSelectionPoints = [point]
            return
        }
        state.currentSelectionPoints = [startPoint, point]
    }

    private func appendSelectionPoints(_ points: [CGPoint], to currentSelectionPoints: inout [CGPoint]) {
        for point in points {
            guard currentSelectionPoints.count < CanvasSizePolicy.maxLassoPointCount else { break }
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
        state: inout State,
        isFinishingStroke: Bool,
        brushSize: Float,
        stabilization: Float
    ) {
        for rawPoint in points {
            guard stroke.points.count < CanvasSizePolicy.maxStrokeSampleCount else { break }
            var candidate = rawPoint
            if state.rawStrokePoints.count < CanvasSizePolicy.maxStrokeSampleCount {
                state.rawStrokePoints.append(rawPoint)
            }
            guard let previous = stroke.points.last else {
                stroke.points.append(candidate)
                state.stabilizerAnchor = candidate
                continue
            }

            if candidate.pressure <= 0.001 {
                candidate.pressure = max(previous.pressure * 0.92, 0.12)
            }

            candidate = stabilizedStrokePoint(
                candidate,
                anchor: state.stabilizerAnchor ?? previous,
                brushSize: brushSize,
                stabilization: stabilization,
                isFinishingStroke: isFinishingStroke
            )

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
                let steps = min(
                    CanvasSizePolicy.maxInterpolatedSamplesPerEvent,
                    max(1, Int(ceil(distance / interpolationSpacing)))
                )
                for step in 1...steps {
                    guard stroke.points.count < CanvasSizePolicy.maxStrokeSampleCount else { break }
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
            state.stabilizerAnchor = candidate
        }
    }

    private func stabilizedStrokePoint(
        _ point: CanvasStrokePoint,
        anchor: CanvasStrokePoint,
        brushSize: Float,
        stabilization: Float,
        isFinishingStroke: Bool
    ) -> CanvasStrokePoint {
        let amount = min(max(stabilization, 0), 1)
        guard amount > 0.001 else { return point }

        let delta = point.position - anchor.position
        let distance = simd_length(delta)
        guard distance > 0.001 else { return point }

        let lazyRadius = stabilizationLazyRadius(brushSize: brushSize, amount: amount)
        let targetPosition: SIMD2<Float>
        if distance <= lazyRadius && !isFinishingStroke {
            targetPosition = anchor.position
        } else if lazyRadius > 0 {
            let trailingRadius = isFinishingStroke ? lazyRadius * 0.45 : lazyRadius
            let direction = delta / distance
            let trailingDistance = min(trailingRadius, distance)
            targetPosition = point.position - (direction * trailingDistance)
        } else {
            targetPosition = point.position
        }

        let targetDelta = targetPosition - anchor.position
        let response = max(1.0 - (amount * 0.55), 0.38)

        var stabilized = point
        stabilized.position = anchor.position + targetDelta * response
        return stabilized
    }

    private func predictedStrokePoints(
        _ points: [CanvasStrokePoint],
        after stroke: CanvasInputStroke,
        anchor: CanvasStrokePoint?,
        brushSize: Float,
        stabilization: Float
    ) -> [CanvasStrokePoint] {
        guard !points.isEmpty else { return [] }
        var previewStroke = CanvasInputStroke(
            points: stroke.points,
            predictedPoints: [],
            color: stroke.color,
            brushSize: stroke.brushSize
        )
        var previewState = State()
        previewState.stabilizerAnchor = anchor ?? stroke.points.last
        appendFilteredPoints(
            points.map { point in
                var predicted = point
                predicted.isPredicted = true
                return predicted
            },
            to: &previewStroke,
            state: &previewState,
            isFinishingStroke: false,
            brushSize: brushSize,
            stabilization: stabilization
        )
        return Array(previewStroke.points.dropFirst(stroke.points.count)).map { point in
            var predicted = point
            predicted.isPredicted = true
            return predicted
        }
    }

    private func resetStrokeState(_ state: inout State) {
        state.currentStroke = nil
        state.shapeStartPoint = nil
        state.stabilizerAnchor = nil
        state.rawStrokePoints.removeAll()
    }

    private func stabilizationLazyRadius(brushSize: Float, amount: Float) -> Float {
        let scaledAmount = pow(amount, 1.05)
        let brushScaledRadius = max(brushSize * 2.4, 28.0)
        return min(brushScaledRadius * scaledAmount, 128.0)
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
