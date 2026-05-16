import CoreGraphics
import Foundation
import PrimoBrushDomain
import simd

public enum StudioToolKind: String, CaseIterable, Equatable, Sendable, Identifiable {
    case brush
    case erase
    case blur
    case fill
    case eyedropper
    case move
    case select
    case shape
    case text

    public var id: String { rawValue }
}

public enum EyedropperSamplingSource: String, CaseIterable, Equatable, Sendable, Identifiable {
    case activeLayer
    case canvas

    public var id: String { rawValue }
}

public enum CanvasTransformMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case standard
    case freeform

    public var id: String { rawValue }
}

public struct StrokePoint: Equatable, Sendable {
    public var position: SIMD2<Float>
    public var pressure: Float
    public var altitude: Float
    public var azimuth: Float
    public var timestamp: Double
    public var isPredicted: Bool

    public init(
        position: SIMD2<Float>,
        pressure: Float,
        altitude: Float,
        azimuth: Float,
        timestamp: Double,
        isPredicted: Bool
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

    public var previewPoint: PreviewStrokePoint {
        PreviewStrokePoint(point: cgPoint, pressure: CGFloat(pressure))
    }
}

public struct Stroke: Equatable, Sendable {
    public var points: [StrokePoint]
    public var predictedPoints: [StrokePoint]
    public var color: SIMD4<Float>
    public var brushSize: Float

    public init(
        points: [StrokePoint] = [],
        predictedPoints: [StrokePoint] = [],
        color: SIMD4<Float> = SIMD4(0, 0, 0, 1),
        brushSize: Float = 4.0
    ) {
        self.points = points
        self.predictedPoints = predictedPoints
        self.color = color
        self.brushSize = brushSize
    }

    public var confirmedPreviewPoints: [PreviewStrokePoint] {
        points.map(\.previewPoint)
    }

    public var predictedPreviewPoints: [PreviewStrokePoint] {
        predictedPoints.map(\.previewPoint)
    }
}

public struct PreviewStrokePoint: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let point: CGPoint
    public let pressure: CGFloat

    public init(id: UUID = UUID(), point: CGPoint, pressure: CGFloat) {
        self.id = id
        self.point = point
        self.pressure = pressure
    }
}

public struct PreviewStrokeStyle: Equatable, @unchecked Sendable {
    public let tipKind: BrushTipKind
    public let isEraser: Bool
    public let radius: CGFloat
    public let opacity: CGFloat
    public let flow: CGFloat
    public let hardness: CGFloat
    public let roundness: CGFloat
    public let angle: CGFloat
    public let followsStrokeAngle: Bool
    public let pressureSensitivity: CGFloat
    public let stabilization: CGFloat
    public let customTip: BrushTipRaster?
    public let color: CGColor

    public init(
        tipKind: BrushTipKind,
        isEraser: Bool,
        radius: CGFloat,
        opacity: CGFloat,
        flow: CGFloat,
        hardness: CGFloat,
        roundness: CGFloat,
        angle: CGFloat,
        followsStrokeAngle: Bool,
        pressureSensitivity: CGFloat,
        stabilization: CGFloat,
        customTip: BrushTipRaster?,
        color: CGColor
    ) {
        self.tipKind = tipKind
        self.isEraser = isEraser
        self.radius = radius
        self.opacity = opacity
        self.flow = flow
        self.hardness = hardness
        self.roundness = roundness
        self.angle = angle
        self.followsStrokeAngle = followsStrokeAngle
        self.pressureSensitivity = pressureSensitivity
        self.stabilization = stabilization
        self.customTip = customTip
        self.color = color
    }
}

public struct PreviewStrokeTrack: Identifiable, Equatable, @unchecked Sendable {
    public let id: UUID
    public let layerIndex: Int
    public let points: [PreviewStrokePoint]
    public let style: PreviewStrokeStyle

    public init(
        id: UUID = UUID(),
        layerIndex: Int,
        points: [PreviewStrokePoint],
        style: PreviewStrokeStyle
    ) {
        self.id = id
        self.layerIndex = layerIndex
        self.points = points
        self.style = style
    }
}

public struct SampledColor: Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}
