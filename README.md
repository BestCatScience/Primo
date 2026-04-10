# atelierprime

`atelierprime` は、SwiftUI フロントエンドと C++ 描画コアを組み合わせた iPad ファーストのペイントプロトタイプです。

このリポジトリは「Apple Pencil での描画体験」と「Krita のような本格的な画像処理コア」のあいだをつなぐ実験場として作られています。UI は SwiftUI と TCA で組み、描画本体は C++ で持ち、Swift からは Objective-C++ ブリッジ越しに利用します。

## プロジェクトの目的

- iPad 上で軽快に動くマルチレイヤーのラスター描画アプリを試作する
- ブラシ、塗りつぶし、レイヤー合成、選択、変形といった基礎機能を一通りつなぐ
- 描画コアを UI から分離し、将来的な高速化や機能追加に耐えられる構造にする
- Krita の `libs/image` や stroke queue の考え方を参考に、内部設計を整理する

## 現在できること

- 複数レイヤー対応のラスター document model
- 筆圧に応じて不透明度と半径が変化する鉛筆風ブラシ
- 消しゴム、ぼかし、塗りつぶし、スポイト、選択、移動、シェイプ系ツールの UI と状態管理
- 高速な C++ ストロークラスタライズと Metal ベースの画面合成
- レイヤーの表示・不透明度・ブレンドモード変更
- レイヤーフォルダの作成、表示切り替え、並び替え
- 選択範囲の作成と変形プレビュー
- キャンバス紙色の変更と透明背景プレビュー
- プロジェクト保存 / 読み込み
- タイムラプス用の操作履歴またはフレーム書き出し
- Swift から利用するための Objective-C++ ブリッジ
- TCA ベースの SwiftUI アプリ構成
- レイヤー一覧、ブラシコントロール、キャンバスを備えた iPad 向け SwiftUI UI
- そのまま開けるチェックイン済みの Xcode プロジェクト

## 画面として見ると何があるか

- 左右のサイドバーにツール、ブラシ設定、レイヤー UI を持つ iPad 向けワークスペース
- Metal で合成表示するキャンバスビュー
- ブラシ半径、硬さ、不透明度、散布、テクスチャ、dual brush などを調整するパレット
- レイヤーのサムネイル、フォルダ、ブレンドモードを扱うサイドバー
- 保存、読み込み、PNG 出力、タイムラプス出力などのドキュメント操作

## プロジェクト構成

- `App/`
  SwiftUI / TCA 側のアプリ本体です。UI、状態管理、ジェスチャ入力、保存メニュー、レイヤー UI などを持ちます。
- `Bridge/`
  Swift と C++ の橋渡し層です。`APPaintDocumentBridge` が `PaintDocument` を Objective-C API として公開します。
- `Engine/`
  描画コアです。レイヤー、ストローク、塗りつぶし、合成、dirty 管理などの中核処理があります。
- `atelierprime.xcodeproj`
  依存関係込みでそのまま開ける Xcode プロジェクトです。

## 重要なファイル

- [App/Features/Document/AppFeature.swift](/Users/goldstein/git/atelierprime/App/Features/Document/AppFeature.swift)
  アプリ全体のドキュメント操作を束ねる TCA reducer です。
- [App/Features/Document/PaintDocumentSession.swift](/Users/goldstein/git/atelierprime/App/Features/Document/PaintDocumentSession.swift)
  Swift 側の document session です。保存、読み込み、タイムラプス、presentation 生成を担当します。
- [App/Features/Canvas/CanvasView.swift](/Users/goldstein/git/atelierprime/App/Features/Canvas/CanvasView.swift)
  UIKit ベースのキャンバスコンテナです。入力を受けて Metal 表示へ渡します。
- [App/Features/Canvas/InputHandler.swift](/Users/goldstein/git/atelierprime/App/Features/Canvas/InputHandler.swift)
  Apple Pencil / touch をストロークや選択操作へ変換します。
- [App/Rendering/MetalCanvasRenderer.swift](/Users/goldstein/git/atelierprime/App/Rendering/MetalCanvasRenderer.swift)
  合成済みピクセルデータを Metal テクスチャへ載せて描画します。
- [Bridge/PaintDocumentBridge.mm](/Users/goldstein/git/atelierprime/Bridge/PaintDocumentBridge.mm)
  C++ エンジンを Swift から呼べるように変換するブリッジ実装です。
- [Engine/include/PaintEngine.hpp](/Users/goldstein/git/atelierprime/Engine/include/PaintEngine.hpp)
  描画エンジンの公開インターフェースです。
- [Engine/PaintEngine.cpp](/Users/goldstein/git/atelierprime/Engine/PaintEngine.cpp)
  ブラシ描画、ストロークキュー、タイルストレージ、レイヤー合成などの本体です。

## はじめ方

1. Xcode でプロジェクトを開きます。

```bash
open atelierprime.xcodeproj
```

2. `atelierprime` スキームを iPad シミュレータまたは実機でビルドして実行します。
3. Apple Pencil を使った描画挙動は実機のほうが確認しやすく、シミュレータは主に UI と基本動作の確認向けです。

### CODEX 環境でビルド確認する

CODEX ではネットワークやホーム配下キャッシュへの書き込みが制限されることがあるため、既存の `SourcePackages` チェックアウトを再利用する専用スクリプトを用意しています。

```bash
chmod +x scripts/codex-build.sh
scripts/codex-build.sh
```

- 既定では `~/Library/Developer/Xcode/DerivedData/atelierprime-gruuszhkrmiexzgjfbedzywqxddp/SourcePackages` を再利用します
- 別の場所を使う場合は `SOURCE_PACKAGES_DIR=/path/to/SourcePackages scripts/codex-build.sh` のように上書きできます
- 生成物は `/tmp/atelierprime-codex-build` と `/tmp/atelierprime-package-cache` に出ます

## アーキテクチャ概要

### 全体の流れ

1. `InputHandler` が Pencil / touch を `Stroke` やツール操作へ変換します。
2. `CanvasFeature` と `AppFeature` が TCA 上でその入力を解釈し、document client に渡します。
3. `PaintDocumentSession` が Swift 側の状態管理、保存、タイムラプス記録、presentation 生成を担当します。
4. `APPaintDocumentBridge` が Swift と C++ のデータ型を相互変換します。
5. `PaintDocument` がレイヤー更新、描画、合成、undo / redo を処理します。
6. `MetalCanvasRenderer` が合成済みピクセルデータを表示用テクスチャへ反映します。

- 各レイヤーは、C++ 側で tile-backed な RGBA ラスターモデルとして保持されます。
- インタラクティブな描画操作は、Krita に着想を得た小さな `stroke / job / strategy / queue` パイプラインでスケジューリングされます。
- ストロークは dab ベースのブラシでアクティブレイヤーへ直接描画されます。
- 描画コアは dirty rect と dirty tile を追跡し、合成結果を段階的に再構築できます。
- Swift 側はプレビュー用に合成済みピクセルデータを Metal テクスチャへアップロードします。
- インタラクション状態は SwiftUI が管理し、描画コア自体はプラットフォーム非依存に保たれます。

### 描画コアの設計

- レイヤーは 64x64 タイル単位で保持され、変更された領域だけを再合成できます
- フリーハンド描画は `stroke / job / strategy / queue` で分解されます
- 現在の実装では `SEQUENTIAL` と `BARRIER` を意識した同期キューとして動きます
- finish / cancel は barrier job として扱われ、必要に応じて合成結果との同期を取ります
- Swift 側には全画面スナップショットだけでなく dirty rect ベースの差分更新も返せます

### レイヤーと合成

- レイヤーごとに可視状態、不透明度、ブレンドモードを持ちます
- レイヤーフォルダを作成でき、可視状態や展開状態を管理できます
- 合成結果は C++ 側で計算し、Metal では主に表示に集中します
- レイヤーサムネイルや保存用 RGBA は必要に応じて Swift 側へ取り出します

### ブラシシステム

- 半径、硬さ、不透明度、筆圧感度
- 散布、カウント、角度ジッタ、丸みジッタ
- テクスチャ、紙質、grain
- wetness、paint load、color mix
- dual brush
- custom tip alpha mask

### ドキュメント保存形式

保存先は単一ファイルではなくディレクトリ構成です。主な内容は次のとおりです。

- `manifest.json`
  キャンバスサイズ、アクティブレイヤー、紙色、レイヤー一覧、フォルダ、タイムラプス情報を持ちます。
- `Layers/layer-XXXX.rgba`
  各レイヤーの生 RGBA データです。
- `Timelapse/`
  フレームベース保存を使う場合のサムネイル / 動画用フレームです。
- `TimelapseData/`
  操作ベースのタイムラプス保存で使う補助データです。

この形式は [PaintDocumentSession.swift](/Users/goldstein/git/atelierprime/App/Features/Document/PaintDocumentSession.swift) と [StoredAtelierDocument](/Users/goldstein/git/atelierprime/App/Features/Document/PaintDocumentSession.swift#L1249) で定義されています。

## 開発メモ

- UI 状態は TCA reducer に寄せてあり、描画ロジックは `PaintDocumentSession` と C++ 側へ分離しています
- C++ コアは SwiftUI や UIKit に依存しません
- `PaintDocumentClient` を介して reducer から document 実装を差し替えやすい構造です
- 描画結果の表示は Metal、保存やエクスポートは Swift 側ユーティリティが担当します

## この README を読んだあとにおすすめの読む順番

1. [App/Features/Document/AppFeature.swift](/Users/goldstein/git/atelierprime/App/Features/Document/AppFeature.swift)
2. [App/Features/Document/PaintDocumentSession.swift](/Users/goldstein/git/atelierprime/App/Features/Document/PaintDocumentSession.swift)
3. [Bridge/PaintDocumentBridge.mm](/Users/goldstein/git/atelierprime/Bridge/PaintDocumentBridge.mm)
4. [Engine/include/PaintEngine.hpp](/Users/goldstein/git/atelierprime/Engine/include/PaintEngine.hpp)
5. [Engine/PaintEngine.cpp](/Users/goldstein/git/atelierprime/Engine/PaintEngine.cpp)

## 現状の注意点

- これは完成品というより、描画体験と内部アーキテクチャを前に進めるための試作プロジェクトです
- 一部のツールや UI は先行して存在し、仕上がりの度合いに差があります
- ストロークキューは Krita の考え方を取り入れていますが、現時点では本格的な並列 scheduler までは実装していません

## 今後の予定

- より現実的なブラシの grain、tilt、wet-mix ダイナミクス
- undo / redo ジャーナルと永続的な document serialization
- レイヤーマスク、選択範囲、非破壊フィルタ
- stroke queue の並列実行と update scheduler の強化
- より堅牢なプロジェクト互換性と検証用テストの追加
