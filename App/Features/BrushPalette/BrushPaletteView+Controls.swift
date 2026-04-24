import PrimoBrushDomain
import PrimoDocumentContracts
import PrimoDocumentDomain
import SwiftUI
import UIKit

extension BrushPaletteView {
    func controlsCard(proxy: GeometryProxy, showsChrome: Bool, showsCategoryPicker: Bool = true) -> some View {
        cardContainer(showsChrome: showsChrome) {
            VStack(alignment: .leading, spacing: 10) {
                if currentTool == .text {
                    segmentedModeRow(
                        title: language.localized("フォント"),
                        selectedTitle: store.text.selectedFontDisplayName ?? language.localized("システム")
                    ) {
                        Picker(language.localized("フォント"), selection: $store.text.selectedFontPostScriptName) {
                            ForEach(store.text.availableFonts) { font in
                                Text(font.displayName).tag(Optional(font.postScriptName))
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: store.text.selectedFontPostScriptName) { _, newValue in
                            if let font = store.text.availableFonts.first(where: { $0.postScriptName == newValue }) {
                                store.text.selectedFontDisplayName = font.displayName
                            }
                        }
                    }

                    sliderRow(
                        title: language.localized("文字サイズ"),
                        value: "\(Int(store.text.fontSize.rounded())) px",
                        slider: Slider(value: $store.text.fontSize, in: 12...240, step: 1)
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(language.localized("テキスト"))
                            .font(StudioTheme.Typography.title(12))
                            .foregroundStyle(panelPrimaryTextStyle)

                        PaletteTextEditor(
                            text: $store.text.content,
                            textColor: usesLightPanelTheme ? UIColor.black.withAlphaComponent(0.84) : UIColor.white.withAlphaComponent(0.92),
                            fontSize: max(min(store.text.fontSize * 0.26, 24), 14),
                            backgroundColor: .clear
                        )
                            .frame(minHeight: 116)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(panelCardFillStrong)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(panelCardBorder, lineWidth: 1)
                            )
                    }

                    HStack(spacing: 8) {
                        Button {
                            isImportingTextFont = true
                        } label: {
                            Label(language.localized("フォントを追加"), systemImage: "plus.circle")
                                .font(StudioTheme.Typography.label(12))
                                .foregroundStyle(panelPrimaryTextStyle)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(panelCardFillStrong)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(panelCardBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.send(.applyTextButtonTapped)
                        } label: {
                            Label(
                                store.text.targetLayerIndex == nil ? language.localized("テキストレイヤーを追加") : language.localized("テキストを更新"),
                                systemImage: "text.badge.plus"
                            )
                            .font(StudioTheme.Typography.label(12))
                            .foregroundStyle(.white.opacity(0.94))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(StudioTheme.Palette.accent)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(store.text.position == nil || store.text.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Text(
                        store.text.position == nil
                            ? language.localized("キャンバスをタップしてテキスト位置を決めてください。")
                            : "\(language.localized("配置")): x \(Int((store.text.position?.x ?? 0).rounded())) / y \(Int((store.text.position?.y ?? 0).rounded()))"
                    )
                    .font(StudioTheme.Typography.body(11))
                    .foregroundStyle(usesLightPanelTheme ? Color.black.opacity(0.56) : .white.opacity(0.62))
                } else if currentTool == .fill {
                    segmentedModeRow(
                        title: language.localized("しきい値モード"),
                        selectedTitle: store.fill.thresholdMode.localizedTitle(language)
                    ) {
                        Picker(language.localized("しきい値モード"), selection: $store.fill.thresholdMode) {
                            ForEach(FillThresholdMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    sliderRow(
                        title: store.fill.thresholdMode == .opacity ? language.localized("不透明度しきい値") : language.localized("色しきい値"),
                        value: "\(Int((store.fill.thresholdMode == .opacity ? store.fill.opacityTolerance : store.fill.colorTolerance) * 100))%",
                        slider: Group {
                            if store.fill.thresholdMode == .opacity {
                                Slider(value: $store.fill.opacityTolerance, in: 0.0...1.0)
                            } else {
                                Slider(value: $store.fill.colorTolerance, in: 0.0...1.0)
                            }
                        }
                    )
                    sliderRow(
                        title: language.localized("拡張"),
                        value: "\(Int(store.fill.expansion)) px",
                        slider: Slider(value: $store.fill.expansion, in: 0...24, step: 1)
                    )
                } else if currentTool == .eyedropper {
                    segmentedModeRow(
                        title: language.localized("取得元"),
                        selectedTitle: store.sampling.eyedropperSource.localizedTitle(language)
                    ) {
                        Picker(language.localized("取得元"), selection: $store.sampling.eyedropperSource) {
                            ForEach(EyedropperSamplingSource.allCases) { source in
                                Text(source.localizedTitle(language)).tag(source)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Text(language.localized("Apple Pencil でタップまたはドラッグすると色を取得して現在色に反映します。"))
                        .font(StudioTheme.Typography.body(11))
                        .foregroundStyle(usesLightPanelTheme ? Color.black.opacity(0.56) : .white.opacity(0.62))
                } else if currentTool == .blur {
                    sliderRow(
                        title: language.localized("ぼかし半径"),
                        value: "\(Int(store.brush.radius)) px",
                        slider: Slider(value: $store.brush.radius, in: 2...BrushPaletteFeature.maximumBrushRadius, step: 1)
                    )
                    sliderRow(
                        title: language.localized("エッジの柔らかさ"),
                        value: "\(Int((1.0 - store.brush.hardness) * 100))%",
                        slider: Slider(
                            value: Binding(
                                get: { 1.0 - store.brush.hardness },
                                set: { store.brush.hardness = 1.0 - $0 }
                            ),
                            in: 0.0...1.0
                        )
                    )
                    sliderRow(
                        title: language.localized("ぼかしの強さ"),
                        value: "\(Int(store.brush.flow * 100))%",
                        slider: Slider(value: $store.brush.flow, in: 0.1...1.0)
                    )

                    Text(language.localized("Apple Pencil でなぞった部分だけをぼかします。サイズは半径、強さはぼかしの効き方です。"))
                        .font(StudioTheme.Typography.body(11))
                        .foregroundStyle(usesLightPanelTheme ? Color.black.opacity(0.56) : .white.opacity(0.62))
                } else if currentTool == .select {
                    segmentedModeRow(
                        title: language.localized("選択アクション"),
                        selectedTitle: store.selection.combineMode.localizedTitle(language)
                    ) {
                        Picker(language.localized("選択アクション"), selection: $store.selection.combineMode) {
                            ForEach(SelectionCombineMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    segmentedModeRow(
                        title: language.localized("選択モード"),
                        selectedTitle: store.selection.toolMode.localizedTitle(language)
                    ) {
                        Picker(language.localized("選択モード"), selection: $store.selection.toolMode) {
                            ForEach(SelectionToolMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    if store.selection.toolMode == .auto {
                        segmentedModeRow(
                            title: language.localized("しきい値モード"),
                            selectedTitle: store.selection.thresholdMode.localizedTitle(language)
                        ) {
                            Picker(language.localized("選択しきい値モード"), selection: $store.selection.thresholdMode) {
                                ForEach(FillThresholdMode.allCases) { mode in
                                    Text(mode.localizedTitle(language)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        sliderRow(
                            title: store.selection.thresholdMode == .opacity ? language.localized("不透明度しきい値") : language.localized("色しきい値"),
                            value: "\(Int((store.selection.thresholdMode == .opacity ? store.selection.opacityTolerance : store.selection.colorTolerance) * 100))%",
                            slider: Group {
                                if store.selection.thresholdMode == .opacity {
                                    Slider(value: $store.selection.opacityTolerance, in: 0.0...1.0)
                                } else {
                                    Slider(value: $store.selection.colorTolerance, in: 0.0...1.0)
                                }
                            }
                        )
                        sliderRow(
                            title: language.localized("拡張"),
                            value: "\(Int(store.selection.expansion)) px",
                            slider: Slider(value: $store.selection.expansion, in: 0...24, step: 1)
                        )
                    }
                    Button {
                        store.send(.clearSelectionButtonTapped)
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 12, weight: .semibold))
                            Text(language.localized("選択を解除"))
                                .font(StudioTheme.Typography.label(12))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(panelPrimaryTextStyle)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(panelCardFillStrong)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(panelCardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 8) {
                        Button {
                            onRequestExpandSelection()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(language.localized("拡張"))
                                    .font(StudioTheme.Typography.label(12))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(panelPrimaryTextStyle)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(panelCardFillStrong)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(panelCardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            onRequestContractSelection()
                        } label: {
                            HStack {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(language.localized("縮小"))
                                    .font(StudioTheme.Typography.label(12))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(panelPrimaryTextStyle)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(panelCardFillStrong)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(panelCardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } else if currentTool == .shape {
                    segmentedModeRow(
                        title: language.localized("形状"),
                        selectedTitle: store.shape.mode.localizedTitle(language)
                    ) {
                        Picker(language.localized("形状"), selection: $store.shape.mode) {
                            ForEach(ShapeToolMode.allCases) { mode in
                                Label(mode.localizedTitle(language), systemImage: mode.systemImage).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    sliderRow(
                        title: language.localized("線幅"),
                        value: "\(Int(store.brush.radius)) px",
                        slider: Slider(value: $store.brush.radius, in: 1...BrushPaletteFeature.maximumBrushRadius, step: 1)
                    )
                    sliderRow(
                        title: language.localized("不透明度"),
                        value: "\(Int(store.brush.opacity * 100))%",
                        slider: Slider(value: $store.brush.opacity, in: 0.1...1.0)
                    )
                    sliderRow(
                        title: language.localized("手ぶれ補正"),
                        value: "\(Int(store.brush.stabilization * 100))%",
                        slider: Slider(value: $store.brush.stabilization, in: 0.0...1.0)
                    )

                    Text(language.localized("Apple Pencil をドラッグすると、始点から現在位置までの範囲で図形の輪郭を描きます。"))
                        .font(StudioTheme.Typography.body(11))
                        .foregroundStyle(usesLightPanelTheme ? Color.black.opacity(0.56) : .white.opacity(0.62))
                } else if currentTool == .move {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(hasSelection ? language.localized("Apple Pencil で選択範囲を移動します。適用するまで確定されません。") : language.localized("Apple Pencil でアクティブレイヤーを移動します。適用するまで確定されません。"))
                            .font(StudioTheme.Typography.body(11))
                            .foregroundStyle(usesLightPanelTheme ? Color.black.opacity(0.56) : .white.opacity(0.62))

                        segmentedModeRow(
                            title: language.localized("変形モード"),
                            selectedTitle: transformMode.title(language)
                        ) {
                            Picker(language.localized("変形モード"), selection: Binding(
                                get: { transformMode },
                                set: { onSetTransformMode($0) }
                            )) {
                                ForEach(CanvasTransformMode.allCases) { mode in
                                    Text(mode.title(language)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        if transformMode == .standard {
                            Toggle(isOn: Binding(
                                get: { transformLocksAspectRatio },
                                set: { onSetTransformAspectRatioLock($0) }
                            )) {
                                Text(language.localized("縦横比を固定"))
                                    .font(StudioTheme.Typography.label(12))
                                    .foregroundStyle(panelPrimaryTextStyle)
                            }
                            .toggleStyle(.switch)
                        }

                        Button {
                            onRequestTransformNumericInput()
                        } label: {
                            HStack {
                                Image(systemName: "number.square")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(language.localized("数値入力"))
                                    .font(StudioTheme.Typography.label(12))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(panelPrimaryTextStyle)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(panelCardFillStrong)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(panelCardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 8) {
                            Button {
                                store.send(.applyTransformButtonTapped)
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(language.localized("適用"))
                                        .font(StudioTheme.Typography.label(12))
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(.horizontal, 12)
                                .frame(minHeight: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(StudioTheme.Palette.accent)
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                store.send(.cancelTransformButtonTapped)
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(language.localized("キャンセル"))
                                        .font(StudioTheme.Typography.label(12))
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(panelPrimaryTextStyle)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(panelCardFillStrong)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(panelCardBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    if showsCategoryPicker {
                        Picker("", selection: $selectedBrushSettingsCategory) {
                            ForEach(BrushSettingsCategory.allCases) { category in
                                Text(category.localizedTitle(language)).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    brushCategoryControls(proxy: proxy)
                }
            }
        }
    }

    @ViewBuilder
    func brushCategoryControls(proxy: GeometryProxy) -> some View {
        switch selectedBrushSettingsCategory {
        case .tip:
            tipControls(proxy: proxy)
        case .scatter:
            scatterControls()
        case .stroke:
            strokeControls(proxy: proxy)
        case .texture:
            textureControls()
        }
    }

    func tipControls(proxy: GeometryProxy) -> some View {
        Group {
            sectionLabel(language.localized("先端形状"))
            segmentedModeRow(
                title: language.localized("ブラシ先端"),
                selectedTitle: store.brush.tipKind.localizedTitle(language)
            ) {
                VStack(spacing: 8) {
                    ForEach(BrushTipKind.allCases) { tipKind in
                        brushTipButton(tipKind: tipKind, isSelected: store.brush.tipKind == tipKind) {
                            store.brush.tipKind = tipKind
                        }
                    }
                }
            }
            sliderRow(title: language.localized("サイズ"), value: "\(Int(store.brush.radius)) px", slider: Slider(value: $store.brush.radius, in: 1...BrushPaletteFeature.maximumBrushRadius), isFullHeight: true, proxy: proxy)
            dynamicControlMenuRow(
                title: language.localized("サイズコントロール"),
                selection: sizeControlBinding,
                allowed: [.off, .pressure]
            )
            sliderRow(title: language.localized("サイズ量"), value: "\(Int(sizeAmountBinding.wrappedValue * 100))%", slider: Slider(value: sizeAmountBinding, in: 0.0...1.0))
            sliderRow(
                title: language.localized("速度でサイズ"),
                value: "\(Int(speedSizeAmountBinding.wrappedValue.rounded()))",
                slider: Slider(value: speedSizeAmountBinding, in: 0...200, step: 1)
            )
            sliderRow(
                title: language.localized("入り"),
                value: "\(Int(taperInAmountBinding.wrappedValue.rounded()))",
                slider: Slider(value: taperInAmountBinding, in: 0...100, step: 1)
            )
            sliderRow(
                title: language.localized("抜き"),
                value: "\(Int(taperOutAmountBinding.wrappedValue.rounded()))",
                slider: Slider(value: taperOutAmountBinding, in: 0...100, step: 1)
            )
            sliderRow(title: language.localized("形状の細さ"), value: "\(Int(store.brush.roundness * 100))%", slider: Slider(value: $store.brush.roundness, in: 0.2...1.0))
            dynamicControlMenuRow(
                title: language.localized("形状コントロール"),
                selection: roundnessControlBinding,
                allowed: [.off, .pressure, .tilt, .random]
            )
            sliderRow(title: language.localized("形状量"), value: "\(Int(roundnessAmountBinding.wrappedValue * 100))%", slider: Slider(value: roundnessAmountBinding, in: 0.0...1.0))
            segmentedModeRow(
                title: language.localized("回転モード"),
                selectedTitle: store.brush.angleMode.localizedTitle(language)
            ) {
                Picker(language.localized("回転モード"), selection: $store.brush.angleMode) {
                    ForEach(BrushAngleMode.allCases) { mode in
                        Text(mode.localizedTitle(language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            sliderRow(title: language.localized("角度"), value: "\(Int((store.brush.angle * 180 / .pi).rounded()))°", slider: Slider(value: $store.brush.angle, in: -.pi / 2 ... .pi / 2))
            dynamicControlMenuRow(
                title: language.localized("角度コントロール"),
                selection: angleControlBinding,
                allowed: [.off, .pressure, .tilt, .random]
            )
            sliderRow(title: language.localized("角度量"), value: "\(Int(angleAmountBinding.wrappedValue * 100))%", slider: Slider(value: angleAmountBinding, in: 0.0...1.0))
            sliderRow(title: language.localized("硬さ"), value: "\(Int(store.brush.hardness * 100))%", slider: Slider(value: $store.brush.hardness, in: 0.2...0.98))
        }
    }

    func scatterControls() -> some View {
        Group {
            sectionLabel("Scattering")
            Toggle(isOn: $store.brush.scatterEnabled) {
                Text(language.localized("散布を有効にする"))
                    .font(StudioTheme.Typography.title(12))
                    .foregroundStyle(panelPrimaryTextStyle)
            }
            .tint(StudioTheme.Palette.accentBright)
            sliderRow(title: language.localized("スタンプ間隔"), value: "\(Int(store.brush.spacing * 100))%", slider: Slider(value: $store.brush.spacing, in: 0.08...0.8))
            if store.brush.scatterEnabled {
                sliderRow(title: language.localized("間隔ジッター"), value: "\(Int(store.brush.spacingJitter * 100))%", slider: Slider(value: $store.brush.spacingJitter, in: 0.0...0.5))
                segmentedModeRow(
                    title: language.localized("散布方式"),
                    selectedTitle: store.brush.scatterMode.localizedTitle(language)
                ) {
                    Picker(language.localized("散布方式"), selection: $store.brush.scatterMode) {
                        ForEach(BrushScatterMode.allCases) { mode in
                            Text(mode.localizedTitle(language)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                sliderRow(title: language.localized("横散布"), value: "\(Int(store.brush.scatterLateral * 100))%", slider: Slider(value: $store.brush.scatterLateral, in: 0.0...0.6))
                sliderRow(title: language.localized("前後散布"), value: "\(Int(store.brush.scatterLinear * 100))%", slider: Slider(value: $store.brush.scatterLinear, in: 0.0...0.4))
                sliderRow(title: language.localized("散布数"), value: "\(Int(store.brush.count.rounded()))", slider: Slider(value: $store.brush.count, in: 1...4, step: 1))
                sliderRow(title: language.localized("数ジッター"), value: "\(Int(store.brush.countJitter * 100))%", slider: Slider(value: $store.brush.countJitter, in: 0.0...1.0))
                sliderRow(title: language.localized("粒サイズばらつき"), value: "\(Int(store.brush.countSizeJitter * 100))%", slider: Slider(value: $store.brush.countSizeJitter, in: 0.0...1.0))
                sliderRow(title: language.localized("粒濃度ばらつき"), value: "\(Int(store.brush.countOpacityJitter * 100))%", slider: Slider(value: $store.brush.countOpacityJitter, in: 0.0...1.0))
            }
        }
    }

    func strokeControls(proxy: GeometryProxy) -> some View {
        Group {
            sectionLabel("Transfer")
            sliderRow(title: language.localized("不透明"), value: "\(Int(store.brush.opacity * 100))%", slider: Slider(value: $store.brush.opacity, in: 0.1...1.0), isFullHeight: true, proxy: proxy)
            dynamicControlMenuRow(
                title: language.localized("不透明度コントロール"),
                selection: opacityControlBinding,
                allowed: [.off, .pressure]
            )
            sliderRow(title: language.localized("不透明度量"), value: "\(Int(opacityAmountBinding.wrappedValue * 100))%", slider: Slider(value: opacityAmountBinding, in: 0.0...1.0))
            sliderRow(
                title: language.localized("Speed Opacity"),
                value: "\(Int(speedOpacityAmountBinding.wrappedValue.rounded()))",
                slider: Slider(value: speedOpacityAmountBinding, in: 0...200, step: 1)
            )
            sliderRow(title: language.localized("フロー"), value: "\(Int(store.brush.flow * 100))%", slider: Slider(value: $store.brush.flow, in: 0.05...1.0))
            dynamicControlMenuRow(
                title: language.localized("フローコントロール"),
                selection: flowControlBinding,
                allowed: [.off, .pressure, .random]
            )
            sliderRow(title: language.localized("フロー量"), value: "\(Int(flowAmountBinding.wrappedValue * 100))%", slider: Slider(value: flowAmountBinding, in: 0.0...1.0))
            sliderRow(title: language.localized("手ぶれ補正"), value: "\(Int(store.brush.stabilization * 100))%", slider: Slider(value: $store.brush.stabilization, in: 0.0...1.0))
        }
    }

    func textureControls() -> some View {
        Group {
            sectionLabel(language.localized("Texture"))
            segmentedModeRow(
                title: language.localized("テクスチャ適用"),
                selectedTitle: store.brush.textureMode.localizedTitle(language)
            ) {
                Picker(language.localized("テクスチャ適用"), selection: $store.brush.textureMode) {
                    ForEach(BrushTextureMode.allCases) { mode in
                        Text(mode.localizedTitle(language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            sliderRow(title: language.localized("先端テクスチャ"), value: "\(Int(store.brush.textureStrength * 100))%", slider: Slider(value: $store.brush.textureStrength, in: 0.0...1.0))
            segmentedModeRow(
                title: language.localized("油彩ライブプレビュー"),
                selectedTitle: store.ui.oilLivePreviewQuality.localizedTitle(language)
            ) {
                Picker(language.localized("油彩ライブプレビュー"), selection: $store.ui.oilLivePreviewQuality) {
                    ForEach(OilLivePreviewQuality.allCases) { quality in
                        Text(quality.localizedTitle(language)).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
            }
            segmentedModeRow(
                title: language.localized("Color Smudge"),
                selectedTitle: store.brush.smudgeEngineEnabled ? store.brush.smudgeMode.localizedTitle(language) : language.localized("オフ")
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $store.brush.smudgeEngineEnabled) {
                        Text(language.localized("Enable Color Smudge"))
                            .font(StudioTheme.Typography.label(11))
                            .foregroundStyle(usesLightPanelTheme ? Color.black.opacity(0.8) : .white.opacity(0.86))
                    }
                    .toggleStyle(.switch)

                    if store.brush.smudgeEngineEnabled {
                        Picker(language.localized("Smudge Mode"), selection: $store.brush.smudgeMode) {
                            ForEach(BrushSmudgeMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        sliderRow(
                            title: language.localized("Smudge Length"),
                            value: "\(Int(store.brush.smudgeLength * 100))%",
                            slider: Slider(value: $store.brush.smudgeLength, in: 0.0...1.0)
                        )
                        sliderRow(
                            title: language.localized("Color Rate"),
                            value: "\(Int(store.brush.colorRate * 100))%",
                            slider: Slider(value: $store.brush.colorRate, in: 0.0...1.0)
                        )
                        sliderRow(
                            title: language.localized("Smudge Radius"),
                            value: "\(Int(store.brush.smudgeRadius * 100))%",
                            slider: Slider(value: $store.brush.smudgeRadius, in: 0.0...1.0)
                        )
                        sliderRow(
                            title: language.localized("Mix Pressure"),
                            value: "\(Int(store.brush.loadPressureSensitivity * 100))%",
                            slider: Slider(value: $store.brush.loadPressureSensitivity, in: 0.0...1.0)
                        )
                    }
                }
            }
            segmentedModeRow(
                title: language.localized("デュアルブラシ"),
                selectedTitle: store.brush.dualEnabled ? store.brush.dualBlendMode.localizedTitle(language) : language.localized("オフ")
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $store.brush.dualEnabled) {
                        Text(language.localized("デュアルブラシを使う"))
                            .font(StudioTheme.Typography.label(11))
                            .foregroundStyle(usesLightPanelTheme ? Color.black.opacity(0.8) : .white.opacity(0.86))
                    }
                    .toggleStyle(.switch)

                    if store.brush.dualEnabled {
                        Picker(language.localized("デュアル先端"), selection: $store.brush.dualTipKind) {
                            ForEach(BrushTipKind.allCases) { tipKind in
                                Text(tipKind.localizedTitle(language)).tag(tipKind)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker(language.localized("合成"), selection: $store.brush.dualBlendMode) {
                            ForEach(BrushDualBlendMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        sliderRow(title: language.localized("デュアルサイズ"), value: "\(Int(store.brush.dualScale * 100))%", slider: Slider(value: $store.brush.dualScale, in: 0.25...1.5))
                        sliderRow(title: language.localized("デュアル間隔"), value: "\(Int(store.brush.dualSpacing * 100))%", slider: Slider(value: $store.brush.dualSpacing, in: 0.0...0.8))
                        sliderRow(title: language.localized("デュアル散布"), value: "\(Int(store.brush.dualScatter * 100))%", slider: Slider(value: $store.brush.dualScatter, in: 0.0...0.8))
                        sliderRow(title: language.localized("デュアル角度"), value: "\(Int((store.brush.dualAngle * 180 / .pi).rounded()))°", slider: Slider(value: $store.brush.dualAngle, in: -.pi / 2 ... .pi / 2))
                    }
                }
            }
            segmentedModeRow(
                title: language.localized("用紙テクスチャ"),
                selectedTitle: "\(Int(store.brush.paperStrength * 100))%"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    sliderRow(title: language.localized("用紙の強さ"), value: "\(Int(store.brush.paperStrength * 100))%", slider: Slider(value: $store.brush.paperStrength, in: 0.0...1.0))
                    sliderRow(title: language.localized("紙目スケール"), value: String(format: "%.2f", store.brush.paperScale), slider: Slider(value: $store.brush.paperScale, in: 0.04...0.30))
                    sliderRow(title: language.localized("紙目しきい値"), value: "\(Int(store.brush.paperThreshold * 100))%", slider: Slider(value: $store.brush.paperThreshold, in: 0.15...0.75))
                    sliderRow(title: language.localized("粒状感"), value: String(format: "%.2f", store.brush.grainScale), slider: Slider(value: $store.brush.grainScale, in: 0.6...2.8))
                    sliderRow(title: language.localized("粒コントラスト"), value: String(format: "%.2f", store.brush.grainContrast), slider: Slider(value: $store.brush.grainContrast, in: 0.8...2.8))
                }
            }
        }
    }
}

private struct PaletteTextEditor: UIViewRepresentable {
    @Binding var text: String
    let textColor: UIColor
    let fontSize: CGFloat
    let backgroundColor: UIColor

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.spellCheckingType = .yes
        textView.text = text
        textView.textColor = textColor
        textView.font = .systemFont(ofSize: fontSize)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.textColor = textColor
        uiView.backgroundColor = backgroundColor
        uiView.font = .systemFont(ofSize: fontSize)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }
    }
}
