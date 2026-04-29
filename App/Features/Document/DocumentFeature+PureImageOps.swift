import CoreGraphics
import Foundation
import PrimoDocumentContracts
import SwiftUI

extension DocumentFeature {
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

    static func aiImageFailureFeedback(_ failure: AIImageEditFailure) -> ApplicationFeature.Feedback {
        switch failure {
        case .invalidResponse:
            return .aiImageInvalidResponse
        case .invalidEndpoint:
            return .aiImageInvalidEndpoint
        case .missingImageData:
            return .aiImageMissingImage
        case let .apiError(message),
             let .transport(message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? .aiImageEditFailed(nil) : .aiImageEditFailed(trimmed)
        }
    }
}
