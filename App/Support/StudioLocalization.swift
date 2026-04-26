import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoLocalization

typealias AppLanguage = PrimoLocalization.AppLanguage

extension AppLanguage {
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
        "Clipping Mask": "クリッピングマスク",
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
        "Color Smudge": "にじみ塗り",
        "Enable Color Smudge": "にじみ塗りを使う",
        "Smudge": "にじみ",
        "Enable Smudge": "にじみを使う",
        "Smudge Mode": "にじみモード",
        "Smearing": "のばし",
        "Dulling": "混色",
        "Smudge Length": "にじみ量",
        "Color Rate": "色の割合",
        "Smudge Radius": "にじみ半径",
        "Mix Pressure": "混色の筆圧",
        "Paint Amount": "絵の具量",
        "Paint Density": "絵の具濃度",
        "Color Stretch": "色延び",
        "Paint Amount Pressure Bypass": "絵の具量 筆圧なし",
        "Paint Density Pressure Bypass": "絵の具濃度 筆圧なし",
        "Color Stretch Pressure Bypass": "色延び 筆圧なし",
        "Smudge Soft": "にじみソフト",
        "Smudge Pull": "にじみプル",
        "Dulling Mixer": "混色ミキサー",
        "Darken": "比較(暗)",
        "Darker": "暗い方",
        "Darker Color": "カラー比較(暗)",
        "Difference": "差の絶対値",
        "Duplicate Layer": "レイヤーを複製",
        "Direction": "線方向",
        "Directional": "方向散布",
        "Divide": "除算",
        "Font": "フォント",
        "Positioned": "配置済み",
        "Not placed": "未配置",
        "New": "新規",
        "Editing": "編集中",
        "Placement": "配置",
        "Text": "テキスト",
        "Text Size": "文字サイズ",
        "Text Settings": "テキスト設定",
        "Add Font": "フォントを追加",
        "Add Text Layer": "テキストレイヤーを追加",
        "Update Text": "テキストを更新",
        "Tap the canvas to place your text.": "キャンバスをタップしてテキスト位置を決めてください。",
        "Tap the canvas to choose a position, then configure text and font before applying it to a layer.": "キャンバスをタップして位置を決め、文字とフォントを設定してレイヤーへ適用します。",
        "Could Not Import Font": "フォントを読み込めませんでした",
        "Could not apply text to the layer": "テキストをレイヤーに適用できませんでした",
        "System": "システム",
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
        "Layer Lock": "レイヤーロック",
        "Layer Opacity": "レイヤー不透明度",
        "Layers": "レイヤー",
        "Alpha Lock": "アルファロック",
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
        "Rotation": "回転",
        "Move the active layer with Pencil. Nothing is committed until you apply.": "Apple Pencil でアクティブレイヤーを移動します。適用するまで確定されません。",
        "Move the selected area with Pencil. Nothing is committed until you apply.": "Apple Pencil で選択範囲を移動します。適用するまで確定されません。",
        "Nano Banana": "Nano Banana",
        "Nano Banana Edit": "Nano Banana で編集",
        "Edit the active layer with Nano Banana": "Nano Banana でアクティブレイヤーを編集",
        "Prompt": "プロンプト",
        "Describe how Nano Banana should edit the active layer": "Nano Banana にどう編集させたいか入力してください",
        "Gemini API Key": "Gemini API キー",
        "Saved locally on this device": "この端末内に保存されます",
        "Generate": "生成",
        "Generating with Nano Banana": "Nano Banana で生成中",
        "Selection Modify Amount": "選択変更量",
        "Pixels": "ピクセル",
        "Invert Selection": "選択を反転",
        "Expand Selection": "選択を拡張",
        "Contract Selection": "選択を縮小",
        "Nano Banana generation canceled": "Nano Banana の生成をキャンセルしました",
        "Access": "接続方式",
        "User API Key": "ユーザー API キー",
        "App Subscription": "アプリ課金プラン",
        "Status": "状態",
        "Active": "有効",
        "Inactive": "未購入",
        "Plan": "プラン",
        "Purchase Subscription": "サブスクリプションを購入",
        "Restore Purchases": "購入を復元",
        "Manage Subscription": "サブスクリプションを管理",
        "Subscription Required": "サブスクリプションが必要です",
        "Unlock Nano Banana": "Nano Banana を有効化",
        "Use Primo subscription to run Nano Banana without your own API key": "Primo のサブスクリプションで、自分の API キーなしに Nano Banana を利用できます",
        "Included": "含まれる内容",
        "Unlimited app-managed Nano Banana edits": "アプリ管理の Nano Banana 編集を利用可能",
        "Purchase state syncs automatically": "購入状態を自動で同期",
        "Restore purchases on a new device": "新しい端末でも購入を復元可能",
        "Loading subscription details…": "サブスクリプション情報を読み込み中…",
        "Input Layer": "入力レイヤー",
        "Edit Scope": "編集範囲",
        "Whole Layer": "レイヤー全体",
        "Selected Area Only": "選択範囲のみ",
        "Subscription product is unavailable.": "サブスクリプション商品は利用できません",
        "Move failed": "移動に失敗しました",
        "Could not restore autosave": "自動保存を復元できませんでした",
        "Could not restore save history": "保存履歴を復元できませんでした",
        "Could not create a tab": "タブを作成できませんでした",
        "Canvas size is not supported": "このキャンバスサイズはサポートされていません",
        "Image resolution updated": "画像の解像度を更新しました",
        "Canvas size updated": "キャンバスサイズを更新しました",
        "Selected Area": "選択範囲",
        "Create a selection to enable inpaint": "インペイントを使うには選択範囲を作成してください",
        "Create a selection to use inpaint": "インペイント用の選択範囲を作成してください",
        "Create Mask From Selection": "選択範囲からマスク作成",
        "Delete Mask": "マスクを削除",
        "Delete Active Layer": "アクティブレイヤーを削除",
        "Apply Mask": "マスクを適用",
        "Create a selection before adding a mask": "選択範囲を作成してからマスクを追加してください",
        "Could not create layer mask": "レイヤーマスクを作成できませんでした",
        "Could not apply layer mask": "レイヤーマスクを適用できませんでした",
        "Could not apply gradient map": "グラデーションマップを適用できませんでした",
        "Could not apply color adjustment": "色補正を適用できませんでした",
        "Mask Expansion": "マスク拡張",
        "Invert Mask": "マスクを反転",
        "Jobs": "ジョブ",
        "History": "履歴",
        "Retry": "再試行",
        "Discard": "破棄",
        "Regenerate": "再生成",
        "Review Nano Banana Result": "Nano Banana の結果を確認",
        "Retouch": "整える",
        "Relight": "ライティング変更",
        "Cleanup": "ノイズ除去",
        "Variant": "バリエーション",
        "Line Cleanup": "線を整える",
        "Colorize": "色を塗る",
        "Add Background": "背景を追加",
        "Lighting Pass": "陰影を追加",
        "Refine this artwork with cleaner edges, improved detail, and polished shading.": "線や輪郭を整え、細部を少し描き込み、自然できれいな陰影にしてください。",
        "Keep the composition the same, but change the lighting to feel more dramatic and cinematic.": "構図はそのままにして、よりドラマチックでシネマティックな光に変えてください。",
        "Clean up artifacts and unwanted marks while preserving the original style and colors.": "元の絵柄と色を保ったまま、不要な汚れやノイズ、乱れを取り除いてください。",
        "Create a close variation of this image while preserving the overall composition and subject.": "全体の構図と被写体を保ったまま、この画像の近いバリエーションを作ってください。",
        "Clean up the line art, keep the original drawing, and improve line confidence without changing the design.": "元の絵柄を変えずに線画を整理し、線の乱れを整えてください。",
        "Color this drawing cleanly while preserving the original shapes and silhouette.": "元の形とシルエットを保ったまま、この絵に自然に色を付けてください。",
        "Add a simple polished background that fits the subject while keeping the main drawing as the focus.": "主役を保ちながら、雰囲気に合うシンプルな背景を追加してください。",
        "Improve lighting and shading while preserving the original composition and design.": "元の構図とデザインを保ったまま、光と陰影を整えてください。",
        "Output": "出力",
        "Output Target": "出力先",
        "Replace Current Layer": "現在のレイヤーを置き換え",
        "Generate Into New Layer": "新規レイヤーに生成",
        "Model": "モデル",
        "Merge Down": "下のレイヤーと結合",
        "Use your own backend to inject the provider API key and verify entitlements": "自社バックエンドでプロバイダ API キー注入と購入権限チェックを行う想定です",
        "Enter a prompt for Nano Banana": "Nano Banana 用のプロンプトを入力してください",
        "Enter your Gemini API key": "Gemini API キーを入力してください",
        "Enter your app server endpoint": "アプリサーバーのエンドポイントを入力してください",
        "Could not prepare the active layer for Nano Banana": "Nano Banana 用にアクティブレイヤーを準備できませんでした",
        "Could not apply Nano Banana edit": "Nano Banana の編集結果を適用できませんでした",
        "Nano Banana edit applied": "Nano Banana の編集結果を適用しました",
        "Nano Banana edit failed": "Nano Banana の編集に失敗しました",
        "Nano Banana returned an invalid response": "Nano Banana から不正な応答が返されました",
        "Nano Banana endpoint is invalid": "Nano Banana のエンドポイントが不正です",
        "Nano Banana did not return an image": "Nano Banana が画像を返しませんでした",
        "Nano Banana returned an unsupported image": "Nano Banana が未対応の画像を返しました",
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
        "Import Photo to New Layer": "写真を新規レイヤーに読み込む",
        "Could not import photo": "写真を読み込めませんでした",
        "Photo imported to a new layer": "写真を新規レイヤーに読み込みました",
        "Start From": "開始方法",
        "Create From Image": "画像から作成",
        "Could not create canvas from image": "画像からキャンバスを作成できませんでした",
        "Canvas created from image": "画像からキャンバスを作成しました",
        "Image size is not supported": "この画像サイズはサポートされていません",
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
        "Speed Opacity": "速度で不透明度",
        "Speed Size": "速度でサイズ",
        "Source": "取得元",
        "Spacing": "スタンプ間隔",
        "Spacing Jitter": "間隔ジッター",
        "Speed Density": "速度で濃さを変える",
        "Spray": "スプレー",
        "Stabilization": "手ぶれ補正",
        "State": "状態",
        "Stroke": "ストローク固定",
        "Subtract": "削る",
        "Taper In": "入り",
        "Taper Out": "抜き",
        "Tap or drag with Apple Pencil to sample a color into the current paint color.": "Apple Pencil でタップまたはドラッグすると色を取得して現在色に反映します。",
        "Tap to sample, then use Move to transform": "タップで選択したあと、移動ツールで変形します",
        "Target": "対象",
        "Texture": "テクスチャ",
        "Texture Apply": "テクスチャ適用",
        "Threshold": "しきい値",
        "Threshold Mode": "しきい値モード",
        "Convert Luminance To Opacity": "輝度を透明度に変換",
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

    static func appName(_ language: AppLanguage) -> String { "Primo" }

    private static func localized(_ language: AppLanguage, japanese: String, english: String) -> String {
        switch language {
        case .english:
            return english
        case .japanese:
            return japanese
        }
    }

    static func savedDocument(_ filename: String, _ language: AppLanguage) -> String {
        localized(language, japanese: "保存しました: \(filename)", english: "Saved: \(filename)")
    }

    static func openedDocument(_ layerCount: Int, _ language: AppLanguage) -> String {
        localized(language, japanese: "\(layerCount)レイヤーの書類を開きました", english: "Opened document with \(layerCount) layers")
    }

    static func openFailed(_ language: AppLanguage) -> String {
        localized(language, japanese: "開くことができませんでした", english: "Open failed")
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
    static func nanoBanana(_ language: AppLanguage) -> String { language.localized("Nano Banana") }
    static func nanoBananaEdit(_ language: AppLanguage) -> String { language.localized("Nano Banana で編集") }
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
    static func homeProjectsTitle(_ language: AppLanguage) -> String {
        localized(language, japanese: "プロジェクト", english: "Projects")
    }
    static func homeProjectsSubtitle(_ language: AppLanguage) -> String {
        localized(language, japanese: "保存済みのキャンバスを続きから開くか、新しい作品を始められます。", english: "Continue from your saved canvases or start a fresh composition.")
    }
    static func homeSettingsTitle(_ language: AppLanguage) -> String {
        localized(language, japanese: "設定", english: "Preferences")
    }
    static func homeSettingsSubtitle(_ language: AppLanguage) -> String {
        localized(language, japanese: "アプリ言語や作業環境の状態を確認できます。", english: "Adjust the app language and review your workspace.")
    }
    static func recentProjects(_ language: AppLanguage) -> String {
        localized(language, japanese: "最近のプロジェクト", english: "Recent Projects")
    }
    static func noProjectsTitle(_ language: AppLanguage) -> String {
        localized(language, japanese: "保存済みプロジェクトはまだありません", english: "No saved projects yet")
    }
    static func noProjectsMessage(_ language: AppLanguage) -> String {
        localized(language, japanese: "最初のキャンバスを作成すると、ここに表示されます。", english: "Create your first canvas and it will appear here.")
    }
    static func createCanvasCTA(_ language: AppLanguage) -> String {
        localized(language, japanese: "キャンバスを作成", english: "Create Canvas")
    }
    static func openFileCTA(_ language: AppLanguage) -> String {
        localized(language, japanese: "ファイルを開く", english: "Open File")
    }
    static func appLanguageTitle(_ language: AppLanguage) -> String {
        localized(language, japanese: "アプリの言語", english: "App Language")
    }
    static func storageSummary(_ count: Int, _ language: AppLanguage) -> String {
        localized(language, japanese: "ローカル保存済みプロジェクト \(count) 件", english: "\(count) saved projects in local storage")
    }
    static func canvasSizeValue(_ size: CGSize, _ language: AppLanguage) -> String {
        localized(
            language,
            japanese: "\(Int(size.width.rounded())) × \(Int(size.height.rounded())) px",
            english: "\(Int(size.width.rounded())) × \(Int(size.height.rounded())) px"
        )
    }
    static func updatedAt(_ date: Date, _ language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language == .english ? Locale(identifier: "en_US_POSIX") : Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let value = formatter.string(from: date)
        return localized(language, japanese: "更新 \(value)", english: "Updated \(value)")
    }

    static func layers(_ count: Int, _ language: AppLanguage) -> String {
        localized(language, japanese: "\(count) レイヤー", english: "\(count) Layers")
    }

    static func folderName(_ count: Int, _ language: AppLanguage) -> String {
        localized(language, japanese: "フォルダ \(count)", english: "Folder \(count)")
    }

    static func moveOutOfFolder(_ language: AppLanguage) -> String {
        localized(language, japanese: "フォルダ外へ戻す", english: "Move Out Of Folder")
    }

    static func dropToMoveOutOfFolder(_ language: AppLanguage) -> String {
        localized(language, japanese: "ここにドロップでフォルダ外へ戻す", english: "Drop here to move out of folder")
    }

    static func layersTitle(_ language: AppLanguage) -> String { language.localized("レイヤー") }
    static func visible(_ language: AppLanguage) -> String { language.localized("表示") }
    static func hidden(_ language: AppLanguage) -> String { language.localized("非表示") }
    static func active(_ language: AppLanguage) -> String { language.localized("選択中") }
    static func standby(_ language: AppLanguage) -> String { language.localized("待機") }

    static func opacityValue(_ value: Int, _ language: AppLanguage) -> String {
        localized(language, japanese: "不透明度 \(value)%", english: "Opacity \(value)%")
    }

    static func exportingTimelapse(_ language: AppLanguage) -> String { language.localized("タイムラプスを書き出し中…") }

    static func dynamicControlOff(_ language: AppLanguage) -> String {
        localized(language, japanese: "なし", english: "Off")
    }

    static func dynamicControlPressure(_ language: AppLanguage) -> String { language.localized("筆圧") }
    static func dynamicControlTilt(_ language: AppLanguage) -> String { language.localized("傾き") }
    static func dynamicControlSpeed(_ language: AppLanguage) -> String { language.localized("速度") }
    static func dynamicControlRandom(_ language: AppLanguage) -> String { language.localized("ランダム") }

    static func brushSettingsCategoryTip(_ language: AppLanguage) -> String { language.localized("先端") }
    static func brushSettingsCategoryScatter(_ language: AppLanguage) -> String { language.localized("散布") }

    static func brushSettingsCategoryStroke(_ language: AppLanguage) -> String {
        localized(language, japanese: "描画", english: "Stroke")
    }

    static func brushSettingsCategoryTexture(_ language: AppLanguage) -> String {
        localized(language, japanese: "質感", english: "Texture")
    }
}
