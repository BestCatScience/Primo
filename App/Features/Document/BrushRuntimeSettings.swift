import Foundation

struct BrushRuntimeSettings: Equatable, Sendable {
    var radius: Double
    var opacity: Double
    var hardness: Double
    var pressureSensitivity: Double
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var isEraser: Bool = false
}
