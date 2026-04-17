import CoreGraphics
import Foundation
import SwiftUI

extension AppFeature {
    static func clampUnit(_ value: CGFloat) -> CGFloat {
        max(0, min(1, value))
    }

    static func interpolate(_ from: CGFloat, _ to: CGFloat, amount: CGFloat) -> CGFloat {
        from + ((to - from) * amount)
    }

    static func rasterizedLuminance(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    }

    static func color(from sampledColor: SampledColor) -> Color {
        Color(
            red: Double(sampledColor.red) / 255.0,
            green: Double(sampledColor.green) / 255.0,
            blue: Double(sampledColor.blue) / 255.0,
            opacity: Double(sampledColor.alpha) / 255.0
        )
    }

    static func nanoBananaErrorFeedback(_ message: String) -> ApplicationFeedback {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .nanoBananaEditFailed(nil)
        }

        let normalized = trimmed.lowercased()
        if normalized.contains("invalid response") {
            return .nanoBananaInvalidResponse
        }
        if normalized.contains("invalid endpoint") {
            return .nanoBananaInvalidEndpoint
        }
        if normalized.contains("missing image")
            || normalized.contains("did not return decodable image")
            || normalized.contains("returned text instead of an image")
        {
            return .nanoBananaMissingImage
        }

        return .nanoBananaEditFailed(trimmed)
    }
}
