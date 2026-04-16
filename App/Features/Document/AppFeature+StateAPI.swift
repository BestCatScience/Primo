import Foundation

extension AppFeature.State {
    var nanoBananaProgress: Double? {
        guard isNanoBananaGenerating else { return nil }
        return 0.6
    }
}
