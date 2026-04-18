import Foundation

public enum SelectionToolMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case lasso
    case auto

    public var id: String { rawValue }
}

public enum ShapeToolMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case line
    case rectangle
    case ellipse
    case triangle
    case pentagon
    case hexagon

    public var id: String { rawValue }
}

public enum LayerBlendMode: String, CaseIterable, Equatable, Sendable, Identifiable {
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

    public var id: String { rawValue }
}

public enum ColorRangeSelectionSource: String, CaseIterable, Equatable, Sendable, Identifiable {
    case activeLayer
    case canvas

    public var id: String { rawValue }
}

public struct ColorRangeSelectionRequest: Equatable, Sendable {
    public let source: ColorRangeSelectionSource
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let tolerance: Double
    public let minimumAlpha: Double
    public let expansion: Int

    public init(
        source: ColorRangeSelectionSource,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        tolerance: Double,
        minimumAlpha: Double,
        expansion: Int
    ) {
        self.source = source
        self.red = red
        self.green = green
        self.blue = blue
        self.tolerance = tolerance
        self.minimumAlpha = minimumAlpha
        self.expansion = expansion
    }
}
