import SwiftUI
import UIKit

extension ContentView {
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
                                gradientMapSettings = AppFeature.gradientMapSettings(for: preset)
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
                        Text(language.localized("Describe how Nano Banana should edit the active layer"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(language.localized("Prompt"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $nanoBananaPrompt)
                            .frame(minHeight: 110)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                            )
                            .textInputAutocapitalization(.sentences)
                            .focused($nanoBananaFocusedField, equals: .prompt)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(NanoBananaPromptPreset.allCases) { preset in
                                Button(preset.title(language)) {
                                    nanoBananaPrompt = preset.prompt(language)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(language.localized("入力")) {
                    Picker(language.localized("Access"), selection: Binding(
                        get: { nanoBananaAccessMode },
                        set: { nanoBananaAccessMode = $0 }
                    )) {
                        ForEach(NanoBananaAccessMode.allCases) { mode in
                            Text(mode.title(language)).tag(mode)
                        }
                    }

                    Picker(language.localized("入力レイヤー"), selection: $nanoBananaInputLayerIndex) {
                        ForEach(store.layerSidebar.layers) { layer in
                            Text(layer.name).tag(layer.index)
                        }
                    }

                    Picker(language.localized("Edit Scope"), selection: $nanoBananaEditScope) {
                        ForEach(NanoBananaEditScope.allCases) { scope in
                            Text(scope.title(language)).tag(scope)
                        }
                    }
                    .disabled(store.canvas.selection?.isEmpty != false)

                    if store.canvas.selection?.isEmpty != false {
                        Text(language.localized("Create a selection to enable inpaint"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if nanoBananaEditScope == .selectedArea {
                        Stepper(
                            "\(language.localized("Mask Expansion")): \(nanoBananaMaskExpansion)",
                            value: $nanoBananaMaskExpansion,
                            in: -24...48
                        )

                        Toggle(language.localized("Invert Mask"), isOn: $nanoBananaInvertsMask)
                    }

                    Picker(language.localized("モデル"), selection: $nanoBananaModel) {
                        ForEach(NanoBananaModel.allCases) { model in
                            Text(model.title(language)).tag(model)
                        }
                    }

                    if nanoBananaAccessMode == .userAPIKey {
                        SecureField(language.localized("Gemini API Key"), text: $nanoBananaAPIKey)
                            .focused($nanoBananaFocusedField, equals: .apiKey)
                        Text(language.localized("Saved locally on this device"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        LabeledContent(language.localized("Status")) {
                            Text(
                                nanoBananaCommerce.isSubscriptionActive
                                ? language.localized("Active")
                                : language.localized("Inactive")
                            )
                            .foregroundStyle(nanoBananaCommerce.isSubscriptionActive ? .green : .secondary)
                        }

                        if let product = nanoBananaCommerce.primaryProduct {
                            LabeledContent(language.localized("Plan")) {
                                Text(product.displayPrice)
                            }
                        }

                        Button(language.localized("Purchase Subscription")) {
                            Task {
                                await nanoBananaCommerce.purchasePrimaryProduct()
                            }
                        }
                        .disabled(nanoBananaCommerce.isLoading || nanoBananaCommerce.isSubscriptionActive)

                        Button(language.localized("Restore Purchases")) {
                            Task {
                                await nanoBananaCommerce.restorePurchases()
                            }
                        }
                        .disabled(nanoBananaCommerce.isLoading)

                        if let purchaseErrorMessage = nanoBananaCommerce.purchaseErrorMessage, !purchaseErrorMessage.isEmpty {
                            Text(purchaseErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Text(language.localized("Use your own backend to inject the provider API key and verify entitlements"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(language.localized("出力")) {
                    Picker(language.localized("出力先"), selection: $nanoBananaOutputMode) {
                        ForEach(NanoBananaOutputMode.allCases) { mode in
                            Text(mode.title(language)).tag(mode)
                        }
                    }
                }

                if !store.nanoBananaJobs.isEmpty {
                    Section(language.localized("Jobs")) {
                        ForEach(store.nanoBananaJobs.prefix(4)) { job in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(job.request.model.title(language))
                                    Spacer()
                                    Text(job.status.rawValue.capitalized)
                                        .foregroundStyle(.secondary)
                                }
                                Text(job.request.prompt)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                if job.status == .failed || job.status == .canceled {
                                    Button(language.localized("Retry")) {
                                        store.send(.nanoBananaRetryJob(job.id))
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }

                if !store.nanoBananaHistory.isEmpty {
                    Section(language.localized("History")) {
                        ForEach(store.nanoBananaHistory.prefix(4)) { item in
                            Button {
                                nanoBananaPrompt = item.request.prompt
                                nanoBananaInputLayerIndex = item.request.inputLayerIndex
                                nanoBananaEditScope = item.request.editScope
                                nanoBananaOutputMode = item.request.outputMode
                                nanoBananaModel = item.request.model
                                nanoBananaMaskExpansion = item.request.maskSettings.expansion
                                nanoBananaInvertsMask = item.request.maskSettings.isInverted
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.request.prompt)
                                        .lineLimit(2)
                                    Text(item.request.model.title(language))
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
                        showsNanoBananaSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(language.localized("Generate")) {
                        nanoBananaFocusedField = nil
                        store.send(
                            .nanoBananaEditRequested(
                                NanoBananaGenerationRequest(
                                    prompt: nanoBananaPrompt,
                                    config: NanoBananaRequestConfig(
                                    accessMode: nanoBananaAccessMode,
                                    credential: nanoBananaAccessMode == .userAPIKey ? nanoBananaAPIKey : nanoBananaCommerce.latestEntitlementJWS,
                                    endpoint: nanoBananaCommerce.proxyEndpoint
                                ),
                                    model: nanoBananaModel,
                                    inputLayerIndex: nanoBananaInputLayerIndex,
                                    editScope: nanoBananaEditScope,
                                    outputMode: nanoBananaOutputMode,
                                    maskSettings: NanoBananaMaskSettings(
                                        expansion: nanoBananaMaskExpansion,
                                        isInverted: nanoBananaInvertsMask
                                    )
                                )
                            )
                        )
                        showsNanoBananaSheet = false
                    }
                    .disabled(
                        store.isNanoBananaGenerating ||
                        store.layerSidebar.layers.isEmpty ||
                        nanoBananaPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        (
                            nanoBananaAccessMode == .userAPIKey
                            ? nanoBananaAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            : (
                                !nanoBananaCommerce.isSubscriptionActive ||
                                nanoBananaCommerce.latestEntitlementJWS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                nanoBananaCommerce.proxyEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                        )
                    )
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
        AppFeature.normalizeGradientMapSettings(gradientMapSettings)
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
        let mixed = AppFeature.mappedGradientColor(
            for: clampedPosition,
            stops: AppFeature.gradientMapStops(for: normalizedGradientMapSettings)
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

    func color(from stop: AppFeature.GradientMapStop) -> Color {
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
                            .fill(Color(red: 0.05, green: 0.11, blue: 0.17))
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
                        .fill(StudioTheme.Palette.accent.opacity(0.18))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(StudioTheme.Palette.accentSoft.opacity(0.4), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            Text(StudioStrings.appName(language))
                .font(StudioTheme.Typography.label(10))
                .foregroundStyle(StudioTheme.Palette.textPrimary)

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
                Button(language.localized("Import Photo to New Layer")) {
                    showsPhotoLayerImporter = true
                }
                Button(StudioStrings.save(language)) {
                    store.send(.saveDocumentRequested)
                }
                Button(StudioStrings.export(language)) {
                    store.send(.exportDocumentRequested)
                }
                Button(StudioStrings.exportTimelapse(language)) {
                    store.send(.exportTimelapseRequested)
                }
            }

            menuBarMenu(StudioStrings.editMenu(language)) {
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

                    Menu(StudioStrings.gradientMap(language)) {
                        Button(language.localized("カスタム…")) {
                            gradientMapSettings = AppFeature.gradientMapSettings(for: .graphite)
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
                    nanoBananaPrompt = ""
                    nanoBananaInputLayerIndex = store.layerSidebar.activeLayerIndex
                    nanoBananaEditScope = store.canvas.selection?.isEmpty == false ? .selectedArea : .wholeLayer
                    nanoBananaMaskExpansion = 0
                    nanoBananaInvertsMask = false
                    nanoBananaOutputMode = .replaceCurrentLayer
                    nanoBananaModel = .flashImage25
                    showsNanoBananaSheet = true
                }
                .disabled(activeLayer == nil || store.canvas.renderSnapshot == nil || store.isNanoBananaGenerating)

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

                Button(language.localized("Import Photo to New Layer")) {
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

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(StudioTheme.Gradients.topBar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
    }

    var undoRedoBar: some View {
        HStack(spacing: 4) {
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
                    .fill(StudioTheme.Palette.accent.opacity(0.18))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.accentSoft.opacity(0.42), lineWidth: 1)
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
                    .fill(StudioTheme.Palette.accent.opacity(0.18))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.accentSoft.opacity(0.42), lineWidth: 1)
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
                    .fill(StudioTheme.Palette.accent.opacity(0.14))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.accentSoft.opacity(0.32), lineWidth: 1)
            }

            Button {
                store.send(.clearActiveLayerButtonTapped)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .minimumHitTarget(30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.accent.opacity(0.14))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.accentSoft.opacity(0.34), lineWidth: 1)
            }
            .disabled(activeLayer == nil)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(red: 0.19, green: 0.19, blue: 0.19))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
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
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .minimumHitTarget(28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(StudioTheme.Palette.toolbarFill)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(StudioTheme.Palette.accentSoft.opacity(0.22), lineWidth: 1)
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
