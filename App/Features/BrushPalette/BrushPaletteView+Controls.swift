import SwiftUI
import UIKit

extension BrushPaletteView {
    func controlsCard(proxy: GeometryProxy, showsChrome: Bool, showsCategoryPicker: Bool = true) -> some View {
        cardContainer(showsChrome: showsChrome) {
            VStack(alignment: .leading, spacing: 10) {
                if currentTool == .fill {
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
                        slider: Slider(value: $store.brush.radius, in: 2...96, step: 1)
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
                } else if currentTool == .move {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(hasSelection ? language.localized("Apple Pencil で選択範囲を移動します。適用するまで確定されません。") : language.localized("Apple Pencil でアクティブレイヤーを移動します。適用するまで確定されません。"))
                            .font(StudioTheme.Typography.body(11))
                            .foregroundStyle(usesLightPanelTheme ? Color.black.opacity(0.56) : .white.opacity(0.62))

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
            sliderRow(title: language.localized("サイズ"), value: "\(Int(store.brush.radius)) px", slider: Slider(value: $store.brush.radius, in: 1...100), isFullHeight: true, proxy: proxy)
            dynamicControlMenuRow(
                title: language.localized("サイズコントロール"),
                selection: sizeControlBinding,
                allowed: [.off, .pressure, .speed]
            )
            sliderRow(title: language.localized("サイズ量"), value: "\(Int(sizeAmountBinding.wrappedValue * 100))%", slider: Slider(value: sizeAmountBinding, in: 0.0...1.0))
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
            sliderRow(title: language.localized("フロー"), value: "\(Int(store.brush.flow * 100))%", slider: Slider(value: $store.brush.flow, in: 0.05...1.0))
            dynamicControlMenuRow(
                title: language.localized("フローコントロール"),
                selection: flowControlBinding,
                allowed: [.off, .pressure, .random]
            )
            sliderRow(title: language.localized("フロー量"), value: "\(Int(flowAmountBinding.wrappedValue * 100))%", slider: Slider(value: flowAmountBinding, in: 0.0...1.0))
            segmentedModeRow(
                title: language.localized("速度で濃さを変える"),
                selectedTitle: store.brush.velocityInfluence > 0.001 ? language.localized("オン") : language.localized("オフ")
            ) {
                Picker(language.localized("速度で濃さを変える"), selection: velocityDensityControlBinding) {
                    Text(language.localized("オフ")).tag(false)
                    Text(language.localized("オン")).tag(true)
                }
                .pickerStyle(.segmented)
            }
            sliderRow(title: language.localized("手ぶれ補正"), value: "\(Int(store.brush.stabilization * 100))%", slider: Slider(value: $store.brush.stabilization, in: 0.0...1.0))
        }
    }

    func textureControls() -> some View {
        Group {
            sectionLabel("Texture")
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
                title: language.localized("ミキサーブラシ"),
                selectedTitle: "Wet / Load / Mix / Flow"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    sliderRow(title: language.localized("ウェット"), value: "\(Int(store.brush.wetness * 100))%", slider: Slider(value: $store.brush.wetness, in: 0.0...1.0))
                    dynamicControlMenuRow(
                        title: language.localized("ウェットコントロール"),
                        selection: wetnessControlBinding,
                        allowed: [.off, .pressure]
                    )
                    sliderRow(title: language.localized("ウェット量"), value: "\(Int(wetnessAmountBinding.wrappedValue * 100))%", slider: Slider(value: wetnessAmountBinding, in: 0.0...1.0))
                    sliderRow(title: language.localized("混色量"), value: "\(Int(store.brush.colorMixStrength * 100))%", slider: Slider(value: $store.brush.colorMixStrength, in: 0.0...1.0))
                    sliderRow(title: language.localized("色の含み"), value: "\(Int(store.brush.paintLoad * 100))%", slider: Slider(value: $store.brush.paintLoad, in: 0.0...1.0))
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
