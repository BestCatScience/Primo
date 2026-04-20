# 2026-04-16 から 2026-04-20 にかけてのドキュメント系リファクタリング記録

この文書は、`0558a6323d9c5f6a371ad3e494729d6eff68687d` から `4e8358b19feef593f801d1c7f85f21ea53852f49` までの 82 コミットで実施した、ドキュメント機能まわりの大規模リファクタリングを振り返るための記録です。

対象は主に次の領域です。

- `AppFeature` の責務分割
- `PaintDocumentSession` の分割と契約化
- workspace のロード、永続化、障害処理の整理
- NanoBanana の domain / application / infrastructure 分離
- ローカル Swift package `Packages/PrimoModules` への段階的な抽出

## 先に結論

このリファクタリングの最終到達点は、アプリ層を「UI と orchestration に専念する薄い層」に寄せ、ドキュメント処理の中心を package 側へ移すことでした。

現在はおおむね次の形に整理されています。

- `AppFeature` は workflow / routing / UI state coordination を担当する
- `PaintDocumentClient` は app から document runtime を使うための依存注入境界になる
- document の query / mutation / stroke / history / persistence / export は contract と gateway で分離される
- workspace / brush / localization / NanoBanana は個別 package に切り出される
- 最後に `PaintDocumentSession` 自体も package runtime 側へ移され、app 側は runtime の組み立てと利用に集中する

## フェーズ別まとめ

## フェーズ 1: AppFeature と PaintDocumentSession の分割開始

期間: 2026-04-16

最初の段階では、巨大化していた `AppFeature.swift` と `PaintDocumentSession.swift` を、責務別のファイル群へ解体する作業が中心でした。

このフェーズで進んだこと:

- `AppFeature` の helper 群を、image / selection / persistence / routing / workflow 単位へ分割
- `DocumentWorkspaceClient` を独立ファイルに抽出
- `PaintDocumentSession` を bridge / persistence / text layer / timelapse などの責務ごとに分割
- state と service を分離し、session を単一巨大型ではなく協調する部品群として扱う方向へ移行
- system 依存の副作用を dependency 経由へ寄せ、静的アクセスを減らす
- brush library の static 依存を client 化
- document path を value object 化して path 取り回しを明示化

狙い:

- 1 ファイルに集まり過ぎていた責務を見える形にする
- reducer と session の境界を先に薄くし、その後の package 抽出に耐えられる形へ整える
- 副作用を dependency 経由にそろえ、テスト可能性を上げる

代表コミット:

- `0558a63` Split AppFeature helpers by responsibility
- `1729d8c` Split PaintDocumentSession by responsibility
- `50488b5` Split PaintDocumentSession state and services
- `77f672d` Inject system side effects behind dependencies
- `9224d13` Introduce document path value objects

## フェーズ 2: workflow / ownership / side effect の境界強化

期間: 2026-04-17

次の段階では、分割したファイルをただ増やすだけでなく、どの層が何を所有するかを明文化する方向へ進みました。特に `AppFeature` が直接いろいろな処理を抱え込む構造をやめ、workflow と state coordination を中心に再編しています。

このフェーズで進んだこと:

- reducer routing を concern ごとに分離
- canvas state transition、palette / sidebar 同期、workspace routing などの coordinator を独立
- workflow side effect と session service の責務を切り分け
- workspace load lifecycle、restore failure、loaded project success effect などのライフサイクル処理を分離
- failure action や feedback を型付きメッセージへ寄せ、エラー伝播を整理
- document mutation contract を導入し、mutation の返り値と失敗型を揃え始める
- editing boundary を強化して、layer / selection / stroke / export / NanoBanana の責務混在を減らす

狙い:

- 「どこで副作用を起こすか」と「どこで状態遷移を決めるか」を分ける
- workspace / canvas / document session の所有権を曖昧にしない
- 失敗系を ad-hoc な分岐ではなく contract と message で扱う

代表コミット:

- `ff36abf` Deepen workflow and session service separation
- `674531b` Encapsulate canvas state transitions
- `5d651f4` Encapsulate workspace routing boundaries
- `6e829b6` Type document workflow failure actions
- `c94e65d` Refactor document mutation contracts
- `de5cd63` Deepen document editing isolation

補足:

- `89e4a12` で `"Isolate document workflow side effects"` を一度 revert しており、この期間は境界を急ぎ過ぎず再調整しながら前進していたことが分かります。

## フェーズ 3: workspace 契約と mutation 実行境界の整理

期間: 2026-04-18

この段階では、workspace のロードや永続化、catalog、予約、canvas replacement といったアプリの土台部分が重点的に整理されました。同時に document mutation の結果や transaction 境界も見直され、操作実行の contract がかなり安定してきます。

このフェーズで進んだこと:

- workspace persistence と stroke workflow を分離
- workspace loading と reservation の手順を明示化
- mutation transaction と mutation result の扱いを整理
- workspace catalog effect と warning / failure contract を整理
- core test を追加し、workspace まわりの振る舞いを固定化
- NanoBanana state と workflow boundary も app 全体の構造に合わせて再編

狙い:

- document を開く / 復元する / 置き換える / 保存する、の一連の遷移を安全にする
- mutation の成功 / 失敗 / index 返却を型として揃える
- package 抽出前に workspace 領域の設計を安定させる

代表コミット:

- `d054e7e` Refactor workspace persistence and stroke workflows
- `ed16423` Refactor workspace loading and add core tests
- `5b32f99` Refactor workspace catalog effects and mutation transactions
- `e3f9fac` Refactor workspace reservation and mutation contracts
- `49872ec` Refine workspace load boundaries and mutation results

## フェーズ 4: package への抽出と NanoBanana の層分離

期間: 2026-04-19

ここからは、前段までに整理した境界を実際に `Packages/PrimoModules` へ移す作業が本格化します。domain / application / infrastructure という層の分け方がはっきり表れ始めるのがこのフェーズです。

このフェーズで進んだこと:

- workspace domain を local Swift package へ抽出
- localization と system client を package 化
- brush domain、import file format、brush import service を package 化
- document identifier を package domain へ移動
- NanoBanana を domain / application / infrastructure 層へ整理
- preview 準備や edit command 生成を application layer へ移し、UI から分離
- document mutation contract を package へ寄せ、execution boundary をさらに明確化
- layer mutation の use case を抽出
- app 側 logging を絞り込み、gateway を app-facing な形へ整える
- project 名を `atelierprime` から `Primo` へ変更

狙い:

- app target から business rule と infrastructure を段階的に切り離す
- NanoBanana を feature 実装ではなく独立モジュールとして育てられる形にする
- brush / workspace / document といったドメインを package 単位で再利用しやすくする

代表コミット:

- `c58d737` Extract workspace domain into local Swift package
- `534bd00` Extract brush domain and import file formats into packages
- `117af05` Refactor app feature and nano banana modules
- `2e8fd1d` Refactor NanoBanana into application layers
- `a923dd9` Move NanoBanana preview prep into application layer
- `ff51db3` Introduce document mutation contracts
- `7dcd8b9` Extract document layer mutation use cases
- `c3f2c02` Rename project to Primo

## フェーズ 5: document runtime の package 移設

期間: 2026-04-19 から 2026-04-20

最後の仕上げとして、contract だけでなく runtime そのものが package 側へ移されました。これにより app 側の `PaintDocumentClient` は runtime factory から gateway 群を受け取って束ねる薄い facade になっています。

このフェーズで進んだこと:

- document runtime contract を package へ移動
- document runtime 実装を package infrastructure へ移動
- `PaintDocumentSession` を package runtime へ移動
- app 側の document 関連 API を gateway 中心の wiring に変更

現在の見え方:

- `PrimoDocumentContracts`
  query / mutation / stroke / history / persistence / export / text layer の契約
- `PrimoDocumentApplication`
  document use case と app から見た操作の意味づけ
- `PrimoDocumentInfrastructure`
  document の基盤実装
- `PrimoDocumentRuntimeInfrastructure`
  legacy runtime を含む runtime factory と app 接続の実体

代表コミット:

- `ec059c5` Move document runtime contracts into packages
- `1482e21` Move document runtime into package infrastructure
- `4e8358b` Move PaintDocumentSession into package runtime

## 最終的に得られた構造

今回の連続リファクタリングで、ドキュメント機能はおおむね次の責務分担に整理されました。

### App 層

- `AppFeature` は reducer と workflow orchestration を担当する
- UI state coordination、routing、presentation の組み立てを行う
- package 側の contract と gateway を組み合わせて使う

### Document package 群

- domain:
  document identifier やコア型を保持する
- contracts:
  app と runtime のあいだの query / mutation / persistence 契約を定義する
- application:
  mutation use case や higher-level operation を表す
- infrastructure:
  bridge、engine、永続化、runtime 実装を提供する

### 周辺 package 群

- `PrimoWorkspace*`
  workspace の domain / application / infrastructure を分離
- `PrimoNanoBanana*`
  NanoBanana の state、edit command、preview preparation、infrastructure を分離
- `PrimoBrush*`
  brush domain、file format、import service を分離
- `PrimoLocalization`
  共通ローカライズ資産を集約

## このリファクタリングの意義

実装上のメリットは次のとおりです。

- 変更の影響範囲が `AppFeature.swift` や `PaintDocumentSession.swift` の巨大ファイル全体へ広がりにくくなった
- reducer から document runtime への依存が gateway 経由になり、差し替えやテストがしやすくなった
- workspace / document / NanoBanana / brush の境界が package 名としても可視化された
- failure と mutation result が型で扱われるようになり、分岐の意図を追いやすくなった
- UI 側の事情と document runtime の事情を別々に進化させやすくなった

## 主要コミット一覧

以下は、この文書の対象にしたコミット一覧です。短い SHA と件名をそのまま残しています。

### 2026-04-16

- `0558a63` Split AppFeature helpers by responsibility
- `ef2f4a2` Extract DocumentWorkspaceClient into dedicated file
- `1729d8c` Split PaintDocumentSession by responsibility
- `77f672d` Inject system side effects behind dependencies
- `50488b5` Split PaintDocumentSession state and services
- `f5261df` Extract AppFeature document workflows
- `3f94f95` Replace brush library statics with clients
- `9224d13` Introduce document path value objects
- `13c98ad` Extract workspace tab workflows from AppFeature
- `626d361` Extract editing workflows from AppFeature
- `caa4117` Thin AppFeature orchestration and session lifecycle
- `19526a8` Extract UI state and bridge services
- `dab8721` Deepen AppFeature workflow encapsulation
- `7b8a733` Split AppFeature workflows by concern
- `5818193` Further isolate AppFeature and session responsibilities
- `1016e2b` Split reducer routing and session services
- `0bc4a14` Split AppFeature image and selection operations
- `57b2178` Further split AppFeature and session domains

### 2026-04-17

- `ff36abf` Deepen workflow and session service separation
- `8d04280` Split bridge services and type document identifiers
- `3bc9c10` Refactor paint document session boundaries
- `60ddf4f` Tighten document session boundaries
- `ff295e7` Harden document architecture boundaries
- `97961ce` Refine document state ownership boundaries
- `3a839a1` Eliminate app feature compatibility layer
- `674531b` Encapsulate canvas state transitions
- `d2ba9a3` Encapsulate palette and sidebar sync
- `3e203f8` Isolate document workflow side effects
- `c3e966a` Isolate workspace loading flows
- `5dbdd44` Strengthen document workflow service boundaries
- `2ef50aa` Consolidate workspace and nano banana services
- `4d8021a` Refine workspace and canvas ownership boundaries
- `d170dac` Tighten export and nano banana boundaries
- `425cf11` Unify loaded project workspace flows
- `a498d1a` Isolate workspace load lifecycle
- `5d651f4` Encapsulate workspace routing boundaries
- `ccd3f8b` Refine restore failure boundaries
- `933a0bf` Separate loaded project success effects
- `2f7f7c5` Harden canvas replacement contracts
- `57a1740` Reserve workspace tabs before replacement
- `9f8a636` Isolate persistence failure handling
- `a6c1ee9` Type document workflow application feedback
- `6e829b6` Type document workflow failure actions
- `fca5072` Make localization source language Japanese-first
- `c94e65d` Refactor document mutation contracts
- `0bbaf93` Strengthen document mutation contracts
- `96d979f` Refine document editing boundaries
- `ddfaad7` Isolate document editing boundaries
- `de5cd63` Deepen document editing isolation
- `89e4a12` Revert "Isolate document workflow side effects"
- `0e2acff` Fix scheme storekit reference and panel state
- `48591ea` Fix Nano Banana subscription messaging

### 2026-04-18

- `6c6240e` Refactor document workflows and support clients
- `a7f10f3` Refactor workflow boundaries and Nano Banana state
- `d62d92e` Refactor document mutation and workspace boundaries
- `d054e7e` Refactor workspace persistence and stroke workflows
- `ed16423` Refactor workspace loading and add core tests
- `5b32f99` Refactor workspace catalog effects and mutation transactions
- `e3f9fac` Refactor workspace reservation and mutation contracts
- `49872ec` Refine workspace load boundaries and mutation results
- `ac3aefe` Refactor workspace load preparation and persistence warnings

### 2026-04-19

- `31e09fa` Refactor workspace contracts and add Codex build script
- `1ed2614` Refactor workspace catalog and canvas failure contracts
- `fb51558` Refactor document failure actions to use messages
- `c58d737` Extract workspace domain into local Swift package
- `ce3fdc9` Extract shared localization and system clients into packages
- `534bd00` Extract brush domain and import file formats into packages
- `12f835b` Move brush import services into package infrastructure
- `46da87f` Move document identifiers into package domain
- `117af05` Refactor app feature and nano banana modules
- `2e8fd1d` Refactor NanoBanana into application layers
- `c6701de` Refine feature state and workspace gateways
- `a923dd9` Move NanoBanana preview prep into application layer
- `ff51db3` Introduce document mutation contracts
- `993f2d5` Refactor document mutation execution boundary
- `7dcd8b9` Extract document layer mutation use cases
- `c3f2c02` Rename project to Primo
- `99a37ad` Refactor document gateways and trim app logging
- `07ffce2` Split app feature routing boundaries
- `ec059c5` Move document runtime contracts into packages

### 2026-04-20

- `1482e21` Move document runtime into package infrastructure
- `4e8358b` Move PaintDocumentSession into package runtime
