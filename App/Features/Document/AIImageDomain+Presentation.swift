import Foundation
import PrimoAIImageDomain

extension AIImageEditScope {
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .wholeLayer:
            return language.localized("レイヤー全体")
        case .selectedArea:
            return language.localized("選択範囲")
        }
    }
}

extension AIImageOutputMode {
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .replaceCurrentLayer:
            return language.localized("現在のレイヤーを置き換え")
        case .newLayer:
            return language.localized("新規レイヤー")
        }
    }
}

extension AIImageModel {
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .flashImage31Preview:
            return "Nano Banana 2"
        case .proImagePreview:
            return "Nano Banana Pro"
        case .gptImage2:
            return "GPT Image 2"
        }
    }
}

extension AIImageAccessMode {
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .userAPIKey:
            return language.localized("直接接続")
        case .appManaged:
            return language.localized("アプリ課金プラン")
        }
    }
}
