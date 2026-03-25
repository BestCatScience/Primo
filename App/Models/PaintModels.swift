import Foundation
import SwiftUI
import CoreGraphics

struct BrushPreset: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let color: Color
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    static func == (lhs: BrushPreset, rhs: BrushPreset) -> Bool {
        lhs.name == rhs.name &&
        lhs.red == rhs.red &&
        lhs.green == rhs.green &&
        lhs.blue == rhs.blue
    }

    static let defaults: [BrushPreset] = [
        BrushPreset(name: "6B Pencil", color: Color(red: 0.12, green: 0.12, blue: 0.13), red: 31, green: 31, blue: 34),
        BrushPreset(name: "Indigo Ink", color: Color(red: 0.20, green: 0.24, blue: 0.42), red: 51, green: 61, blue: 107),
        BrushPreset(name: "Burnt Sienna", color: Color(red: 0.63, green: 0.31, blue: 0.20), red: 160, green: 79, blue: 51)
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

struct MetalLayerSnapshot: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
    let opacity: Float
    let visible: Bool
    let pixelData: Data

    static func == (lhs: MetalLayerSnapshot, rhs: MetalLayerSnapshot) -> Bool {
        lhs.index == rhs.index &&
        lhs.opacity == rhs.opacity &&
        lhs.visible == rhs.visible &&
        lhs.pixelData == rhs.pixelData
    }
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
        lhs.layers == rhs.layers
    }
}
