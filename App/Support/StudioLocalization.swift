import Foundation

enum AppLanguage: String, CaseIterable, Equatable, Sendable, Identifiable {
    case english
    case japanese

    static let storageKey = "atelierprime.appLanguage"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        }
    }

    static func load() -> AppLanguage {
        guard
            let rawValue = UserDefaults.standard.string(forKey: storageKey),
            let language = AppLanguage(rawValue: rawValue)
        else {
            return .japanese
        }
        return language
    }

    func persist() {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
    }
}

enum StudioStrings {
    static func appName(_ language: AppLanguage) -> String { "atelierprime" }

    static func settingsMenu(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Settings"
        case .japanese: return "設定"
        }
    }

    static func fileMenu(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "File"
        case .japanese: return "ファイル"
        }
    }

    static func editMenu(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Edit"
        case .japanese: return "編集"
        }
    }

    static func pageMenu(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Pages"
        case .japanese: return "ページ管理"
        }
    }

    static func layerMenu(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Layer"
        case .japanese: return "レイヤー"
        }
    }

    static func languageMenu(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Language"
        case .japanese: return "言語"
        }
    }

    static func newCanvas(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "New Canvas"
        case .japanese: return "新規キャンバス"
        }
    }

    static func customSize(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Custom Size..."
        case .japanese: return "カスタムサイズ..."
        }
    }

    static func open(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Open"
        case .japanese: return "開く"
        }
    }

    static func save(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Save"
        case .japanese: return "保存"
        }
    }

    static func export(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Export"
        case .japanese: return "書き出し"
        }
    }

    static func exportTimelapse(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Export Timelapse"
        case .japanese: return "タイムラプスを書き出し"
        }
    }

    static func refreshView(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Refresh View"
        case .japanese: return "表示を更新"
        }
    }

    static func addLayer(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "New Layer"
        case .japanese: return "新規レイヤー"
        }
    }

    static func clearActiveLayer(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Clear Active Layer"
        case .japanese: return "アクティブレイヤーをクリア"
        }
    }

    static func showBrushPanel(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Show Brush Panel"
        case .japanese: return "ブラシパネルを表示"
        }
    }

    static func hideBrushPanel(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Hide Brush Panel"
        case .japanese: return "ブラシパネルを隠す"
        }
    }

    static func showLayerPanel(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Show Layer Panel"
        case .japanese: return "レイヤーパネルを表示"
        }
    }

    static func hideLayerPanel(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Hide Layer Panel"
        case .japanese: return "レイヤーパネルを隠す"
        }
    }

    static func stackPanels(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Stack Panels"
        case .japanese: return "パネルを重ねる"
        }
    }

    static func unstackPanels(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Unstack Panels"
        case .japanese: return "パネルの重なりを解除"
        }
    }

    static func swapStackOrder(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Swap Stack Order"
        case .japanese: return "スタック順を入れ替え"
        }
    }

    static func showActiveLayer(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Show Active Layer"
        case .japanese: return "アクティブレイヤーを表示"
        }
    }

    static func hideActiveLayer(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Hide Active Layer"
        case .japanese: return "アクティブレイヤーを非表示"
        }
    }

    static func selectUpperLayer(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Select Layer Above"
        case .japanese: return "ひとつ上のレイヤーを選択"
        }
    }

    static func selectLowerLayer(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Select Layer Below"
        case .japanese: return "ひとつ下のレイヤーを選択"
        }
    }

    static func pagesAdd(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Add Page"
        case .japanese: return "ページを追加"
        }
    }

    static func pagesDuplicate(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Duplicate Page"
        case .japanese: return "ページを複製"
        }
    }

    static func pagesDelete(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Delete Page"
        case .japanese: return "ページを削除"
        }
    }

    static func size(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Size"
        case .japanese: return "サイズ"
        }
    }

    static func width(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Width"
        case .japanese: return "幅"
        }
    }

    static func height(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Height"
        case .japanese: return "高さ"
        }
    }

    static func cancel(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Cancel"
        case .japanese: return "キャンセル"
        }
    }

    static func create(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Create"
        case .japanese: return "作成"
        }
    }

    static func layers(_ count: Int, _ language: AppLanguage) -> String {
        switch language {
        case .english: return "\(count) Layers"
        case .japanese: return "\(count) レイヤー"
        }
    }

    static func layersTitle(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Layers"
        case .japanese: return "レイヤー"
        }
    }

    static func visible(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Visible"
        case .japanese: return "表示"
        }
    }

    static func hidden(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Hidden"
        case .japanese: return "非表示"
        }
    }

    static func active(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Active"
        case .japanese: return "選択中"
        }
    }

    static func standby(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Standby"
        case .japanese: return "待機"
        }
    }

    static func opacityValue(_ value: Int, _ language: AppLanguage) -> String {
        switch language {
        case .english: return "Opacity \(value)%"
        case .japanese: return "不透明度 \(value)%"
        }
    }
}
