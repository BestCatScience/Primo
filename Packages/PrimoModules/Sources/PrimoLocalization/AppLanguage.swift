import Foundation

public enum AppLanguage: String, CaseIterable, Equatable, Sendable, Identifiable {
    case english
    case japanese

    public static let storageKey = "primo.appLanguage"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        }
    }
}
