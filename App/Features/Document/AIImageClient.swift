import Foundation

enum AIImagePromptPreset: String, CaseIterable, Equatable, Sendable, Identifiable {
    case retouch
    case relight
    case cleanup
    case variant

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .retouch:
            return language.localized("整える")
        case .relight:
            return language.localized("ライティング変更")
        case .cleanup:
            return language.localized("ノイズ除去")
        case .variant:
            return language.localized("バリエーション")
        }
    }

    func prompt(_ language: AppLanguage) -> String {
        switch self {
        case .retouch:
            return language.localized("線や輪郭を整え、細部を少し描き込み、自然できれいな陰影にしてください。")
        case .relight:
            return language.localized("構図はそのままにして、よりドラマチックでシネマティックな光に変えてください。")
        case .cleanup:
            return language.localized("元の絵柄と色を保ったまま、不要な汚れやノイズ、乱れを取り除いてください。")
        case .variant:
            return language.localized("全体の構図と被写体を保ったまま、この画像の近いバリエーションを作ってください。")
        }
    }
}
