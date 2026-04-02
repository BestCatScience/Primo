import Foundation

struct BrushRuntimeSettings: Equatable, Sendable {
    var tipKind: BrushTipKind
    var radius: Double
    var opacity: Double
    var hardness: Double
    var pressureSensitivity: Double
    var stabilization: Double = 0.0
    var fillThresholdMode: FillThresholdMode = .opacity
    var fillOpacityTolerance: Double = 0.0
    var fillColorTolerance: Double = 0.12
    var fillExpansion: Int = 0
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var isEraser: Bool = false
}
