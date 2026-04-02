import Foundation
import SwiftUI
import CoreGraphics
import simd

enum StudioToolKind: String, CaseIterable, Equatable, Sendable, Identifiable {
    case brush
    case erase
    case fill
    case select
    case move
    case shape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brush:
            return "Brush"
        case .erase:
            return "Erase"
        case .fill:
            return "Fill"
        case .select:
            return "Select"
        case .move:
            return "Move"
        case .shape:
            return "Shape"
        }
    }

    var systemImage: String {
        switch self {
        case .brush:
            return "paintbrush.pointed"
        case .erase:
            return "eraser"
        case .fill:
            return "paintbrush.fill"
        case .select:
            return "lasso"
        case .move:
            return "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left"
        case .shape:
            return "square.on.circle"
        }
    }
}

enum FillThresholdMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case opacity
    case color

    var id: String { rawValue }

    var title: String {
        switch self {
        case .opacity:
            return "Opacity"
        case .color:
            return "Color"
        }
    }
}

enum SelectionToolMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case lasso
    case auto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lasso:
            return "Lasso"
        case .auto:
            return "Auto"
        }
    }
}

enum SelectionCombineMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case replace
    case add
    case subtract

    var id: String { rawValue }

    var title: String {
        switch self {
        case .replace:
            return "Replace"
        case .add:
            return "Add"
        case .subtract:
            return "Subtract"
        }
    }
}

enum BrushTipKind: String, CaseIterable, Equatable, Sendable, Identifiable {
    case pencil
    case ink
    case oil
    case airbrush

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pencil:
            return "Pencil"
        case .ink:
            return "Ink"
        case .oil:
            return "Oil"
        case .airbrush:
            return "Airbrush"
        }
    }

    var systemImage: String {
        switch self {
        case .pencil:
            return "pencil.tip"
        case .ink:
            return "paintbrush.pointed"
        case .oil:
            return "paintbrush"
        case .airbrush:
            return "aqi.low"
        }
    }
}

struct BrushPreset: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let tipKind: BrushTipKind
    let color: Color
    let radius: Double
    let opacity: Double
    let hardness: Double
    let pressureSensitivity: Double
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    static func == (lhs: BrushPreset, rhs: BrushPreset) -> Bool {
        lhs.name == rhs.name &&
        lhs.tipKind == rhs.tipKind &&
        lhs.radius == rhs.radius &&
        lhs.opacity == rhs.opacity &&
        lhs.hardness == rhs.hardness &&
        lhs.pressureSensitivity == rhs.pressureSensitivity &&
        lhs.red == rhs.red &&
        lhs.green == rhs.green &&
        lhs.blue == rhs.blue
    }

    static let defaults: [BrushPreset] = [
        BrushPreset(
            name: "6B Pencil",
            tipKind: .pencil,
            color: Color(red: 0.12, green: 0.12, blue: 0.13),
            radius: 3.2,
            opacity: 0.92,
            hardness: 0.80,
            pressureSensitivity: 0.62,
            red: 31, green: 31, blue: 34
        ),
        BrushPreset(
            name: "Fine Liner",
            tipKind: .ink,
            color: Color(red: 0.07, green: 0.08, blue: 0.10),
            radius: 1.5,
            opacity: 0.98,
            hardness: 0.96,
            pressureSensitivity: 0.32,
            red: 18, green: 21, blue: 26
        ),
        BrushPreset(
            name: "Indigo Ink",
            tipKind: .ink,
            color: Color(red: 0.20, green: 0.24, blue: 0.42),
            radius: 2.8,
            opacity: 0.88,
            hardness: 0.72,
            pressureSensitivity: 0.44,
            red: 51, green: 61, blue: 107
        ),
        BrushPreset(
            name: "Soft Airbrush",
            tipKind: .airbrush,
            color: Color(red: 0.10, green: 0.10, blue: 0.11),
            radius: 8.5,
            opacity: 0.16,
            hardness: 0.10,
            pressureSensitivity: 0.18,
            red: 25, green: 25, blue: 29
        ),
        BrushPreset(
            name: "Wash Airbrush",
            tipKind: .airbrush,
            color: Color(red: 0.16, green: 0.19, blue: 0.26),
            radius: 11.0,
            opacity: 0.10,
            hardness: 0.06,
            pressureSensitivity: 0.10,
            red: 41, green: 49, blue: 66
        ),
        BrushPreset(
            name: "Burnt Sienna",
            tipKind: .oil,
            color: Color(red: 0.63, green: 0.31, blue: 0.20),
            radius: 3.8,
            opacity: 0.84,
            hardness: 0.66,
            pressureSensitivity: 0.40,
            red: 160, green: 79, blue: 51
        ),
        BrushPreset(
            name: "Flat Oil",
            tipKind: .oil,
            color: Color(red: 0.18, green: 0.26, blue: 0.61),
            radius: 6.0,
            opacity: 0.80,
            hardness: 0.72,
            pressureSensitivity: 0.36,
            red: 46, green: 66, blue: 156
        ),
        BrushPreset(
            name: "HB Sketch",
            tipKind: .pencil,
            color: Color(red: 0.25, green: 0.25, blue: 0.27),
            radius: 2.2,
            opacity: 0.70,
            hardness: 0.68,
            pressureSensitivity: 0.82,
            red: 64, green: 64, blue: 69
        )
    ]

    static let defaultPencil = defaults[0]
}

struct LayerRowModel: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
    let name: String
    let visible: Bool
    let opacity: Double

    static func == (lhs: LayerRowModel, rhs: LayerRowModel) -> Bool {
        lhs.index == rhs.index &&
        lhs.name == rhs.name &&
        lhs.visible == rhs.visible &&
        lhs.opacity == rhs.opacity
    }
}

struct LayerCanvasBuffer: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
    var name: String
    var visible: Bool
    var opacity: Double
    var strokes: [PreviewStrokeTrack] = []
}

struct StylusSample: Equatable {
    let point: CGPoint
    let pressure: CGFloat
    let altitude: CGFloat
    let azimuth: CGFloat
    let timestamp: TimeInterval

    static func == (lhs: StylusSample, rhs: StylusSample) -> Bool {
        lhs.point == rhs.point &&
        lhs.pressure == rhs.pressure &&
        lhs.altitude == rhs.altitude &&
        lhs.azimuth == rhs.azimuth &&
        lhs.timestamp == rhs.timestamp
    }
}

struct StrokePoint: Equatable {
    var position: SIMD2<Float>
    var pressure: Float
    var altitude: Float
    var azimuth: Float
    var timestamp: Double
    var isPredicted: Bool

    var cgPoint: CGPoint {
        CGPoint(x: CGFloat(position.x), y: CGFloat(position.y))
    }

    var stylusSample: StylusSample {
        StylusSample(
            point: cgPoint,
            pressure: CGFloat(pressure),
            altitude: CGFloat(altitude),
            azimuth: CGFloat(azimuth),
            timestamp: timestamp
        )
    }

    var previewPoint: PreviewStrokePoint {
        PreviewStrokePoint(
            point: cgPoint,
            pressure: CGFloat(pressure)
        )
    }
}

struct Stroke: Equatable {
    var points: [StrokePoint] = []
    var predictedPoints: [StrokePoint] = []
    var color: SIMD4<Float> = SIMD4(0, 0, 0, 1)
    var brushSize: Float = 4.0

    var confirmedPreviewPoints: [PreviewStrokePoint] {
        points.map(\.previewPoint)
    }

    var predictedPreviewPoints: [PreviewStrokePoint] {
        predictedPoints.map(\.previewPoint)
    }
}

struct PreviewStrokePoint: Identifiable, Equatable {
    let id = UUID()
    let point: CGPoint
    let pressure: CGFloat

    static func == (lhs: PreviewStrokePoint, rhs: PreviewStrokePoint) -> Bool {
        lhs.id == rhs.id &&
        lhs.point == rhs.point &&
        lhs.pressure == rhs.pressure
    }
}

struct PreviewStrokeStyle: Equatable {
    let tipKind: BrushTipKind
    let isEraser: Bool
    let radius: CGFloat
    let opacity: CGFloat
    let hardness: CGFloat
    let pressureSensitivity: CGFloat
    let color: CGColor
}

struct PreviewStrokeTrack: Identifiable, Equatable {
    let id = UUID()
    let layerIndex: Int
    let points: [PreviewStrokePoint]
    let style: PreviewStrokeStyle

    static func == (lhs: PreviewStrokeTrack, rhs: PreviewStrokeTrack) -> Bool {
        lhs.id == rhs.id &&
        lhs.layerIndex == rhs.layerIndex &&
        lhs.points == rhs.points &&
        lhs.style == rhs.style
    }
}

struct MetalLayerSnapshot: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
    let opacity: Float
    let visible: Bool
    let thumbnailData: Data?
    let pixelData: Data

    static func == (lhs: MetalLayerSnapshot, rhs: MetalLayerSnapshot) -> Bool {
        lhs.index == rhs.index &&
        lhs.opacity == rhs.opacity &&
        lhs.visible == rhs.visible &&
        lhs.thumbnailData?.count == rhs.thumbnailData?.count &&
        lhs.pixelData.count == rhs.pixelData.count
    }
}

struct TimelapseFrame: Equatable, Sendable {
    let imageData: Data
    let size: CGSize
}

struct TimelapseCapture: Equatable, Sendable {
    let canvasSize: CGSize
    let frames: [TimelapseFrame]
    let framesPerSecond: Int
}

struct MetalDocumentSnapshot: Equatable {
    let width: Int
    let height: Int
    let revision: Int
    let layers: [MetalLayerSnapshot]

    static func == (lhs: MetalDocumentSnapshot, rhs: MetalDocumentSnapshot) -> Bool {
        lhs.width == rhs.width &&
        lhs.height == rhs.height &&
        lhs.revision == rhs.revision &&
        lhs.layers.count == rhs.layers.count
    }
}

struct IncrementalLayerUpdate: Equatable, Identifiable {
    let id = UUID()
    let layerIndex: Int
    let originX: Int
    let originY: Int
    let width: Int
    let height: Int
    let pixelData: Data

    var isEmpty: Bool { width <= 0 || height <= 0 || pixelData.isEmpty }

    static func == (lhs: IncrementalLayerUpdate, rhs: IncrementalLayerUpdate) -> Bool {
        lhs.id == rhs.id
    }
}

struct CanvasSelection: Equatable {
    let bounds: CGRect
    let maskWidth: Int
    let maskHeight: Int
    let maskData: Data
    let mode: SelectionToolMode

    var isEmpty: Bool {
        maskWidth <= 0 || maskHeight <= 0 || maskData.isEmpty || bounds.isNull || bounds.isEmpty
    }
}
