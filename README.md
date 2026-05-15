# Primo

`Primo` は、SwiftUI / TCA のアプリ層、Swift Package 化された document runtime、Metal ベースの描画処理を組み合わせた iPad 向けペイントアプリのプロトタイプです。

Apple Pencil での入力、マルチレイヤー編集、選択・変形・塗りつぶし・テキスト・タイムラプス・AI 画像編集補助を、UI から描画エンジン、永続化、プレビュー表示まで一通り接続することを目的にしています。完成品というより、描画体験と内部アーキテクチャを同時に育てるための実験場です。

## 現在の状態

2026-05-08 時点では、Primo はホーム画面、workspace tab、document runtime、Metal canvas presentation、project persistence、autosave recovery、timelapse、AI image edit workflow までを接続した iPad simulator / 実機向けの開発版です。

- `PrimoApp` は起動時に `DocumentRuntimeFactory.live()` で live document runtime を組み立て、TCA dependency として root store に注入します。
- `PrimoRootFeature` は `ApplicationFeature`、`WorkspaceFeature`、`DocumentFeature`、`ImportExportFeature`、`AIImageFeature` を scope し、`CrossFeatureIntegrationReducer` が delegate action を通して feature 間の連携を担います。
- ホーム画面は保存済み project catalog と autosave recovery item を読み込み、サムネイル付きの `.atelier` project を開けます。
- 保存済み project のロードは full render snapshot 付きの `LoadedPaintProject` を返し、再起動後のディスクロードでも canvas / layer sidebar / interaction state へ適用できるようにしています。
- 連続ストロークでは、正式な presentation refresh を待つ間も直前の GPU commit surface を `pendingCommittedSnapshot` として次ストロークの base に使います。
- canvas thumbnail / project preview は表示専用 view として扱い、SwiftUI の card / button gesture を妨げないようにしています。
- 実装の確認は app build、package tests、focused app tests を分けて行う前提です。

## 目的

- iPad 上で軽快に動くマルチレイヤーのラスター描画体験を試作する
- ブラシ、消しゴム、ぼかし、塗りつぶし、選択、変形、テキスト、レイヤー操作、タイムラプスをひとつの document workflow として接続する
- UI、workflow、document mutation、GPU 処理、永続化、外部サービス連携の責務を分け、テストと差し替えがしやすい構造にする
- Metal を中心に、stroke、layer processing、selection、preview composite、export を段階的に高速化できる余地を残す

## 設計方針

Primo は、アプリ層を SwiftUI / TCA の orchestration 層に寄せ、document 処理、workspace 処理、brush import、AI image edit などの実処理を `Packages/PrimoModules` 側へ移す方針で整理しています。

- **App は状態、画面、workflow に集中する**
  `App/` は SwiftUI view、TCA reducer、画面 routing、workflow coordination、dependency wiring を担当します。`DocumentFeature` は canvas、layer sidebar、brush palette、presentation refresh、lifecycle、canvas editing、layer workflow、adjustment、AI image workflow を束ねますが、document の実処理は gateway / service / use case 越しに呼び出します。
- **Root feature は feature 間通信を明示する**
  `PrimoRootFeature` は各 feature を scope し、`CrossFeatureIntegrationReducer` が application、workspace、document、import/export、AI image の delegate action を翻訳します。たとえば home catalog load は application delegate から workspace action へ、loaded project apply は workspace delegate から document presentation action へ渡ります。
- **document runtime は façade と contract の後ろに隠す**
  App は `DocumentRuntime` façade から `DocumentCanvasCommandService`、`DocumentLayerCommandService`、`DocumentStrokeCommandService`、`DocumentHistoryCommandService`、`DocumentMutationWorkflowService`、`DocumentContentService`、`CanvasEditingWorkflowService`、`SelectionWorkflowService` などを受け取ります。query、mutation、stroke、history、persistence、export、text layer、GPU operation は contract module の gateway として表現し、app から live runtime 実装へ直接依存しない形にしています。
- **App validation は preflight、runtime validation は本契約**
  `DocumentWorkflowCommandValidator` は UI state から fast feedback 用の事前チェックを行いますが、その state は stale になり得ます。`DocumentEditorUseCase` と live gateway は revision-aware な `ExistingLayerIndex` / `EditableLayerIndex` を実行直前に再検証し、access control を伴う authoritative validation として扱います。
- **App 側 dependency は一か所で展開する**
  `App/Features/Document/PaintDocumentClient.swift` が `DocumentRuntime` を TCA dependency として登録し、runtime から個別の gateway / service / renderer / processor を `DependencyValues` へ展開します。テストではこの境界を差し替えます。
- **domain / contracts / application / runtime / infrastructure を分ける**
  値やルールは domain、境界の型は contracts、操作の意味は application、app-facing façade は runtime、Metal / file I/O / network などの副作用は infrastructure に置きます。
- **狭い contract import を優先する**
  App files は必要な Primo contract module を明示的に import します。互換 target の `PrimoModuleExports` は広い re-export を行わない方針です。
- **副作用は dependency と gateway に閉じ込める**
  ファイル I/O、日時、UUID、保存、読み込み、エクスポート、AI 編集、GPU backend は reducer の外側に置きます。`FileClient`、`DateClient`、`UUIDClient`、`HTTPClient`、`KeyValueStoreClient`、`SecretStoreClient`、`SecurityScopedResourceClient` などは `PrimoCoreTypes` の client として扱います。
- **描画は snapshot と incremental update で扱う**
  runtime は document snapshot、dirty update、GPU-backed layer buffer handle を管理します。表示側は render snapshot / incremental update / preview surface を受け取り、Metal 表示へ反映します。
- **workspace は catalog / load / persistence を分ける**
  ホーム一覧は catalog、プロジェクト読み込みは load、保存・autosave・tab backing store は persistence として分け、TCA reducer から workspace application workflow と runtime client 越しに呼び出します。

## 実装の全体像

### 起動、hydration、home catalog

1. `PrimoApp` が `DocumentRuntimeFactory.live()` を作り、`PrimoRootFeature` の store に `documentRuntime` dependency として注入する
2. `ApplicationFeature.task` が startup language load、startup presentation bootstrap、home projects load、autosave recovery load を開始する
3. `CrossFeatureIntegrationReducer` が application delegate を workspace / document action に変換する
4. `WorkspaceFeature` が catalog、autosave recovery、save history、tab reservation、project load / persistence を進める
5. `DocumentFeature` が bootstrap presentation や loaded project presentation を canvas / layer sidebar / brush palette 周辺 state に適用する

### Canvas入力からstroke commitまで

1. `CanvasPresentationContainerView` と `CanvasInputHandler` が Pencil / touch / gesture を `CanvasPresentationAction` に変換する
2. `CanvasView` がその action を `CanvasFeature.Action` へ写し、`DocumentFeature` の canvas editing workflow へ渡す
3. `CanvasEditingWorkflowReducer` が tool、active layer、brush settings、selection state から stroke context を組み立てる
4. `CanvasStrokeInteractionService` と `DocumentStrokeSessionUseCase` が stroke session と preview lease を管理する
5. `DocumentStrokeCommandService` / `StrokeInputGateway` が begin / append / end / cancel / fill を runtime へ渡す
6. `DocumentEngineLive` が `SwiftDocumentRuntime` から stroke commit plan を作り、Metal stroke services で GPU mutation を実行する
7. `SwiftDocumentRuntime` が GPU 結果を layer record / buffer handle / undo history / dirty update / timelapse に反映する
8. presentation refresh が canvas state に反映されるまで、canvas は committed snapshot や preview surface を併用して次の入力に備える

### Layer、selection、transform、text、adjustment

1. `LayerWorkflowReducer`、`AdjustmentWorkflowReducer`、`CanvasEditingWorkflowReducer` が UI 操作を document mutation intent に変換する
2. `DocumentMutationWorkflowService`、`DocumentContentService`、`DocumentEditingGateway`、`SelectionWorkflowService` が layer mutation、folder mutation、mask、selection、text layer、processing request を組み立てる
3. `DocumentRuntimeComposition` が `DocumentEngineLive` の gateway と GPU operation gateway を組み合わせ、application service から呼べる境界を作る
4. Metal rendering infrastructure が preview composite、selection overlay、layer transform、alpha mask、scaled / translated pixel data、layer processing を担当する
5. mutation 成功時は lightweight presentation が publish され、必要に応じて full presentation refresh が走る

### Project save/loadとworkspace

1. ホーム画面の project card が `WorkspaceFeature.Action.homeProjectSelected` を送る
2. `WorkspaceFeature` が active tab の保存準備や tab reservation を行い、workspace application workflow に load / persistence command を渡す
3. `DocumentEngineLive` が `SwiftDocumentRuntime.loadProject` で `.atelier` package を読み、full `presentation()` と paper style を持つ `LoadedPaintProject` を返す
4. `DocumentFeature` が loaded presentation を canvas / layer sidebar / interaction state に適用する
5. workspace が tab reservation を確定し、application state がホームを閉じて編集画面へ戻る

### Presentation、preview、export

- `DocumentPresentationReader` は lightweight / full presentation を読み出す app-facing 境界です。
- `DocumentDirtyUpdateQueue` は runtime の dirty update を消費する境界です。
- `DocumentRenderingWorkflow` は paper preview、composited preview pixel data、processed layer pixel data、alpha mask、cropped selection mask、scale / translate などを GPU operation に委譲します。
- `GpuCanvasPreviewRenderer` は eyedropper loupe、selection overlay、preview surface など canvas 表示補助を担当します。
- `DocumentExportGateway` は paper style を反映した composite surface、PNG data、timelapse capture を返します。

### Timelapse

- `SwiftDocumentRuntime` は stroke、blur、fill、paper style、layer/folder mutation などの timelapse operation と frame data を記録します。
- `PrimoDocumentTimelapseInfrastructure` は operation の保存・復元と frame persistence を担当します。
- `TimelapseExportService` は `TimelapseCapture` を video export し、progress callback で preview surface / preview image data を返せます。
- `DocumentTimelapseReplayService` は timelapse operation を replay して preview surface を生成します。

### AI image edit

- `AIImageFeature` は設定、commerce 状態、generation 状態、UI feedback を扱います。
- `AIImageWorkflowReducer` は prompt、selection、active layer、text layer、document content をもとに edit request を準備します。
- `AIImageEditUseCase` は `AIImageRemoteEditClient` を通して remote edit を実行します。
- `AIImageRuntime` は settings、commerce、remote edit client の live façade を提供し、network / secrets / key-value storage は infrastructure 側へ閉じ込めます。
- edit 結果は document mutation workflow に戻され、layer pixels や text layer data へ反映されます。

## 主な機能

- 複数レイヤーのラスター document model
- レイヤーの追加、削除、複製、移動、名前変更、表示切り替え、ロック、alpha lock、clipping、opacity、blend mode
- レイヤーフォルダの作成、削除、表示、展開、リネーム、割り当て
- レイヤーマスクの作成、クリア、適用
- Apple Pencil / touch 入力による brush stroke、eraser、blur stroke
- 塗りつぶし、スポイト、選択、移動、変形、シェイプ、テキスト系 workflow
- selection mask の生成、合成、拡張、縮小、ぼかし、反転、変形
- layer processing、mask 操作、merge down、canvas resize / extent resize
- paper style、透明背景 preview、PNG export
- project save / load、workspace autosave、復元、タブ管理、save history
- timelapse capture / export / replay
- Gemini / OpenAI Image を扱う AI 画像編集補助
- Photoshop brush / brush tip import、custom brush tip、font import、brush runtime settings

## プロジェクト構成

- `App/`
  SwiftUI / TCA のアプリ本体です。画面、reducer、workflow、dependency wiring、menus、workspace UI、canvas wrapper を持ちます。
- `Packages/PrimoModules/`
  domain、contracts、application、runtime façade、Metal infrastructure、workspace、brush、AI image、localization をまとめたローカル Swift package です。Primo app 専用の module 群として app と同じ iOS 26.0 以上を前提にしています。macOS target は package 単体の `swift test` を実行するためのものです。
- `PrimoTests/`
  app 側 workflow と reducer まわりのテストです。
- `Packages/PrimoModules/Tests/`
  package 化された domain / application / infrastructure のテストです。
- `project.yml`
  XcodeGen 用のプロジェクト定義です。チェックイン済みの `Primo.xcodeproj` もあります。

## Package分割

`PrimoModules` は次のような責務で分かれています。

### Core、domain

- `PrimoCoreTypes`
  file、date、UUID、HTTP、key-value store、secret store、security-scoped resource、main queue などの共通 client と operation contract
- `PrimoLocalization`
  共通ローカライズ型
- `PrimoDocumentDomain`
  document identifier、pixel geometry、tool、layer、folder、text layer、workspace document の基本型
- `PrimoCanvasInputDomain`
  stylus sample、canvas input event、gesture / pointer input などの入力 domain
- `PrimoCanvasPresentationDomain`
  canvas presentation state、preview、selection / transform overlay など UIKit / Metal presentation に渡す型
- `PrimoWorkspaceDomain`
  workspace item、saved project summary、autosave recovery、tab / catalog 関連の domain
- `PrimoBrushDomain`
  brush kind、tip、preset、色やブラシ設定の domain
- `PrimoAIImageDomain`
  AI image edit の model、provider、settings、commerce / generation 周辺の domain

### Contracts

- `PrimoDocumentMutationContracts`
  document mutation request / payload / failure、layer processing、selection / mask / text mutation などの境界
- `PrimoDocumentPersistenceContracts`
  project save / load、loaded project、export、timelapse capture など persistence / export 境界
- `PrimoDocumentPresentationContracts`
  `PaintDocumentPresentation`、layer row、canvas paper style、composite surface など app presentation 境界
- `PrimoDocumentRenderingContracts`
  preview rendering、selection mask processing、layer transform processing、rendering workflow の境界
- `PrimoDocumentGPUContracts`
  Metal buffer handle、GPU resource lease、stroke / preview / layer GPU operation request の境界
- `PrimoDocumentContracts`
  app と document runtime の間にある query / render / dirty update / mutation / stroke / history / persistence / export / text layer gateway の集約
- `PrimoBrushRuntimeContracts`
  brush runtime settings、descriptor assembly、imported Photoshop brush sample など brush runtime 境界

### Application

- `PrimoDocumentApplication`
  document editing、layer mutation、canvas editing、selection workflow、content service、raster image service、mutation workflow などの use case
- `PrimoDocumentStrokeApplication`
  stroke session state、stroke interaction、preview lease、stroke commit workflow の application service
- `PrimoWorkspaceApplication`
  workspace catalog、autosave、load、reservation、persistence、save history の workflow service
- `PrimoAIImageApplication`
  AI image settings、command builder、remote edit use case の application service

### Runtime façade

- `PrimoDocumentRuntime`
  app-facing façade です。`DocumentRuntimeFactory.live()`、`DocumentRuntime`、command services、presentation reader、rendering workflow、preview renderer、timelapse export service などを公開します。
- `PrimoWorkspaceRuntime`
  workspace application services、document workspace client、document import client の live façade です。
- `PrimoBrushRuntime`
  brush tip library、font library、brush import service の live façade です。
- `PrimoAIImageRuntime`
  AI image settings、commerce、remote edit client の live façade です。

### Infrastructure

- `PrimoDocumentInfrastructure`
  document runtime support、shared document helper 実装
- `PrimoDocumentEngineInfrastructure`
  `SwiftDocumentRuntime`、`DocumentEngineLive`、`DocumentRuntimeComposition`、runtime GPU service wiring、project preview loader、timelapse export を持つ live engine 層
- `PrimoDocumentMetalRuntimeInfrastructure`
  Metal runtime context、shader library、Metal canvas view、document processing client、`PaintShaders.metal` など低レベル Metal runtime
- `PrimoDocumentMetalSurfaceInfrastructure`
  Metal surface resource gateway と buffer handle 管理
- `PrimoDocumentMetalStrokeInfrastructure`
  stroke processing service と GPU stroke renderer
- `PrimoDocumentMetalLayerInfrastructure`
  Metal layer processing façade
- `PrimoDocumentRenderingInfrastructure`
  canvas preview、selection、transform、eyedropper、rendering operations、GPU operation backend
- `PrimoDocumentPersistenceInfrastructure`
  project save / load、manifest、layer RGBA、mask、timelapse persistence、image codec
- `PrimoDocumentStrokeInfrastructure`
  CPU 側 stroke geometry、brush stroke kernel、document raster service
- `PrimoDocumentTimelapseInfrastructure`
  timelapse operation、frame persistence、stored operation model
- `PrimoCanvasPresentationInfrastructure`
  UIKit / Metal presentation views、input handler、selection overlay、eyedropper loupe、render session
- `PrimoWorkspaceInfrastructure`
  document workspace client、project catalog、import client
- `PrimoBrushFileFormats`
  Photoshop brush / brush tip file format
- `PrimoBrushInfrastructure`
  brush tip library、font library、brush import
- `PrimoAIImageInfrastructure`
  remote edit HTTP client、settings storage、commerce adapter

## 重要なファイル

- [App/Application/PrimoApp.swift](App/Application/PrimoApp.swift)
  app entry point です。`DocumentRuntimeFactory.live()` を作り、root store の dependency に注入します。
- [App/Features/Document/PrimoRootFeature.swift](App/Features/Document/PrimoRootFeature.swift)
  root reducer です。application / workspace / document / import-export / AI image feature を scope します。
- [App/Features/Document/CrossFeatureIntegrationReducer.swift](App/Features/Document/CrossFeatureIntegrationReducer.swift)
  feature 間の delegate action を接続する integration reducer です。
- [App/Features/Document/PaintDocumentClient.swift](App/Features/Document/PaintDocumentClient.swift)
  app 側 document dependency wiring です。`DocumentRuntime` から各 command service / gateway / renderer / processor を `DependencyValues` へ展開します。
- [App/Features/Document/DocumentFeature.swift](App/Features/Document/DocumentFeature.swift)
  document editor の TCA reducer 本体です。canvas interaction、document mutation、import / export、AI 画像編集 workflow を束ねます。
- [App/Features/Canvas/CanvasView.swift](App/Features/Canvas/CanvasView.swift)
  SwiftUI と UIKit canvas presentation の接続点です。
- [App/Features/Canvas/CanvasFeature.swift](App/Features/Canvas/CanvasFeature.swift)
  canvas state、render snapshot、stroke preview、pending committed snapshot、selection / transform preview を保持します。
- [App/Features/Document/WorkspaceFeature+Workflow.swift](App/Features/Document/WorkspaceFeature+Workflow.swift)
  home project selection、tab reservation、autosave、save history、project load / persistence の workflow を扱います。
- [Packages/PrimoModules/Sources/PrimoDocumentRuntime/DocumentRuntimeFacade.swift](Packages/PrimoModules/Sources/PrimoDocumentRuntime/DocumentRuntimeFacade.swift)
  app-facing runtime façade です。engine infrastructure の composition を公開用 `DocumentRuntime` と services に変換します。
- [Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift](Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift)
  runtime、stroke use case、GPU operation gateway を app 向けに組み合わせる composition root です。
- [Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift](Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift)
  `SwiftDocumentRuntime` を `LockedDocumentRuntimeExecutor` の後ろに保持し、gateway 群として公開する live engine です。
- [Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentRuntime.swift](Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentRuntime.swift)
  document store、undo / redo、dirty update、stroke commit、GPU-backed layer buffer、save / load、timelapse を扱う runtime 本体です。
- [Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeGpuServices.swift](Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeGpuServices.swift)
  runtime から Metal 処理を呼び出すための GPU service 集約です。
- [Packages/PrimoModules/Sources/PrimoDocumentRenderingInfrastructure/DocumentGpuOperationBackend.swift](Packages/PrimoModules/Sources/PrimoDocumentRenderingInfrastructure/DocumentGpuOperationBackend.swift)
  preview、selection、transform、layer processing など表示・編集補助向け GPU operation の backend です。
- [Packages/PrimoModules/Sources/PrimoCanvasPresentationInfrastructure/CanvasPresentationContainerView.swift](Packages/PrimoModules/Sources/PrimoCanvasPresentationInfrastructure/CanvasPresentationContainerView.swift)
  canvas surface、入力、selection overlay、transform preview、text overlay、eyedropper loupe を束ねる UIKit view です。
- [Packages/PrimoModules/Sources/PrimoCanvasPresentationInfrastructure/CanvasMetalSurfaceViews.swift](Packages/PrimoModules/Sources/PrimoCanvasPresentationInfrastructure/CanvasMetalSurfaceViews.swift)
  Metal surface を SwiftUI / UIKit から表示する view 群です。ホームや tab preview では表示専用として hit testing を無効化します。
- [Packages/PrimoModules/Sources/PrimoDocumentPersistenceInfrastructure/DocumentPersistenceModels.swift](Packages/PrimoModules/Sources/PrimoDocumentPersistenceInfrastructure/DocumentPersistenceModels.swift)
  `.atelier` project の `manifest.json` に対応する `StoredPrimoDocument` model です。

## ドキュメント保存形式

project save は単一ファイルではなく `.atelier` package として扱うディレクトリ構成です。主な内容は package 側の persistence 実装で定義されています。

- `manifest.json`
  `StoredPrimoDocument` として保存されます。`version`、`canvasWidth`、`canvasHeight`、`activeLayerIndex`、`paperStyle`、`layers`、`folders`、`timelapseFrames`、`timelapseOperations` を保持します。
- `Layers/layer-XXXX.rgba`
  各レイヤーの RGBA pixel data です。manifest の各 layer は `pixelFilename` を持ちます。
- `Layers/layer-mask-XXXX.mask`
  レイヤーマスクがある場合に使われます。manifest の各 layer は optional な `maskFilename` を持ちます。
- `Timelapse/`
  フレームベースのタイムラプス保存に使います。
- `TimelapseData/`
  操作ベースのタイムラプス補助データに使います。

manifest の layer entry は index、name、visible、locked、alphaLocked、clipped、opacity、blendMode、folderID、textLayer、pixelFilename、maskFilename を持ちます。folder entry は id、name、visible、expanded、anchorLayerIndex を持ちます。古い manifest から読むときは、lock / alpha lock / clipping / folder / timelapse operation など一部 field に fallback を用意しています。

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

リポジトリルートのアプリビルド確認には `scripts/codex-build.sh` を使います。この script は package dependency resolve、SwiftNavigation manifest patch、app build を行い、test は実行しません。

```bash
scripts/codex-build.sh
```

CI / pre-merge の最低限の品質ゲートは、build と test を分けて実行します。

```bash
scripts/codex-build.sh
scripts/codex-test-package.sh
scripts/codex-test-canvas-stroke.sh
```

`scripts/codex-test-canvas-stroke.sh` は利用可能な iPad Simulator を自動選択します。特定の simulator を使う場合は `PRIMO_TEST_DESTINATION` で上書きできます。

Metal / simulator / device 依存のテストが増えた場合は、GPU 必須テストと pure reducer tests を分けて、CI でも別 job として扱います。

Fork している Swift package dependency の理由、upstream 差分、upstream へ戻す条件、security update と third-party notices の更新方針は [docs/DependencyForks.md](docs/DependencyForks.md) にまとめています。

よく使う focused test は次のとおりです。

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild test -scheme Primo -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' -only-testing:PrimoTests/CanvasStrokeWorkflowTests
xcodebuild test -scheme Primo -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' -only-testing:PrimoTests/PrimoRootFeatureIntegrationTests
cd Packages/PrimoModules && swift test --filter PrimoCanvasPresentationInfrastructureTests
```

## README更新時の確認

README は実装の入口として扱うため、設計説明を更新するときは次を確認します。

- README 内で参照しているファイルが存在すること
- `Packages/PrimoModules/Package.swift` の target / product 分割と説明がずれていないこと
- `project.yml` の app target dependencies と README の runtime / package 説明が矛盾していないこと
- `PrimoRootFeature`、`PaintDocumentClient`、`DocumentRuntimeFacade`、`DocumentRuntimeComposition`、`DocumentEngineLive`、`SwiftDocumentRuntime` の責務説明が現状と合っていること
- Markdown の見出し階層、コードブロック、相対リンクが崩れていないこと
