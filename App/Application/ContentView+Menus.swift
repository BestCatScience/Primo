import PrimoDocumentContracts
import PrimoDocumentDomain
import SwiftUI
import UIKit
import PrimoNanoBananaDomain

extension ContentView {
    var resolvedNanoBananaInputLayerIndex: Int {
        if store.layerSidebar.layers.contains(where: { $0.index == nanoBananaState.composer.inputLayerIndex }) {
            return nanoBananaState.composer.inputLayerIndex
        }
        return store.layerSidebar.activeLayerIndex
    }

    var resolvedNanoBananaInputLayerName: String {
        store.layerSidebar.layers.first(where: { $0.index == resolvedNanoBananaInputLayerIndex })?.name ?? "-"
    }

    var nanoBananaPromptBinding: Binding<String> {
        Binding(
            get: { nanoBananaState.composer.prompt },
            set: { store.send(.nanoBanana(.promptChanged($0))) }
        )
    }

    var nanoBananaInputLayerIndexBinding: Binding<Int> {
        Binding(
            get: { nanoBananaState.composer.inputLayerIndex },
            set: { store.send(.nanoBanana(.inputLayerIndexChanged($0))) }
        )
    }

    var nanoBananaEditScopeBinding: Binding<NanoBananaEditScope> {
        Binding(
            get: { nanoBananaState.composer.editScope },
            set: { store.send(.nanoBanana(.editScopeChanged($0))) }
        )
    }

    var nanoBananaOutputModeBinding: Binding<NanoBananaOutputMode> {
        Binding(
            get: { nanoBananaState.composer.outputMode },
            set: { store.send(.nanoBanana(.outputModeChanged($0))) }
        )
    }

    var nanoBananaMaskExpansionBinding: Binding<Int> {
        Binding(
            get: { nanoBananaState.composer.maskSettings.expansion },
            set: { store.send(.nanoBanana(.maskExpansionChanged($0))) }
        )
    }

    var nanoBananaMaskInversionBinding: Binding<Bool> {
        Binding(
            get: { nanoBananaState.composer.maskSettings.isInverted },
            set: { store.send(.nanoBanana(.maskInversionChanged($0))) }
        )
    }

    var nanoBananaModelBinding: Binding<NanoBananaModel> {
        Binding(
            get: { nanoBananaState.composer.model },
            set: { store.send(.nanoBanana(.modelChanged($0))) }
        )
    }

    var nanoBananaAccessModeBinding: Binding<NanoBananaAccessMode> {
        Binding(
            get: { nanoBananaState.accessMode },
            set: { store.send(.nanoBanana(.accessModeChanged($0))) }
        )
    }

    var nanoBananaAPIKeyBinding: Binding<String> {
        Binding(
            get: { nanoBananaState.apiKey },
            set: { store.send(.nanoBanana(.apiKeyChanged($0))) }
        )
    }

    func prepareNanoBananaComposer() {
        store.send(
            .nanoBanana(
                .prepareComposer(
                    activeLayerIndex: store.layerSidebar.activeLayerIndex,
                    hasSelection: store.canvas.selection?.isEmpty == false
                )
            )
        )
    }

    var nanoBananaGenerateDisabled: Bool {
        nanoBananaState.generateDisabled || store.layerSidebar.layers.isEmpty
    }

    func requestNanoBananaGeneration(closeSheet: Bool) {
        nanoBananaFocusedField = nil
        store.send(.nanoBanana(.inputLayerIndexChanged(resolvedNanoBananaInputLayerIndex)))
        store.send(.nanoBanana(.generateButtonTapped(closeSheet: closeSheet)))
    }

    @ViewBuilder
    var nanoBananaSubscriptionControls: some View {
        LabeledContent(language.localized("状態")) {
            Text(
                nanoBananaState.commerce.isSubscriptionActive
                ? language.localized("有効")
                : language.localized("未購入")
            )
            .foregroundStyle(nanoBananaState.commerce.isSubscriptionActive ? .green : .secondary)
        }

        if let product = nanoBananaState.commerce.primaryProduct {
            LabeledContent(language.localized("プラン")) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayName)
                    Text(product.displayPrice)
                        .foregroundStyle(.secondary)
                }
            }
        } else if nanoBananaState.commerce.isLoading {
            Text(language.localized("サブスクリプション情報を読み込み中…"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        Button(language.localized("サブスクリプションを購入")) {
            store.send(.nanoBanana(.purchasePrimaryProductTapped))
        }
        .disabled(nanoBananaState.commerce.isLoading || nanoBananaState.commerce.isSubscriptionActive)

        Button(language.localized("購入を復元")) {
            store.send(.nanoBanana(.restorePurchasesTapped))
        }
        .disabled(nanoBananaState.commerce.isLoading)

        if let manageURL = nanoBananaState.commerce.manageSubscriptionsURL {
            Link(language.localized("サブスクリプションを管理"), destination: manageURL)
        }

        if let purchaseErrorMessage = nanoBananaState.commerce.purchaseErrorMessage, !purchaseErrorMessage.isEmpty {
            Text(purchaseErrorMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(language.localized("メッセージを閉じる")) {
                store.send(.nanoBanana(.purchaseErrorDismissed))
            }
            .buttonStyle(.borderless)
        }

        Text(language.localized("自社バックエンドでプロバイダ API キー注入と購入権限チェックを行う想定です"))
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    var nanoBananaPaywallSheet: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(language.localized("Nano Banana を有効化"))
                            .font(.title3.weight(.semibold))
                        Text(language.localized("Primo のサブスクリプションで、自分の API キーなしに Nano Banana を利用できます"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section(language.localized("含まれる内容")) {
                    Label(language.localized("アプリ管理の Nano Banana 編集を利用可能"), systemImage: "sparkles")
                    Label(language.localized("購入状態を自動で同期"), systemImage: "arrow.triangle.2.circlepath")
                    Label(language.localized("新しい端末でも購入を復元可能"), systemImage: "icloud")
                }

                Section(language.localized("プラン")) {
                    if let product = nanoBananaState.commerce.primaryProduct {
                        LabeledContent(product.displayName) {
                            Text(product.displayPrice)
                        }
                    } else {
                        Text(
                            nanoBananaState.commerce.isLoading
                            ? language.localized("サブスクリプション情報を読み込み中…")
                            : language.localized("サブスクリプション商品は利用できません")
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                Section(language.localized("アプリ課金プラン")) {
                    nanoBananaSubscriptionControls
                }
            }
            .navigationTitle(language.localized("サブスクリプションが必要です"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.nanoBanana(.paywallPresentationChanged(false)))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    var canvasSizePresets: [(label: String, width: Int, height: Int)] {
        [
            (
                "現在のサイズ (\(max(Int(store.canvas.canvasSize.width.rounded()), 1)) × \(max(Int(store.canvas.canvasSize.height.rounded()), 1)))",
                max(Int(store.canvas.canvasSize.width.rounded()), 1),
                max(Int(store.canvas.canvasSize.height.rounded()), 1)
            ),
            ("768 × 1024", 768, 1024),
            ("1024 × 1024", 1024, 1024),
            ("1152 × 1536", 1152, 1536),
            ("1536 × 2048", 1536, 2048),
            ("2048 × 2048", 2048, 2048)
        ]
    }

    var newCanvasSheet: some View {
        NavigationStack {
            Form {
                Section("サイズ") {
                    TextField(StudioStrings.width(language), text: $newCanvasWidthText)
                        .keyboardType(.numberPad)

                    TextField(StudioStrings.height(language), text: $newCanvasHeightText)
                        .keyboardType(.numberPad)
                }

                Section(language.localized("開始方法")) {
                    Button(language.localized("画像から作成")) {
                        beginCreateCanvasFromImageFlow()
                    }
                }
            }
            .navigationTitle(StudioStrings.newCanvas(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        showsNewCanvasSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.create(language)) {
                        guard
                            let width = resolvedCanvasDimension(from: newCanvasWidthText, fallback: defaultNewCanvasWidth),
                            let height = resolvedCanvasDimension(from: newCanvasHeightText, fallback: defaultNewCanvasHeight)
                        else { return }
                        store.send(.newCanvasRequested(width: width, height: height))
                        showsNewCanvasSheet = false
                    }
                    .disabled(
                        resolvedCanvasDimension(from: newCanvasWidthText, fallback: defaultNewCanvasWidth) == nil ||
                        resolvedCanvasDimension(from: newCanvasHeightText, fallback: defaultNewCanvasHeight) == nil
                    )
                }
            }
        }
        .onAppear {
            if newCanvasWidthText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                newCanvasWidthText = "\(defaultNewCanvasWidth)"
            }
            if newCanvasHeightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                newCanvasHeightText = "\(defaultNewCanvasHeight)"
            }
        }
        .presentationDetents([.height(410)])
        .presentationDragIndicator(.visible)
    }

    var resizeCanvasSheet: some View {
        NavigationStack {
            Form {
                Section(language.localized("サイズ")) {
                    TextField(StudioStrings.width(language), text: $resizeCanvasWidthText)
                        .keyboardType(.numberPad)

                    TextField(StudioStrings.height(language), text: $resizeCanvasHeightText)
                        .keyboardType(.numberPad)
                }

                Section {
                    Text(language.localized("現在のレイヤー内容を新しい解像度へ合わせて拡大縮小します。"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(language.localized("画像解像度"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        showsResizeCanvasSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(language.localized("変更")) {
                        guard
                            let width = resolvedCanvasDimension(from: resizeCanvasWidthText, fallback: max(Int(store.canvas.canvasSize.width.rounded()), 1)),
                            let height = resolvedCanvasDimension(from: resizeCanvasHeightText, fallback: max(Int(store.canvas.canvasSize.height.rounded()), 1))
                        else { return }
                        store.send(.resizeCanvasRequested(width: width, height: height))
                        showsResizeCanvasSheet = false
                    }
                    .disabled(
                        resolvedCanvasDimension(from: resizeCanvasWidthText, fallback: max(Int(store.canvas.canvasSize.width.rounded()), 1)) == nil ||
                        resolvedCanvasDimension(from: resizeCanvasHeightText, fallback: max(Int(store.canvas.canvasSize.height.rounded()), 1)) == nil
                    )
                }
            }
        }
        .onAppear {
            resizeCanvasWidthText = "\(max(Int(store.canvas.canvasSize.width.rounded()), 1))"
            resizeCanvasHeightText = "\(max(Int(store.canvas.canvasSize.height.rounded()), 1))"
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    var resizeCanvasExtentSheet: some View {
        NavigationStack {
            Form {
                Section(language.localized("サイズ")) {
                    TextField(StudioStrings.width(language), text: $resizeCanvasExtentWidthText)
                        .keyboardType(.numberPad)

                    TextField(StudioStrings.height(language), text: $resizeCanvasExtentHeightText)
                        .keyboardType(.numberPad)
                }

                Section {
                    Text(language.localized("描画内容は拡大縮小せず、中央基準で余白追加またはトリミングします。"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(language.localized("キャンバスサイズ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        showsResizeCanvasExtentSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(language.localized("変更")) {
                        guard
                            let width = resolvedCanvasDimension(from: resizeCanvasExtentWidthText, fallback: max(Int(store.canvas.canvasSize.width.rounded()), 1)),
                            let height = resolvedCanvasDimension(from: resizeCanvasExtentHeightText, fallback: max(Int(store.canvas.canvasSize.height.rounded()), 1))
                        else { return }
                        store.send(.resizeCanvasExtentRequested(width: width, height: height))
                        showsResizeCanvasExtentSheet = false
                    }
                    .disabled(
                        resolvedCanvasDimension(from: resizeCanvasExtentWidthText, fallback: max(Int(store.canvas.canvasSize.width.rounded()), 1)) == nil ||
                        resolvedCanvasDimension(from: resizeCanvasExtentHeightText, fallback: max(Int(store.canvas.canvasSize.height.rounded()), 1)) == nil
                    )
                }
            }
        }
        .onAppear {
            resizeCanvasExtentWidthText = "\(max(Int(store.canvas.canvasSize.width.rounded()), 1))"
            resizeCanvasExtentHeightText = "\(max(Int(store.canvas.canvasSize.height.rounded()), 1))"
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    var expandSelectionSheet: some View {
        selectionPixelAmountSheet(
            title: language.localized("選択範囲を拡張"),
            text: $selectionExpansionText,
            confirmTitle: language.localized("拡張")
        ) { amount in
            store.send(.brushPalette(.delegate(.expandSelection(amount))))
            showsExpandSelectionSheet = false
        }
    }

    var contractSelectionSheet: some View {
        selectionPixelAmountSheet(
            title: language.localized("選択範囲を縮小"),
            text: $selectionContractionText,
            confirmTitle: language.localized("縮小")
        ) { amount in
            store.send(.brushPalette(.delegate(.contractSelection(amount))))
            showsContractSelectionSheet = false
        }
    }

    var featherSelectionSheet: some View {
        selectionPixelAmountSheet(
            title: language.localized("境界をぼかす"),
            text: $selectionFeatherRadiusText,
            confirmTitle: language.localized("適用")
        ) { amount in
            store.send(.featherSelectionRequested(amount))
            showsFeatherSelectionSheet = false
        }
    }

    var transformNumericSheet: some View {
        NavigationStack {
            Form {
                Section(language.localized("位置")) {
                    LabeledContent("X") {
                        TextField("0", text: $transformOffsetXText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    LabeledContent("Y") {
                        TextField("0", text: $transformOffsetYText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }

                Section(language.localized("スケール")) {
                    if store.canvas.transformMode == .standard {
                        LabeledContent("X") {
                            TextField("100", text: $transformScaleXText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                        }
                        LabeledContent("Y") {
                            TextField("100", text: $transformScaleYText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                        }
                        Toggle(language.localized("縦横比を固定"), isOn: $transformLocksAspectRatio)
                    } else {
                        Text(language.localized("自由変形では四隅や辺を直接動かしてゆがませます。"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if store.canvas.transformMode == .standard {
                    Section(language.localized("回転")) {
                        TextField("0", text: $transformRotationText)
                            .keyboardType(.numbersAndPunctuation)
                    }

                    Section(language.localized("回転中心")) {
                        LabeledContent("X") {
                            TextField("0", text: $transformPivotXText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                        }
                        LabeledContent("Y") {
                            TextField("0", text: $transformPivotYText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }
                }
            }
            .navigationTitle(language.localized("変形の数値入力"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        showsTransformNumericSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.localized("適用")) {
                        applyTransformNumericDraft()
                        showsTransformNumericSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .onAppear {
            syncTransformNumericDraft()
        }
    }

    @ViewBuilder
    func selectionPixelAmountSheet(
        title: String,
        text: Binding<String>,
        confirmTitle: String,
        onConfirm: @escaping (Int) -> Void
    ) -> some View {
        NavigationStack {
            Form {
                Section(language.localized("ピクセル数")) {
                    TextField(language.localized("値"), text: text)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        showsExpandSelectionSheet = false
                        showsContractSelectionSheet = false
                        showsFeatherSelectionSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) {
                        guard let amount = parsedSelectionPixelValue(from: text.wrappedValue) else { return }
                        onConfirm(amount)
                    }
                    .disabled(parsedSelectionPixelValue(from: text.wrappedValue) == nil)
                }
            }
        }
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
    }

    func syncTransformNumericDraft() {
        transformOffsetXText = String(Int(store.canvas.transformPreviewOffset.width.rounded()))
        transformOffsetYText = String(Int(store.canvas.transformPreviewOffset.height.rounded()))
        transformScaleXText = String(Int((store.canvas.transformPreviewScaleX * 100).rounded()))
        transformScaleYText = String(Int((store.canvas.transformPreviewScaleY * 100).rounded()))
        transformRotationText = String(Int(store.canvas.transformPreviewRotationDegrees.rounded()))
        transformLocksAspectRatio = store.canvas.transformLocksAspectRatio
        let visualPivot = currentTransformVisualPivot()
        transformPivotXText = String(Int(visualPivot.x.rounded()))
        transformPivotYText = String(Int(visualPivot.y.rounded()))
    }

    func currentTransformBounds() -> CGRect? {
        if let selection = store.canvas.selection, !selection.isEmpty {
            return selection.bounds
        }
        guard
            let snapshot = store.canvas.renderSnapshot,
            let layer = snapshot.layers.first(where: { $0.index == store.canvas.activeLayerIndex })
        else {
            return nil
        }
        return PrimoRootFeature.transformationBounds(
            selection: nil,
            pixelData: layer.pixelData,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            gpuOperations: documentGpuOperationGateway
        )
    }

    func currentTransformVisualPivot() -> CGPoint {
        let translation = store.canvas.transformPreviewOffset
        if let pivot = store.canvas.transformPivot {
            return CGPoint(x: pivot.x + translation.width, y: pivot.y + translation.height)
        }
        let fallback = currentTransformBounds().map { CGPoint(x: $0.midX, y: $0.midY) } ?? .zero
        return CGPoint(x: fallback.x + translation.width, y: fallback.y + translation.height)
    }

    func applyTransformNumericDraft() {
        let offsetX = Double(transformOffsetXText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let offsetY = Double(transformOffsetYText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let scaleXPercent = Double(transformScaleXText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 100
        let scaleYPercent = Double(transformScaleYText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 100
        let rotation = Double(transformRotationText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let pivotX = Double(transformPivotXText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let pivotY = Double(transformPivotYText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let offset = CGSize(width: offsetX, height: offsetY)
        let resolvedScaleYPercent = (store.canvas.transformMode == .standard && transformLocksAspectRatio) ? scaleXPercent : scaleYPercent
        store.send(.canvas(.transformOffsetSet(offset)))
        store.send(.canvas(.transformAspectRatioLockChanged(transformLocksAspectRatio)))
        if store.canvas.transformMode == .standard {
            store.send(.canvas(.transformScaleSet(
                x: CGFloat(scaleXPercent / 100.0),
                y: CGFloat(resolvedScaleYPercent / 100.0)
            )))
            store.send(.canvas(.transformRotationSet(rotation)))
            store.send(.canvas(.transformPivotSet(CGPoint(
                x: pivotX - offsetX,
                y: pivotY - offsetY
            ))))
        }
    }

    var colorRangeSelectionSheet: some View {
        NavigationStack {
            Form {
                Section(language.localized("対象")) {
                    Picker(language.localized("サンプル元"), selection: $colorRangeSource) {
                        ForEach(ColorRangeSelectionSource.allCases) { source in
                            Text(source.title(language)).tag(source)
                        }
                    }
                }

                Section(language.localized("現在色")) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(store.brushPalette.brush.activeOpaqueColor)
                            .frame(width: 42, height: 42)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
                            )

                        Text(language.localized("ブラシの現在色に近い色を選択します"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(language.localized("しきい値")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(language.localized("色しきい値"))
                            Spacer()
                            Text("\(Int(colorRangeTolerance * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $colorRangeTolerance, in: 0.0...1.0)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(language.localized("最小不透明度"))
                            Spacer()
                            Text("\(Int(colorRangeMinimumAlpha * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $colorRangeMinimumAlpha, in: 0.0...1.0)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(language.localized("拡張"))
                            Spacer()
                            Text("\(Int(colorRangeExpansion.rounded())) px")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $colorRangeExpansion, in: 0...24, step: 1)
                    }
                }
            }
            .navigationTitle(language.localized("色域選択"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        showsColorRangeSelectionSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(language.localized("選択")) {
                        store.send(.colorRangeSelectionRequested(currentColorRangeRequest))
                        showsColorRangeSelectionSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    var hueSaturationBrightnessSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.hueSaturationBrightness(language)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(StudioStrings.hue(language))
                            Spacer()
                            Text("\(Int(hsbAdjustmentSettings.hueDegrees.rounded()))°")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $hsbAdjustmentSettings.hueDegrees, in: -180...180, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(StudioStrings.saturation(language))
                            Spacer()
                            Text(String(format: "%.2f", hsbAdjustmentSettings.saturation))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $hsbAdjustmentSettings.saturation, in: 0...2, step: 0.01)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(StudioStrings.brightness(language))
                            Spacer()
                            Text(String(format: "%.2f", hsbAdjustmentSettings.brightness))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $hsbAdjustmentSettings.brightness, in: -1...1, step: 0.01)
                    }
                }
            }
            .navigationTitle(StudioStrings.hueSaturationBrightness(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.hueSaturationBrightnessPreviewChanged(nil))
                        showsHSBSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.hueSaturationBrightnessApplied(hsbAdjustmentSettings))
                        showsHSBSheet = false
                    }
                }
            }
        }
        .onChange(of: hsbAdjustmentSettings) { _, newValue in
            store.send(.hueSaturationBrightnessPreviewChanged(newValue))
        }
        .onDisappear {
            store.send(.hueSaturationBrightnessPreviewChanged(nil))
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    var brightnessContrastSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.brightnessContrast(language)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(StudioStrings.brightness(language))
                            Spacer()
                            Text(String(format: "%.2f", brightnessContrastSettings.brightness))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $brightnessContrastSettings.brightness, in: -1...1, step: 0.01)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(StudioStrings.contrast(language))
                            Spacer()
                            Text(String(format: "%.2f", brightnessContrastSettings.contrast))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $brightnessContrastSettings.contrast, in: 0...2, step: 0.01)
                    }
                }
            }
            .navigationTitle(StudioStrings.brightnessContrast(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.brightnessContrastPreviewChanged(nil))
                        showsBrightnessContrastSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.brightnessContrastApplied(brightnessContrastSettings))
                        showsBrightnessContrastSheet = false
                    }
                }
            }
        }
        .onChange(of: brightnessContrastSettings) { _, newValue in
            store.send(.brightnessContrastPreviewChanged(newValue))
        }
        .onDisappear {
            store.send(.brightnessContrastPreviewChanged(nil))
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }

    var levelsSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.levels(language)) {
                    adjustmentSlider(
                        title: StudioStrings.inputBlack(language),
                        valueText: String(format: "%.2f", levelsAdjustmentSettings.inputBlack),
                        value: $levelsAdjustmentSettings.inputBlack,
                        range: 0...0.95
                    )
                    adjustmentSlider(
                        title: StudioStrings.inputWhite(language),
                        valueText: String(format: "%.2f", levelsAdjustmentSettings.inputWhite),
                        value: $levelsAdjustmentSettings.inputWhite,
                        range: 0.05...1
                    )
                    adjustmentSlider(
                        title: StudioStrings.gamma(language),
                        valueText: String(format: "%.2f", levelsAdjustmentSettings.gamma),
                        value: $levelsAdjustmentSettings.gamma,
                        range: 0.2...3
                    )
                    adjustmentSlider(
                        title: StudioStrings.outputBlack(language),
                        valueText: String(format: "%.2f", levelsAdjustmentSettings.outputBlack),
                        value: $levelsAdjustmentSettings.outputBlack,
                        range: 0...0.95
                    )
                    adjustmentSlider(
                        title: StudioStrings.outputWhite(language),
                        valueText: String(format: "%.2f", levelsAdjustmentSettings.outputWhite),
                        value: $levelsAdjustmentSettings.outputWhite,
                        range: 0.05...1
                    )
                }
            }
            .navigationTitle(StudioStrings.levels(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.levelsPreviewChanged(nil))
                        showsLevelsSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.levelsApplied(normalizedLevelsSettings))
                        showsLevelsSheet = false
                    }
                }
            }
        }
        .onChange(of: levelsAdjustmentSettings) { _, _ in
            store.send(.levelsPreviewChanged(normalizedLevelsSettings))
        }
        .onDisappear {
            store.send(.levelsPreviewChanged(nil))
        }
        .presentationDetents([.height(480)])
        .presentationDragIndicator(.visible)
    }

    var toneCurveSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.toneCurve(language)) {
                    adjustmentSlider(
                        title: StudioStrings.shadows(language),
                        valueText: String(format: "%.2f", toneCurveSettings.shadows),
                        value: $toneCurveSettings.shadows,
                        range: -1...1
                    )
                    adjustmentSlider(
                        title: StudioStrings.midtones(language),
                        valueText: String(format: "%.2f", toneCurveSettings.midtones),
                        value: $toneCurveSettings.midtones,
                        range: -1...1
                    )
                    adjustmentSlider(
                        title: StudioStrings.highlights(language),
                        valueText: String(format: "%.2f", toneCurveSettings.highlights),
                        value: $toneCurveSettings.highlights,
                        range: -1...1
                    )
                }
            }
            .navigationTitle(StudioStrings.toneCurve(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.toneCurvePreviewChanged(nil))
                        showsToneCurveSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.toneCurveApplied(toneCurveSettings))
                        showsToneCurveSheet = false
                    }
                }
            }
        }
        .onChange(of: toneCurveSettings) { _, newValue in
            store.send(.toneCurvePreviewChanged(newValue))
        }
        .onDisappear {
            store.send(.toneCurvePreviewChanged(nil))
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    var colorBalanceSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.colorBalance(language)) {
                    adjustmentSlider(
                        title: StudioStrings.redCyan(language),
                        valueText: String(format: "%.2f", colorBalanceSettings.redCyan),
                        value: $colorBalanceSettings.redCyan,
                        range: -1...1
                    )
                    adjustmentSlider(
                        title: StudioStrings.greenMagenta(language),
                        valueText: String(format: "%.2f", colorBalanceSettings.greenMagenta),
                        value: $colorBalanceSettings.greenMagenta,
                        range: -1...1
                    )
                    adjustmentSlider(
                        title: StudioStrings.blueYellow(language),
                        valueText: String(format: "%.2f", colorBalanceSettings.blueYellow),
                        value: $colorBalanceSettings.blueYellow,
                        range: -1...1
                    )
                }
            }
            .navigationTitle(StudioStrings.colorBalance(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.colorBalancePreviewChanged(nil))
                        showsColorBalanceSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.colorBalanceApplied(colorBalanceSettings))
                        showsColorBalanceSheet = false
                    }
                }
            }
        }
        .onChange(of: colorBalanceSettings) { _, newValue in
            store.send(.colorBalancePreviewChanged(newValue))
        }
        .onDisappear {
            store.send(.colorBalancePreviewChanged(nil))
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    var thresholdSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.thresholdAdjustment(language)) {
                    adjustmentSlider(
                        title: StudioStrings.threshold(language),
                        valueText: String(format: "%.2f", thresholdSettings.threshold),
                        value: $thresholdSettings.threshold,
                        range: 0...1
                    )
                }
            }
            .navigationTitle(StudioStrings.thresholdAdjustment(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.thresholdPreviewChanged(nil))
                        showsThresholdSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.thresholdApplied(thresholdSettings))
                        showsThresholdSheet = false
                    }
                }
            }
        }
        .onChange(of: thresholdSettings) { _, newValue in
            store.send(.thresholdPreviewChanged(newValue))
        }
        .onDisappear {
            store.send(.thresholdPreviewChanged(nil))
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
    }

    var posterizeSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.posterize(language)) {
                    adjustmentSlider(
                        title: StudioStrings.levelCount(language),
                        valueText: "\(Int(posterizeSettings.levels.rounded()))",
                        value: $posterizeSettings.levels,
                        range: 2...32,
                        step: 1
                    )
                }
            }
            .navigationTitle(StudioStrings.posterize(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.posterizePreviewChanged(nil))
                        showsPosterizeSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.posterizeApplied(posterizeSettings))
                        showsPosterizeSheet = false
                    }
                }
            }
        }
        .onChange(of: posterizeSettings) { _, newValue in
            store.send(.posterizePreviewChanged(newValue))
        }
        .onDisappear {
            store.send(.posterizePreviewChanged(nil))
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
    }

    var gradientMapSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.gradientMap(language)) {
                    gradientPreviewBar

                    Text(language.localized("プレビューをタップすると点を追加、点をドラッグすると移動できます。"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(language.localized("プリセット読込"))
                            .font(.headline)

                        ForEach(GradientMapPreset.allCases) { preset in
                            Button(preset.localizedTitle(language)) {
                                gradientMapSettings = PrimoRootFeature.gradientMapSettings(for: preset)
                                selectedGradientStopID = gradientMapSettings.stops.dropFirst().first?.id
                            }
                        }
                    }

                    ForEach($gradientMapSettings.stops) { $stop in
                        gradientStopEditor(stop: $stop)
                    }

                    Button(language.localized("ポイントを追加")) {
                        addGradientStop()
                    }
                    .disabled(gradientMapSettings.stops.count >= 8)
                }
            }
            .navigationTitle(StudioStrings.gradientMap(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.gradientMapPreviewChanged(nil))
                        showsGradientMapSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.gradientMapApplied(normalizedGradientMapSettings))
                        showsGradientMapSheet = false
                    }
                }
            }
        }
        .onAppear {
            if selectedGradientStopID == nil {
                selectedGradientStopID = normalizedGradientMapSettings.stops.dropFirst().first?.id
            }
            store.send(.gradientMapPreviewChanged(normalizedGradientMapSettings))
        }
        .onChange(of: gradientMapSettings) { _, _ in
            store.send(.gradientMapPreviewChanged(normalizedGradientMapSettings))
        }
        .onDisappear {
            store.send(.gradientMapPreviewChanged(nil))
        }
        .presentationDetents([.height(620)])
        .presentationDragIndicator(.visible)
    }

    var nanoBananaSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.nanoBanana(language)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(StudioStrings.nanoBananaEdit(language))
                        Text(language.localized("Nano Banana にどう編集させたいか入力してください"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(language.localized("プロンプト"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextEditor(text: nanoBananaPromptBinding)
                            .frame(minHeight: 110)
                            .foregroundStyle(.black)
                            .tint(.black)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.black.opacity(0.14), lineWidth: 1)
                            )
                            .textInputAutocapitalization(.sentences)
                            .focused($nanoBananaFocusedField, equals: .prompt)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(NanoBananaPromptPreset.allCases) { preset in
                                Button(preset.title(language)) {
                                    store.send(.nanoBanana(.promptChanged(preset.prompt(language))))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.black.opacity(0.92))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.96))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(language.localized("入力")) {
                    Picker(language.localized("接続方式"), selection: nanoBananaAccessModeBinding) {
                        ForEach(NanoBananaAccessMode.allCases) { mode in
                            Text(mode.title(language)).tag(mode)
                        }
                    }

                    Picker(language.localized("入力レイヤー"), selection: nanoBananaInputLayerIndexBinding) {
                        ForEach(store.layerSidebar.layers) { layer in
                            Text(layer.name).tag(layer.index)
                        }
                    }

                    Picker(language.localized("編集範囲"), selection: nanoBananaEditScopeBinding) {
                        ForEach(NanoBananaEditScope.allCases) { scope in
                            Text(scope.title(language)).tag(scope)
                        }
                    }
                    .disabled(store.canvas.selection?.isEmpty != false)

                    if store.canvas.selection?.isEmpty != false {
                        Text(language.localized("インペイントを使うには選択範囲を作成してください"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if nanoBananaState.composer.editScope == .selectedArea {
                        Stepper(
                            "\(language.localized("マスク拡張")): \(nanoBananaState.composer.maskSettings.expansion)",
                            value: nanoBananaMaskExpansionBinding,
                            in: -24...48
                        )

                        Toggle(language.localized("マスクを反転"), isOn: nanoBananaMaskInversionBinding)
                    }

                    Picker(language.localized("モデル"), selection: nanoBananaModelBinding) {
                        ForEach(NanoBananaModel.allCases) { model in
                            Text(model.title(language)).tag(model)
                        }
                    }

                    if nanoBananaState.accessMode == .userAPIKey {
                        SecureField(language.localized("Gemini API キー"), text: nanoBananaAPIKeyBinding)
                            .focused($nanoBananaFocusedField, equals: .apiKey)
                        Text(language.localized("この端末内に保存されます"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        nanoBananaSubscriptionControls
                    }
                }

                Section(language.localized("出力")) {
                    Picker(language.localized("出力先"), selection: nanoBananaOutputModeBinding) {
                        ForEach(NanoBananaOutputMode.allCases) { mode in
                            Text(mode.title(language)).tag(mode)
                        }
                    }
                }

                if !nanoBananaState.jobs.isEmpty {
                    Section(language.localized("ジョブ")) {
                        ForEach(nanoBananaState.jobs.prefix(4)) { job in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(job.descriptor.model.title(language))
                                    Spacer()
                                    Text(job.status.rawValue.capitalized)
                                        .foregroundStyle(.secondary)
                                }
                                Text(job.descriptor.prompt.rawValue)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                if job.status == .failed || job.status == .canceled {
                                    Button(language.localized("再試行")) {
                                        store.send(.nanoBanana(.retryJobTapped(job.id)))
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }

                if !nanoBananaState.history.isEmpty {
                    Section(language.localized("履歴")) {
                        ForEach(nanoBananaState.history.prefix(4)) { item in
                            Button {
                                store.send(.nanoBanana(.historyItemSelected(item.descriptor)))
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.descriptor.prompt.rawValue)
                                        .lineLimit(2)
                                    Text(item.descriptor.model.title(language))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(StudioStrings.nanoBanana(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        nanoBananaFocusedField = nil
                        store.send(.nanoBanana(.sheetPresentationChanged(false)))
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(language.localized("生成")) {
                        requestNanoBananaGeneration(closeSheet: true)
                    }
                    .disabled(nanoBananaGenerateDisabled)
                }
            }
        }
        .presentationDetents([.height(560)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    func adjustmentSlider(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.01
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText)
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    @ViewBuilder
    func gradientStopEditor(stop: Binding<GradientMapStopSettings>) -> some View {
        let isEndpoint = isEndpointStop(id: stop.wrappedValue.id)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(gradientStopTitle(for: stop.wrappedValue.id))
                    .font(.headline)
                    .foregroundStyle(selectedGradientStopID == stop.wrappedValue.id ? StudioTheme.Palette.accentBright : .primary)

                Spacer()

                if !isEndpoint {
                    Button(role: .destructive) {
                        removeGradientStop(id: stop.wrappedValue.id)
                    } label: {
                        Text(language.localized("削除"))
                    }
                }
            }

            ColorPicker(
                language.localized("色"),
                selection: Binding(
                    get: { color(from: stop.wrappedValue) },
                    set: { newColor in
                        apply(color: newColor, to: stop)
                    }
                ),
                supportsOpacity: false
            )

            if !isEndpoint {
                adjustmentSlider(
                    title: language.localized("位置"),
                    valueText: String(format: "%.2f", stop.wrappedValue.position),
                    value: stop.position,
                    range: 0.05...0.95
                )
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedGradientStopID = stop.wrappedValue.id
        }
    }

    var gradientPreviewBar: some View {
        let normalizedSettings = normalizedGradientMapSettings
        let stops = normalizedSettings.stops
        return VStack(alignment: .leading, spacing: 10) {
            Text(language.localized("プレビュー"))
                .font(.headline)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    LinearGradient(
                        stops: stops.map {
                            .init(color: color(from: $0), location: $0.position)
                        },
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                addGradientStop(at: value.location.x, width: proxy.size.width)
                            }
                    )

                    ForEach(stops) { stop in
                        Circle()
                            .fill(color(from: stop))
                            .frame(
                                width: selectedGradientStopID == stop.id ? 18 : 14,
                                height: selectedGradientStopID == stop.id ? 18 : 14
                            )
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                            .position(
                                x: proxy.size.width * stop.position,
                                y: proxy.size.height / 2
                            )
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        selectedGradientStopID = stop.id
                                        updateGradientStopPosition(
                                            id: stop.id,
                                            x: value.location.x,
                                            width: proxy.size.width
                                        )
                                    }
                            )
                    }
                }
            }
            .frame(height: 44)
        }
    }

    var normalizedGradientMapSettings: GradientMapSettings {
        PrimoRootFeature.normalizeGradientMapSettings(gradientMapSettings)
    }

    func gradientStopTitle(for id: GradientMapStopSettings.ID) -> String {
        let normalizedStops = normalizedGradientMapSettings.stops
        guard let index = normalizedStops.firstIndex(where: { $0.id == id }) else {
            return language.localized("ポイント")
        }
        if index == 0 {
            return StudioStrings.shadows(language)
        }
        if index == normalizedStops.count - 1 {
            return StudioStrings.highlights(language)
        }
        return "\(language.localized("ポイント")) \(index)"
    }

    func isEndpointStop(id: GradientMapStopSettings.ID) -> Bool {
        let normalizedStops = normalizedGradientMapSettings.stops
        guard let index = normalizedStops.firstIndex(where: { $0.id == id }) else { return false }
        return index == 0 || index == normalizedStops.count - 1
    }

    func addGradientStop() {
        let normalized = normalizedGradientMapSettings.stops
        guard let previous = normalized.dropLast().last,
              let next = normalized.last else { return }
        let midpoint = (previous.position + next.position) / 2
        insertGradientStop(at: midpoint)
    }

    func addGradientStop(at x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let position = min(max(Double(x / width), 0.0), 1.0)
        insertGradientStop(at: position)
    }

    func removeGradientStop(id: GradientMapStopSettings.ID) {
        guard gradientMapSettings.stops.count > 2 else { return }
        gradientMapSettings.stops.removeAll { $0.id == id }
        if selectedGradientStopID == id {
            selectedGradientStopID = normalizedGradientMapSettings.stops.dropFirst().first?.id
        }
    }

    func insertGradientStop(at position: Double) {
        guard gradientMapSettings.stops.count < 8 else { return }
        let clampedPosition = min(max(position, 0.0), 1.0)
        let mixed = PrimoRootFeature.mappedGradientColor(
            for: clampedPosition,
            stops: PrimoRootFeature.gradientMapStops(for: normalizedGradientMapSettings)
        )
        let newStop = GradientMapStopSettings(
            position: clampedPosition,
            red: mixed.red,
            green: mixed.green,
            blue: mixed.blue
        )
        gradientMapSettings.stops.append(newStop)
        gradientMapSettings = normalizedGradientMapSettings
        selectedGradientStopID = newStop.id
    }

    func updateGradientStopPosition(id: GradientMapStopSettings.ID, x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        guard let index = gradientMapSettings.stops.firstIndex(where: { $0.id == id }) else { return }
        guard !isEndpointStop(id: id) else { return }
        gradientMapSettings.stops[index].position = min(max(Double(x / width), 0.0), 1.0)
        gradientMapSettings = normalizedGradientMapSettings
    }

    func color(from stop: GradientMapStopSettings) -> Color {
        Color(
            red: Double(stop.red) / 255.0,
            green: Double(stop.green) / 255.0,
            blue: Double(stop.blue) / 255.0
        )
    }

    func color(from stop: PrimoRootFeature.GradientMapStop) -> Color {
        Color(
            red: Double(stop.red) / 255.0,
            green: Double(stop.green) / 255.0,
            blue: Double(stop.blue) / 255.0
        )
    }

    func apply(color: Color, to stop: Binding<GradientMapStopSettings>) {
        let resolved = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: nil)
        stop.wrappedValue.red = UInt8(min(max((red * 255.0).rounded(), 0), 255))
        stop.wrappedValue.green = UInt8(min(max((green * 255.0).rounded(), 0), 255))
        stop.wrappedValue.blue = UInt8(min(max((blue * 255.0).rounded(), 0), 255))
    }

    func parsedCanvasDimension(from text: String) -> Int? {
        let digits = text.filter(\.isNumber)
        guard let value = Int(digits), (64...8192).contains(value) else { return nil }
        return value
    }

    func resolvedCanvasDimension(from text: String, fallback: Int) -> Int? {
        if let parsed = parsedCanvasDimension(from: text) {
            return parsed
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return nil }
        return (64...8192).contains(fallback) ? fallback : nil
    }

    func parsedSelectionPixelValue(from text: String) -> Int? {
        let digits = text.filter(\.isNumber)
        guard let value = Int(digits), (1...256).contains(value) else { return nil }
        return value
    }

    var currentColorRangeRequest: ColorRangeSelectionRequest {
        let resolved = UIColor(store.brushPalette.brush.activeOpaqueColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return ColorRangeSelectionRequest(
            source: colorRangeSource,
            red: UInt8(min(max((red * 255.0).rounded(), 0), 255)),
            green: UInt8(min(max((green * 255.0).rounded(), 0), 255)),
            blue: UInt8(min(max((blue * 255.0).rounded(), 0), 255)),
            tolerance: colorRangeTolerance,
            minimumAlpha: colorRangeMinimumAlpha,
            expansion: Int(colorRangeExpansion.rounded())
        )
    }

    var defaultNewCanvasWidth: Int {
        max(Int(CanvasFeature.defaultCanvasSize.width.rounded()), 1)
    }

    var defaultNewCanvasHeight: Int {
        max(Int(CanvasFeature.defaultCanvasSize.height.rounded()), 1)
    }

    var menuBar: some View {
        HStack(spacing: 8) {
            Button {
                store.send(.homeReturnRequested)
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.black.opacity(0.4))
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(StudioTheme.Palette.accentSoft.opacity(0.55), lineWidth: 1)
                        Image(systemName: "house.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(StudioTheme.Palette.accentBright)
                    }
                    .frame(width: 18, height: 18)

                    Text(language.localized("ホーム"))
                        .font(StudioTheme.Typography.label(9))
                }
                .foregroundStyle(StudioTheme.Palette.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(StudioTheme.Palette.cardFillStrong)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Text(StudioStrings.appName(language))
                    .font(StudioTheme.Typography.label(10))
                    .foregroundStyle(StudioTheme.Palette.textPrimary)
            }

            menuBarMenu(StudioStrings.fileMenu(language)) {
                Menu(StudioStrings.newCanvas(language)) {
                    ForEach(canvasSizePresets, id: \.label) { preset in
                        Button(preset.label) {
                            store.send(.newCanvasRequested(width: preset.width, height: preset.height))
                        }
                    }

                    Divider()

                    Button(StudioStrings.customSize(language)) {
                        newCanvasWidthText = "\(max(Int(store.canvas.canvasSize.width.rounded()), 1))"
                        newCanvasHeightText = "\(max(Int(store.canvas.canvasSize.height.rounded()), 1))"
                        showsNewCanvasSheet = true
                    }
                }
                Button(StudioStrings.open(language)) {
                    showsOpenDocumentImporter = true
                }
                Button(language.localized("写真を新規レイヤーに読み込む")) {
                    showsPhotoLayerImporter = true
                }
                Button(StudioStrings.save(language)) {
                    store.send(.saveDocumentRequested)
                }
                Button(language.localized("名前を付けて保存")) {
                    store.send(.saveDocumentCopyRequested)
                }
                Button(language.localized("保存履歴")) {
                    store.send(.saveHistoryRequested)
                }
                Button(StudioStrings.export(language)) {
                    store.send(.exportDocumentRequested)
                }
                Button(StudioStrings.exportTimelapse(language)) {
                    store.send(.exportTimelapseRequested)
                }
            }

            menuBarMenu(StudioStrings.editMenu(language)) {
                Menu(language.localized("選択範囲")) {
                    Button(language.localized("選択反転")) {
                        store.send(.brushPalette(.delegate(.invertSelection)))
                    }

                    Button(language.localized("選択範囲を拡張")) {
                        selectionExpansionText = "4"
                        showsExpandSelectionSheet = true
                    }

                    Button(language.localized("選択範囲を縮小")) {
                        selectionContractionText = "4"
                        showsContractSelectionSheet = true
                    }

                    Button(language.localized("境界をぼかす")) {
                        selectionFeatherRadiusText = "8"
                        showsFeatherSelectionSheet = true
                    }

                    Button(language.localized("色域選択")) {
                        colorRangeTolerance = store.brushPalette.selection.colorTolerance
                        colorRangeMinimumAlpha = 0.05
                        colorRangeExpansion = max(store.brushPalette.selection.expansion, 0)
                        colorRangeSource = .activeLayer
                        showsColorRangeSelectionSheet = true
                    }
                }

                Divider()

                Button(language.localized("キャンバスサイズを変更")) {
                    resizeCanvasExtentWidthText = "\(max(Int(store.canvas.canvasSize.width.rounded()), 1))"
                    resizeCanvasExtentHeightText = "\(max(Int(store.canvas.canvasSize.height.rounded()), 1))"
                    showsResizeCanvasExtentSheet = true
                }

                Button(language.localized("画像解像度を変更")) {
                    resizeCanvasWidthText = "\(max(Int(store.canvas.canvasSize.width.rounded()), 1))"
                    resizeCanvasHeightText = "\(max(Int(store.canvas.canvasSize.height.rounded()), 1))"
                    showsResizeCanvasSheet = true
                }

                Divider()

                Menu(StudioStrings.colorCorrection(language)) {
                    Button(StudioStrings.hueSaturationBrightness(language)) {
                        store.send(.brightnessContrastPreviewChanged(nil))
                        hsbAdjustmentSettings = HueSaturationBrightnessSettings()
                        showsHSBSheet = true
                    }

                    Button(StudioStrings.brightnessContrast(language)) {
                        store.send(.hueSaturationBrightnessPreviewChanged(nil))
                        brightnessContrastSettings = BrightnessContrastSettings()
                        showsBrightnessContrastSheet = true
                    }

                    Button(StudioStrings.levels(language)) {
                        levelsAdjustmentSettings = LevelsAdjustmentSettings()
                        store.send(.levelsPreviewChanged(normalizedLevelsSettings))
                        showsLevelsSheet = true
                    }

                    Button(StudioStrings.toneCurve(language)) {
                        toneCurveSettings = ToneCurveSettings()
                        showsToneCurveSheet = true
                    }

                    Button(StudioStrings.colorBalance(language)) {
                        colorBalanceSettings = ColorBalanceSettings()
                        showsColorBalanceSheet = true
                    }

                    Button(StudioStrings.thresholdAdjustment(language)) {
                        thresholdSettings = ThresholdSettings()
                        showsThresholdSheet = true
                    }

                    Button(StudioStrings.posterize(language)) {
                        posterizeSettings = PosterizeSettings()
                        showsPosterizeSheet = true
                    }

                    Button(language.localized("輝度を透明度に変換")) {
                        store.send(.luminanceToAlphaRequested)
                    }

                    Menu(StudioStrings.gradientMap(language)) {
                        Button(language.localized("カスタム…")) {
                            gradientMapSettings = PrimoRootFeature.gradientMapSettings(for: .graphite)
                            showsGradientMapSheet = true
                        }

                        Divider()

                        ForEach(GradientMapPreset.allCases) { preset in
                            Button(preset.localizedTitle(language)) {
                                store.send(.gradientMapSelected(preset))
                            }
                        }
                    }
                }
                .disabled(activeLayer == nil || store.canvas.renderSnapshot == nil)

                Button(StudioStrings.nanoBananaEdit(language)) {
                    prepareNanoBananaComposer()
                    store.send(.nanoBanana(.sheetPresentationChanged(true)))
                }
                .disabled(activeLayer == nil || store.canvas.renderSnapshot == nil || nanoBananaState.isGenerating)

                Divider()

                Button(StudioStrings.clearActiveLayer(language)) {
                    store.send(.clearActiveLayerButtonTapped)
                }

                Button(StudioStrings.refreshView(language)) {
                    store.send(.refreshPresentationRequested)
                }
            }

            menuBarMenu(StudioStrings.pageMenu(language)) {
                Button(StudioStrings.pagesAdd(language)) {}
                    .disabled(true)
                Button(StudioStrings.pagesDuplicate(language)) {}
                    .disabled(true)
                Button(StudioStrings.pagesDelete(language)) {}
                    .disabled(true)
            }

            menuBarMenu(StudioStrings.layerMenu(language)) {
                Button(StudioStrings.addLayer(language)) {
                    store.send(.layerSidebar(.addLayerButtonTapped))
                }

                Button(language.localized("写真を新規レイヤーに読み込む")) {
                    showsPhotoLayerImporter = true
                }

                Button(StudioStrings.addFolder(language)) {
                    store.send(.layerSidebar(.addFolderButtonTapped))
                }

                Button(activeLayerIsVisible ? StudioStrings.hideActiveLayer(language) : StudioStrings.showActiveLayer(language)) {
                    store.send(.activeLayerVisibilityToggled)
                }
                .disabled(activeLayer == nil)

                Divider()

                Button(StudioStrings.selectUpperLayer(language)) {
                    store.send(.selectPreviousLayer)
                }
                .disabled(!canSelectPreviousLayer)

                Button(StudioStrings.selectLowerLayer(language)) {
                    store.send(.selectNextLayer)
                }
                .disabled(!canSelectNextLayer)

                Divider()

                Button(language.localized("選択範囲からマスク作成")) {
                    store.send(.createLayerMaskFromSelectionRequested)
                }
                .disabled(activeLayer == nil || store.canvas.selection?.isEmpty != false)

                Button(language.localized("マスクを削除")) {
                    store.send(.clearLayerMaskRequested)
                }
                .disabled(activeLayerHasMask == false)

                Button(language.localized("マスクを適用")) {
                    store.send(.applyLayerMaskRequested)
                }
                .disabled(activeLayerHasMask == false)

                Divider()

                Button(StudioStrings.clearActiveLayer(language)) {
                    store.send(.clearActiveLayerButtonTapped)
                }
                .disabled(activeLayer == nil)
            }

            menuBarMenu(StudioStrings.settingsMenu(language)) {
                Menu(StudioStrings.languageMenu(language)) {
                    ForEach(AppLanguage.allCases) { option in
                        Button {
                            store.send(.languageChanged(option))
                        } label: {
                            if option == language {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                }

                Divider()

                Button(store.brushPanel.isCollapsed ? StudioStrings.showBrushPanel(language) : StudioStrings.hideBrushPanel(language)) {
                    store.send(.panelCollapseToggled(.brush))
                }

                Button(store.layerPanel.isCollapsed ? StudioStrings.showLayerPanel(language) : StudioStrings.hideLayerPanel(language)) {
                    store.send(.panelCollapseToggled(.layers))
                }
            }

            Spacer(minLength: 8)

        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(StudioTheme.Gradients.topBar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
    }

    var undoRedoBar: some View {
        HStack(spacing: 6) {
            Button {
                store.send(.undoRequested)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .minimumHitTarget(30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.cardFillStrong)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
            }

            Button {
                store.send(.redoRequested)
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .minimumHitTarget(30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.cardFillStrong)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
            }

            Button {
                showsPhotoLayerImporter = true
            } label: {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .minimumHitTarget(30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.cardFillStrong)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
            }

            Button {
                store.send(.clearActiveLayerButtonTapped)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .minimumHitTarget(44)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(StudioTheme.Palette.cardFillStrong)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
            }
            .disabled(activeLayer == nil)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(StudioTheme.Gradients.chrome)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
        }
    }

    func menuBarMenu<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            Text(title)
                .font(StudioTheme.Typography.label(9))
                .foregroundStyle(StudioTheme.Palette.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .minimumHitTarget(28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(StudioTheme.Palette.toolbarFill)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                }
        }
    }

    var activeLayer: LayerRowModel? {
        store.layerSidebar.layers.first { $0.index == store.layerSidebar.activeLayerIndex }
    }

    var activeLayerIsVisible: Bool {
        activeLayer?.visible ?? false
    }

    var activeLayerHasMask: Bool {
        activeLayer?.hasMask ?? false
    }

    var activeLayerPosition: Int? {
        store.layerSidebar.layers.firstIndex { $0.index == store.layerSidebar.activeLayerIndex }
    }

    var normalizedLevelsSettings: LevelsAdjustmentSettings {
        var settings = levelsAdjustmentSettings
        settings.inputBlack = min(settings.inputBlack, settings.inputWhite - 0.001)
        settings.inputWhite = max(settings.inputWhite, settings.inputBlack + 0.001)
        settings.outputBlack = min(settings.outputBlack, settings.outputWhite)
        settings.outputWhite = max(settings.outputWhite, settings.outputBlack)
        settings.gamma = max(settings.gamma, 0.01)
        return settings
    }

    var canSelectPreviousLayer: Bool {
        guard let activeLayerPosition else { return false }
        return activeLayerPosition > 0
    }

    var canSelectNextLayer: Bool {
        guard let activeLayerPosition else { return false }
        return activeLayerPosition < store.layerSidebar.layers.count - 1
    }
}
