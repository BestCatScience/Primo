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

    func localized(_ text: String) -> String {
        switch self {
        case .english:
            return StudioStrings.englishCatalog[text] ?? text
        case .japanese:
            return StudioStrings.japaneseCatalog[text] ?? text
        }
    }

}

enum StudioStrings {
    static let japaneseCatalog: [String: String] = [
        "Active Layer": "アクティブレイヤー",
        "Add": "加算",
        "Add Glow": "加算(発光)",
        "Airbrush": "エアブラシ",
        "Angle": "角度",
        "Angle Amount": "角度量",
        "Angle Control": "角度コントロール",
        "Apply": "適用",
        "Auto": "自動",
        "Backmost": "最背面",
        "Behavior": "動作",
        "Blend": "合成",
        "Brush": "ブラシ",
        "Brush Engine": "ブラシ設定",
        "Brush Library": "ブラシライブラリ",
        "Brush Settings": "ブラシ設定",
        "Brush Tip": "ブラシ先端",
        "Brush Tip Shape": "先端形状",
        "Cancel": "キャンセル",
        "Canvas": "キャンバス",
        "Clear Selection": "選択を解除",
        "Close Path": "パスを閉じる",
        "Color": "色",
        "Color Burn": "焼き込みカラー",
        "Color Dodge": "覆い焼きカラー",
        "Color Match": "色一致",
        "Color Threshold": "色しきい値",
        "Combine": "合成",
        "Could Not Import Brush": "ブラシを読み込めませんでした",
        "Count": "散布数",
        "Count Jitter": "数ジッター",
        "Current Color": "現在色",
        "Custom": "カスタム",
        "Custom Brush": "カスタムブラシ",
        "Custom Mix": "カスタム",
        "Darken": "比較(暗)",
        "Darker": "暗い方",
        "Darker Color": "カラー比較(暗)",
        "Difference": "差の絶対値",
        "Direction": "線方向",
        "Directional": "方向散布",
        "Divide": "除算",
        "Drag sideways to move": "左右ドラッグで移動",
        "Drag sideways to move, up/down to reorder": "左右ドラッグで移動、上下ドラッグで並び替え",
        "Drag to sample continuously": "ドラッグで連続取得",
        "Drop to left rail": "左レールへ移動",
        "Drop to right rail": "右レールへ移動",
        "Dual Angle": "デュアル角度",
        "Dual Brush": "デュアルブラシ",
        "Dual Scale": "デュアルサイズ",
        "Dual Scatter": "デュアル散布",
        "Dual Spacing": "デュアル間隔",
        "Dual Tip": "デュアル先端",
        "Each Tip": "先端ごと",
        "Enable Scatter": "散布を有効にする",
        "Enable dual brush": "デュアルブラシを使う",
        "Erase": "消しゴム",
        "Exclusion": "除外",
        "Expansion": "拡張",
        "Export failed": "書き出しに失敗しました",
        "Eyedropper": "スポイト設定",
        "Fill": "塗りつぶし",
        "Fill Color": "塗り色",
        "Fill Engine": "塗りつぶし設定",
        "Fixed": "固定",
        "Flow": "フロー",
        "Flow Amount": "フロー量",
        "Flow Control": "フローコントロール",
        "Freehand": "フリーハンド",
        "Gesture": "入力",
        "Glow Dodge": "覆い焼き(発光)",
        "Grain Contrast": "粒コントラスト",
        "Grain Scale": "粒状感",
        "Hard Light": "ハードライト",
        "Hard Mix": "ハードミックス",
        "Hardness": "硬さ",
        "Hue": "色相",
        "Idle": "待機",
        "Import": "読込",
        "Ink": "インク",
        "Input": "入力",
        "Lasso": "投げ縄",
        "Layer": "レイヤー",
        "Layer Opacity": "レイヤー不透明度",
        "Layers": "レイヤー",
        "Lighten": "比較(明)",
        "Lighter Color": "カラー比較(明)",
        "Linear Burn": "焼き込み(リニア)",
        "Linear Light": "リニアライト",
        "Levels": "レベル補正",
        "Tone Curve": "トーンカーブ",
        "Color Balance": "カラーバランス",
        "Threshold Adjustment": "2値化",
        "Posterize": "階調化",
        "Input Black": "入力(黒)",
        "Input White": "入力(白)",
        "Output Black": "出力(黒)",
        "Output White": "出力(白)",
        "Gamma": "ガンマ",
        "Shadows": "シャドウ",
        "Midtones": "中間調",
        "Highlights": "ハイライト",
        "Red/Cyan": "レッド/シアン",
        "Green/Magenta": "グリーン/マゼンタ",
        "Blue/Yellow": "ブルー/イエロー",
        "Level Count": "階調数",
        "Load Amount": "含み量",
        "Load Control": "含みコントロール",
        "Luminosity": "輝度",
        "Manage": "管理",
        "Match": "一致",
        "Mix Strength": "混色量",
        "Mixer Brush": "ミキサーブラシ",
        "Mode": "モード",
        "Move": "移動",
        "Move the active layer with Pencil. Nothing is committed until you apply.": "Apple Pencil でアクティブレイヤーを移動します。適用するまで確定されません。",
        "Move the selected area with Pencil. Nothing is committed until you apply.": "Apple Pencil で選択範囲を移動します。適用するまで確定されません。",
        "Moving": "移動",
        "Multiply": "乗算",
        "No presets yet.": "まだプリセットがありません。",
        "No supported sampled brushes were found.": "対応している先端が見つかりませんでした。",
        "Normal": "通常",
        "Not enough drawing history for timelapse yet": "タイムラプス用の描画履歴がまだ足りません",
        "Off": "オフ",
        "Oil": "油彩",
        "On": "オン",
        "Opacity": "不透明",
        "Opacity Amount": "不透明度量",
        "Opacity Control": "不透明度コントロール",
        "Opacity Match": "不透明度一致",
        "Opacity Threshold": "不透明度しきい値",
        "Overlay": "オーバーレイ",
        "Paint Load": "色の含み",
        "Paper": "紙質",
        "Paper Color": "用紙色",
        "Paper Scale": "紙目スケール",
        "Paper Strength": "紙質の強さ",
        "Paper Texture": "紙質テクスチャ",
        "Paper Threshold": "紙目しきい値",
        "Particle Opacity": "粒濃度ばらつき",
        "Particle Size": "粒サイズばらつき",
        "Pencil": "鉛筆",
        "Pending": "未確定",
        "Pin Light": "ピンライト",
        "Presets": "プリセット",
        "Radius": "半径",
        "Redo is unavailable while drawing": "描画中はやり直しできません",
        "Replace": "置換",
        "Rotation Mode": "回転モード",
        "Roundness": "形状の細さ",
        "Roundness Amount": "形状量",
        "Roundness Control": "形状コントロール",
        "Sampled Color": "取得色",
        "Sampling Source": "取得元",
        "Saturation": "彩度",
        "Save": "保存",
        "Save failed": "保存に失敗しました",
        "Saved": "保存済み",
        "Saved brushes appear here.": "保存したブラシがここに並びます。",
        "Scale": "拡大率",
        "Scatter": "散布",
        "Scatter Mode": "散布方式",
        "Scatter X": "横散布",
        "Scatter Y": "前後散布",
        "Scope": "対象",
        "Screen": "スクリーン",
        "Select": "選択",
        "Selection": "選択設定",
        "Selection Action": "選択アクション",
        "Selection Mode": "選択モード",
        "Selection Threshold Mode": "選択しきい値モード",
        "Settings": "設定",
        "Shape": "形状",
        "Size": "サイズ",
        "Size Amount": "サイズ量",
        "Size Control": "サイズコントロール",
        "Soft Light": "ソフトライト",
        "Source": "取得元",
        "Spacing": "スタンプ間隔",
        "Spacing Jitter": "間隔ジッター",
        "Speed Density": "速度で濃さを変える",
        "Spray": "スプレー",
        "Stabilization": "手ぶれ補正",
        "State": "状態",
        "Stroke": "ストローク固定",
        "Subtract": "削る",
        "Tap or drag with Apple Pencil to sample a color into the current paint color.": "Apple Pencil でタップまたはドラッグすると色を取得して現在色に反映します。",
        "Tap to sample, then use Move to transform": "タップで選択したあと、移動ツールで変形します",
        "Target": "対象",
        "Texture": "テクスチャ",
        "Texture Apply": "テクスチャ適用",
        "Threshold": "しきい値",
        "Threshold Mode": "しきい値モード",
        "Tilt": "傾き",
        "Timelapse export failed": "タイムラプスの書き出しに失敗しました",
        "Tip": "先端",
        "Tip Texture": "先端テクスチャ",
        "Trace with Pencil, then use Move to transform": "Apple Pencil で囲んだあと、移動ツールで変形します",
        "Transform": "変形",
        "Transparent": "透明",
        "Transparent Paper": "透明な用紙",
        "Undo is unavailable while drawing": "描画中は取り消しできません",
        "Visible": "表示",
        "Vivid Light": "ビビッドライト",
        "Wet": "ウェット",
        "Wet Amount": "ウェット量",
        "Wet Control": "ウェットコントロール",
        "File": "ファイル",
        "Edit": "編集",
        "Pages": "ページ管理",
        "Language": "言語",
        "New Canvas": "新規キャンバス",
        "Custom Size...": "カスタムサイズ...",
        "Open": "開く",
        "Export": "書き出し",
        "Export Timelapse": "タイムラプスを書き出し",
        "Refresh View": "表示を更新",
        "New Layer": "新規レイヤー",
        "New Folder": "新規フォルダ",
        "Clear Active Layer": "アクティブレイヤーをクリア",
        "Show Brush Panel": "ブラシパネルを表示",
        "Hide Brush Panel": "ブラシパネルを隠す",
        "Show Layer Panel": "レイヤーパネルを表示",
        "Hide Layer Panel": "レイヤーパネルを隠す",
        "Stack Panels": "パネルを重ねる",
        "Unstack Panels": "パネルの重なりを解除",
        "Swap Stack Order": "スタック順を入れ替え",
        "Show Active Layer": "アクティブレイヤーを表示",
        "Hide Active Layer": "アクティブレイヤーを非表示",
        "Select Layer Above": "ひとつ上のレイヤーを選択",
        "Select Layer Below": "ひとつ下のレイヤーを選択",
        "Add Page": "ページを追加",
        "Duplicate Page": "ページを複製",
        "Delete Page": "ページを削除",
        "Width": "幅",
        "Height": "高さ",
        "Create": "作成",
        "Hidden": "非表示",
        "Active": "選択中",
        "Standby": "待機",
        "Exporting timelapse...": "タイムラプスを書き出し中…",
        "Pressure": "筆圧",
        "Speed": "速度",
        "Random": "ランダム",
    ]
    static let englishCatalog: [String: String] = {
        var map: [String: String] = [:]
        for (english, japanese) in japaneseCatalog {
            map[japanese] = english
        }
        return map
    }()

    static func appName(_ language: AppLanguage) -> String { "atelierprime" }

    private static func localized(_ language: AppLanguage, english: String, japanese: String) -> String {
        switch language {
        case .english:
            return english
        case .japanese:
            return japanese
        }
    }

    static func savedDocument(_ filename: String, _ language: AppLanguage) -> String {
        localized(language, english: "Saved: \(filename)", japanese: "保存しました: \(filename)")
    }

    static func openedDocument(_ layerCount: Int, _ language: AppLanguage) -> String {
        localized(language, english: "Opened document with \(layerCount) layers", japanese: "\(layerCount)レイヤーの書類を開きました")
    }

    static func openFailed(_ language: AppLanguage) -> String {
        localized(language, english: "Open failed", japanese: "開くことができませんでした")
    }

    static func settingsMenu(_ language: AppLanguage) -> String { language.localized("設定") }
    static func fileMenu(_ language: AppLanguage) -> String { language.localized("ファイル") }
    static func editMenu(_ language: AppLanguage) -> String { language.localized("編集") }
    static func pageMenu(_ language: AppLanguage) -> String { language.localized("ページ管理") }
    static func layerMenu(_ language: AppLanguage) -> String { language.localized("レイヤー") }
    static func languageMenu(_ language: AppLanguage) -> String { language.localized("言語") }
    static func newCanvas(_ language: AppLanguage) -> String { language.localized("新規キャンバス") }
    static func customSize(_ language: AppLanguage) -> String { language.localized("カスタムサイズ...") }
    static func open(_ language: AppLanguage) -> String { language.localized("開く") }
    static func save(_ language: AppLanguage) -> String { language.localized("保存") }
    static func colorCorrection(_ language: AppLanguage) -> String { language.localized("色補正") }
    static func hueSaturationBrightness(_ language: AppLanguage) -> String { language.localized("色相・彩度・明度") }
    static func brightnessContrast(_ language: AppLanguage) -> String { language.localized("明度・コントラスト") }
    static func levels(_ language: AppLanguage) -> String { language.localized("レベル補正") }
    static func toneCurve(_ language: AppLanguage) -> String { language.localized("トーンカーブ") }
    static func colorBalance(_ language: AppLanguage) -> String { language.localized("カラーバランス") }
    static func thresholdAdjustment(_ language: AppLanguage) -> String { language.localized("2値化") }
    static func posterize(_ language: AppLanguage) -> String { language.localized("階調化") }
    static func gradientMap(_ language: AppLanguage) -> String { language.localized("グラデーションマップ") }
    static func export(_ language: AppLanguage) -> String { language.localized("書き出し") }
    static func exportTimelapse(_ language: AppLanguage) -> String { language.localized("タイムラプスを書き出し") }
    static func refreshView(_ language: AppLanguage) -> String { language.localized("表示を更新") }

    static func addLayer(_ language: AppLanguage) -> String { language.localized("新規レイヤー") }
    static func addFolder(_ language: AppLanguage) -> String { language.localized("新規フォルダ") }
    static func clearActiveLayer(_ language: AppLanguage) -> String { language.localized("アクティブレイヤーをクリア") }
    static func showBrushPanel(_ language: AppLanguage) -> String { language.localized("ブラシパネルを表示") }
    static func hideBrushPanel(_ language: AppLanguage) -> String { language.localized("ブラシパネルを隠す") }
    static func showLayerPanel(_ language: AppLanguage) -> String { language.localized("レイヤーパネルを表示") }
    static func hideLayerPanel(_ language: AppLanguage) -> String { language.localized("レイヤーパネルを隠す") }
    static func stackPanels(_ language: AppLanguage) -> String { language.localized("パネルを重ねる") }
    static func unstackPanels(_ language: AppLanguage) -> String { language.localized("パネルの重なりを解除") }
    static func swapStackOrder(_ language: AppLanguage) -> String { language.localized("スタック順を入れ替え") }
    static func showActiveLayer(_ language: AppLanguage) -> String { language.localized("アクティブレイヤーを表示") }
    static func hideActiveLayer(_ language: AppLanguage) -> String { language.localized("アクティブレイヤーを非表示") }
    static func selectUpperLayer(_ language: AppLanguage) -> String { language.localized("ひとつ上のレイヤーを選択") }
    static func selectLowerLayer(_ language: AppLanguage) -> String { language.localized("ひとつ下のレイヤーを選択") }
    static func pagesAdd(_ language: AppLanguage) -> String { language.localized("ページを追加") }
    static func pagesDuplicate(_ language: AppLanguage) -> String { language.localized("ページを複製") }
    static func pagesDelete(_ language: AppLanguage) -> String { language.localized("ページを削除") }
    static func apply(_ language: AppLanguage) -> String { language.localized("適用") }
    static func size(_ language: AppLanguage) -> String { language.localized("サイズ") }
    static func width(_ language: AppLanguage) -> String { language.localized("幅") }
    static func hue(_ language: AppLanguage) -> String { language.localized("色相") }
    static func saturation(_ language: AppLanguage) -> String { language.localized("彩度") }
    static func brightness(_ language: AppLanguage) -> String { language.localized("明度") }
    static func contrast(_ language: AppLanguage) -> String { language.localized("コントラスト") }
    static func threshold(_ language: AppLanguage) -> String { language.localized("しきい値") }
    static func inputBlack(_ language: AppLanguage) -> String { language.localized("入力(黒)") }
    static func inputWhite(_ language: AppLanguage) -> String { language.localized("入力(白)") }
    static func outputBlack(_ language: AppLanguage) -> String { language.localized("出力(黒)") }
    static func outputWhite(_ language: AppLanguage) -> String { language.localized("出力(白)") }
    static func gamma(_ language: AppLanguage) -> String { language.localized("ガンマ") }
    static func shadows(_ language: AppLanguage) -> String { language.localized("シャドウ") }
    static func midtones(_ language: AppLanguage) -> String { language.localized("中間調") }
    static func highlights(_ language: AppLanguage) -> String { language.localized("ハイライト") }
    static func redCyan(_ language: AppLanguage) -> String { language.localized("レッド/シアン") }
    static func greenMagenta(_ language: AppLanguage) -> String { language.localized("グリーン/マゼンタ") }
    static func blueYellow(_ language: AppLanguage) -> String { language.localized("ブルー/イエロー") }
    static func levelCount(_ language: AppLanguage) -> String { language.localized("階調数") }
    static func height(_ language: AppLanguage) -> String { language.localized("高さ") }
    static func cancel(_ language: AppLanguage) -> String { language.localized("キャンセル") }
    static func create(_ language: AppLanguage) -> String { language.localized("作成") }

    static func layers(_ count: Int, _ language: AppLanguage) -> String {
        localized(language, english: "\(count) Layers", japanese: "\(count) レイヤー")
    }

    static func folderName(_ count: Int, _ language: AppLanguage) -> String {
        localized(language, english: "Folder \(count)", japanese: "フォルダ \(count)")
    }

    static func moveOutOfFolder(_ language: AppLanguage) -> String {
        localized(language, english: "Move Out Of Folder", japanese: "フォルダ外へ戻す")
    }

    static func dropToMoveOutOfFolder(_ language: AppLanguage) -> String {
        localized(language, english: "Drop here to move out of folder", japanese: "ここにドロップでフォルダ外へ戻す")
    }

    static func layersTitle(_ language: AppLanguage) -> String { language.localized("レイヤー") }
    static func visible(_ language: AppLanguage) -> String { language.localized("表示") }
    static func hidden(_ language: AppLanguage) -> String { language.localized("非表示") }
    static func active(_ language: AppLanguage) -> String { language.localized("選択中") }
    static func standby(_ language: AppLanguage) -> String { language.localized("待機") }

    static func opacityValue(_ value: Int, _ language: AppLanguage) -> String {
        localized(language, english: "Opacity \(value)%", japanese: "不透明度 \(value)%")
    }

    static func exportingTimelapse(_ language: AppLanguage) -> String { language.localized("タイムラプスを書き出し中…") }

    static func dynamicControlOff(_ language: AppLanguage) -> String {
        localized(language, english: "Off", japanese: "なし")
    }

    static func dynamicControlPressure(_ language: AppLanguage) -> String { language.localized("筆圧") }
    static func dynamicControlTilt(_ language: AppLanguage) -> String { language.localized("傾き") }
    static func dynamicControlSpeed(_ language: AppLanguage) -> String { language.localized("速度") }
    static func dynamicControlRandom(_ language: AppLanguage) -> String { language.localized("ランダム") }

    static func brushSettingsCategoryTip(_ language: AppLanguage) -> String { language.localized("先端") }
    static func brushSettingsCategoryScatter(_ language: AppLanguage) -> String { language.localized("散布") }

    static func brushSettingsCategoryStroke(_ language: AppLanguage) -> String {
        localized(language, english: "Stroke", japanese: "描画")
    }

    static func brushSettingsCategoryTexture(_ language: AppLanguage) -> String {
        localized(language, english: "Texture", japanese: "質感")
    }
}
