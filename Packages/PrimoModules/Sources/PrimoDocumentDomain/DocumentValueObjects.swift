import Foundation

public struct UnitInterval: Equatable, Sendable {
    public let rawValue: Double

    public init?(_ rawValue: Double) {
        guard rawValue.isFinite, (0...1).contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct PositiveFiniteDouble: Equatable, Sendable {
    public let rawValue: Double

    public init?(_ rawValue: Double) {
        guard rawValue.isFinite, rawValue > 0 else { return nil }
        self.rawValue = rawValue
    }
}

public struct FiniteDouble: Equatable, Sendable {
    public let rawValue: Double

    public init?(_ rawValue: Double) {
        guard rawValue.isFinite else { return nil }
        self.rawValue = rawValue
    }
}

public struct CanvasColor: Equatable, Sendable {
    public let red: UnitInterval
    public let green: UnitInterval
    public let blue: UnitInterval
    public let alpha: UnitInterval

    public init(red: UnitInterval, green: UnitInterval, blue: UnitInterval, alpha: UnitInterval) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init?(red: Double, green: Double, blue: Double, alpha: Double) {
        guard let red = UnitInterval(red),
              let green = UnitInterval(green),
              let blue = UnitInterval(blue),
              let alpha = UnitInterval(alpha) else {
            return nil
        }
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
