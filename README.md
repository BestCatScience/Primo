# Primo

`Primo` は、SwiftUI / TCA のアプリ層と Swift Package 化された document runtime、Metal ベースの描画処理を組み合わせた iPad 向けペイントアプリのプロトタイプです。

Apple Pencil での入力、マルチレイヤー編集、選択・変形・塗りつぶし・テキスト・タイムラプス・AI 画像編集補助を、UI から描画エンジンまで一通りつなぐことを目的にしています。完成品というより、描画体験と内部アーキテクチャを同時に育てるための実験場です。

## 目的

- iPad 上で軽快に動くマルチレイヤーのラスター描画体験を試作する
- ブラシ、消しゴム、ぼかし、塗りつぶし、選択、変形、テキスト、レイヤー操作、タイムラプスをひとつの document workflow として接続する
- UI、workflow、document mutation、GPU 処理、永続化、外部サービス連携の責務を分け、テストと差し替えがしやすい構造にする
- Metal を中心に、stroke、layer processing、selection、preview composite、export を段階的に高速化できる余地を残す

## 現在の設計方針

Primo は、アプリ層を薄い orchestration 層に寄せ、実際の document 処理を `Packages/PrimoModules` 側へ移す方針で整理しています。

- **App は UI と workflow に集中する**
  `AppFeature` は TCA reducer として、画面状態、routing、workflow coordination、dependency の呼び出しを担当します。document の実処理は gateway / use case 越しに呼び出します。
- **document runtime は contract の後ろに隠す**
  query、mutation、stroke、history、persistence、export、text layer、GPU operation は `PrimoDocumentContracts` の gateway として表現し、app から runtime 実装へ直接依存しない形にしています。
- **domain / application / infrastructure を分ける**
  document、workspace、brush、NanoBanana などは、値やルールを置く domain、操作の意味を定義する application、Metal / file I/O / network などを扱う infrastructure に分けています。
- **副作用は dependency と gateway に閉じ込める**
  ファイル I/O、日時、UUID、保存、読み込み、エクスポート、AI 編集、GPU backend は reducer の外側に置き、テストでは差し替えられる境界を用意します。
- **描画は snapshot と incremental update で扱う**
  runtime は document snapshot と dirty update を管理し、表示側は render snapshot / incremental update / preview surface を受け取って Metal 表示へ反映します。

## 実装の全体像

おおまかな入力から描画までの流れは次のとおりです。

1. `CanvasPresentationContainerView` と `CanvasInputHandler` が Pencil / touch / gesture を `CanvasPresentationAction` に変換する
2. `CanvasView` がその action を `CanvasFeature.Action` へ写し、TCA の state / workflow へ渡す
3. `AppFeature` と各 feature reducer が document command service、gateway、use case を呼び出す
4. `DocumentRuntimeCompositionFactory.live` が `DocumentEngineLive`、stroke use case、GPU operation gateway を組み合わせる
5. `DocumentEngineLive` が `SwiftDocumentRuntime` を `LockedDocumentRuntimeBox` の後ろに保持し、query / mutation / stroke / history / persistence / export の gateway を公開する
6. `SwiftDocumentRuntime` が document store、undo / redo、timelapse、dirty update、layer buffer handle を管理する
7. `DocumentRuntimeGpuServices` と `DocumentGpuOperationGateway` が Metal stroke、layer mutation、selection、preview composite、export surface を実行する
8. canvas presentation infrastructure が render snapshot と incremental update を Metal view に反映する

## 主な機能

- 複数レイヤーのラスター document model
- レイヤーの追加、削除、複製、移動、名前変更、表示切り替え、ロック、alpha lock、clipping、opacity、blend mode
- レイヤーフォルダの作成、削除、表示、展開、リネーム、割り当て
- Apple Pencil / touch 入力による brush stroke、eraser、blur stroke
- 塗りつぶし、スポイト、選択、移動、変形、シェイプ、テキスト系 workflow
- selection mask の生成、合成、拡張、縮小、ぼかし、反転、変形
- layer processing、mask 操作、merge down、canvas resize / extent resize
- paper style、透明背景 preview、PNG export
- project save / load、workspace autosave、復元、タブ管理
- timelapse capture / export
- NanoBanana 連携による画像編集補助
- Photoshop brush / brush tip import 周辺の file format と brush runtime settings

## プロジェクト構成

- `App/`
  SwiftUI / TCA のアプリ本体です。画面、reducer、workflow、dependency wiring、menus、workspace UI、canvas wrapper を持ちます。
- `Packages/PrimoModules/`
  domain、application、contracts、runtime、Metal infrastructure、workspace、brush、NanoBanana、localization をまとめたローカル Swift package です。
- `PrimoTests/`
  app 側 workflow と reducer まわりのテストです。
- `Packages/PrimoModules/Tests/`
  package 化された domain / application / infrastructure のテストです。
- `project.yml`
  XcodeGen 用のプロジェクト定義です。チェックイン済みの `Primo.xcodeproj` もあります。
- `docs/`
  設計メモや大きめのリファクタリング記録を置きます。

## Package 分割

`PrimoModules` は次のような責務で分かれています。

- `PrimoCoreTypes`
  file、date、UUID などの共通 client と operation contract
- `PrimoDocumentDomain`
  document identifier、layer / text / tool / workspace document の基本型
- `PrimoDocumentContracts`
  app と runtime の境界になる query / mutation / stroke / history / persistence / export / text / GPU contract
- `PrimoDocumentApplication`
  document editing、layer mutation、raster image、content service などの use case
- `PrimoDocumentEngineInfrastructure`
  `SwiftDocumentRuntime`、`DocumentEngineLive`、`DocumentRuntimeComposition`、timelapse export、runtime GPU service wiring
- `PrimoDocumentMetalRuntimeInfrastructure`
  Metal resource、stroke / composite / layer / text の低レベル runtime
- `PrimoDocumentMetalStrokeInfrastructure`
  stroke processing service と GPU stroke renderer
- `PrimoDocumentRenderingInfrastructure`
  canvas preview、selection、transform、eyedropper、GPU operation gateway
- `PrimoDocumentPersistenceInfrastructure`
  project save / load、manifest、layer RGBA、timelapse persistence
- `PrimoDocumentStrokeApplication` / `PrimoDocumentStrokeInfrastructure`
  stroke session use case と CPU 側 stroke geometry / raster service
- `PrimoCanvasInputDomain` / `PrimoCanvasPresentationDomain` / `PrimoCanvasPresentationInfrastructure`
  canvas input、presentation state、UIKit / Metal presentation views
- `PrimoWorkspaceDomain` / `PrimoWorkspaceApplication` / `PrimoWorkspaceInfrastructure`
  workspace catalog、autosave、load、reservation、persistence
- `PrimoBrushDomain` / `PrimoBrushFileFormats` / `PrimoBrushInfrastructure`
  brush settings、Photoshop brush / tip formats、brush import
- `PrimoNanoBananaDomain` / `PrimoNanoBananaApplication` / `PrimoNanoBananaInfrastructure`
  AI edit command、preview preparation、commerce / remote client
- `PrimoLocalization`
  共通ローカライズ型

## 重要なファイル

- [App/Features/Document/AppFeature.swift](/Users/goldstein/git/Primo/App/Features/Document/AppFeature.swift)
  TCA reducer の入口です。workspace、document editor、canvas interaction、import / export、NanoBanana feature を束ねます。
- [App/Features/Document/PaintDocumentClient.swift](/Users/goldstein/git/Primo/App/Features/Document/PaintDocumentClient.swift)
  app 側 dependency wiring です。`DocumentRuntimeComposition` から各 command service / gateway を組み立てます。
- [App/Features/Canvas/CanvasView.swift](/Users/goldstein/git/Primo/App/Features/Canvas/CanvasView.swift)
  SwiftUI と UIKit canvas presentation の接続点です。
- [Packages/PrimoModules/Sources/PrimoCanvasPresentationInfrastructure/CanvasPresentationContainerView.swift](/Users/goldstein/git/Primo/Packages/PrimoModules/Sources/PrimoCanvasPresentationInfrastructure/CanvasPresentationContainerView.swift)
  canvas surface、入力、selection overlay、transform preview、text overlay、eyedropper loupe を束ねる UIKit view です。
- [Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift](/Users/goldstein/git/Primo/Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift)
  runtime、stroke use case、GPU operation gateway を app 向けに組み合わせる composition root です。
- [Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift](/Users/goldstein/git/Primo/Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift)
  `SwiftDocumentRuntime` を gateway 群として公開する live engine です。
- [Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentRuntime.swift](/Users/goldstein/git/Primo/Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentRuntime.swift)
  document store、undo / redo、dirty update、stroke commit、save / load、timelapse を扱う runtime 本体です。
- [Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeGpuServices.swift](/Users/goldstein/git/Primo/Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeGpuServices.swift)
  runtime から Metal 処理を呼び出すための GPU service 集約です。
- [Packages/PrimoModules/Sources/PrimoDocumentRenderingInfrastructure/DocumentGpuOperationBackend.swift](/Users/goldstein/git/Primo/Packages/PrimoModules/Sources/PrimoDocumentRenderingInfrastructure/DocumentGpuOperationBackend.swift)
  preview、selection、transform、layer processing など表示・編集補助向け GPU operation の境界です。

## ドキュメント保存形式

project save は単一ファイルではなくディレクトリ構成です。主な内容は package 側の persistence 実装で定義されています。

- `manifest.json`
  canvas size、active layer、paper style、layer / folder、timelapse metadata などを保持します。
- `Layers/layer-XXXX.rgba`
  各レイヤーの RGBA pixel data です。
- `Timelapse/`
  フレームベースのタイムラプス保存に使います。
- `TimelapseData/`
  操作ベースのタイムラプス補助データに使います。

## はじめ方

Xcode でチェックイン済みのプロジェクトを開きます。

```bash
open Primo.xcodeproj
```

`Primo` scheme を iPad simulator または iPad 実機でビルドして実行します。Apple Pencil の筆圧や Pencil interaction は実機のほうが確認しやすく、simulator は UI と基本 workflow の確認向けです。

Package 単体のテストは次のように実行できます。

```bash
cd Packages/PrimoModules
swift test
```

リポジトリルートのアプリビルド確認には `scripts/codex-build.sh` を使います。

```bash
scripts/codex-build.sh
```

## 現状の注意点

- これはプロトタイプであり、機能ごとの完成度には差があります。
- UI に先に露出している操作でも、内部実装や GPU path は継続的に整理中です。
- document runtime は package 側へ移っていますが、app 側にはまだ workflow / reducer helper が多く残っています。
