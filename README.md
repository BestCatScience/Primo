# Primo

`Primo` は、SwiftUI / TCA のアプリ層と Swift Package 化された document runtime、Metal ベースの描画処理を組み合わせた iPad 向けペイントアプリのプロトタイプです。

Apple Pencil での入力、マルチレイヤー編集、選択・変形・塗りつぶし・テキスト・タイムラプス・AI 画像編集補助を、UI から描画エンジンまで一通りつなぐことを目的にしています。完成品というより、描画体験と内部アーキテクチャを同時に育てるための実験場です。

## 現在の状態

2026-04-29 時点では、Primo はホーム画面、workspace tab、document runtime、Metal canvas presentation、project persistence までを接続した iPad simulator / 実機向けの開発版です。

- ホーム画面には保存済み project catalog を表示し、サムネイルから `.atelier` project を開けます。
- 保存済み project のロードは full render snapshot 付きの presentation を返し、再起動後のディスクロードでも canvas へ適用できるようにしています。
- 連続ストロークでは、正式な presentation refresh を待つ間も直前の GPU commit surface を `pendingCommittedSnapshot` として次ストロークの base に使います。
- canvas thumbnail / project preview は表示専用 view として扱い、SwiftUI の card / button gesture を妨げないようにしています。
- `CanvasStrokeWorkflowTests`、`PrimoRootFeatureIntegrationTests`、`PrimoCanvasPresentationInfrastructureTests`、`scripts/codex-build.sh` で直近の修正を確認しています。

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
  document、workspace、brush、AI 画像編集などは、値やルールを置く domain、操作の意味を定義する application、Metal / file I/O / network などを扱う infrastructure に分けています。
- **副作用は dependency と gateway に閉じ込める**
  ファイル I/O、日時、UUID、保存、読み込み、エクスポート、AI 編集、GPU backend は reducer の外側に置き、テストでは差し替えられる境界を用意します。
- **描画は snapshot と incremental update で扱う**
  runtime は document snapshot と dirty update を管理し、表示側は render snapshot / incremental update / preview surface を受け取って Metal 表示へ反映します。
- **workspace は catalog / load / persistence を分ける**
  ホーム一覧は catalog、プロジェクト読み込みは load、保存・autosave・tab backing store は persistence として分け、TCA reducer から use case 越しに呼び出します。

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

保存済み project を開く流れは次のとおりです。

1. ホーム画面の project card が `WorkspaceFeature.Action.homeProjectSelected` を送る
2. `WorkspaceFeature` が active tab の保存準備を必要に応じて行い、`WorkspaceProjectLoadingService` へ load command を渡す
3. `DocumentEngineLive` が `SwiftDocumentRuntime.loadProject` で `.atelier` package を読み、full `presentation()` と paper style を持つ `LoadedPaintProject` を返す
4. `DocumentFeature` が loaded presentation を canvas / layer sidebar / interaction state に適用する
5. workspace が tab reservation を確定し、application state がホームを閉じて編集画面へ戻る

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
- Gemini / OpenAI Image を扱う AI 画像編集補助
- Photoshop brush / brush tip import 周辺の file format と brush runtime settings

## プロジェクト構成

- `App/`
  SwiftUI / TCA のアプリ本体です。画面、reducer、workflow、dependency wiring、menus、workspace UI、canvas wrapper を持ちます。
- `Packages/PrimoModules/`
  domain、application、contracts、runtime、Metal infrastructure、workspace、brush、AI 画像編集、localization をまとめたローカル Swift package です。
- `PrimoTests/`
  app 側 workflow と reducer まわりのテストです。
- `Packages/PrimoModules/Tests/`
  package 化された domain / application / infrastructure のテストです。
- `project.yml`
  XcodeGen 用のプロジェクト定義です。チェックイン済みの `Primo.xcodeproj` もあります。

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
  AI 画像編集 backend。旧称 NanoBanana module として残しつつ、Gemini 系 image model と OpenAI Image model の command、preview preparation、commerce / remote client を扱います。
- `PrimoLocalization`
  共通ローカライズ型

## 重要なファイル

- [App/Features/Document/DocumentFeature.swift](App/Features/Document/DocumentFeature.swift)
  document editor の TCA reducer 本体です。canvas interaction、document mutation、import / export、AI 画像編集 workflow を束ねます。
- [App/Features/Document/PaintDocumentClient.swift](App/Features/Document/PaintDocumentClient.swift)
  app 側 dependency wiring です。`DocumentRuntimeComposition` から各 command service / gateway を組み立てます。
- [App/Features/Canvas/CanvasView.swift](App/Features/Canvas/CanvasView.swift)
  SwiftUI と UIKit canvas presentation の接続点です。
- [Packages/PrimoModules/Sources/PrimoCanvasPresentationInfrastructure/CanvasPresentationContainerView.swift](Packages/PrimoModules/Sources/PrimoCanvasPresentationInfrastructure/CanvasPresentationContainerView.swift)
  canvas surface、入力、selection overlay、transform preview、text overlay、eyedropper loupe を束ねる UIKit view です。
- [Packages/PrimoModules/Sources/PrimoCanvasPresentationInfrastructure/CanvasMetalSurfaceViews.swift](Packages/PrimoModules/Sources/PrimoCanvasPresentationInfrastructure/CanvasMetalSurfaceViews.swift)
  Metal surface を SwiftUI / UIKit から表示する view 群です。ホームや tab preview では表示専用として hit testing を無効化します。
- [Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift](Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift)
  runtime、stroke use case、GPU operation gateway を app 向けに組み合わせる composition root です。
- [Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift](Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift)
  `SwiftDocumentRuntime` を gateway 群として公開する live engine です。
- [Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentRuntime.swift](Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentRuntime.swift)
  document store、undo / redo、dirty update、stroke commit、save / load、timelapse を扱う runtime 本体です。
- [App/Features/Document/WorkspaceFeature+Workflow.swift](App/Features/Document/WorkspaceFeature+Workflow.swift)
  home project selection、tab reservation、autosave、save history、project load / persistence の workflow を扱います。
- [App/Features/Canvas/CanvasFeature.swift](App/Features/Canvas/CanvasFeature.swift)
  canvas state、render snapshot、stroke preview、pending committed snapshot、selection / transform preview を保持します。
- [Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeGpuServices.swift](Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeGpuServices.swift)
  runtime から Metal 処理を呼び出すための GPU service 集約です。
- [Packages/PrimoModules/Sources/PrimoDocumentRenderingInfrastructure/DocumentGpuOperationBackend.swift](Packages/PrimoModules/Sources/PrimoDocumentRenderingInfrastructure/DocumentGpuOperationBackend.swift)
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

保存済み project はアプリの Documents 配下の `primo-projects/` に配置されます。作業中 tab の backing store は一時領域の `primo-tabs/` に置かれ、保存時やホームへ戻るときに `.atelier` package として project catalog 側へ反映されます。

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

よく使う focused test は次のとおりです。

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild test -scheme Primo -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' -only-testing:PrimoTests/CanvasStrokeWorkflowTests
xcodebuild test -scheme Primo -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' -only-testing:PrimoTests/PrimoRootFeatureIntegrationTests
cd Packages/PrimoModules && swift test --filter PrimoCanvasPresentationInfrastructureTests
```
