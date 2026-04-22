import Foundation

public enum BrushTipKind: String, CaseIterable, Equatable, Sendable, Identifiable {
    case pencil
    case ink
    case oil
    case airbrush

    public var id: String { rawValue }
}

public enum BrushAngleMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case fixed
    case strokeDirection
    case stylusTilt

    public var id: String { rawValue }
}

public enum BrushTextureMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case off
    case strokeLocked
    case eachTip
    case moving

    public var id: String { rawValue }
}

public enum BrushDualBlendMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case multiply
    case darker
    case subtract

    public var id: String { rawValue }
}

public enum BrushScatterMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case directional
    case spray

    public var id: String { rawValue }
}

public enum BrushColorMixingMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case off
    case blend
    case runningColor
    case smear

    public var id: String { rawValue }

    public static func inferred(
        wetness: Double,
        colorMixStrength: Double,
        smudgeBlurEnabled: Bool,
        smudgeBleed: Double,
        smudgeRadius: Double,
        paintLoad: Double
    ) -> BrushColorMixingMode {
        if smudgeBlurEnabled || smudgeBleed > 0.001 || smudgeRadius > 0.001 {
            return .runningColor
        }
        if wetness > 0.001 || colorMixStrength > 0.001 {
            return paintLoad <= 0.18 ? .smear : .blend
        }
        return .off
    }
}

public enum BrushSmudgeMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case smearing
    case dulling

    public var id: String { rawValue }
}
