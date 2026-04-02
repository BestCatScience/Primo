import ComposableArchitecture
import SwiftUI

struct BrushPaletteView: View {
    @Bindable var store: StoreOf<BrushPaletteFeature>
    let currentTool: StudioToolKind
    let hasSelection: Bool
    let transformPreviewOffset: CGSize
    let language: AppLanguage
    var showsTitle = true
    private let paletteColumns = Array(repeating: GridItem(.fixed(22), spacing: 8), count: 5)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if showsTitle {
                    Text(panelTitle)
                        .font(StudioTheme.Typography.title(26))
                        .foregroundStyle(.white.opacity(0.94))
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel(sectionTitle)

                    if currentTool == .fill {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            store.brushColor.opacity(0.95),
                                            store.brushColor.opacity(0.32)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: "paintbrush.fill")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundStyle(StudioTheme.Palette.textPrimary)
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                metricRow(language == .japanese ? "しきい値" : "Threshold", value: store.fillThresholdMode.localizedTitle(language))
                                metricRow(
                                    store.fillThresholdMode == .opacity ? (language == .japanese ? "不透明度一致" : "Opacity Match") : (language == .japanese ? "色一致" : "Color Match"),
                                    value: "\(Int((store.fillThresholdMode == .opacity ? store.fillOpacityTolerance : store.fillColorTolerance) * 100))%"
                                )
                                metricRow(language == .japanese ? "拡張" : "Expansion", value: "\(Int(store.fillExpansion)) px")
                                metricRow(language == .japanese ? "色" : "Color", value: store.selectedBrush?.name ?? (language == .japanese ? "カスタム" : "Custom Mix"))
                            }
                        }
                    } else if currentTool == .select {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            StudioTheme.Palette.accent.opacity(0.95),
                                            StudioTheme.Palette.coolGlow.opacity(0.42)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: store.selectionToolMode == .lasso ? "lasso" : "wand.and.stars")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(StudioTheme.Palette.textPrimary)
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                metricRow(language == .japanese ? "モード" : "Mode", value: store.selectionToolMode.localizedTitle(language))
                                metricRow(language == .japanese ? "合成" : "Combine", value: store.selectionCombineMode.localizedTitle(language))
                                if store.selectionToolMode == .auto {
                                    metricRow(language == .japanese ? "しきい値" : "Threshold", value: store.selectionThresholdMode.localizedTitle(language))
                                    metricRow(
                                        language == .japanese ? "一致" : "Match",
                                        value: "\(Int((store.selectionThresholdMode == .opacity ? store.selectionOpacityTolerance : store.selectionColorTolerance) * 100))%"
                                    )
                                    metricRow(language == .japanese ? "拡張" : "Expansion", value: "\(Int(store.selectionExpansion)) px")
                                } else {
                                    metricRow(language == .japanese ? "入力" : "Gesture", value: language == .japanese ? "フリーハンド" : "Freehand")
                                    metricRow(language == .japanese ? "動作" : "Behavior", value: language == .japanese ? "パスを閉じる" : "Close Path")
                                    metricRow(language == .japanese ? "対象" : "Scope", value: language == .japanese ? "アクティブレイヤー" : "Active Layer")
                                }
                            }
                        }
                    } else if currentTool == .move {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            StudioTheme.Palette.coolGlow.opacity(0.9),
                                            StudioTheme.Palette.accent.opacity(0.45)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: hasSelection ? "selection.pin.in.out" : "square.stack.3d.up")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(StudioTheme.Palette.textPrimary)
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                metricRow(language == .japanese ? "対象" : "Target", value: hasSelection ? (language == .japanese ? "選択範囲" : "Selection") : (language == .japanese ? "レイヤー" : "Layer"))
                                metricRow("Offset X", value: "\(Int(transformPreviewOffset.width.rounded())) px")
                                metricRow("Offset Y", value: "\(Int(transformPreviewOffset.height.rounded())) px")
                                metricRow(language == .japanese ? "状態" : "State", value: transformPreviewOffset == .zero ? (language == .japanese ? "待機" : "Idle") : (language == .japanese ? "未確定" : "Pending"))
                            }
                        }
                    } else {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            store.brushColor.opacity(0.95),
                                            store.brushColor.opacity(0.32)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Circle()
                                        .fill(StudioTheme.Palette.textPrimary)
                                        .frame(
                                            width: min(58, max(10, store.brushRadius * 3.4)),
                                            height: min(58, max(10, store.brushRadius * 3.4))
                                        )
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                metricRow(language == .japanese ? "先端" : "Tip", value: store.brushTipKind.localizedTitle(language))
                                metricRow(language == .japanese ? "半径" : "Radius", value: "\(Int(store.brushRadius)) px")
                                metricRow(language == .japanese ? "不透明度" : "Opacity", value: "\(Int(store.brushOpacity * 100))%")
                                metricRow(language == .japanese ? "硬さ" : "Hardness", value: "\(Int(store.brushHardness * 100))%")
                                metricRow(language == .japanese ? "筆圧" : "Pressure", value: store.brushPressureSensitivity < 0.6 ? (language == .japanese ? "弱め" : "Soft") : store.brushPressureSensitivity > 1.2 ? (language == .japanese ? "強め" : "Hard") : (language == .japanese ? "標準" : "Medium"))
                                metricRow(language == .japanese ? "手ぶれ補正" : "Stabilization", value: "\(Int(store.brushStabilization * 100))%")
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    if currentTool == .fill {
                        segmentedModeRow(
                            title: language == .japanese ? "しきい値モード" : "Threshold Mode",
                            selectedTitle: store.fillThresholdMode.localizedTitle(language)
                        ) {
                            Picker(language == .japanese ? "しきい値モード" : "Threshold Mode", selection: $store.fillThresholdMode) {
                                ForEach(FillThresholdMode.allCases) { mode in
                                    Text(mode.localizedTitle(language)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        sliderRow(
                            title: store.fillThresholdMode == .opacity ? (language == .japanese ? "不透明度しきい値" : "Opacity Threshold") : (language == .japanese ? "色しきい値" : "Color Threshold"),
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
                            title: language == .japanese ? "拡張" : "Expansion",
                            value: "\(Int(store.fillExpansion)) px",
                            slider: Slider(value: $store.fillExpansion, in: 0...24, step: 1)
                        )
                    } else if currentTool == .select {
                        segmentedModeRow(
                            title: language == .japanese ? "選択アクション" : "Selection Action",
                            selectedTitle: store.selectionCombineMode.localizedTitle(language)
                        ) {
                            Picker(language == .japanese ? "選択アクション" : "Selection Action", selection: $store.selectionCombineMode) {
                                ForEach(SelectionCombineMode.allCases) { mode in
                                    Text(mode.localizedTitle(language)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        segmentedModeRow(
                            title: language == .japanese ? "選択モード" : "Selection Mode",
                            selectedTitle: store.selectionToolMode.localizedTitle(language)
                        ) {
                            Picker(language == .japanese ? "選択モード" : "Selection Mode", selection: $store.selectionToolMode) {
                                ForEach(SelectionToolMode.allCases) { mode in
                                    Text(mode.localizedTitle(language)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        if store.selectionToolMode == .auto {
                            segmentedModeRow(
                                title: language == .japanese ? "しきい値モード" : "Threshold Mode",
                                selectedTitle: store.selectionThresholdMode.localizedTitle(language)
                            ) {
                                Picker(language == .japanese ? "選択しきい値モード" : "Selection Threshold Mode", selection: $store.selectionThresholdMode) {
                                    ForEach(FillThresholdMode.allCases) { mode in
                                        Text(mode.localizedTitle(language)).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            sliderRow(
                                title: store.selectionThresholdMode == .opacity ? (language == .japanese ? "不透明度しきい値" : "Opacity Threshold") : (language == .japanese ? "色しきい値" : "Color Threshold"),
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
                                title: language == .japanese ? "拡張" : "Expansion",
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
                                Text(language == .japanese ? "選択を解除" : "Clear Selection")
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
                            Text(hasSelection ? (language == .japanese ? "Apple Pencil で選択範囲を移動します。適用するまで確定されません。" : "Move the selected area with Pencil. Nothing is committed until you apply.") : (language == .japanese ? "Apple Pencil でアクティブレイヤーを移動します。適用するまで確定されません。" : "Move the active layer with Pencil. Nothing is committed until you apply."))
                                .font(StudioTheme.Typography.body(11))
                                .foregroundStyle(.white.opacity(0.62))

                            HStack(spacing: 8) {
                                Button {
                                    store.send(.applyTransformButtonTapped)
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(language == .japanese ? "適用" : "Apply")
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
                                        Text(language == .japanese ? "キャンセル" : "Cancel")
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
                        segmentedModeRow(
                            title: language == .japanese ? "ブラシ先端" : "Brush Tip",
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
                        sliderRow(title: language == .japanese ? "サイズ" : "Size", value: "\(Int(store.brushRadius)) px", slider: Slider(value: $store.brushRadius, in: 1...100))
                        sliderRow(title: language == .japanese ? "不透明度" : "Opacity", value: "\(Int(store.brushOpacity * 100))%", slider: Slider(value: $store.brushOpacity, in: 0.1...1.0))
                        sliderRow(title: language == .japanese ? "硬さ" : "Hardness", value: "\(Int(store.brushHardness * 100))%", slider: Slider(value: $store.brushHardness, in: 0.2...0.98))
                        sliderRow(title: language == .japanese ? "筆圧" : "Pressure", value: store.brushPressureSensitivity < 0.6 ? (language == .japanese ? "弱め" : "Soft") : store.brushPressureSensitivity > 1.2 ? (language == .japanese ? "強め" : "Hard") : (language == .japanese ? "標準" : "Medium"), slider: Slider(value: $store.brushPressureSensitivity, in: 0.1...2.0))
                        sliderRow(title: language == .japanese ? "手ぶれ補正" : "Stabilization", value: "\(Int(store.brushStabilization * 100))%", slider: Slider(value: $store.brushStabilization, in: 0.0...1.0))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(StudioTheme.Palette.cardFill)
                )

                if currentTool != .select && currentTool != .move {
                    VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            StudioTheme.Palette.textPrimary,
                                            Color.white.opacity(0.55)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(store.brushColor)
                                .padding(4)
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(currentTool == .fill ? (language == .japanese ? "塗り色" : "Fill Color") : (language == .japanese ? "ブラシと色" : "Brushes & Color"))
                                .font(StudioTheme.Typography.title(14))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(currentTool == .fill ? (store.selectedBrush?.name ?? (language == .japanese ? "カスタム" : "Custom Mix")) : (store.selectedBrush?.name ?? "\(store.brushTipKind.localizedTitle(language)) \(language == .japanese ? "カスタム" : "Custom")"))
                                .font(StudioTheme.Typography.body(11))
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer(minLength: 0)
                    }

                    ColorPicker("", selection: $store.brushColor, supportsOpacity: false)
                        .labelsHidden()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(StudioTheme.Palette.hairline)
                        )

                    if currentTool != .fill {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(store.presets) { preset in
                                    presetChip(
                                        preset: preset,
                                        isSelected: store.selectedBrush == preset
                                    ) {
                                        store.send(.selectPreset(preset))
                                    }
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }

                    LazyVGrid(columns: paletteColumns, alignment: .leading, spacing: 8) {
                        ForEach(store.presets) { preset in
                            colorSwatch(color: preset.color, isSelected: store.selectedBrush == preset) {
                                store.send(.selectPreset(preset))
                            }
                        }

                        ForEach(PaletteSwatch.defaults) { swatch in
                            colorSwatch(color: swatch.color, isSelected: false) {
                                store.send(.binding(.set(\.brushColor, swatch.color)))
                            }
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(StudioTheme.Palette.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(store.transparentPaper ? StudioTheme.Palette.cardFillStrong : store.paperColor)

                            Image(systemName: store.transparentPaper ? "square.dashed" : "doc.richtext")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(language == .japanese ? "用紙" : "Paper")
                                .font(StudioTheme.Typography.title(14))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(store.transparentPaper ? (language == .japanese ? "透明背景" : "Transparent background") : (language == .japanese ? "カスタム用紙色" : "Custom paper color"))
                                .font(StudioTheme.Typography.body(11))
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer(minLength: 0)
                    }

                    Toggle(isOn: $store.transparentPaper) {
                        Text(language == .japanese ? "透明な用紙" : "Transparent Paper")
                            .font(StudioTheme.Typography.title(12))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .tint(StudioTheme.Palette.accentBright)

                    ColorPicker(language == .japanese ? "用紙の色" : "Paper Color", selection: $store.paperColor, supportsOpacity: false)
                        .font(StudioTheme.Typography.title(12))
                        .foregroundStyle(.white.opacity(0.88))
                        .disabled(store.transparentPaper)
                        .opacity(store.transparentPaper ? 0.45 : 1.0)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(StudioTheme.Palette.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                StudioTheme.Palette.accent,
                                                StudioTheme.Palette.coolGlow
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )

                                Image(systemName: "selection.pin.in.out")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.92))
                            }
                            .frame(width: 38, height: 38)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(language == .japanese ? "選択" : "Selection")
                                    .font(StudioTheme.Typography.title(14))
                                    .foregroundStyle(.white.opacity(0.9))
                                Text(store.selectionToolMode == .lasso ? (language == .japanese ? "Apple Pencil で囲んだあと、移動ツールで変形します" : "Trace with Pencil, then use Move to transform") : (language == .japanese ? "タップで選択したあと、移動ツールで変形します" : "Tap to sample, then use Move to transform"))
                                    .font(StudioTheme.Typography.body(11))
                                    .foregroundStyle(.white.opacity(0.52))
                            }

                            Spacer(minLength: 0)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(StudioTheme.Palette.cardFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                    )
                }

            }
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var panelTitle: String {
        switch currentTool {
        case .fill:
            return currentTool.localizedTitle(language)
        case .select:
            return currentTool.localizedTitle(language)
        case .move:
            return currentTool.localizedTitle(language)
        default:
            return StudioToolKind.brush.localizedTitle(language)
        }
    }

    private var sectionTitle: String {
        switch currentTool {
        case .fill:
            return language == .japanese ? "塗りつぶし設定" : "Fill Engine"
        case .select:
            return language == .japanese ? "選択設定" : "Selection"
        case .move:
            return language == .japanese ? "変形" : "Transform"
        default:
            return language == .japanese ? "ブラシ設定" : "Brush Engine"
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(StudioTheme.Typography.mono(10))
            .foregroundStyle(.white.opacity(0.48))
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(.white.opacity(0.48))
            Spacer()
            Text(value)
                .font(StudioTheme.Typography.title(12))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private func sliderRow<SliderView: View>(title: String, value: String, slider: SliderView) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(StudioTheme.Typography.title(12))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Text(value)
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            slider
                .tint(StudioTheme.Palette.accentBright)
                .frame(minHeight: 38)
                .contentShape(Rectangle())
        }
    }

    private func segmentedModeRow<Content: View>(
        title: String,
        selectedTitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(StudioTheme.Typography.title(12))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Text(selectedTitle)
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            content()
                .frame(minHeight: 32)
        }
    }

    private func colorSwatch(color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.95), lineWidth: 1.5)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.95 : 0.16), lineWidth: isSelected ? 2.5 : 1)
                        .padding(isSelected ? -4 : -2)
                )
        }
        .buttonStyle(.plain)
        .minimumHitTarget()
    }

    private func presetChip(preset: BrushPreset, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(preset.color.opacity(0.95))
                    Image(systemName: preset.tipKind.systemImage)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(StudioTheme.Typography.label(11))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(preset.tipKind.localizedTitle(language))
                        .font(StudioTheme.Typography.mono(9))
                        .foregroundStyle(.white.opacity(0.46))
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? StudioTheme.Palette.accent.opacity(0.28) : StudioTheme.Palette.hairline)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? StudioTheme.Palette.accent : StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension BrushPaletteView {
    func brushTipButton(tipKind: BrushTipKind, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tipKind.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)

                Text(tipKind.localizedTitle(language))
                    .font(StudioTheme.Typography.label(11))

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white.opacity(isSelected ? 0.96 : 0.82))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? StudioTheme.Palette.accent.opacity(0.28) : StudioTheme.Palette.hairline)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? StudioTheme.Palette.accent : StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PaletteSwatch: Identifiable {
    let id: String
    let color: Color

    static let defaults: [PaletteSwatch] = [
        PaletteSwatch(id: "graphite", color: Color(red: 0.14, green: 0.15, blue: 0.18)),
        PaletteSwatch(id: "ruby", color: Color(red: 0.77, green: 0.23, blue: 0.26)),
        PaletteSwatch(id: "amber", color: Color(red: 0.89, green: 0.61, blue: 0.18)),
        PaletteSwatch(id: "moss", color: Color(red: 0.34, green: 0.55, blue: 0.29)),
        PaletteSwatch(id: "lagoon", color: Color(red: 0.19, green: 0.55, blue: 0.72)),
        PaletteSwatch(id: "violet", color: Color(red: 0.49, green: 0.37, blue: 0.76)),
        PaletteSwatch(id: "rose", color: Color(red: 0.86, green: 0.46, blue: 0.59))
    ]
}
