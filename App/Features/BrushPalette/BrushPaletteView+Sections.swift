import SwiftUI
import UIKit

extension BrushPaletteView {
    var showsBrushLibrarySidebar: Bool {
        currentTool == .brush || currentTool == .erase
    }

    func settingsPanelContent(proxy: GeometryProxy, showHeaderTitle: Bool) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if showHeaderTitle {
                    Text(panelTitle)
                        .font(StudioTheme.Typography.title(26))
                        .foregroundStyle(.white.opacity(0.94))
                }

                headerCard(showsChrome: true)
                controlsCard(proxy: proxy, showsChrome: true)
                detailCard(showsChrome: true)
            }
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: proxy.size.height)
    }

    func headerCard(showsChrome: Bool) -> some View {
        cardContainer(showsChrome: showsChrome) {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel(sectionTitle)

                if currentTool == .fill {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                            metricRow(language.localized("しきい値"), value: store.fillThresholdMode.localizedTitle(language))
                            metricRow(
                                store.fillThresholdMode == .opacity ? language.localized("不透明度一致") : language.localized("色一致"),
                                value: "\(Int((store.fillThresholdMode == .opacity ? store.fillOpacityTolerance : store.fillColorTolerance) * 100))%"
                            )
                            metricRow(language.localized("拡張"), value: "\(Int(store.fillExpansion)) px")
                            metricRow(language.localized("色"), value: store.selectedBrush?.name ?? language.localized("カスタム"))
                        }
                    }
                } else if currentTool == .eyedropper {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        store.brushColor.opacity(0.96),
                                        StudioTheme.Palette.coolGlow.opacity(0.34)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .overlay(
                                Image(systemName: "eyedropper")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(StudioTheme.Palette.textPrimary)
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            metricRow(language.localized("取得元"), value: store.eyedropperSamplingSource.localizedTitle(language))
                            metricRow(language.localized("現在色"), value: colorHexLabel)
                            metricRow(language.localized("入力"), value: "Apple Pencil")
                            metricRow(language.localized("動作"), value: language.localized("ドラッグで連続取得"))
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
                            metricRow(language.localized("モード"), value: store.selectionToolMode.localizedTitle(language))
                            metricRow(language.localized("合成"), value: store.selectionCombineMode.localizedTitle(language))
                            if store.selectionToolMode == .auto {
                                metricRow(language.localized("しきい値"), value: store.selectionThresholdMode.localizedTitle(language))
                                metricRow(
                                    language.localized("一致"),
                                    value: "\(Int((store.selectionThresholdMode == .opacity ? store.selectionOpacityTolerance : store.selectionColorTolerance) * 100))%"
                                )
                                metricRow(language.localized("拡張"), value: "\(Int(store.selectionExpansion)) px")
                            } else {
                                metricRow(language.localized("入力"), value: language.localized("フリーハンド"))
                                metricRow(language.localized("動作"), value: language.localized("パスを閉じる"))
                                metricRow(language.localized("対象"), value: language.localized("アクティブレイヤー"))
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
                            metricRow(language.localized("対象"), value: hasSelection ? language.localized("選択設定") : language.localized("レイヤー"))
                            metricRow("Offset X", value: "\(Int(transformPreviewOffset.width.rounded())) px")
                            metricRow("Offset Y", value: "\(Int(transformPreviewOffset.height.rounded())) px")
                            metricRow(language.localized("拡大率"), value: "\(Int((transformPreviewScale * 100).rounded()))%")
                            metricRow(language.localized("状態"), value: transformPreviewOffset == .zero ? language.localized("待機") : language.localized("未確定"))
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        store.brushColor.opacity(0.92),
                                        store.brushColor.opacity(0.22)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 122)
                            .overlay(
                                BrushStrokePreview(style: currentBrushPreviewStyle)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                            )

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(minimum: 90), spacing: 10),
                                GridItem(.flexible(minimum: 90), spacing: 10)
                            ],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            metricRow(language.localized("先端"), value: store.brushTipKind.localizedTitle(language))
                            metricRow(language.localized("半径"), value: "\(Int(store.brushRadius)) px")
                            metricRow(language.localized("形状"), value: "\(Int(store.brushRoundness * 100))%")
                            metricRow(language.localized("角度"), value: "\(Int((store.brushAngle * 180 / .pi).rounded()))°")
                            metricRow(language.localized("不透明"), value: "\(Int(store.brushOpacity * 100))%")
                            metricRow(language.localized("スタンプ間隔"), value: "\(Int(store.brushSpacing * 100))%")
                            metricRow(language.localized("散布"), value: store.brushScatterEnabled ? language.localized("オン") : language.localized("オフ"))
                            metricRow(language.localized("テクスチャ"), value: store.brushTextureMode.localizedTitle(language))
                            metricRow(language.localized("フロー"), value: "\(Int(store.brushFlow * 100))%")
                            metricRow(language.localized("紙質"), value: "\(Int(store.brushPaperStrength * 100))%")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func detailCard(showsChrome: Bool) -> some View {
        if currentTool != .select && currentTool != .move {
            cardContainer(showsChrome: showsChrome) {
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
                            Text(currentTool == .fill ? language.localized("塗り色") : (currentTool == .eyedropper ? language.localized("取得色") : language.localized("色")))
                                .font(StudioTheme.Typography.title(14))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(
                                currentTool == .fill
                                    ? (store.selectedBrush?.name ?? language.localized("カスタム"))
                                    : (currentTool == .eyedropper
                                        ? colorHexLabel
                                        : (store.selectedBrush?.name ?? "\(store.brushTipKind.localizedTitle(language)) \(language.localized("カスタム"))"))
                            )
                            .font(StudioTheme.Typography.body(11))
                            .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer(minLength: 0)
                    }

                    SpectrumColorControl(color: $store.brushColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(StudioTheme.Palette.hairline)
                        )

                    LazyVGrid(columns: paletteColumns, alignment: .leading, spacing: 8) {
                        ForEach(PaletteSwatch.defaults) { swatch in
                            colorSwatch(color: swatch.color, isSelected: false) {
                                store.send(.binding(.set(\.brushColor, swatch.color)))
                            }
                        }
                    }
                }
            }
        } else {
            cardContainer(showsChrome: showsChrome) {
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
                            Text(language.localized("選択設定"))
                                .font(StudioTheme.Typography.title(14))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(store.selectionToolMode == .lasso ? language.localized("Apple Pencil で囲んだあと、移動ツールで変形します") : language.localized("タップで選択したあと、移動ツールで変形します"))
                                .font(StudioTheme.Typography.body(11))
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    var panelTitle: String {
        switch currentTool {
        case .fill, .eyedropper, .select, .move:
            return currentTool.localizedTitle(language)
        default:
            return StudioToolKind.brush.localizedTitle(language)
        }
    }

    var currentBrushPreviewStyle: BrushPreviewStyle {
        BrushPreviewStyle(
            color: currentDetailPreviewColor,
            radius: store.brushRadius,
            opacity: store.brushOpacity,
            roundness: store.brushRoundness,
            angle: store.brushAngle,
            spacing: store.brushSpacing,
            scatterEnabled: store.brushScatterEnabled,
            scatterMode: store.brushScatterMode,
            scatterLateral: store.brushScatterLateral,
            scatterLinear: store.brushScatterLinear,
            count: Int(store.brushCount.rounded()),
            countSizeJitter: store.brushCountSizeJitter,
            countOpacityJitter: store.brushCountOpacityJitter,
            textureStrength: store.brushTextureStrength,
            flow: store.brushFlow
        )
    }

    var currentDetailPreviewColor: Color {
        let resolved = UIColor(store.brushColor)
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        if resolved.getWhite(&white, alpha: &alpha), white > 0.9 {
            return Color.black.opacity(0.88)
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        if luminance > 0.82 {
            return Color(
                red: Double(red * 0.28),
                green: Double(green * 0.28),
                blue: Double(blue * 0.28)
            )
        }

        return store.brushColor
    }

    var sectionTitle: String {
        switch currentTool {
        case .fill:
            return language.localized("塗りつぶし設定")
        case .eyedropper:
            return language.localized("スポイト設定")
        case .select:
            return language.localized("選択設定")
        case .move:
            return language.localized("変形")
        default:
            return language.localized("ブラシ設定")
        }
    }
}
