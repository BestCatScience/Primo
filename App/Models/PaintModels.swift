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
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .brush:
            return language == .japanese ? "ブラシ" : "Brush"
        case .erase:
            return language == .japanese ? "消しゴム" : "Erase"
        case .fill:
            return language == .japanese ? "塗りつぶし" : "Fill"
        case .select:
            return language == .japanese ? "選択" : "Select"
        case .move:
            return language == .japanese ? "移動" : "Move"
        case .shape:
            return language == .japanese ? "図形" : "Shape"
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
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .opacity:
            return language == .japanese ? "不透明度" : "Opacity"
        case .color:
            return language == .japanese ? "色" : "Color"
        }
    }
}

enum SelectionToolMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case lasso
    case auto

    var id: String { rawValue }

    var title: String {
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .lasso:
            return language == .japanese ? "投げ縄" : "Lasso"
        case .auto:
            return language == .japanese ? "自動" : "Auto"
        }
    }
}

enum SelectionCombineMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case replace
    case add
    case subtract

    var id: String { rawValue }

    var title: String {
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .replace:
            return language == .japanese ? "置換" : "Replace"
        case .add:
            return language == .japanese ? "加算" : "Add"
        case .subtract:
            return language == .japanese ? "減算" : "Subtract"
        }
    }
}

enum LayerBlendMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case normal
    case darken
    case multiply
    case colorBurn
    case linearBurn
    case subtract
    case lighten
    case screen
    case colorDodge
    case glowDodge
    case overlay
    case softLight
    case hardLight
    case difference
    case vividLight
    case linearLight
    case pinLight
    case hardMix
    case exclusion
    case darkerColor
    case lighterColor
    case divide
    case hue
    case saturation
    case color
    case add
    case addGlow
    case luminosity

    var id: String { rawValue }

    var title: String {
        localizedTitle(.japanese)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .normal:
            return language == .japanese ? "通常" : "Normal"
        case .darken:
            return language == .japanese ? "比較(暗)" : "Darken"
        case .multiply:
            return language == .japanese ? "乗算" : "Multiply"
        case .colorBurn:
            return language == .japanese ? "焼き込みカラー" : "Color Burn"
        case .linearBurn:
            return language == .japanese ? "焼き込み(リニア)" : "Linear Burn"
        case .subtract:
            return language == .japanese ? "減算" : "Subtract"
        case .lighten:
            return language == .japanese ? "比較(明)" : "Lighten"
        case .screen:
            return language == .japanese ? "スクリーン" : "Screen"
        case .colorDodge:
            return language == .japanese ? "覆い焼きカラー" : "Color Dodge"
        case .glowDodge:
            return language == .japanese ? "覆い焼き(発光)" : "Glow Dodge"
        case .overlay:
            return language == .japanese ? "オーバーレイ" : "Overlay"
        case .softLight:
            return language == .japanese ? "ソフトライト" : "Soft Light"
        case .hardLight:
            return language == .japanese ? "ハードライト" : "Hard Light"
        case .difference:
            return language == .japanese ? "差の絶対値" : "Difference"
        case .vividLight:
            return language == .japanese ? "ビビッドライト" : "Vivid Light"
        case .linearLight:
            return language == .japanese ? "リニアライト" : "Linear Light"
        case .pinLight:
            return language == .japanese ? "ピンライト" : "Pin Light"
        case .hardMix:
            return language == .japanese ? "ハードミックス" : "Hard Mix"
        case .exclusion:
            return language == .japanese ? "除外" : "Exclusion"
        case .darkerColor:
            return language == .japanese ? "カラー比較(暗)" : "Darker Color"
        case .lighterColor:
            return language == .japanese ? "カラー比較(明)" : "Lighter Color"
        case .divide:
            return language == .japanese ? "除算" : "Divide"
        case .hue:
            return language == .japanese ? "色相" : "Hue"
        case .saturation:
            return language == .japanese ? "彩度" : "Saturation"
        case .color:
            return language == .japanese ? "カラー" : "Color"
        case .add:
            return language == .japanese ? "加算" : "Add"
        case .addGlow:
            return language == .japanese ? "加算(発光)" : "Add Glow"
        case .luminosity:
            return language == .japanese ? "輝度" : "Luminosity"
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
        localizedTitle(.english)
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .pencil:
            return language == .japanese ? "鉛筆" : "Pencil"
        case .ink:
            return language == .japanese ? "インク" : "Ink"
        case .oil:
            return language == .japanese ? "油彩" : "Oil"
        case .airbrush:
            return language == .japanese ? "エアブラシ" : "Airbrush"
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

struct CanvasPaperStyle: Equatable, Sendable {
    var red: Float
    var green: Float
    var blue: Float
    var alpha: Float
    var isTransparent: Bool

    static let `default` = CanvasPaperStyle(
        red: 0.93,
        green: 0.93,
        blue: 0.91,
        alpha: 1.0,
        isTransparent: false
    )
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
    let blendMode: LayerBlendMode

    static func == (lhs: LayerRowModel, rhs: LayerRowModel) -> Bool {
        lhs.index == rhs.index &&
        lhs.name == rhs.name &&
        lhs.visible == rhs.visible &&
        lhs.opacity == rhs.opacity &&
        lhs.blendMode == rhs.blendMode
    }
}

struct LayerCanvasBuffer: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
    var name: String
    var visible: Bool
    var opacity: Double
    var blendMode: LayerBlendMode = .normal
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
    let stabilization: CGFloat
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
    let blendMode: LayerBlendMode
    let thumbnailData: Data?
    let pixelData: Data

    static func == (lhs: MetalLayerSnapshot, rhs: MetalLayerSnapshot) -> Bool {
        lhs.index == rhs.index &&
        lhs.opacity == rhs.opacity &&
        lhs.visible == rhs.visible &&
        lhs.blendMode == rhs.blendMode &&
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
    let compositePixelData: Data
    let layers: [MetalLayerSnapshot]

    static func == (lhs: MetalDocumentSnapshot, rhs: MetalDocumentSnapshot) -> Bool {
        lhs.width == rhs.width &&
        lhs.height == rhs.height &&
        lhs.revision == rhs.revision &&
        lhs.compositePixelData.count == rhs.compositePixelData.count &&
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
