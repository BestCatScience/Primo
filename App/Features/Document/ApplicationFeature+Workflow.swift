import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication

extension ApplicationFeature {
    func startupLanguageLoadEffect() -> Effect<Action> {
        .run { [appLanguageClient] send in
            await send(.startupLanguageLoaded(appLanguageClient.load()))
        }
    }

    func persistLanguageEffect(_ language: AppLanguage) -> Effect<Action> {
        .run { [appLanguageClient] _ in
            appLanguageClient.persist(language)
        }
    }
}

extension ApplicationFeature.Feedback {
    func message(for language: AppLanguage) -> String {
        switch self {
        case let .saveFailed(message):
            return (message?.isEmpty == false) ? message! : language.localized("保存に失敗しました")
        case let .openFailed(message):
            return (message?.isEmpty == false) ? message! : StudioStrings.openFailed(language)
        case let .moveFailed(message):
            return (message?.isEmpty == false) ? message! : language.localized("移動に失敗しました")
        case let .autosaveRestoreFailed(message):
            return (message?.isEmpty == false)
                ? message!
                : language.localized("自動保存を復元できませんでした")
        case let .saveHistoryRestoreFailed(message):
            return (message?.isEmpty == false)
                ? message!
                : language.localized("保存履歴を復元できませんでした")
        case let .couldNotCreateCanvasFromImage(message):
            return (message?.isEmpty == false) ? message! : language.localized("画像からキャンバスを作成できませんでした")
        case let .couldNotImportPhoto(message):
            return (message?.isEmpty == false) ? message! : language.localized("写真を読み込めませんでした")
        case .photoImportedToNewLayer:
            return language.localized("写真を新規レイヤーに読み込みました")
        case .textLayerApplyFailed:
            return language == .japanese
                ? "テキストをレイヤーに適用できませんでした"
                : "Could not apply text to the layer"
        case .layerUnavailable:
            return language == .japanese
                ? "対象のレイヤーが見つかりませんでした"
                : "The target layer could not be found"
        case .folderUnavailable:
            return language == .japanese
                ? "対象のフォルダが見つかりませんでした"
                : "The target folder could not be found"
        case .layerEditLocked:
            return language == .japanese
                ? "レイヤーがロックされているため編集できません"
                : "The layer is locked and cannot be edited"
        case .layerAlphaEditLocked:
            return language == .japanese
                ? "アルファロックされているため編集できません"
                : "The layer is alpha locked and cannot be edited"
        case .invalidLayerOpacity:
            return language == .japanese
                ? "レイヤーの不透明度が不正です"
                : "The layer opacity is invalid"
        case .emptyDocumentMutationInput:
            return language == .japanese
                ? "空の入力ではこの操作を実行できません"
                : "This operation requires a non-empty input"
        case let .documentMutationBridgeFailed(message):
            return (message?.isEmpty == false)
                ? message!
                : (language == .japanese
                    ? "ドキュメントの更新に失敗しました"
                    : "The document update failed")
        case let .documentMutationTransactionFailed(primary, rollback):
            let primaryMessage = DocumentFeature.documentMutationFailureMessage(primary, language: language)
            let rollbackMessage = DocumentFeature.documentMutationFailureMessage(rollback, language: language)
            return language == .japanese
                ? "\(primaryMessage)\n復旧処理にも失敗しました: \(rollbackMessage)"
                : "\(primaryMessage)\nRollback also failed: \(rollbackMessage)"
        case .unsupportedLayerType:
            return language == .japanese
                ? "このレイヤー種類では操作できません"
                : "This operation is not supported for the current layer type"
        case .createLayerMaskNeedsSelection:
            return language == .japanese
                ? "選択範囲を作成してからマスクを追加してください"
                : "Create a selection before adding a mask"
        case .createLayerMaskFailed:
            return language == .japanese
                ? "レイヤーマスクを作成できませんでした"
                : "Could not create the layer mask"
        case .applyLayerMaskFailed:
            return language == .japanese
                ? "レイヤーマスクを適用できませんでした"
                : "Could not apply the layer mask"
        case .gradientMapApplyFailed:
            return language.localized("グラデーションマップを適用できませんでした")
        case .colorAdjustmentApplyFailed:
            return language.localized("色補正を適用できませんでした")
        case .exportFailed:
            return language.localized("書き出しに失敗しました")
        case .timelapseHistoryUnavailable:
            return language.localized("タイムラプス用の描画履歴がまだ足りません")
        case let .timelapseExportFailed(message):
            return (message?.isEmpty == false) ? message! : language.localized("タイムラプスの書き出しに失敗しました")
        case .nanoBananaPromptRequired:
            return language.localized("AI画像編集用のプロンプトを入力してください")
        case .nanoBananaAPIKeyRequired:
            return language.localized("AI画像編集にはサブスクリプションが必要です")
        case .nanoBananaEndpointRequired:
            return language.localized("アプリサーバーのエンドポイントを入力してください")
        case .nanoBananaPrepareLayerFailed:
            return language.localized("AI画像編集用にアクティブレイヤーを準備できませんでした")
        case .nanoBananaSelectionRequired:
            return language.localized("インペイント用の選択範囲を作成してください")
        case .nanoBananaApplyFailed:
            return language.localized("AI画像編集の結果を適用できませんでした")
        case .nanoBananaInvalidResponse:
            return language.localized("AI画像編集から不正な応答が返されました")
        case .nanoBananaInvalidEndpoint:
            return language.localized("AI画像編集のエンドポイントが不正です")
        case .nanoBananaMissingImage:
            return language.localized("AI画像編集が画像を返しませんでした")
        case .nanoBananaUnsupportedImage:
            return language.localized("AI画像編集が未対応の画像を返しました")
        case let .nanoBananaEditFailed(message):
            return (message?.isEmpty == false) ? message! : language.localized("AI画像編集に失敗しました")
        case .nanoBananaGenerationCanceled:
            return language.localized("AI画像編集の生成をキャンセルしました")
        case .nanoBananaEditApplied:
            return language.localized("AI画像編集の結果を適用しました")
        case .couldNotCreateTab:
            return language.localized("タブを作成できませんでした")
        case .canvasSizeUnsupported:
            return language.localized("このキャンバスサイズはサポートされていません")
        case .imageResolutionUpdated:
            return language.localized("画像の解像度を更新しました")
        case .canvasSizeUpdated:
            return language.localized("キャンバスサイズを更新しました")
        case .imageSizeUnsupported:
            return language.localized("この画像サイズはサポートされていません")
        case .canvasCreatedFromImage:
            return language.localized("画像からキャンバスを作成しました")
        case .undoUnavailableWhileDrawing:
            return language.localized("描画中は取り消しできません")
        case .redoUnavailableWhileDrawing:
            return language.localized("描画中はやり直しできません")
        case let .openedDocument(layerCount):
            return StudioStrings.openedDocument(layerCount, language)
        case let .savedDocument(fileName):
            return StudioStrings.savedDocument(fileName, language)
        case .restoredSaveHistory:
            return language == .japanese
                ? "保存履歴を復元しました"
                : "Restored from save history"
        case .restoredAutosave:
            return language == .japanese
                ? "自動保存から復元しました"
                : "Restored from autosave"
        }
    }
}

extension ApplicationFeature.State {
    mutating func beginStartup(language: AppLanguage) {
        isHydrating = true
        showsHome = true
        isLoadingHomeProjects = true
        appLanguage = language
    }

    mutating func beginHydration() {
        isHydrating = true
    }

    mutating func finishHydration(showingHome: Bool? = nil) {
        isHydrating = false
        if let showingHome {
            showsHome = showingHome
        }
    }

    mutating func failHydration(
        message: String?,
        showingHome: Bool? = nil
    ) {
        finishHydration(showingHome: showingHome)
        presentBanner(message)
    }

    mutating func completeWorkspaceProjectLoad(
        message: String? = nil
    ) {
        finishHydration(showingHome: false)
        presentBanner(message)
    }

    mutating func showHome(section: HomeSidebarSection = .home) {
        showsHome = true
        homeSection = section
    }

    mutating func selectHomeSection(_ section: HomeSidebarSection) {
        homeSection = section
    }

    mutating func showWorkspace() {
        showsHome = false
    }

    mutating func beginLoadingHomeProjects() {
        isLoadingHomeProjects = true
    }

    mutating func finishLoadingHomeProjects(_ projects: [SavedProjectSummary]) {
        homeProjects = projects
        isLoadingHomeProjects = false
    }

    mutating func presentBanner(_ message: String?) {
        bannerMessage = message
    }

    mutating func presentFeedback(_ feedback: ApplicationFeature.Feedback) {
        presentBanner(feedback.message(for: appLanguage))
    }

    mutating func clearBanner() {
        bannerMessage = nil
    }

    mutating func updateLanguage(_ language: AppLanguage) {
        appLanguage = language
    }
}

extension ApplicationFeature.RecoveryState {
    func item(id: WorkspaceItemID) -> AutosaveRecoveryItem? {
        items.first(where: { $0.id == id })
    }

    mutating func present(items: [AutosaveRecoveryItem]) {
        self.items = items
        isPresented = !items.isEmpty
    }

    mutating func dismiss() {
        isPresented = false
    }

    mutating func removeItem(id: WorkspaceItemID) {
        items.removeAll { $0.id == id }
        isPresented = !items.isEmpty
    }

    mutating func completeRestore(of id: WorkspaceItemID) {
        removeItem(id: id)
        dismiss()
    }
}
