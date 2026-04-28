import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure

extension DocumentFeature {
    struct DocumentNamingPolicy: Equatable {
        let language: AppLanguage

        func defaultLayerName(for layerSidebar: LayerSidebarFeature.State) -> String {
            layerSidebar.numberedLayerName(prefix: "Layer")
        }

        func folderName(forOrdinal ordinal: Int) -> String {
            StudioStrings.folderName(ordinal, language)
        }

        func duplicatedLayerName(for originalName: String) -> String {
            language == .japanese ? "\(originalName) のコピー" : "\(originalName) Copy"
        }

        func photoLayerName(
            proposedName: String?,
            layerSidebar: LayerSidebarFeature.State
        ) -> String {
            let fallbackName = layerSidebar.numberedLayerName(
                prefix: language == .japanese ? "写真" : "Photo"
            )
            let trimmedName = proposedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmedName.isEmpty ? fallbackName : trimmedName
        }

        func textLayerName(from draftText: String) -> String {
            let trimmedLine = draftText
                .components(separatedBy: CharacterSet.newlines)
                .first?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if let trimmedLine, !trimmedLine.isEmpty {
                return trimmedLine
            }
            return language == .japanese ? "テキスト" : "Text"
        }

        func importedCanvasLayerName(from proposedName: String?) -> String {
            let trimmedName = proposedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmedName.isEmpty {
                return trimmedName
            }
            return language == .japanese ? "画像 1" : "Image 1"
        }

        func nanoBananaLayerName(for layerSidebar: LayerSidebarFeature.State) -> String {
            layerSidebar.numberedLayerName(prefix: "Nano Banana")
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
            let primaryMessage = DocumentFeatureRuntimeReducer.documentMutationFailureMessage(primary, language: language)
            let rollbackMessage = DocumentFeatureRuntimeReducer.documentMutationFailureMessage(rollback, language: language)
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
            return language.localized("Nano Banana 用のプロンプトを入力してください")
        case .nanoBananaAPIKeyRequired:
            return language.localized("Gemini API キーを入力してください")
        case .nanoBananaEndpointRequired:
            return language.localized("アプリサーバーのエンドポイントを入力してください")
        case .nanoBananaPrepareLayerFailed:
            return language.localized("Nano Banana 用にアクティブレイヤーを準備できませんでした")
        case .nanoBananaSelectionRequired:
            return language.localized("インペイント用の選択範囲を作成してください")
        case .nanoBananaApplyFailed:
            return language.localized("Nano Banana の編集結果を適用できませんでした")
        case .nanoBananaInvalidResponse:
            return language.localized("Nano Banana から不正な応答が返されました")
        case .nanoBananaInvalidEndpoint:
            return language.localized("Nano Banana のエンドポイントが不正です")
        case .nanoBananaMissingImage:
            return language.localized("Nano Banana が画像を返しませんでした")
        case .nanoBananaUnsupportedImage:
            return language.localized("Nano Banana が未対応の画像を返しました")
        case let .nanoBananaEditFailed(message):
            return (message?.isEmpty == false) ? message! : language.localized("Nano Banana の編集に失敗しました")
        case .nanoBananaGenerationCanceled:
            return language.localized("Nano Banana の生成をキャンセルしました")
        case .nanoBananaEditApplied:
            return language.localized("Nano Banana の編集結果を適用しました")
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

extension DocumentFeatureRuntimeReducer {
    static func optionalErrorMessage(_ error: Error) -> String? {
        let message = error.localizedDescription
        return message.isEmpty ? nil : message
    }

    static func documentMutationFailureMessage(
        _ failure: DocumentMutationFailure,
        language: AppLanguage
    ) -> String {
        switch failure {
        case .invalidCanvasSize:
            return ApplicationFeedback.canvasSizeUnsupported.message(for: language)
        case .noUndoState:
            return ApplicationFeedback.undoUnavailableWhileDrawing.message(for: language)
        case .noRedoState:
            return ApplicationFeedback.redoUnavailableWhileDrawing.message(for: language)
        case .invalidLayerIndex:
            return ApplicationFeedback.layerUnavailable.message(for: language)
        case .invalidFolderID:
            return ApplicationFeedback.folderUnavailable.message(for: language)
        case .layerLocked:
            return ApplicationFeedback.layerEditLocked.message(for: language)
        case .alphaLocked:
            return ApplicationFeedback.layerAlphaEditLocked.message(for: language)
        case .invalidOpacity:
            return ApplicationFeedback.invalidLayerOpacity.message(for: language)
        case .emptyInput:
            return ApplicationFeedback.emptyDocumentMutationInput.message(for: language)
        case let .bridgeMutationFailed(message):
            return ApplicationFeedback.documentMutationBridgeFailed(message).message(for: language)
        case .incompatibleLayerType:
            return ApplicationFeedback.unsupportedLayerType.message(for: language)
        case let .transactionFailure(primary, rollback):
            return ApplicationFeedback.documentMutationTransactionFailed(
                primary,
                rollback
            )
            .message(for: language)
        }
    }

    func namingPolicy(for state: State) -> DocumentNamingPolicy {
        DocumentNamingPolicy(language: state.application.appLanguage)
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

extension ImportExportFeature.SaveHistoryState {
    mutating func beginPresentation() {
        isPresented = true
    }

    mutating func present(entries: [SaveHistoryEntry]) {
        self.entries = entries
        isPresented = true
    }

    mutating func dismiss() {
        isPresented = false
    }

    mutating func completeRestore() {
        dismiss()
    }
}

extension ImportExportFeature.ExportState {
    mutating func presentShareSheet(_ shareExport: ShareExport) {
        shareSheet = shareExport
    }

    mutating func clearOutputs() {
        shareSheet = nil
        timelapsePreview = nil
    }

    mutating func startTimelapsePreview(from capture: TimelapseCapture) {
        timelapsePreview = TimelapseExportPreview(
            progress: 0,
            previewSurface: capture.previewSurface,
            previewImageData: capture.previewImageData
        )
    }

    mutating func updateTimelapsePreview(_ progress: TimelapseExportProgress) {
        timelapsePreview = TimelapseExportPreview(
            progress: progress.progress,
            previewSurface: progress.previewSurface ?? timelapsePreview?.previewSurface,
            previewImageData: progress.previewImageData ?? timelapsePreview?.previewImageData
        )
    }

    mutating func completeTimelapseExport(with shareExport: ShareExport) {
        timelapsePreview = nil
        shareSheet = shareExport
    }

    mutating func failTimelapseExport() {
        timelapsePreview = nil
    }

    mutating func dismissShareSheet() {
        shareSheet = nil
    }
}
