# primo

`primo` は、SwiftUI フロントエンドと Swift / Metal ベースの描画ランタイムを組み合わせた iPad ファーストのペイントプロトタイプです。

このリポジトリは「Apple Pencil での描画体験」と「リアルタイムに反応する GPU 中心の画像処理パイプライン」のあいだをつなぐ実験場として作られています。UI は SwiftUI と TCA で組み、document runtime は Swift package 側で管理し、表示と描画更新は Metal を主軸にしています。

## プロジェクトの目的

- iPad 上で軽快に動くマルチレイヤーのラスター描画アプリを試作する
- ブラシ、塗りつぶし、レイヤー合成、選択、変形といった基礎機能を一通りつなぐ
- 描画コアを UI から分離し、将来的な高速化や機能追加に耐えられる構造にする
- Krita の `libs/image` や stroke queue の考え方を参考に、内部設計を整理する

## 現在できること

- 複数レイヤー対応のラスター document model
- 筆圧に応じて不透明度と半径が変化する鉛筆風ブラシ
- 消しゴム、ぼかし、塗りつぶし、スポイト、選択、移動、シェイプ系ツールの UI と状態管理
- Swift / Metal ベースのストローク処理と画面合成
- レイヤーの表示・不透明度・ブレンドモード変更
- レイヤーフォルダの作成、表示切り替え、並び替え
- 選択範囲の作成と変形プレビュー
- キャンバス紙色の変更と透明背景プレビュー
- プロジェクト保存 / 読み込み
- タイムラプス用の操作履歴またはフレーム書き出し
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
- `Packages/PrimoModules/`
  document runtime、履歴、保存、タイムラプス、描画処理、Metal runtime などの shared modules です。
- `Primo.xcodeproj`
  依存関係込みでそのまま開ける Xcode プロジェクトです。

## 重要なファイル

- [App/Features/Document/AppFeature.swift](/Users/goldstein/git/primo/App/Features/Document/AppFeature.swift)
  アプリ全体のドキュメント操作を束ねる TCA reducer です。
- [Packages/PrimoModules/Sources/PrimoDocumentInfrastructure/LegacyRuntime/SwiftDocumentRuntime.swift](/Users/goldstein/git/Primo/Packages/PrimoModules/Sources/PrimoDocumentInfrastructure/LegacyRuntime/SwiftDocumentRuntime.swift)
  現在の document runtime 実装です。保存、読み込み、履歴、presentation、描画 commit を担当します。
- [App/Features/Canvas/CanvasView.swift](/Users/goldstein/git/primo/App/Features/Canvas/CanvasView.swift)
  UIKit ベースのキャンバスコンテナです。入力を受けて Metal 表示へ渡します。
- [App/Features/Canvas/InputHandler.swift](/Users/goldstein/git/primo/App/Features/Canvas/InputHandler.swift)
  Apple Pencil / touch をストロークや選択操作へ変換します。
- [App/Rendering/MetalCanvasRenderer.swift](/Users/goldstein/git/primo/App/Rendering/MetalCanvasRenderer.swift)
  合成済みピクセルデータを Metal テクスチャへ載せて描画します。
- [Packages/PrimoModules/Sources/PrimoDocumentMetalRuntimeInfrastructure/PrimoMetalDocumentProcessingClient.swift](/Users/goldstein/git/Primo/Packages/PrimoModules/Sources/PrimoDocumentMetalRuntimeInfrastructure/PrimoMetalDocumentProcessingClient.swift)
  package 側の Metal 描画処理です。stroke / dirty rect composite / GPU 更新を担当します。

## はじめ方

1. Xcode でプロジェクトを開きます。

```bash
open Primo.xcodeproj
```

2. `Primo` スキームを iPad シミュレータまたは実機でビルドして実行します。
3. Apple Pencil を使った描画挙動は実機のほうが確認しやすく、シミュレータは主に UI と基本動作の確認向けです。

## アーキテクチャ概要

### 全体の流れ

1. `InputHandler` が Pencil / touch を `Stroke` やツール操作へ変換します。
2. `CanvasFeature` と `AppFeature` が TCA 上でその入力を解釈し、document client に渡します。
3. `DocumentRuntimeLive` と `SwiftDocumentRuntime` が document 状態、保存、履歴、presentation 生成を担当します。
4. `PrimoMetalDocumentProcessingClient` が stroke / composite などの描画処理を package 側で実行します。
5. `MetalCanvasRenderer` が合成済みピクセルデータを表示用テクスチャへ反映します。

- 各レイヤーは runtime 側で保持され、通常編集は dirty rect ベースで更新されます。
- インタラクティブな描画操作は Swift / Metal の stroke / composite パイプラインで処理されます。
- ストロークは dab ベースのブラシでアクティブレイヤーへ直接描画されます。
- 描画コアは dirty rect と dirty tile を追跡し、合成結果を段階的に再構築できます。
- Swift 側はプレビュー用に合成済みピクセルデータを Metal テクスチャへアップロードします。
- インタラクション状態は SwiftUI が管理し、描画コア自体はプラットフォーム非依存に保たれます。

### 現在の設計原則

現在のアプリ層と package 層の分割は、次の原則を明確に意識して進めています。

- カプセル化
  `AppFeature`、workspace、NanoBanana、document runtime はそれぞれが自分の状態遷移と操作 API を持ち、内部の表現や補助処理を外へ漏らしにくい構造を目指しています。特に document runtime は `PaintDocumentClient` と各 gateway の後ろに隠し、UI から engine や bridge の詳細へ直接触れなくて済むようにしています。
- 関心の分離
  UI、workflow orchestration、document mutation、workspace 永続化、brush import、NanoBanana 生成を別々の関心として扱います。`AppFeature` は画面とユースケースの接続に集中し、document の実処理は session / runtime / package 側へ寄せます。
- 契約による設計
  query、mutation、stroke、history、persistence、export といった document 操作は contract と gateway で表現します。実装より先に「何を受け取り何を返すか」を揃えることで、app 層、runtime 層、テストが同じ言葉で接続できるようにしています。
- 副作用の隔離
  ファイル I/O、日時、UUID、エクスポート、サブスクリプション、外部サービス呼び出しのような副作用は dependency や infrastructure 層へ閉じ込めます。reducer や domain ロジックでは、できるだけ純粋な状態遷移と command の決定だけを行い、副作用の発火点を追いやすくしています。

この原則に沿って、巨大な型にロジックを集約するのではなく、責務ごとに分かれた workflow、coordinator、gateway、package を組み合わせる方向へ設計を寄せています。

### 描画コアの設計

- レイヤーは 64x64 タイル単位で保持され、変更された領域だけを再合成できます
- フリーハンド描画は `stroke / job / strategy / queue` で分解されます
- 現在の実装では `SEQUENTIAL` と `BARRIER` を意識した同期キューとして動きます
- finish / cancel は barrier job として扱われ、必要に応じて合成結果との同期を取ります
- Swift 側には全画面スナップショットだけでなく dirty rect ベースの差分更新も返せます

### レイヤーと合成

- レイヤーごとに可視状態、不透明度、ブレンドモードを持ちます
- レイヤーフォルダを作成でき、可視状態や展開状態を管理できます
- 合成結果は package 側 runtime と Metal 処理で構築され、viewer 側の Metal は主に表示に集中します
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

この形式は package 側の runtime / persistence 実装で定義されています。

## 開発メモ

- UI 状態は TCA reducer に寄せてあり、描画ロジックは package runtime と Metal backend へ分離しています
- `PaintDocumentClient` を介して reducer から document 実装を差し替えやすい構造です
- 描画結果の表示は Metal、保存やエクスポートは Swift 側ユーティリティが担当します
- 2026-04-16 から 2026-04-20 にかけてのドキュメント機能リファクタリング記録は [docs/document-refactors-2026-04-16-to-2026-04-20.md](/Users/goldstein/git/Primo/docs/document-refactors-2026-04-16-to-2026-04-20.md) にまとめています

## この README を読んだあとにおすすめの読む順番

1. [App/Features/Document/AppFeature.swift](/Users/goldstein/git/primo/App/Features/Document/AppFeature.swift)
2. [Packages/PrimoModules/Sources/PrimoDocumentInfrastructure/LegacyRuntime/DocumentRuntimeLive.swift](/Users/goldstein/git/Primo/Packages/PrimoModules/Sources/PrimoDocumentInfrastructure/LegacyRuntime/DocumentRuntimeLive.swift)
3. [Packages/PrimoModules/Sources/PrimoDocumentInfrastructure/LegacyRuntime/SwiftDocumentRuntime.swift](/Users/goldstein/git/Primo/Packages/PrimoModules/Sources/PrimoDocumentInfrastructure/LegacyRuntime/SwiftDocumentRuntime.swift)
4. [Packages/PrimoModules/Sources/PrimoDocumentMetalRuntimeInfrastructure/PrimoMetalDocumentProcessingClient.swift](/Users/goldstein/git/Primo/Packages/PrimoModules/Sources/PrimoDocumentMetalRuntimeInfrastructure/PrimoMetalDocumentProcessingClient.swift)

## 現状の注意点

- これは完成品というより、描画体験と内部アーキテクチャを前に進めるための試作プロジェクトです
- 一部のツールや UI は先行して存在し、仕上がりの度合いに差があります
- 連続描画の遅延削減を優先しており、runtime 内部は引き続き整理中です

## 今後の予定

- より現実的なブラシの grain、tilt、wet-mix ダイナミクス
- undo / redo ジャーナルと永続的な document serialization
- レイヤーマスク、選択範囲、非破壊フィルタ
- stroke queue の並列実行と update scheduler の強化
- より堅牢なプロジェクト互換性と検証用テストの追加
