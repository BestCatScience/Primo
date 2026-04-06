import SwiftUI
import UIKit

extension BrushPaletteView {
    func controlsCard(proxy: GeometryProxy, showsChrome: Bool, showsCategoryPicker: Bool = true) -> some View {
        cardContainer(showsChrome: showsChrome) {
            VStack(alignment: .leading, spacing: 10) {
                if currentTool == .fill {
                    segmentedModeRow(
                        title: language.localized("しきい値モード"),
                        selectedTitle: store.fillThresholdMode.localizedTitle(language)
                    ) {
                        Picker(language.localized("しきい値モード"), selection: $store.fillThresholdMode) {
                            ForEach(FillThresholdMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    sliderRow(
                        title: store.fillThresholdMode == .opacity ? language.localized("不透明度しきい値") : language.localized("色しきい値"),
                        value: "\(Int((store.fillThresholdMode == .opacity ? store.fillOpacityTolerance : store.fillColorTolerance) * 100))%",
                        slider: Group {
                            if store.fillThresholdMode == .opacity {
                                Slider(value: $store.fillOpacityTolerance, in: 0.0...1.0)
                            } else {
                                Slider(value: $store.fillColorTolerance, in: 0.0...1.0)
                            }
                        }
                    )
                    sliderRow(
                        title: language.localized("拡張"),
                        value: "\(Int(store.fillExpansion)) px",
                        slider: Slider(value: $store.fillExpansion, in: 0...24, step: 1)
                    )
                } else if currentTool == .eyedropper {
                    segmentedModeRow(
                        title: language.localized("取得元"),
                        selectedTitle: store.eyedropperSamplingSource.localizedTitle(language)
                    ) {
                        Picker(language.localized("取得元"), selection: $store.eyedropperSamplingSource) {
                            ForEach(EyedropperSamplingSource.allCases) { source in
                                Text(source.localizedTitle(language)).tag(source)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Text(language.localized("Apple Pencil でタップまたはドラッグすると色を取得して現在色に反映します。"))
                        .font(StudioTheme.Typography.body(11))
                        .foregroundStyle(.white.opacity(0.62))
                } else if currentTool == .select {
                    segmentedModeRow(
                        title: language.localized("選択アクション"),
                        selectedTitle: store.selectionCombineMode.localizedTitle(language)
                    ) {
                        Picker(language.localized("選択アクション"), selection: $store.selectionCombineMode) {
                            ForEach(SelectionCombineMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    segmentedModeRow(
                        title: language.localized("選択モード"),
                        selectedTitle: store.selectionToolMode.localizedTitle(language)
                    ) {
                        Picker(language.localized("選択モード"), selection: $store.selectionToolMode) {
                            ForEach(SelectionToolMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    if store.selectionToolMode == .auto {
                        segmentedModeRow(
                            title: language.localized("しきい値モード"),
                            selectedTitle: store.selectionThresholdMode.localizedTitle(language)
                        ) {
                            Picker(language.localized("選択しきい値モード"), selection: $store.selectionThresholdMode) {
                                ForEach(FillThresholdMode.allCases) { mode in
                                    Text(mode.localizedTitle(language)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        sliderRow(
                            title: store.selectionThresholdMode == .opacity ? language.localized("不透明度しきい値") : language.localized("色しきい値"),
                            value: "\(Int((store.selectionThresholdMode == .opacity ? store.selectionOpacityTolerance : store.selectionColorTolerance) * 100))%",
                            slider: Group {
                                if store.selectionThresholdMode == .opacity {
                                    Slider(value: $store.selectionOpacityTolerance, in: 0.0...1.0)
                                } else {
                                    Slider(value: $store.selectionColorTolerance, in: 0.0...1.0)
                                }
                            }
                        )
                        sliderRow(
                            title: language.localized("拡張"),
                            value: "\(Int(store.selectionExpansion)) px",
                            slider: Slider(value: $store.selectionExpansion, in: 0...24, step: 1)
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
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(StudioTheme.Palette.cardFillStrong)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                } else if currentTool == .move {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(hasSelection ? language.localized("Apple Pencil で選択範囲を移動します。適用するまで確定されません。") : language.localized("Apple Pencil でアクティブレイヤーを移動します。適用するまで確定されません。"))
                            .font(StudioTheme.Typography.body(11))
                            .foregroundStyle(.white.opacity(0.62))

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
                                .foregroundStyle(.white.opacity(0.88))
                                .padding(.horizontal, 12)
                                .frame(minHeight: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(StudioTheme.Palette.cardFillStrong)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
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
                selectedTitle: store.brushTipKind.localizedTitle(language)
            ) {
                VStack(spacing: 8) {
                    ForEach(BrushTipKind.allCases) { tipKind in
                        brushTipButton(tipKind: tipKind, isSelected: store.brushTipKind == tipKind) {
                            store.brushTipKind = tipKind
                        }
                    }
                }
            }
            sliderRow(title: language.localized("サイズ"), value: "\(Int(store.brushRadius)) px", slider: Slider(value: $store.brushRadius, in: 1...100), isFullHeight: true, proxy: proxy)
            dynamicControlMenuRow(
                title: language.localized("サイズコントロール"),
                selection: sizeControlBinding,
                allowed: [.off, .pressure, .speed]
            )
            sliderRow(title: language.localized("サイズ量"), value: "\(Int(sizeAmountBinding.wrappedValue * 100))%", slider: Slider(value: sizeAmountBinding, in: 0.0...1.0))
            sliderRow(title: language.localized("形状の細さ"), value: "\(Int(store.brushRoundness * 100))%", slider: Slider(value: $store.brushRoundness, in: 0.2...1.0))
            dynamicControlMenuRow(
                title: language.localized("形状コントロール"),
                selection: roundnessControlBinding,
                allowed: [.off, .pressure, .tilt, .random]
            )
            sliderRow(title: language.localized("形状量"), value: "\(Int(roundnessAmountBinding.wrappedValue * 100))%", slider: Slider(value: roundnessAmountBinding, in: 0.0...1.0))
            segmentedModeRow(
                title: language.localized("回転モード"),
                selectedTitle: store.brushAngleMode.localizedTitle(language)
            ) {
                Picker(language.localized("回転モード"), selection: $store.brushAngleMode) {
                    ForEach(BrushAngleMode.allCases) { mode in
                        Text(mode.localizedTitle(language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            sliderRow(title: language.localized("角度"), value: "\(Int((store.brushAngle * 180 / .pi).rounded()))°", slider: Slider(value: $store.brushAngle, in: -.pi / 2 ... .pi / 2))
            dynamicControlMenuRow(
                title: language.localized("角度コントロール"),
                selection: angleControlBinding,
                allowed: [.off, .pressure, .tilt, .random]
            )
            sliderRow(title: language.localized("角度量"), value: "\(Int(angleAmountBinding.wrappedValue * 100))%", slider: Slider(value: angleAmountBinding, in: 0.0...1.0))
            sliderRow(title: language.localized("硬さ"), value: "\(Int(store.brushHardness * 100))%", slider: Slider(value: $store.brushHardness, in: 0.2...0.98))
        }
    }

    func scatterControls() -> some View {
        Group {
            sectionLabel("Scattering")
            Toggle(isOn: $store.brushScatterEnabled) {
                Text(language.localized("散布を有効にする"))
                    .font(StudioTheme.Typography.title(12))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .tint(StudioTheme.Palette.accentBright)
            sliderRow(title: language.localized("スタンプ間隔"), value: "\(Int(store.brushSpacing * 100))%", slider: Slider(value: $store.brushSpacing, in: 0.08...0.8))
            if store.brushScatterEnabled {
                sliderRow(title: language.localized("間隔ジッター"), value: "\(Int(store.brushSpacingJitter * 100))%", slider: Slider(value: $store.brushSpacingJitter, in: 0.0...0.5))
                segmentedModeRow(
                    title: language.localized("散布方式"),
                    selectedTitle: store.brushScatterMode.localizedTitle(language)
                ) {
                    Picker(language.localized("散布方式"), selection: $store.brushScatterMode) {
                        ForEach(BrushScatterMode.allCases) { mode in
                            Text(mode.localizedTitle(language)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                sliderRow(title: language.localized("横散布"), value: "\(Int(store.brushScatterLateral * 100))%", slider: Slider(value: $store.brushScatterLateral, in: 0.0...0.6))
                sliderRow(title: language.localized("前後散布"), value: "\(Int(store.brushScatterLinear * 100))%", slider: Slider(value: $store.brushScatterLinear, in: 0.0...0.4))
                sliderRow(title: language.localized("散布数"), value: "\(Int(store.brushCount.rounded()))", slider: Slider(value: $store.brushCount, in: 1...4, step: 1))
                sliderRow(title: language.localized("数ジッター"), value: "\(Int(store.brushCountJitter * 100))%", slider: Slider(value: $store.brushCountJitter, in: 0.0...1.0))
                sliderRow(title: language.localized("粒サイズばらつき"), value: "\(Int(store.brushCountSizeJitter * 100))%", slider: Slider(value: $store.brushCountSizeJitter, in: 0.0...1.0))
                sliderRow(title: language.localized("粒濃度ばらつき"), value: "\(Int(store.brushCountOpacityJitter * 100))%", slider: Slider(value: $store.brushCountOpacityJitter, in: 0.0...1.0))
            }
        }
    }

    func strokeControls(proxy: GeometryProxy) -> some View {
        Group {
            sectionLabel("Transfer")
            sliderRow(title: language.localized("不透明"), value: "\(Int(store.brushOpacity * 100))%", slider: Slider(value: $store.brushOpacity, in: 0.1...1.0), isFullHeight: true, proxy: proxy)
            dynamicControlMenuRow(
                title: language.localized("不透明度コントロール"),
                selection: opacityControlBinding,
                allowed: [.off, .pressure]
            )
            sliderRow(title: language.localized("不透明度量"), value: "\(Int(opacityAmountBinding.wrappedValue * 100))%", slider: Slider(value: opacityAmountBinding, in: 0.0...1.0))
            sliderRow(title: language.localized("フロー"), value: "\(Int(store.brushFlow * 100))%", slider: Slider(value: $store.brushFlow, in: 0.05...1.0))
            dynamicControlMenuRow(
                title: language.localized("フローコントロール"),
                selection: flowControlBinding,
                allowed: [.off, .pressure, .random]
            )
            sliderRow(title: language.localized("フロー量"), value: "\(Int(flowAmountBinding.wrappedValue * 100))%", slider: Slider(value: flowAmountBinding, in: 0.0...1.0))
            segmentedModeRow(
                title: language.localized("速度で濃さを変える"),
                selectedTitle: store.brushVelocityInfluence > 0.001 ? language.localized("オン") : language.localized("オフ")
            ) {
                Picker(language.localized("速度で濃さを変える"), selection: velocityDensityControlBinding) {
                    Text(language.localized("オフ")).tag(false)
                    Text(language.localized("オン")).tag(true)
                }
                .pickerStyle(.segmented)
            }
            sliderRow(title: language.localized("手ぶれ補正"), value: "\(Int(store.brushStabilization * 100))%", slider: Slider(value: $store.brushStabilization, in: 0.0...1.0))
        }
    }

    func textureControls() -> some View {
        Group {
            sectionLabel("Texture")
            segmentedModeRow(
                title: language.localized("テクスチャ適用"),
                selectedTitle: store.brushTextureMode.localizedTitle(language)
            ) {
                Picker(language.localized("テクスチャ適用"), selection: $store.brushTextureMode) {
                    ForEach(BrushTextureMode.allCases) { mode in
                        Text(mode.localizedTitle(language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            sliderRow(title: language.localized("先端テクスチャ"), value: "\(Int(store.brushTextureStrength * 100))%", slider: Slider(value: $store.brushTextureStrength, in: 0.0...1.0))
            segmentedModeRow(
                title: language.localized("ミキサーブラシ"),
                selectedTitle: "Wet / Load / Mix / Flow"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    sliderRow(title: language.localized("ウェット"), value: "\(Int(store.brushWetness * 100))%", slider: Slider(value: $store.brushWetness, in: 0.0...1.0))
                    dynamicControlMenuRow(
                        title: language.localized("ウェットコントロール"),
                        selection: wetnessControlBinding,
                        allowed: [.off, .pressure]
                    )
                    sliderRow(title: language.localized("ウェット量"), value: "\(Int(wetnessAmountBinding.wrappedValue * 100))%", slider: Slider(value: wetnessAmountBinding, in: 0.0...1.0))
                    sliderRow(title: language.localized("混色量"), value: "\(Int(store.brushColorMixStrength * 100))%", slider: Slider(value: $store.brushColorMixStrength, in: 0.0...1.0))
                    sliderRow(title: language.localized("色の含み"), value: "\(Int(store.brushPaintLoad * 100))%", slider: Slider(value: $store.brushPaintLoad, in: 0.0...1.0))
                    dynamicControlMenuRow(
                        title: language.localized("含みコントロール"),
                        selection: loadControlBinding,
                        allowed: [.off, .pressure]
                    )
                    sliderRow(title: language.localized("含み量"), value: "\(Int(loadAmountBinding.wrappedValue * 100))%", slider: Slider(value: loadAmountBinding, in: 0.0...1.0))
                }
            }
            segmentedModeRow(
                title: language.localized("デュアルブラシ"),
                selectedTitle: store.brushDualEnabled ? store.brushDualBlendMode.localizedTitle(language) : language.localized("オフ")
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $store.brushDualEnabled) {
                        Text(language.localized("デュアルブラシを使う"))
                            .font(StudioTheme.Typography.label(11))
                            .foregroundStyle(.white.opacity(0.86))
                    }
                    .toggleStyle(.switch)

                    if store.brushDualEnabled {
                        Picker(language.localized("デュアル先端"), selection: $store.brushDualTipKind) {
                            ForEach(BrushTipKind.allCases) { tipKind in
                                Text(tipKind.localizedTitle(language)).tag(tipKind)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker(language.localized("合成"), selection: $store.brushDualBlendMode) {
                            ForEach(BrushDualBlendMode.allCases) { mode in
                                Text(mode.localizedTitle(language)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        sliderRow(title: language.localized("デュアルサイズ"), value: "\(Int(store.brushDualScale * 100))%", slider: Slider(value: $store.brushDualScale, in: 0.25...1.5))
                        sliderRow(title: language.localized("デュアル間隔"), value: "\(Int(store.brushDualSpacing * 100))%", slider: Slider(value: $store.brushDualSpacing, in: 0.0...0.8))
                        sliderRow(title: language.localized("デュアル散布"), value: "\(Int(store.brushDualScatter * 100))%", slider: Slider(value: $store.brushDualScatter, in: 0.0...0.8))
                        sliderRow(title: language.localized("デュアル角度"), value: "\(Int((store.brushDualAngle * 180 / .pi).rounded()))°", slider: Slider(value: $store.brushDualAngle, in: -.pi / 2 ... .pi / 2))
                    }
                }
            }
            segmentedModeRow(
                title: language.localized("紙質テクスチャ"),
                selectedTitle: "\(Int(store.brushPaperStrength * 100))%"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    sliderRow(title: language.localized("紙質の強さ"), value: "\(Int(store.brushPaperStrength * 100))%", slider: Slider(value: $store.brushPaperStrength, in: 0.0...1.0))
                    sliderRow(title: language.localized("紙目スケール"), value: String(format: "%.2f", store.brushPaperScale), slider: Slider(value: $store.brushPaperScale, in: 0.04...0.30))
                    sliderRow(title: language.localized("紙目しきい値"), value: "\(Int(store.brushPaperThreshold * 100))%", slider: Slider(value: $store.brushPaperThreshold, in: 0.15...0.75))
                    sliderRow(title: language.localized("粒状感"), value: String(format: "%.2f", store.brushGrainScale), slider: Slider(value: $store.brushGrainScale, in: 0.6...2.8))
                    sliderRow(title: language.localized("粒コントラスト"), value: String(format: "%.2f", store.brushGrainContrast), slider: Slider(value: $store.brushGrainContrast, in: 0.8...2.8))
                }
            }
        }
    }
}
