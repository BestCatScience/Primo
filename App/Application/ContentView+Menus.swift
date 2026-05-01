import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import SwiftUI
import UIKit
import PrimoAIImageDomain

private enum NewCanvasPresetMeasurement: Equatable {
    case pixels(Int, Int)
    case millimeters(Int, Int, dpi: Int)

    var canvasSize: (width: Int, height: Int) {
        switch self {
        case let .pixels(width, height):
            return (width, height)
        case let .millimeters(width, height, dpi):
            return (
                Int((Double(width) / 25.4 * Double(dpi)).rounded()),
                Int((Double(height) / 25.4 * Double(dpi)).rounded())
            )
        }
    }

    var detailText: String {
        switch self {
        case let .pixels(width, height):
            return "\(width.formatted()) × \(height.formatted()) px\n350dpi"
        case let .millimeters(width, height, dpi):
            return "\(width) × \(height) mm\n\(dpi)dpi"
        }
    }
}

private struct NewCanvasPreset: Identifiable, Equatable {
    let id: String
    let title: String
    let measurement: NewCanvasPresetMeasurement
    let defaultIsLandscape: Bool

    var portraitSize: (width: Int, height: Int) {
        let size = measurement.canvasSize
        return size.width <= size.height ? size : (size.height, size.width)
    }

    var landscapeSize: (width: Int, height: Int) {
        let size = measurement.canvasSize
        return size.width >= size.height ? size : (size.height, size.width)
    }
}

extension ContentView {
    var resolvedAIImageInputLayerIndex: Int {
        if store.document.editing.layerSidebar.layers.contains(where: { $0.index == aiImageState.composer.inputLayerIndex }) {
            return aiImageState.composer.inputLayerIndex
        }
        return store.document.editing.layerSidebar.activeLayerIndex
    }

    var resolvedAIImageInputLayerName: String {
        store.document.editing.layerSidebar.layers.first(where: { $0.index == resolvedAIImageInputLayerIndex })?.name ?? "-"
    }

    var aiImagePromptBinding: Binding<String> {
        Binding(
            get: { aiImageState.composer.prompt },
            set: { store.send(.aiImage(.promptChanged($0))) }
        )
    }

    var aiImageInputLayerIndexBinding: Binding<Int> {
        Binding(
            get: { aiImageState.composer.inputLayerIndex },
            set: { store.send(.aiImage(.inputLayerIndexChanged($0))) }
        )
    }

    var aiImageEditScopeBinding: Binding<AIImageEditScope> {
        Binding(
            get: { aiImageState.composer.editScope },
            set: { store.send(.aiImage(.editScopeChanged($0))) }
        )
    }

    var aiImageOutputModeBinding: Binding<AIImageOutputMode> {
        Binding(
            get: { aiImageState.composer.outputMode },
            set: { store.send(.aiImage(.outputModeChanged($0))) }
        )
    }

    var aiImageMaskExpansionBinding: Binding<Int> {
        Binding(
            get: { aiImageState.composer.maskSettings.expansion },
            set: { store.send(.aiImage(.maskExpansionChanged($0))) }
        )
    }

    var aiImageMaskInversionBinding: Binding<Bool> {
        Binding(
            get: { aiImageState.composer.maskSettings.isInverted },
            set: { store.send(.aiImage(.maskInversionChanged($0))) }
        )
    }

    var aiImageModelBinding: Binding<AIImageModel> {
        Binding(
            get: { aiImageState.composer.model },
            set: { store.send(.aiImage(.modelChanged($0))) }
        )
    }

    func prepareAIImageComposer() {
        store.send(
            .aiImage(
                .prepareComposer(
                    activeLayerIndex: store.document.editing.layerSidebar.activeLayerIndex,
                    hasSelection: store.document.editing.canvas.selection?.isEmpty == false
                )
            )
        )
    }

    var aiImageGenerateDisabled: Bool {
        aiImageState.generateDisabled || store.document.editing.layerSidebar.layers.isEmpty
    }

    var aiImagePrimaryActionDisabled: Bool {
        if aiImageState.requiresSubscriptionForCurrentAccessMode {
            return aiImageState.commerce.isLoading
        }
        return aiImageGenerateDisabled
    }

    func aiImagePrimaryActionTitle(fallback: String) -> String {
        if aiImageState.requiresSubscriptionForCurrentAccessMode {
            return language.localized("サブスクリプションが必要です")
        }
        return fallback
    }

    var aiImageGeminiPlanHint: String {
        switch language {
        case .english:
            return "AI image editing is available with the Primo subscription."
        case .japanese:
            return "AI画像編集は Primo のサブスクリプションで利用できます"
        }
    }

    var aiImageGeminiPlanSoftHint: String {
        switch language {
        case .english:
            return "AI image editing is available with the Primo subscription."
        case .japanese:
            return "AI画像編集は Primo のサブスクリプションで利用できます"
        }
    }

    func requestAIImageGeneration(closeSheet: Bool) {
        aiImageFocusedField = nil
        store.send(.aiImage(.inputLayerIndexChanged(resolvedAIImageInputLayerIndex)))
        store.send(.aiImage(.generateButtonTapped(closeSheet: closeSheet)))
    }

    func handleAIImagePrimaryAction(closeSheet: Bool) {
        guard !aiImageState.requiresSubscriptionForCurrentAccessMode else {
            aiImageFocusedField = nil
            store.send(.aiImage(.paywallPresentationChanged(true)))
            return
        }
        requestAIImageGeneration(closeSheet: closeSheet)
    }

    @ViewBuilder
    var aiImageSubscriptionControls: some View {
        LabeledContent(language.localized("状態")) {
            Text(
                aiImageState.commerce.isSubscriptionActive
                ? language.localized("有効")
                : language.localized("未購入")
            )
            .foregroundStyle(aiImageState.commerce.isSubscriptionActive ? .green : .secondary)
        }

        if let product = aiImageState.commerce.primaryProduct {
            LabeledContent(language.localized("プラン")) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayName)
                    Text(product.displayPrice)
                        .foregroundStyle(.secondary)
                }
            }
        } else if aiImageState.commerce.isLoading {
            Text(language.localized("サブスクリプション情報を読み込み中…"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        Button(language.localized("サブスクリプションを購入")) {
            store.send(.aiImage(.purchasePrimaryProductTapped))
        }
        .disabled(aiImageState.commerce.isLoading || aiImageState.commerce.isSubscriptionActive)

        Button(language.localized("購入を復元")) {
            store.send(.aiImage(.restorePurchasesTapped))
        }
        .disabled(aiImageState.commerce.isLoading)

        if let manageURL = aiImageState.commerce.manageSubscriptionsURL {
            Link(language.localized("サブスクリプションを管理"), destination: manageURL)
        }

        if let purchaseErrorMessage = aiImageState.commerce.purchaseErrorMessage, !purchaseErrorMessage.isEmpty {
            Text(purchaseErrorMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(language.localized("メッセージを閉じる")) {
                store.send(.aiImage(.purchaseErrorDismissed))
            }
            .buttonStyle(.borderless)
        }

        Text(
            aiImageState.appManagedProxyEndpointConfigured
            ? language.localized("Primo のサブスクリプションでAI画像編集を利用できます")
            : language.localized("このビルドではアプリ管理のAI画像編集は無効です")
        )
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    var aiImageSettingsSheet: some View {
        NavigationStack {
            Form {
                Section(language.localized("AI画像設定")) {
                    Picker(language.localized("モデル"), selection: aiImageModelBinding) {
                        ForEach(AIImageModel.allCases) { model in
                            Text(model.title(language)).tag(model)
                        }
                    }

                    aiImageSubscriptionControls
                }
            }
            .navigationTitle(language.localized("AI画像設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.localized("完了")) {
                        aiImageFocusedField = nil
                        showsAIImageSettingsSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    var aiImagePaywallSheet: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(language.localized("AI画像を有効化"))
                            .font(.title3.weight(.semibold))
                        Text(language.localized("Primo のサブスクリプションでAI画像編集を利用できます"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section(language.localized("含まれる内容")) {
                    Label(language.localized("アプリ管理のAI画像編集を利用可能"), systemImage: "sparkles")
                    Label(language.localized("購入状態を自動で同期"), systemImage: "arrow.triangle.2.circlepath")
                    Label(language.localized("新しい端末でも購入を復元可能"), systemImage: "icloud")
                }

                Section(language.localized("プラン")) {
                    if let product = aiImageState.commerce.primaryProduct {
                        LabeledContent(product.displayName) {
                            Text(product.displayPrice)
                        }
                    } else {
                        Text(
                            aiImageState.commerce.isLoading
                            ? language.localized("サブスクリプション情報を読み込み中…")
                            : language.localized("サブスクリプション商品は利用できません")
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                Section(language.localized("アプリ課金プラン")) {
                    aiImageSubscriptionControls
                }
            }
            .navigationTitle(language.localized("サブスクリプションが必要です"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        store.send(.aiImage(.paywallPresentationChanged(false)))
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
                "現在のサイズ (\(max(Int(store.document.editing.canvas.canvasSize.width.rounded()), 1)) × \(max(Int(store.document.editing.canvas.canvasSize.height.rounded()), 1)))",
                max(Int(store.document.editing.canvas.canvasSize.width.rounded()), 1),
                max(Int(store.document.editing.canvas.canvasSize.height.rounded()), 1)
            ),
            ("768 × 1024", 768, 1024),
            ("1024 × 1024", 1024, 1024),
            ("1152 × 1536", 1152, 1536),
            ("1536 × 2048", 1536, 2048),
            ("2048 × 2048", 2048, 2048)
        ]
    }

    var newCanvasSheet: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width, 720)

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 18) {
                    Text(StudioStrings.newCanvasTitle(language))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.26, green: 0.26, blue: 0.26))

                    Spacer(minLength: 0)

                    HStack(spacing: 10) {
                        newCanvasToolbarButton(systemName: "photo.badge.plus", accessibilityLabel: StudioStrings.createFromImage(language)) {
                            beginCreateCanvasFromImageFlow()
                        }

                        newCanvasToolbarButton(systemName: "doc.badge.plus", accessibilityLabel: StudioStrings.openFileCTA(language)) {
                            beginOpenDocumentFromNewCanvasFlow()
                        }

                        newCanvasToolbarButton(systemName: "plus", accessibilityLabel: StudioStrings.customSize(language)) {
                            if newCanvasWidthText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                newCanvasWidthText = "\(defaultNewCanvasWidth)"
                            }
                            if newCanvasHeightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                newCanvasHeightText = "\(defaultNewCanvasHeight)"
                            }
                            showsNewCanvasCustomSizeSheet = true
                        }
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 44)
                .padding(.bottom, 22)

                ScrollView {
                    LazyVGrid(
                        columns: newCanvasGridColumns(for: contentWidth),
                        alignment: .center,
                        spacing: 20
                    ) {
                        ForEach(newCanvasPresets) { preset in
                            newCanvasPresetCard(preset)
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 8)
                    .padding(.bottom, 34)
                }
            }
            .frame(width: contentWidth, height: proxy.size.height, alignment: .top)
        }
        .frame(minWidth: 720, idealWidth: 760, maxWidth: 980, minHeight: 570, idealHeight: 620)
        .background(Color.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showsNewCanvasCustomSizeSheet) {
            newCanvasCustomSizeSheet
        }
    }

    private var newCanvasCustomSizeSheet: some View {
        NavigationStack {
            Form {
                Section(language.localized("サイズ")) {
                    TextField(StudioStrings.width(language), text: $newCanvasWidthText)
                        .keyboardType(.numberPad)

                    TextField(StudioStrings.height(language), text: $newCanvasHeightText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(StudioStrings.customSize(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        showsNewCanvasCustomSizeSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.create(language)) {
                        guard
                            let width = resolvedCanvasDimension(from: newCanvasWidthText, fallback: defaultNewCanvasWidth),
                            let height = resolvedCanvasDimension(from: newCanvasHeightText, fallback: defaultNewCanvasHeight)
                        else { return }
                        createNewCanvas(width: width, height: height)
                        showsNewCanvasCustomSizeSheet = false
                    }
                    .disabled(
                        resolvedCanvasDimension(from: newCanvasWidthText, fallback: defaultNewCanvasWidth) == nil ||
                        resolvedCanvasDimension(from: newCanvasHeightText, fallback: defaultNewCanvasHeight) == nil
                    )
                }
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    private var newCanvasPresets: [NewCanvasPreset] {
        [
            NewCanvasPreset(id: "screen", title: StudioStrings.screenSize(language), measurement: .pixels(2388, 1668), defaultIsLandscape: true),
            NewCanvasPreset(id: "square", title: StudioStrings.square(language), measurement: .pixels(2000, 2000), defaultIsLandscape: false),
            NewCanvasPreset(id: "a3", title: "A3", measurement: .millimeters(297, 420, dpi: 350), defaultIsLandscape: false),
            NewCanvasPreset(id: "a4", title: "A4", measurement: .millimeters(210, 297, dpi: 350), defaultIsLandscape: false),
            NewCanvasPreset(id: "a5", title: "A5", measurement: .millimeters(148, 210, dpi: 350), defaultIsLandscape: false),
            NewCanvasPreset(id: "b3", title: "B3", measurement: .millimeters(364, 515, dpi: 350), defaultIsLandscape: false),
            NewCanvasPreset(id: "b4", title: "B4", measurement: .millimeters(257, 364, dpi: 350), defaultIsLandscape: false),
            NewCanvasPreset(id: "b5", title: "B5", measurement: .millimeters(182, 257, dpi: 350), defaultIsLandscape: false),
            NewCanvasPreset(id: "720p", title: "720p", measurement: .pixels(1280, 720), defaultIsLandscape: true),
            NewCanvasPreset(id: "1080p", title: "1080p", measurement: .pixels(1920, 1080), defaultIsLandscape: true),
            NewCanvasPreset(id: "2160p", title: "2160p", measurement: .pixels(3840, 2160), defaultIsLandscape: true)
        ]
    }

    private func newCanvasToolbarButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color(red: 0.25, green: 0.25, blue: 0.25))
                .frame(width: 58, height: 46)
                .background(Color(red: 0.965, green: 0.965, blue: 0.965), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func newCanvasGridColumns(for width: CGFloat) -> [GridItem] {
        let columnCount: Int
        if width >= 700 {
            columnCount = 5
        } else if width >= 560 {
            columnCount = 4
        } else if width >= 420 {
            columnCount = 3
        } else {
            columnCount = 2
        }

        return Array(
            repeating: GridItem(.flexible(minimum: 98, maximum: 138), spacing: 24, alignment: .top),
            count: columnCount
        )
    }

    private func newCanvasPresetCard(_ preset: NewCanvasPreset) -> some View {
        let isLandscape = newCanvasPresetLandscapeSelections[preset.id] ?? preset.defaultIsLandscape
        let selectedSize = isLandscape ? preset.landscapeSize : preset.portraitSize

        return VStack(spacing: 8) {
            Button {
                createNewCanvas(width: selectedSize.width, height: selectedSize.height)
            } label: {
                newCanvasPaperPreview(width: selectedSize.width, height: selectedSize.height)
                    .frame(height: 86)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                newCanvasOrientationToggle(
                    systemName: "rectangle.portrait",
                    isSelected: !isLandscape,
                    accessibilityLabel: StudioStrings.portrait(language)
                ) {
                    newCanvasPresetLandscapeSelections[preset.id] = false
                }

                newCanvasOrientationToggle(
                    systemName: "rectangle",
                    isSelected: isLandscape,
                    accessibilityLabel: StudioStrings.landscape(language)
                ) {
                    newCanvasPresetLandscapeSelections[preset.id] = true
                }

                Button {} label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.56, green: 0.56, blue: 0.56))
                        .frame(width: 22, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(true)
                .accessibilityHidden(true)
            }

            Button {
                createNewCanvas(width: selectedSize.width, height: selectedSize.height)
            } label: {
                VStack(spacing: 4) {
                    Text(preset.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.31, green: 0.31, blue: 0.31))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(preset.measurement.detailText)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                        .foregroundStyle(Color(red: 0.68, green: 0.68, blue: 0.68))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private func newCanvasPaperPreview(width: Int, height: Int) -> some View {
        GeometryReader { proxy in
            let maxWidth = proxy.size.width
            let maxHeight = proxy.size.height
            let scale = min(maxWidth / CGFloat(width), maxHeight / CGFloat(height), 1)
            let previewWidth = max(24, CGFloat(width) * scale)
            let previewHeight = max(24, CGFloat(height) * scale)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 0.82, green: 0.82, blue: 0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color(red: 0.72, green: 0.72, blue: 0.72), lineWidth: 1.5)
                )
                .frame(width: previewWidth, height: previewHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func newCanvasOrientationToggle(
        systemName: String,
        isSelected: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black : Color(red: 0.65, green: 0.65, blue: 0.65))
                .frame(width: 32, height: 28)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.white : Color(red: 0.975, green: 0.975, blue: 0.975))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Color(red: 0.90, green: 0.90, blue: 0.90) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func createNewCanvas(width: Int, height: Int) {
        store.send(.document(.lifecycle(.newCanvasRequested(width: width, height: height))))
        showsNewCanvasSheet = false
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
                            let width = resolvedCanvasDimension(from: resizeCanvasWidthText, fallback: max(Int(store.document.editing.canvas.canvasSize.width.rounded()), 1)),
                            let height = resolvedCanvasDimension(from: resizeCanvasHeightText, fallback: max(Int(store.document.editing.canvas.canvasSize.height.rounded()), 1))
                        else { return }
                        store.send(.document(.lifecycle(.resizeCanvasRequested(width: width, height: height))))
                        showsResizeCanvasSheet = false
                    }
                    .disabled(
                        resolvedCanvasDimension(from: resizeCanvasWidthText, fallback: max(Int(store.document.editing.canvas.canvasSize.width.rounded()), 1)) == nil ||
                        resolvedCanvasDimension(from: resizeCanvasHeightText, fallback: max(Int(store.document.editing.canvas.canvasSize.height.rounded()), 1)) == nil
                    )
                }
            }
        }
        .onAppear {
            resizeCanvasWidthText = "\(max(Int(store.document.editing.canvas.canvasSize.width.rounded()), 1))"
            resizeCanvasHeightText = "\(max(Int(store.document.editing.canvas.canvasSize.height.rounded()), 1))"
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
                            let width = resolvedCanvasDimension(from: resizeCanvasExtentWidthText, fallback: max(Int(store.document.editing.canvas.canvasSize.width.rounded()), 1)),
                            let height = resolvedCanvasDimension(from: resizeCanvasExtentHeightText, fallback: max(Int(store.document.editing.canvas.canvasSize.height.rounded()), 1))
                        else { return }
                        store.send(.document(.lifecycle(.resizeCanvasExtentRequested(width: width, height: height))))
                        showsResizeCanvasExtentSheet = false
                    }
                    .disabled(
                        resolvedCanvasDimension(from: resizeCanvasExtentWidthText, fallback: max(Int(store.document.editing.canvas.canvasSize.width.rounded()), 1)) == nil ||
                        resolvedCanvasDimension(from: resizeCanvasExtentHeightText, fallback: max(Int(store.document.editing.canvas.canvasSize.height.rounded()), 1)) == nil
                    )
                }
            }
        }
        .onAppear {
            resizeCanvasExtentWidthText = "\(max(Int(store.document.editing.canvas.canvasSize.width.rounded()), 1))"
            resizeCanvasExtentHeightText = "\(max(Int(store.document.editing.canvas.canvasSize.height.rounded()), 1))"
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
            store.send(.document(.brushPalette(.delegate(.expandSelection(amount)))))
            showsExpandSelectionSheet = false
        }
    }

    var contractSelectionSheet: some View {
        selectionPixelAmountSheet(
            title: language.localized("選択範囲を縮小"),
            text: $selectionContractionText,
            confirmTitle: language.localized("縮小")
        ) { amount in
            store.send(.document(.brushPalette(.delegate(.contractSelection(amount)))))
            showsContractSelectionSheet = false
        }
    }

    var featherSelectionSheet: some View {
        selectionPixelAmountSheet(
            title: language.localized("境界をぼかす"),
            text: $selectionFeatherRadiusText,
            confirmTitle: language.localized("適用")
        ) { amount in
            store.send(.document(.canvasEditing(.editing(.featherSelectionRequested(amount)))))
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
                    if store.document.editing.canvas.transformMode == .standard {
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

                if store.document.editing.canvas.transformMode == .standard {
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
        transformOffsetXText = String(Int(store.document.editing.canvas.transformPreviewOffset.width.rounded()))
        transformOffsetYText = String(Int(store.document.editing.canvas.transformPreviewOffset.height.rounded()))
        transformScaleXText = String(Int((store.document.editing.canvas.transformPreviewScaleX * 100).rounded()))
        transformScaleYText = String(Int((store.document.editing.canvas.transformPreviewScaleY * 100).rounded()))
        transformRotationText = String(Int(store.document.editing.canvas.transformPreviewRotationDegrees.rounded()))
        transformLocksAspectRatio = store.document.editing.canvas.transformLocksAspectRatio
        let visualPivot = currentTransformVisualPivot()
        transformPivotXText = String(Int(visualPivot.x.rounded()))
        transformPivotYText = String(Int(visualPivot.y.rounded()))
    }

    func currentTransformBounds() -> CGRect? {
        if let selection = store.document.editing.canvas.selection, !selection.isEmpty {
            return selection.bounds
        }
        guard
            let snapshot = store.document.editing.canvas.renderSnapshot,
            let layer = snapshot.layers.first(where: { $0.index == store.document.editing.canvas.activeLayerIndex })
        else {
            return nil
        }
        return DocumentFeature.transformationBounds(
            selection: nil,
            pixelData: layer.pixelData,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            gpuOperations: documentRenderingWorkflow
        )
    }

    func currentTransformVisualPivot() -> CGPoint {
        let translation = store.document.editing.canvas.transformPreviewOffset
        if let pivot = store.document.editing.canvas.transformPivot {
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
        let resolvedScaleYPercent = (store.document.editing.canvas.transformMode == .standard && transformLocksAspectRatio) ? scaleXPercent : scaleYPercent
        store.send(.document(.canvas(.transformOffsetSet(offset))))
        store.send(.document(.canvas(.transformAspectRatioLockChanged(transformLocksAspectRatio))))
        if store.document.editing.canvas.transformMode == .standard {
            store.send(.document(.canvas(.transformScaleSet(
                x: CGFloat(scaleXPercent / 100.0),
                y: CGFloat(resolvedScaleYPercent / 100.0)
            ))))
            store.send(.document(.canvas(.transformRotationSet(rotation))))
            store.send(.document(.canvas(.transformPivotSet(CGPoint(
                x: pivotX - offsetX,
                y: pivotY - offsetY
            )))))
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
                            .fill(store.document.editing.brushPalette.brush.activeOpaqueColor)
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
                        store.send(.document(.canvasEditing(.editing(.colorRangeSelectionRequested(currentColorRangeRequest)))))
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
                        store.send(.document(.adjustment(.editing(.hueSaturationBrightnessPreviewChanged(nil)))))
                        showsHSBSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.document(.adjustment(.editing(.hueSaturationBrightnessApplied(hsbAdjustmentSettings)))))
                        showsHSBSheet = false
                    }
                }
            }
        }
        .onChange(of: hsbAdjustmentSettings) { _, newValue in
            store.send(.document(.adjustment(.editing(.hueSaturationBrightnessPreviewChanged(newValue)))))
        }
        .onDisappear {
            store.send(.document(.adjustment(.editing(.hueSaturationBrightnessPreviewChanged(nil)))))
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
                        store.send(.document(.adjustment(.editing(.brightnessContrastPreviewChanged(nil)))))
                        showsBrightnessContrastSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.document(.adjustment(.editing(.brightnessContrastApplied(brightnessContrastSettings)))))
                        showsBrightnessContrastSheet = false
                    }
                }
            }
        }
        .onChange(of: brightnessContrastSettings) { _, newValue in
            store.send(.document(.adjustment(.editing(.brightnessContrastPreviewChanged(newValue)))))
        }
        .onDisappear {
            store.send(.document(.adjustment(.editing(.brightnessContrastPreviewChanged(nil)))))
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
                        store.send(.document(.adjustment(.editing(.levelsPreviewChanged(nil)))))
                        showsLevelsSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.document(.adjustment(.editing(.levelsApplied(normalizedLevelsSettings)))))
                        showsLevelsSheet = false
                    }
                }
            }
        }
        .onChange(of: levelsAdjustmentSettings) { _, _ in
            store.send(.document(.adjustment(.editing(.levelsPreviewChanged(normalizedLevelsSettings)))))
        }
        .onDisappear {
            store.send(.document(.adjustment(.editing(.levelsPreviewChanged(nil)))))
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
                        store.send(.document(.adjustment(.editing(.toneCurvePreviewChanged(nil)))))
                        showsToneCurveSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.document(.adjustment(.editing(.toneCurveApplied(toneCurveSettings)))))
                        showsToneCurveSheet = false
                    }
                }
            }
        }
        .onChange(of: toneCurveSettings) { _, newValue in
            store.send(.document(.adjustment(.editing(.toneCurvePreviewChanged(newValue)))))
        }
        .onDisappear {
            store.send(.document(.adjustment(.editing(.toneCurvePreviewChanged(nil)))))
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
                        store.send(.document(.adjustment(.editing(.colorBalancePreviewChanged(nil)))))
                        showsColorBalanceSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.document(.adjustment(.editing(.colorBalanceApplied(colorBalanceSettings)))))
                        showsColorBalanceSheet = false
                    }
                }
            }
        }
        .onChange(of: colorBalanceSettings) { _, newValue in
            store.send(.document(.adjustment(.editing(.colorBalancePreviewChanged(newValue)))))
        }
        .onDisappear {
            store.send(.document(.adjustment(.editing(.colorBalancePreviewChanged(nil)))))
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
                        store.send(.document(.adjustment(.editing(.thresholdPreviewChanged(nil)))))
                        showsThresholdSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.document(.adjustment(.editing(.thresholdApplied(thresholdSettings)))))
                        showsThresholdSheet = false
                    }
                }
            }
        }
        .onChange(of: thresholdSettings) { _, newValue in
            store.send(.document(.adjustment(.editing(.thresholdPreviewChanged(newValue)))))
        }
        .onDisappear {
            store.send(.document(.adjustment(.editing(.thresholdPreviewChanged(nil)))))
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
                        store.send(.document(.adjustment(.editing(.posterizePreviewChanged(nil)))))
                        showsPosterizeSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.document(.adjustment(.editing(.posterizeApplied(posterizeSettings)))))
                        showsPosterizeSheet = false
                    }
                }
            }
        }
        .onChange(of: posterizeSettings) { _, newValue in
            store.send(.document(.adjustment(.editing(.posterizePreviewChanged(newValue)))))
        }
        .onDisappear {
            store.send(.document(.adjustment(.editing(.posterizePreviewChanged(nil)))))
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
                                gradientMapSettings = DocumentFeature.gradientMapSettings(for: preset)
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
                        store.send(.document(.adjustment(.editing(.gradientMapPreviewChanged(nil)))))
                        showsGradientMapSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.apply(language)) {
                        store.send(.document(.adjustment(.editing(.gradientMapApplied(normalizedGradientMapSettings)))))
                        showsGradientMapSheet = false
                    }
                }
            }
        }
        .onAppear {
            if selectedGradientStopID == nil {
                selectedGradientStopID = normalizedGradientMapSettings.stops.dropFirst().first?.id
            }
            store.send(.document(.adjustment(.editing(.gradientMapPreviewChanged(normalizedGradientMapSettings)))))
        }
        .onChange(of: gradientMapSettings) { _, _ in
            store.send(.document(.adjustment(.editing(.gradientMapPreviewChanged(normalizedGradientMapSettings)))))
        }
        .onDisappear {
            store.send(.document(.adjustment(.editing(.gradientMapPreviewChanged(nil)))))
        }
        .presentationDetents([.height(620)])
        .presentationDragIndicator(.visible)
    }

    var aiImageSheet: some View {
        NavigationStack {
            Form {
                Section(StudioStrings.aiImage(language)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(StudioStrings.aiImageEdit(language))
                        Text(language.localized("AI画像にどう編集させたいか入力してください"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(language.localized("プロンプト"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextEditor(text: aiImagePromptBinding)
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
                            .focused($aiImageFocusedField, equals: .prompt)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(AIImagePromptPreset.allCases) { preset in
                                Button(preset.title(language)) {
                                    store.send(.aiImage(.promptChanged(preset.prompt(language))))
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
                    Picker(language.localized("入力レイヤー"), selection: aiImageInputLayerIndexBinding) {
                        ForEach(store.document.editing.layerSidebar.layers) { layer in
                            Text(layer.name).tag(layer.index)
                        }
                    }

                    Picker(language.localized("編集範囲"), selection: aiImageEditScopeBinding) {
                        ForEach(AIImageEditScope.allCases) { scope in
                            Text(scope.title(language)).tag(scope)
                        }
                    }
                    .disabled(store.document.editing.canvas.selection?.isEmpty != false)

                    if store.document.editing.canvas.selection?.isEmpty != false {
                        Text(language.localized("インペイントを使うには選択範囲を作成してください"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if aiImageState.composer.editScope == .selectedArea {
                        Stepper(
                            "\(language.localized("マスク拡張")): \(aiImageState.composer.maskSettings.expansion)",
                            value: aiImageMaskExpansionBinding,
                            in: -24...48
                        )

                        Toggle(language.localized("マスクを反転"), isOn: aiImageMaskInversionBinding)
                    }

                    Picker(language.localized("モデル"), selection: aiImageModelBinding) {
                        ForEach(AIImageModel.allCases) { model in
                            Text(model.title(language)).tag(model)
                        }
                    }

                    aiImageSubscriptionControls
                }

                Section(language.localized("出力")) {
                    Picker(language.localized("出力先"), selection: aiImageOutputModeBinding) {
                        ForEach(AIImageOutputMode.allCases) { mode in
                            Text(mode.title(language)).tag(mode)
                        }
                    }
                }

                if !aiImageState.jobs.isEmpty {
                    Section(language.localized("ジョブ")) {
                        ForEach(aiImageState.jobs.prefix(4)) { job in
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
                                        store.send(.aiImage(.retryJobTapped(job.id)))
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }

                if !aiImageState.history.isEmpty {
                    Section(language.localized("履歴")) {
                        ForEach(aiImageState.history.prefix(4)) { item in
                            Button {
                                store.send(.aiImage(.historyItemSelected(item.descriptor)))
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
            .navigationTitle(StudioStrings.aiImage(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        aiImageFocusedField = nil
                        store.send(.aiImage(.sheetPresentationChanged(false)))
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(aiImagePrimaryActionTitle(fallback: language.localized("生成"))) {
                        handleAIImagePrimaryAction(closeSheet: true)
                    }
                    .disabled(aiImagePrimaryActionDisabled)
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
        DocumentFeature.normalizeGradientMapSettings(gradientMapSettings)
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
        let mixed = DocumentFeature.mappedGradientColor(
            for: clampedPosition,
            stops: DocumentFeature.gradientMapStops(for: normalizedGradientMapSettings)
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

    func color(from stop: DocumentFeature.GradientMapStop) -> Color {
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
        let resolved = UIColor(store.document.editing.brushPalette.brush.activeOpaqueColor)
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
                store.send(.workspace(.homeReturnRequested))
            } label: {
                HStack(spacing: 7) {
                    Image("AppLogo")
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)

                    Text(language.localized("ホーム"))
                        .font(StudioTheme.Typography.label(10))
                }
                .foregroundStyle(StudioTheme.Palette.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(StudioTheme.Palette.toolbarFill)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(StudioTheme.Palette.hairline, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Text(StudioStrings.appName(language))
                    .font(StudioTheme.Typography.label(11))
                    .foregroundStyle(StudioTheme.Palette.textPrimary)
            }

            menuBarMenu(StudioStrings.fileMenu(language)) {
                Menu(StudioStrings.newCanvas(language)) {
                    ForEach(canvasSizePresets, id: \.label) { preset in
                        Button(preset.label) {
                            store.send(.document(.lifecycle(.newCanvasRequested(width: preset.width, height: preset.height))))
                        }
                    }

                    Divider()

                    Button(StudioStrings.customSize(language)) {
                        newCanvasWidthText = "\(max(Int(store.document.editing.canvas.canvasSize.width.rounded()), 1))"
                        newCanvasHeightText = "\(max(Int(store.document.editing.canvas.canvasSize.height.rounded()), 1))"
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
                    store.send(.importExport(.saveDocumentRequested))
                }
                Button(language.localized("名前を付けて保存")) {
                    store.send(.importExport(.saveDocumentCopyRequested))
                }
                Button(language.localized("保存履歴")) {
                    store.send(.importExport(.saveHistoryRequested))
                }
                Button(StudioStrings.export(language)) {
                    store.send(.importExport(.exportDocumentRequested))
                }
                Button(StudioStrings.exportTimelapse(language)) {
                    store.send(.importExport(.exportTimelapseRequested))
                }
            }

            menuBarMenu(StudioStrings.editMenu(language)) {
                Menu(language.localized("選択範囲")) {
                    Button(language.localized("選択反転")) {
                        store.send(.document(.brushPalette(.delegate(.invertSelection))))
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
                        colorRangeTolerance = store.document.editing.brushPalette.selection.colorTolerance
                        colorRangeMinimumAlpha = 0.05
                        colorRangeExpansion = max(store.document.editing.brushPalette.selection.expansion, 0)
                        colorRangeSource = .activeLayer
                        showsColorRangeSelectionSheet = true
                    }
                }

                Divider()

                Button(language.localized("キャンバスサイズを変更")) {
                    resizeCanvasExtentWidthText = "\(max(Int(store.document.editing.canvas.canvasSize.width.rounded()), 1))"
                    resizeCanvasExtentHeightText = "\(max(Int(store.document.editing.canvas.canvasSize.height.rounded()), 1))"
                    showsResizeCanvasExtentSheet = true
                }

                Button(language.localized("画像解像度を変更")) {
                    resizeCanvasWidthText = "\(max(Int(store.document.editing.canvas.canvasSize.width.rounded()), 1))"
                    resizeCanvasHeightText = "\(max(Int(store.document.editing.canvas.canvasSize.height.rounded()), 1))"
                    showsResizeCanvasSheet = true
                }

                Divider()

                Menu(StudioStrings.colorCorrection(language)) {
                    Button(StudioStrings.hueSaturationBrightness(language)) {
                        store.send(.document(.adjustment(.editing(.brightnessContrastPreviewChanged(nil)))))
                        hsbAdjustmentSettings = HueSaturationBrightnessSettings()
                        showsHSBSheet = true
                    }

                    Button(StudioStrings.brightnessContrast(language)) {
                        store.send(.document(.adjustment(.editing(.hueSaturationBrightnessPreviewChanged(nil)))))
                        brightnessContrastSettings = BrightnessContrastSettings()
                        showsBrightnessContrastSheet = true
                    }

                    Button(StudioStrings.levels(language)) {
                        levelsAdjustmentSettings = LevelsAdjustmentSettings()
                        store.send(.document(.adjustment(.editing(.levelsPreviewChanged(normalizedLevelsSettings)))))
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
                        store.send(.document(.adjustment(.editing(.luminanceToAlphaRequested))))
                    }

                    Menu(StudioStrings.gradientMap(language)) {
                        Button(language.localized("カスタム…")) {
                            gradientMapSettings = DocumentFeature.gradientMapSettings(for: .graphite)
                            showsGradientMapSheet = true
                        }

                        Divider()

                        ForEach(GradientMapPreset.allCases) { preset in
                            Button(preset.localizedTitle(language)) {
                                store.send(.document(.adjustment(.editing(.gradientMapSelected(preset)))))
                            }
                        }
                    }
                }
                .disabled(activeLayer == nil || store.document.editing.canvas.renderSnapshot == nil)

                Button(StudioStrings.aiImageEdit(language)) {
                    prepareAIImageComposer()
                    store.send(.aiImage(.sheetPresentationChanged(true)))
                }
                .disabled(activeLayer == nil || store.document.editing.canvas.renderSnapshot == nil || aiImageState.isGenerating)

                Divider()

                Button(StudioStrings.clearActiveLayer(language)) {
                    store.send(.document(.layerWorkflow(.editing(.clearActiveLayerButtonTapped))))
                }

                Button(StudioStrings.refreshView(language)) {
                    store.send(.application(.refreshPresentationRequested))
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
                    store.send(.document(.layerSidebar(.addLayerButtonTapped)))
                }

                Button(language.localized("写真を新規レイヤーに読み込む")) {
                    showsPhotoLayerImporter = true
                }

                Button(StudioStrings.addFolder(language)) {
                    store.send(.document(.layerSidebar(.addFolderButtonTapped)))
                }

                Button(activeLayerIsVisible ? StudioStrings.hideActiveLayer(language) : StudioStrings.showActiveLayer(language)) {
                    store.send(.document(.layerWorkflow(.editing(.activeLayerVisibilityToggled))))
                }
                .disabled(activeLayer == nil)

                Divider()

                Button(StudioStrings.selectUpperLayer(language)) {
                    store.send(.document(.layerWorkflow(.editing(.selectPreviousLayer))))
                }
                .disabled(!canSelectPreviousLayer)

                Button(StudioStrings.selectLowerLayer(language)) {
                    store.send(.document(.layerWorkflow(.editing(.selectNextLayer))))
                }
                .disabled(!canSelectNextLayer)

                Divider()

                Button(language.localized("選択範囲からマスク作成")) {
                    store.send(.document(.layerWorkflow(.editing(.createLayerMaskFromSelectionRequested))))
                }
                .disabled(activeLayer == nil || store.document.editing.canvas.selection?.isEmpty != false)

                Button(language.localized("マスクを削除")) {
                    store.send(.document(.layerWorkflow(.editing(.clearLayerMaskRequested))))
                }
                .disabled(activeLayerHasMask == false)

                Button(language.localized("マスクを適用")) {
                    store.send(.document(.layerWorkflow(.editing(.applyLayerMaskRequested))))
                }
                .disabled(activeLayerHasMask == false)

                Divider()

                Button(StudioStrings.clearActiveLayer(language)) {
                    store.send(.document(.layerWorkflow(.editing(.clearActiveLayerButtonTapped))))
                }
                .disabled(activeLayer == nil)
            }

            menuBarMenu(StudioStrings.settingsMenu(language)) {
                Menu(StudioStrings.languageMenu(language)) {
                    ForEach(AppLanguage.allCases) { option in
                        Button {
                            store.send(.application(.languageChanged(option)))
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

                Button {
                    store.send(
                        .document(
                            .brushPalette(
                                .binding(
                                    .set(
                                        \.ui.allowsFingerTouchInput,
                                         !store.document.editing.brushPalette.allowsFingerTouchInput
                                    )
                                )
                            )
                        )
                    )
                } label: {
                    if store.document.editing.brushPalette.allowsFingerTouchInput {
                        Label(language.localized("指入力"), systemImage: "checkmark")
                    } else {
                        Text(language.localized("指入力"))
                    }
                }

                Divider()

                Button(store.document.editing.brushPanel.isCollapsed ? StudioStrings.showBrushPanel(language) : StudioStrings.hideBrushPanel(language)) {
                    toggleStudioPanel(.brush)
                }

                Button(store.document.editing.layerPanel.isCollapsed ? StudioStrings.showLayerPanel(language) : StudioStrings.hideLayerPanel(language)) {
                    toggleStudioPanel(.layers)
                }

                Divider()

                Button(StudioStrings.licenses(language)) {
                    showsLicensesSheet = true
                }
            }

            Spacer(minLength: 8)

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(StudioTheme.Gradients.topBar)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.025))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
    }

    var undoRedoBar: some View {
        HStack(spacing: 8) {
            panelToolbarToggleButton(
                systemImage: store.document.editing.brushPanel.isCollapsed
                    ? "rectangle.leftthird.inset.filled"
                    : "sidebar.left",
                accessibilityLabel: store.document.editing.brushPanel.isCollapsed
                    ? StudioStrings.showBrushPanel(language)
                    : StudioStrings.hideBrushPanel(language),
                isPanelToggle: true,
                isPanelOpen: !store.document.editing.brushPanel.isCollapsed
            ) {
                toggleStudioPanel(.brush)
            }

            Button {
                store.send(.document(.lifecycle(.undoRequested)))
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .minimumHitTarget(36)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.toolbarFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.hairline, lineWidth: 1)
            }

            Button {
                store.send(.document(.lifecycle(.redoRequested)))
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .minimumHitTarget(36)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.toolbarFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.hairline, lineWidth: 1)
            }

            Button {
                showsPhotoLayerImporter = true
            } label: {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .minimumHitTarget(36)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.toolbarFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.hairline, lineWidth: 1)
            }

            Button {
                store.send(.document(.layerWorkflow(.editing(.clearActiveLayerButtonTapped))))
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .minimumHitTarget(44)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(StudioTheme.Palette.toolbarFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(StudioTheme.Palette.hairline, lineWidth: 1)
            }
            .disabled(activeLayer == nil)

            Spacer(minLength: 0)

            panelToolbarToggleButton(
                systemImage: store.document.editing.layerPanel.isCollapsed
                    ? "rectangle.rightthird.inset.filled"
                    : "sidebar.right",
                accessibilityLabel: store.document.editing.layerPanel.isCollapsed
                    ? StudioStrings.showLayerPanel(language)
                    : StudioStrings.hideLayerPanel(language),
                isPanelToggle: true,
                isPanelOpen: !store.document.editing.layerPanel.isCollapsed
            ) {
                toggleStudioPanel(.layers)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(StudioTheme.Gradients.chrome)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
        }
    }

    func panelToolbarToggleButton(
        systemImage: String,
        accessibilityLabel: String,
        isPanelToggle: Bool = false,
        isPanelOpen: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isPanelToggle ? StudioTheme.Palette.accentBright : StudioTheme.Palette.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .minimumHitTarget(52)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isPanelToggle ? StudioTheme.Palette.accentBright.opacity(isPanelOpen ? 0.13 : 0.08) : StudioTheme.Palette.toolbarFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(
                    isPanelToggle
                        ? StudioTheme.Palette.accentBright.opacity(isPanelOpen ? 0.94 : 0.64)
                        : StudioTheme.Palette.hairline,
                    lineWidth: isPanelToggle ? 1.5 : 1
                )
        }
        .shadow(
            color: isPanelToggle ? StudioTheme.Palette.accentBright.opacity(isPanelOpen ? 0.34 : 0.20) : .clear,
            radius: isPanelToggle ? 8 : 0,
            x: 0,
            y: 0
        )
        .contentShape(Rectangle())
        .hoverEffect(.lift)
        .accessibilityLabel(accessibilityLabel)
    }

    func menuBarMenu<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            Text(title)
                .font(StudioTheme.Typography.label(10))
                .foregroundStyle(StudioTheme.Palette.textPrimary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .minimumHitTarget(34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(StudioTheme.Palette.toolbarFill)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(StudioTheme.Palette.hairline, lineWidth: 1)
                }
        }
    }

    var activeLayer: LayerRowModel? {
        store.document.editing.layerSidebar.layers.first { $0.index == store.document.editing.layerSidebar.activeLayerIndex }
    }

    var activeLayerIsVisible: Bool {
        activeLayer?.visible ?? false
    }

    var activeLayerHasMask: Bool {
        activeLayer?.hasMask ?? false
    }

    var activeLayerPosition: Int? {
        store.document.editing.layerSidebar.layers.firstIndex { $0.index == store.document.editing.layerSidebar.activeLayerIndex }
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
        return activeLayerPosition < store.document.editing.layerSidebar.layers.count - 1
    }
}
