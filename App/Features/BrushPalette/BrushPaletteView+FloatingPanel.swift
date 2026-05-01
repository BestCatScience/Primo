import PrimoDocumentContracts
import PrimoDocumentPresentationContracts
import SwiftUI
import UIKit

extension BrushPaletteView {
    @ViewBuilder
    func floatingBrushSettingsPanel(proxy: GeometryProxy) -> some View {
        if currentTool == .brush || currentTool == .erase {
            compactBrushToolPanel(proxy: proxy)
                .simultaneousGesture(floatingPanelCloseGesture(edge: .bottom))
        } else {
            legacyFloatingBrushSettingsPanel(proxy: proxy)
                .simultaneousGesture(floatingPanelCloseGesture(edge: .leading))
        }
    }

    private enum FloatingPanelCloseEdge {
        case leading
        case bottom
    }

    private func floatingPanelCloseGesture(edge: FloatingPanelCloseEdge) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onEnded { value in
                let shouldClose: Bool
                switch edge {
                case .leading:
                    let horizontalTravel = min(value.translation.width, value.predictedEndTranslation.width)
                    shouldClose = abs(horizontalTravel) > abs(value.translation.height) * 1.25
                        && horizontalTravel < -28
                case .bottom:
                    let verticalTravel = max(value.translation.height, value.predictedEndTranslation.height)
                    shouldClose = abs(verticalTravel) > abs(value.translation.width) * 1.25
                        && verticalTravel > 24
                }

                if shouldClose {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        store.ui.showsBrushSettingsPopover = false
                    }
                }
            }
    }

    private func legacyFloatingBrushSettingsPanel(proxy: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            floatingPanelHeader
                .padding(.horizontal, floatingPanelHorizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    floatingPanelTopSection
                    floatingPanelCategoryStrip
                    floatingPanelCategoryContent(proxy: proxy)
                }
                .padding(.horizontal, floatingPanelHorizontalPadding)
                .padding(.bottom, 24)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StudioTheme.Gradients.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
        .studioWindowGlow(cornerRadius: 16, intensity: 0.52)
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
    }

    var floatingPanelIsWide: Bool {
        horizontalSizeClass == .regular && currentTool != .brush && currentTool != .erase
    }

    var floatingPanelHorizontalPadding: CGFloat {
        floatingPanelIsWide ? 24 : 18
    }

    var floatingPanelHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.library.selectedBrush?.name ?? currentTool.localizedTitle(language))
                    .font(StudioTheme.Typography.title(16))
                    .foregroundStyle(StudioTheme.Palette.textPrimary)
                Text(language.localized("ブラシの詳細設定"))
                    .font(StudioTheme.Typography.body(11))
                    .foregroundStyle(StudioTheme.Palette.textMuted)
            }

            Spacer(minLength: 0)
        }
    }

    func compactBrushToolPanel(proxy: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            compactBrushToolHeader
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    compactBrushPreviewCard
                    compactInspectorTabPicker
                    compactBrushToolContent(proxy: proxy)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StudioTheme.Gradients.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
        .studioWindowGlow(cornerRadius: 16, intensity: 0.52)
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
    }

    var compactBrushToolHeader: some View {
        HStack(spacing: 8) {
            Text(language.localized("ツール"))
                .font(StudioTheme.Typography.title(18))
                .foregroundStyle(StudioTheme.Palette.textPrimary)

            Spacer(minLength: 0)
        }
    }

    var compactBrushPreviewCard: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(currentTool == .erase ? StudioTheme.Palette.panelControl : StudioTheme.Palette.panelInset)
            .frame(height: 84)
            .overlay {
                ZStack {
                    if currentTool == .brush {
                        CompactPreviewCheckerboard(cornerRadius: 12)
                            .padding(1)
                    }

                    BrushStrokePreview(style: currentBrushPreviewStyle)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
    }

    var compactInspectorTabPicker: some View {
        HStack(spacing: 8) {
            ForEach(ToolInspectorTab.allCases) { tab in
                let isSelected = selectedToolInspectorTab == tab
                Button {
                    selectedToolInspectorTab = tab
                } label: {
                    Text(tab.localizedTitle(language))
                        .font(StudioTheme.Typography.title(14))
                        .foregroundStyle(isSelected ? StudioTheme.Palette.textPrimary : StudioTheme.Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? StudioTheme.Palette.selectedFill : StudioTheme.Palette.cardFillStrong)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    func compactBrushToolContent(proxy: GeometryProxy) -> some View {
        if selectedToolInspectorTab == .basic {
            compactBasicBrushControls
        } else {
            VStack(alignment: .leading, spacing: 12) {
                controlsCard(proxy: proxy, showsChrome: true)
                if currentTool == .brush {
                    detailCard(showsChrome: true)
                }
            }
        }
    }

    var compactBasicBrushControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            compactSliderRow(
                title: language.localized("ブラシサイズ"),
                value: "\(Int(store.brush.radius.rounded()))",
                slider: Slider(value: $store.brush.radius, in: 1...BrushPaletteFeature.maximumBrushRadius, step: 1)
            )

            compactSliderRow(
                title: language.localized("不透明度"),
                value: "\(Int((store.brush.opacity * 100).rounded()))",
                slider: Slider(value: $store.brush.opacity, in: 0.1...1.0)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(language.localized("ブラシタイプ"))
                    .font(StudioTheme.Typography.title(14))
                    .foregroundStyle(StudioTheme.Palette.textPrimary)

                HStack(spacing: 0) {
                    compactToolSwitchButton(tool: .brush)
                    compactToolSwitchButton(tool: .erase)
                }
                .padding(2)
                .background(
                    Capsule(style: .continuous)
                        .fill(StudioTheme.Palette.panelInset)
                )
            }

            compactSliderRow(
                title: language.localized("手ぶれ補正"),
                value: "\(Int((store.brush.stabilization * 100).rounded()))",
                slider: Slider(value: $store.brush.stabilization, in: 0.0...1.0)
            )
        }
    }

    func compactSliderRow<SliderView: View>(title: String, value: String, slider: SliderView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(StudioTheme.Typography.title(14))
                    .foregroundStyle(StudioTheme.Palette.textPrimary)

                Spacer(minLength: 0)

                Text(value)
                    .font(StudioTheme.Typography.title(14))
                    .foregroundStyle(StudioTheme.Palette.textSecondary)
                    .padding(.horizontal, 8)
                    .frame(minWidth: 48, minHeight: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(StudioTheme.Palette.panelInset)
                    )
            }

            slider
                .tint(StudioTheme.Palette.accentBright)
                .frame(minHeight: 28)
        }
    }

    func compactToolSwitchButton(tool: StudioToolKind) -> some View {
        let isSelected = currentTool == tool

        return Button {
            onSelectTool(tool)
        } label: {
            Text(tool.localizedTitle(language))
                .font(StudioTheme.Typography.title(14))
                .foregroundStyle(isSelected ? StudioTheme.Palette.textPrimary : StudioTheme.Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? StudioTheme.Palette.selectedFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var floatingPanelTopSection: some View {
        if floatingPanelIsWide {
            HStack(alignment: .top, spacing: 18) {
                floatingPanelPreviewCard
                    .frame(maxWidth: .infinity)
                floatingPanelPrimaryControls
                    .frame(width: 240)
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                floatingPanelPreviewCard
                floatingPanelPrimaryControls
            }
        }
    }

    var floatingPanelPreviewCard: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(StudioTheme.Palette.panelInset)
            .frame(height: floatingPanelIsWide ? 186 : 150)
            .overlay(
                BrushStrokePreview(style: currentBrushPreviewStyle)
                    .padding(.horizontal, floatingPanelIsWide ? 24 : 18)
                    .padding(.vertical, floatingPanelIsWide ? 18 : 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 6)
    }

    var floatingPanelPrimaryControls: some View {
        VStack(spacing: 14) {
            heroSliderRow(
                title: language.localized("ブラシサイズ"),
                value: String(format: "%.1f", store.brush.radius),
                slider: Slider(value: $store.brush.radius, in: 1...BrushPaletteFeature.maximumBrushRadius)
            )

            heroSliderRow(
                title: language.localized("不透明度"),
                value: "\(Int((store.brush.opacity * 100).rounded()))",
                slider: Slider(value: $store.brush.opacity, in: 0.1...1.0)
            )

            Button {
                store.send(.resetCurrentBrushSettingsButtonTapped)
            } label: {
                Text(language.localized("設定をリセット"))
                    .font(StudioTheme.Typography.title(14))
                    .foregroundStyle(StudioTheme.Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Capsule(style: .continuous)
                            .fill(StudioTheme.Palette.cardFillStrong)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, floatingPanelIsWide ? 4 : 0)
        .padding(.vertical, floatingPanelIsWide ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(floatingPanelIsWide ? StudioTheme.Palette.cardFill : Color.clear)
        )
    }

    var floatingPanelCategoryStrip: some View {
        HStack(spacing: 12) {
            ForEach(BrushSettingsCategory.allCases) { category in
                let isSelected = selectedBrushSettingsCategory == category
                Button {
                    selectedBrushSettingsCategory = category
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: category.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                        Text(category.localizedTitle(language))
                            .font(StudioTheme.Typography.mono(9))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? StudioTheme.Palette.textPrimary : StudioTheme.Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: floatingPanelIsWide ? 60 : 54)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? StudioTheme.Palette.selectedFill : StudioTheme.Palette.cardFillStrong)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    func floatingPanelCategoryContent(proxy: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            categorySummaryPills
            controlsCard(proxy: proxy, showsChrome: true, showsCategoryPicker: false)
            if selectedBrushSettingsCategory == .texture {
                detailCard(showsChrome: true)
            }
        }
        .padding(.top, 2)
    }

    var categorySummaryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                summaryPill(
                    title: language.localized("先端"),
                    value: store.brush.tipKind.localizedTitle(language)
                )
                summaryPill(
                    title: language.localized("硬さ"),
                    value: "\(Int((store.brush.hardness * 100).rounded()))%"
                )
                summaryPill(
                    title: language.localized("フロー"),
                    value: "\(Int((store.brush.flow * 100).rounded()))%"
                )
                summaryPill(
                    title: language.localized("散布"),
                    value: store.brush.scatterEnabled ? language.localized("オン") : language.localized("オフ")
                )
            }
            .padding(.vertical, 2)
        }
    }

    func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(StudioTheme.Typography.mono(9))
                .foregroundStyle(StudioTheme.Palette.textMuted)
            Text(value)
                .font(StudioTheme.Typography.title(12))
                .foregroundStyle(StudioTheme.Palette.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            Capsule(style: .continuous)
                .fill(StudioTheme.Palette.cardFillStrong)
        )
    }
}

private struct CompactPreviewCheckerboard: View {
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let tile: CGFloat = 10

            Canvas { context, size in
                let rows = Int(ceil(size.height / tile))
                let columns = Int(ceil(size.width / tile))

                for row in 0..<rows {
                    for column in 0..<columns {
                        let rect = CGRect(
                            x: CGFloat(column) * tile,
                            y: CGFloat(row) * tile,
                            width: tile,
                            height: tile
                        )
                        let color = (row + column).isMultiple(of: 2)
                            ? Color(red: 0.94, green: 0.94, blue: 0.94)
                            : Color(red: 0.84, green: 0.84, blue: 0.84)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
