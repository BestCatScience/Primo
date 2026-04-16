import Foundation

extension AppFeature.State {
    var nanoBananaProgress: Double? {
        guard nanoBanana.isGenerating else { return nil }
        return 0.6
    }
}
