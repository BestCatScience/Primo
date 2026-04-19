import Foundation
import PrimoNanoBananaDomain

extension NanoBananaEditScope {
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .wholeLayer:
            return language.localized("レイヤー全体")
        case .selectedArea:
            return language.localized("選択範囲")
        }
    }
}

extension NanoBananaOutputMode {
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .replaceCurrentLayer:
            return language.localized("現在のレイヤーを置き換え")
        case .newLayer:
            return language.localized("新規レイヤー")
        }
    }
}

extension NanoBananaModel {
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .flashImage25:
            return "Nano Banana"
        case .flashImage31Preview:
            return "Nano Banana 2"
        case .proImagePreview:
            return "Nano Banana Pro"
        }
    }
}

extension NanoBananaAccessMode {
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .userAPIKey:
            return language.localized("ユーザー API キー")
        case .appManaged:
            return language.localized("アプリ課金プラン")
        }
    }
}
